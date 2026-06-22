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
  String agentABComparisonChoose(String option) {
    return 'Zvolit $option';
  }

  @override
  String agentABComparisonOption(String option) {
    return 'Možnost $option';
  }

  @override
  String agentABComparisonPrefer(String option) {
    return 'Dávám přednost možnosti $option';
  }

  @override
  String get agentBinaryChoiceNo => 'Ne';

  @override
  String get agentBinaryChoiceYes => 'Ano';

  @override
  String get agentCategoryRatingsScaleMax => 'Opravit první';

  @override
  String get agentCategoryRatingsScaleMin => 'Nechat být';

  @override
  String agentCategoryRatingsStarLabel(int starIndex, int totalStars) {
    return '$starIndex of $totalStars stars';
  }

  @override
  String get agentCategoryRatingsSubmit => 'Použít tyto priority';

  @override
  String get agentCategoryRatingsSubtitle =>
      'Jak důležité je, abych každou z těchto věcí opravil? 1 znamená nechat být, 5 znamená opravit jako první.';

  @override
  String get agentCategoryRatingsTitle => 'Pomoz mi s prioritami';

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
  String get agentConversationEmpty => 'Zatím žádné konverzace.';

  @override
  String agentConversationThreadSummary(
    int messageCount,
    int toolCallCount,
    String shortId,
  ) {
    return '$messageCount messages, $toolCallCount tool calls · $shortId';
  }

  @override
  String agentConversationTokenCount(String tokenCount) {
    return '$tokenCount tokenů';
  }

  @override
  String get agentDefaultProfileLabel => 'Výchozí inferenční profil';

  @override
  String agentDetailErrorLoading(String error) {
    return 'Chyba při načítání agenta: $error';
  }

  @override
  String get agentDetailNotFound => 'Agent nebyl nalezen.';

  @override
  String get agentDetailUnexpectedType => 'Neočekávaný typ entity.';

  @override
  String get agentEvolutionApprovalRate => 'Approval Rate';

  @override
  String get agentEvolutionChartMttrTrend => 'MTTR Trend';

  @override
  String get agentEvolutionChartSuccessRateTrend => 'Success Trend';

  @override
  String get agentEvolutionChartVersionPerformance => 'By Version';

  @override
  String get agentEvolutionChartWakeHistory => 'Wake History';

  @override
  String get agentEvolutionChatPlaceholder =>
      'Share feedback or ask about performance...';

  @override
  String get agentEvolutionCurrentDirectives => 'Current Directives';

  @override
  String get agentEvolutionDashboardTitle => 'Performance';

  @override
  String get agentEvolutionHistoryTitle => 'Evolution History';

  @override
  String get agentEvolutionMetricActive => 'Active';

  @override
  String get agentEvolutionMetricAvgDuration => 'Avg Duration';

  @override
  String get agentEvolutionMetricFailures => 'Failures';

  @override
  String get agentEvolutionMetricSuccess => 'Success';

  @override
  String get agentEvolutionMetricWakes => 'Wakes';

  @override
  String get agentEvolutionNoSessions => 'No evolution sessions yet';

  @override
  String get agentEvolutionNoteRecorded => 'Note Recorded';

  @override
  String get agentEvolutionProposalApprovalFailed =>
      'Approval failed — please try again';

  @override
  String get agentEvolutionProposalRationale => 'Rationale';

  @override
  String get agentEvolutionProposalRejected =>
      'Proposal rejected — continue the conversation';

  @override
  String get agentEvolutionProposalTitle => 'Proposed Changes';

  @override
  String get agentEvolutionProposedDirectives => 'Proposed Directives';

  @override
  String get agentEvolutionSessionAbandoned => 'Session ended without changes';

  @override
  String agentEvolutionSessionCompleted(int version) {
    return 'Session completed — version $version created';
  }

  @override
  String get agentEvolutionSessionCount => 'Sessions';

  @override
  String get agentEvolutionSessionError => 'Failed to start evolution session';

  @override
  String agentEvolutionSessionProgress(int sessionNumber, int totalSessions) {
    return 'Session $sessionNumber of $totalSessions';
  }

  @override
  String get agentEvolutionSessionStarting => 'Starting evolution session...';

  @override
  String agentEvolutionSessionTitle(int sessionNumber) {
    return 'Evolution #$sessionNumber';
  }

  @override
  String agentEvolutionSoulCurrentField(String field) {
    return 'Current — $field';
  }

  @override
  String agentEvolutionSoulProposedField(String field) {
    return 'Proposed — $field';
  }

  @override
  String get agentEvolutionStatusAbandoned => 'Abandoned';

  @override
  String get agentEvolutionStatusActive => 'Active';

  @override
  String get agentEvolutionStatusCompleted => 'Completed';

  @override
  String get agentEvolutionTimelineFeedbackLabel => 'Feedback';

  @override
  String get agentEvolutionVersionProposed => 'Version proposed';

  @override
  String get agentFeedbackCategoryAccuracy => 'Přesnost';

  @override
  String get agentFeedbackCategoryBreakdownTitle => 'Rozložení podle kategorií';

  @override
  String get agentFeedbackCategoryCommunication => 'Komunikace';

  @override
  String get agentFeedbackCategoryGeneral => 'Obecné';

  @override
  String get agentFeedbackCategoryPrioritization => 'Prioritizace';

  @override
  String get agentFeedbackCategoryTimeliness => 'Včasnost';

  @override
  String get agentFeedbackCategoryTooling => 'Nástroje';

  @override
  String get agentFeedbackClassificationTitle => 'Klasifikace zpětné vazby';

  @override
  String get agentFeedbackExcellenceTitle => 'Vynikající výkony';

  @override
  String get agentFeedbackGrievancesTitle => 'Stížnosti';

  @override
  String get agentFeedbackHighPriorityTitle => 'Vysoce prioritní zpětná vazba';

  @override
  String agentFeedbackItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count položek',
      few: '$count položky',
      one: '1 položka',
    );
    return '$_temp0';
  }

  @override
  String get agentFeedbackSourceDecision => 'Rozhodnutí';

  @override
  String get agentFeedbackSourceMetric => 'Metrika';

  @override
  String get agentFeedbackSourceObservation => 'Pozorování';

  @override
  String get agentFeedbackSourceRating => 'Hodnocení';

  @override
  String get agentInstancesEmptyFiltered =>
      'Žádné instance neodpovídají tvým filtrům.';

  @override
  String get agentInstancesFilterClearAll => 'Vymazat vše';

  @override
  String get agentInstancesFilterClearSection => 'Vymazat';

  @override
  String get agentInstancesFilterSectionSoul => 'Duše';

  @override
  String get agentInstancesFilterSectionStatus => 'Stav';

  @override
  String get agentInstancesFilterSectionType => 'Typ';

  @override
  String agentInstancesGroupActiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aktivních',
      few: '$count aktivní',
      one: '1 aktivní',
    );
    return '$_temp0';
  }

  @override
  String get agentInstancesGroupBySoul => 'Duše';

  @override
  String get agentInstancesGroupByStatus => 'Stav';

  @override
  String get agentInstancesGroupByType => 'Typ';

  @override
  String get agentInstancesKindEvolution => 'Evoluce';

  @override
  String get agentInstancesKindTaskAgent => 'Agent úkolů';

  @override
  String get agentInstancesPageTitle => 'Instance agentů';

  @override
  String agentInstancesResultCountAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count instancí',
      few: '$count instance',
      one: '1 instance',
    );
    return '$_temp0';
  }

  @override
  String agentInstancesResultCountFiltered(int filtered, int total) {
    return '$filtered z $total';
  }

  @override
  String get agentInstancesSearchClear => 'Vymazat hledání';

  @override
  String get agentInstancesSearchPlaceholder => 'Hledat instance…';

  @override
  String get agentInstancesSortName => 'Název';

  @override
  String get agentInstancesSortOldest => 'Nejstarší';

  @override
  String get agentInstancesSortRecent => 'Nejnovější';

  @override
  String get agentInstancesTitle => 'Instance';

  @override
  String get agentInstancesToolbarFilters => 'Filtry';

  @override
  String get agentInstancesToolbarGroupBy => 'Seskupit podle';

  @override
  String get agentInstancesUnassignedSoul => 'Nepřiřazeno';

  @override
  String get agentLifecycleActive => 'Aktivní';

  @override
  String get agentLifecycleCreated => 'Vytvořen';

  @override
  String get agentLifecycleDestroyed => 'Zničen';

  @override
  String get agentLifecycleDormant => 'Neaktivní';

  @override
  String get agentMessageKindAction => 'Akce';

  @override
  String get agentMessageKindMilestone => 'Milník';

  @override
  String get agentMessageKindObservation => 'Pozorování';

  @override
  String get agentMessageKindRetraction => 'Stažení';

  @override
  String get agentMessageKindSummary => 'Shrnutí';

  @override
  String get agentMessageKindSystem => 'Systém';

  @override
  String get agentMessageKindSystemPrompt => 'Systémový prompt';

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
  String agentPendingWakesActivityHourDetail(
    String hour,
    int count,
    String reasons,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count probuzení',
      one: '1 probuzení',
    );
    return '$hour: $_temp0 ($reasons)';
  }

  @override
  String get agentPendingWakesActivityTitle => 'Aktivita probuzení (24h)';

  @override
  String agentPendingWakesActivityTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count probuzení celkem',
      one: '1 probuzení celkem',
    );
    return '$_temp0';
  }

  @override
  String get agentPendingWakesDeleteTooltip => 'Odstranit probuzení';

  @override
  String get agentPendingWakesEmptyFiltered =>
      'Žádná probuzení neodpovídají tvým filtrům.';

  @override
  String get agentPendingWakesFilterSectionType => 'Typ';

  @override
  String get agentPendingWakesGroupByType => 'Typ';

  @override
  String get agentPendingWakesPendingLabel => 'Čekající';

  @override
  String agentPendingWakesRunningHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Právě běží ($count)',
      one: 'Právě běží',
    );
    return '$_temp0';
  }

  @override
  String get agentPendingWakesScheduledLabel => 'Naplánované';

  @override
  String get agentPendingWakesSearchPlaceholder => 'Hledat probuzení…';

  @override
  String get agentPendingWakesSortDueLatest => 'Spustí se nejpozději';

  @override
  String get agentPendingWakesSortDueSoonest => 'Spustí se nejdříve';

  @override
  String get agentPendingWakesTitle => 'Cykly probouzení';

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
  String get agentRitualReviewAction => 'Start Conversation';

  @override
  String get agentRitualReviewNegativeSignals => 'Negativní';

  @override
  String get agentRitualReviewNeutralSignals => 'Neutrální';

  @override
  String get agentRitualReviewNoFeedback =>
      'V tomto okně nejsou žádné signály zpětné vazby';

  @override
  String get agentRitualReviewNoNegativeSignals =>
      'V této záložce nejsou žádné negativní signály zpětné vazby';

  @override
  String get agentRitualReviewNoNeutralSignals =>
      'V této záložce nejsou žádné neutrální signály zpětné vazby';

  @override
  String get agentRitualReviewNoPositiveSignals =>
      'V této záložce nejsou žádné pozitivní signály zpětné vazby';

  @override
  String get agentRitualReviewPositiveSignals => 'Pozitivní';

  @override
  String get agentRitualReviewProposalSection => 'Current Proposal';

  @override
  String get agentRitualReviewSessionHistory => 'Session History';

  @override
  String get agentRitualReviewTitle => '1-on-1';

  @override
  String get agentRitualSummaryApprovedChangesHeading => 'Approved changes';

  @override
  String get agentRitualSummaryConversationHeading => 'Conversation';

  @override
  String get agentRitualSummaryRecapHeading => 'Session Recap';

  @override
  String get agentRitualSummaryRoleAssistant => 'Agent';

  @override
  String get agentRitualSummaryRoleUser => 'You';

  @override
  String get agentRitualSummaryStartHint =>
      'Start a 1-on-1 to review what bothered you, what worked, and what should change next.';

  @override
  String get agentRitualSummarySubtitle =>
      'Recent 1-on-1s, real wake activity, and the changes you agreed to.';

  @override
  String get agentRitualSummaryTokensSinceLast => 'Tokens since last 1-on-1';

  @override
  String get agentRitualSummaryWakeHistory30Days =>
      'Wake activity (last 30 days)';

  @override
  String get agentRitualSummaryWakesSinceLast => 'Wakes since last 1-on-1';

  @override
  String get agentRunningIndicator => 'Running';

  @override
  String get agentSessionProgressTitle => 'Session Progress';

  @override
  String get agentSettingsSubtitle => 'Templates, instances, and monitoring';

  @override
  String get agentSettingsTitle => 'Agents';

  @override
  String get agentSoulAntiSycophancyLabel => 'Zásady proti pochlebování';

  @override
  String get agentSoulAssignedTemplatesTitle => 'Přiřazené šablony';

  @override
  String get agentSoulAssignmentLabel => 'Duše';

  @override
  String get agentSoulCoachingStyleLabel => 'Styl koučování';

  @override
  String get agentSoulCreatedSuccess => 'Duše vytvořena';

  @override
  String get agentSoulCreateTitle => 'Vytvořit duši';

  @override
  String get agentSoulDeleteConfirmBody =>
      'Tím se odstraní duše a všechny její verze.';

  @override
  String get agentSoulDeleteConfirmTitle => 'Smazat duši';

  @override
  String get agentSoulDetailTitle => 'Detail duše';

  @override
  String get agentSoulDisplayNameLabel => 'Název';

  @override
  String get agentSoulEvolutionHistoryTitle => 'Historie vývoje duše';

  @override
  String get agentSoulEvolutionNoSessions => 'Zatím žádné relace vývoje duše';

  @override
  String get agentSoulFieldAntiSycophancy => 'Anti-Sycophancy';

  @override
  String get agentSoulFieldCoachingStyle => 'Coaching Style';

  @override
  String get agentSoulFieldToneBounds => 'Tone Bounds';

  @override
  String get agentSoulFieldVoice => 'Voice';

  @override
  String get agentSoulInfoTab => 'Info';

  @override
  String get agentSoulNoneAssigned => 'Žádná duše přiřazena';

  @override
  String get agentSoulNotFound => 'Duše nenalezena';

  @override
  String get agentSoulProposalSubtitle => 'Proposed personality changes';

  @override
  String get agentSoulProposalTitle => 'Soul Personality Proposal';

  @override
  String get agentSoulReviewHeroSubtitle =>
      'Uprav osobnost napříč všemi šablonami sdílejícími tuto duši. Agent pro vývoj vidí zpětnou vazbu z každé šablony, která tuto osobnost používá.';

  @override
  String get agentSoulReviewStartAction => 'Zahájit revizi osobnosti';

  @override
  String get agentSoulReviewStartHint =>
      'Zahaj relaci zaměřenou na osobnost, kde projdeš zpětnou vazbu a rozvineš hlas, tón, styl koučování a přímost.';

  @override
  String agentSoulReviewTemplateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count šablon sdílejících tuto duši',
      one: '1 šablona sdílející tuto duši',
    );
    return '$_temp0';
  }

  @override
  String get agentSoulReviewTitle => 'Duše 1-on-1';

  @override
  String get agentSoulRollbackAction => 'Vrátit na tuto verzi';

  @override
  String agentSoulRollbackConfirm(int version) {
    return 'Vrátit na verzi $version? Všechny šablony používající tuto duši budou ovlivněny.';
  }

  @override
  String get agentSoulSelectTitle => 'Vybrat duši';

  @override
  String get agentSoulsEmptyFiltered => 'Žádné duše neodpovídají tvým filtrům.';

  @override
  String get agentSoulSettingsTab => 'Nastavení';

  @override
  String get agentSoulsSearchPlaceholder => 'Hledat duše…';

  @override
  String get agentSoulsTitle => 'Duše';

  @override
  String get agentSoulToneBoundsLabel => 'Hranice tónu';

  @override
  String get agentSoulVersionHistoryTitle => 'Historie verzí';

  @override
  String agentSoulVersionLabel(int version) {
    return 'Verze $version';
  }

  @override
  String get agentSoulVersionSaved => 'Nová verze duše uložena';

  @override
  String get agentSoulVoiceDirectiveLabel => 'Hlasová direktiva';

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
  String get agentStatsAllDayLegend => 'Celý den';

  @override
  String get agentStatsAverageLabel => 'Průměr';

  @override
  String agentStatsByTimeLegend(String time) {
    return 'Denně do $time';
  }

  @override
  String get agentStatsCacheRateLabel => 'Míra cache';

  @override
  String get agentStatsDailyUsageHeading => 'Denní využití';

  @override
  String get agentStatsInputLabel => 'Vstup';

  @override
  String get agentStatsNoUsage =>
      'Za posledních 7 dní nebyla zaznamenána žádná spotřeba tokenů.';

  @override
  String get agentStatsOutputLabel => 'Výstup';

  @override
  String agentStatsSourceActiveFor(String duration) {
    return 'Aktivní po dobu $duration';
  }

  @override
  String get agentStatsSourceActivityHeading => 'Aktivita agentů';

  @override
  String agentStatsSourceWakes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count probuzení',
      few: '$count probuzení',
      one: '1 probuzení',
    );
    return '$_temp0';
  }

  @override
  String get agentStatsTabTitle => 'Statistiky';

  @override
  String get agentStatsThoughtsLabel => 'Myšlenky';

  @override
  String get agentStatsTodayLabel => 'Dnes';

  @override
  String get agentStatsTokensPerWakeLabel => 'Tokeny / probuzení';

  @override
  String get agentStatsTokensUnit => 'tokeny';

  @override
  String agentStatsUsageAboveAverage(String time) {
    return 'Dnes používáš více tokenů, než je obvyklé v $time.';
  }

  @override
  String agentStatsUsageBelowAverage(String time) {
    return 'Dnes používáš méně tokenů, než je obvyklé v $time.';
  }

  @override
  String get agentStatsWakesLabel => 'Probuzení';

  @override
  String get agentSuggestionTimeEntryUpdateCurrent => 'Aktuální';

  @override
  String get agentSuggestionTimeEntryUpdateNoChange => '(beze změny)';

  @override
  String get agentSuggestionTimeEntryUpdateProposed => 'Navrhované';

  @override
  String get agentSuggestionTimeEntryUpdateUnavailable =>
      'Původní záznam není k dispozici';

  @override
  String get agentTabActivity => 'Aktivita';

  @override
  String get agentTabConversations => 'Konverzace';

  @override
  String get agentTabObservations => 'Pozorování';

  @override
  String get agentTabReports => 'Zprávy';

  @override
  String get agentTabStats => 'Statistiky';

  @override
  String get agentTemplateAggregateTokenUsageHeading =>
      'Celkové využití tokenů';

  @override
  String get agentTemplateAssignedLabel => 'Template';

  @override
  String get agentTemplateCreatedSuccess => 'Template created';

  @override
  String get agentTemplateCreateTitle => 'Create Template';

  @override
  String get agentTemplateDeleteConfirm =>
      'Delete this template? This cannot be undone.';

  @override
  String get agentTemplateDeleteHasInstances =>
      'Cannot delete: active agents are using this template.';

  @override
  String get agentTemplateDisplayNameLabel => 'Name';

  @override
  String get agentTemplateEditTitle => 'Edit Template';

  @override
  String get agentTemplateEvolveApprove => 'Approve & Save';

  @override
  String get agentTemplateEvolveReject => 'Reject';

  @override
  String get agentTemplateGeneralDirectiveHint =>
      'Definuj osobnost, nástroje, cíle a styl interakce agenta...';

  @override
  String get agentTemplateGeneralDirectiveLabel => 'Obecná direktiva';

  @override
  String get agentTemplateInstanceBreakdownHeading => 'Rozpis podle instancí';

  @override
  String get agentTemplateKindDayAgent => 'Denní agent';

  @override
  String get agentTemplateKindEventAgent => 'Agent události';

  @override
  String get agentTemplateKindImprover => 'Zlepšovač šablon';

  @override
  String get agentTemplateKindProjectAgent => 'Agent projektu';

  @override
  String get agentTemplateKindTaskAgent => 'Agent úkolů';

  @override
  String get agentTemplateMetricsTotalWakes => 'Total Wakes';

  @override
  String get agentTemplateNoneAssigned => 'No template assigned';

  @override
  String get agentTemplateNoTemplates =>
      'No templates available. Create one in Settings first.';

  @override
  String get agentTemplateNotFound => 'Template not found';

  @override
  String get agentTemplateNoVersions => 'No versions';

  @override
  String get agentTemplateReportDirectiveHint =>
      'Definuj strukturu reportu, povinné sekce a pravidla formátování...';

  @override
  String get agentTemplateReportDirectiveLabel => 'Direktiva reportu';

  @override
  String get agentTemplateReportsEmpty => 'No reports yet.';

  @override
  String get agentTemplateReportsTab => 'Reporty';

  @override
  String get agentTemplateRollbackAction => 'Roll Back to This Version';

  @override
  String agentTemplateRollbackConfirm(int version) {
    return 'Roll back to version $version? The agent will use this version on its next wake.';
  }

  @override
  String get agentTemplateSaveNewVersion => 'Save';

  @override
  String get agentTemplateSelectTitle => 'Select Template';

  @override
  String get agentTemplatesEmptyFiltered =>
      'Žádné šablony neodpovídají tvým filtrům.';

  @override
  String get agentTemplateSettingsTab => 'Nastavení';

  @override
  String get agentTemplatesFilterSectionKind => 'Druh';

  @override
  String get agentTemplatesGroupByKind => 'Druh';

  @override
  String get agentTemplatesGroupNone => 'Vše';

  @override
  String get agentTemplatesSearchPlaceholder => 'Hledat šablony…';

  @override
  String get agentTemplateStatsTab => 'Statistiky';

  @override
  String get agentTemplateStatusActive => 'Active';

  @override
  String get agentTemplateStatusArchived => 'Archived';

  @override
  String get agentTemplatesTitle => 'Agent Templates';

  @override
  String get agentTemplateSwitchHint =>
      'To use a different template, destroy this agent and create a new one.';

  @override
  String get agentTemplateVersionHistoryTitle => 'Version History';

  @override
  String agentTemplateVersionLabel(int version) {
    return 'Version $version';
  }

  @override
  String get agentTemplateVersionSaved => 'New version saved';

  @override
  String get agentThreadReportLabel => 'Report produced during this wake';

  @override
  String get agentTokenUsageCachedTokens => 'Z mezipaměti';

  @override
  String get agentTokenUsageEmpty =>
      'Zatím nebyla zaznamenána žádná spotřeba tokenů.';

  @override
  String agentTokenUsageErrorLoading(String error) {
    return 'Nepodařilo se načíst spotřebu tokenů: $error';
  }

  @override
  String get agentTokenUsageHeading => 'Spotřeba tokenů';

  @override
  String get agentTokenUsageInputTokens => 'Vstup';

  @override
  String get agentTokenUsageModel => 'Model';

  @override
  String get agentTokenUsageOutputTokens => 'Výstup';

  @override
  String get agentTokenUsageThoughtsTokens => 'Úvahy';

  @override
  String get agentTokenUsageTotalTokens => 'Celkem';

  @override
  String get agentTokenUsageWakeCount => 'Probuzení';

  @override
  String get aggregationDailyAvg => 'Denní průměr';

  @override
  String get aggregationDailyMax => 'Denní maximum';

  @override
  String get aggregationDailySum => 'Denní součet';

  @override
  String get aggregationHourlySum => 'Hodinový součet';

  @override
  String get aggregationNone => 'Žádná';

  @override
  String get aiAssistantTitle => 'Generovat…';

  @override
  String get aiBatchToggleTooltip => 'Přepnout na standardní nahrávání';

  @override
  String get aiCapabilityChipImageGeneration => 'Generování obrázků';

  @override
  String get aiCapabilityChipImageRecognition => 'Rozpoznávání obrázků';

  @override
  String get aiCapabilityChipThinking => 'Uvažování';

  @override
  String get aiCapabilityChipTranscription => 'Přepis';

  @override
  String get aiCardEmptyProposals =>
      'Žádné otevřené návrhy · agent zde zobrazí nové změny';

  @override
  String aiCardHistoryToggle(int count) {
    return 'Historie · $count';
  }

  @override
  String get aiCardMenuActionDelete => 'Smazat';

  @override
  String get aiCardMenuActionEdit => 'Upravit';

  @override
  String get aiCardMenuTooltip => 'Další akce';

  @override
  String get aiCardOpenAgentInternals => 'Otevřít interní informace agenta';

  @override
  String get aiCardProposalConfirmed => 'Potvrzeno';

  @override
  String get aiCardProposalDismissed => 'Zamítnuto';

  @override
  String get aiCardProposalKindAdd => 'Přidat';

  @override
  String get aiCardProposalKindDue => 'Termín';

  @override
  String get aiCardProposalKindEstimate => 'Odhad';

  @override
  String get aiCardProposalKindLabel => 'Štítek';

  @override
  String get aiCardProposalKindPriority => 'Priorita';

  @override
  String get aiCardProposalKindRemove => 'Odstranit';

  @override
  String get aiCardProposalKindStatus => 'Stav';

  @override
  String get aiCardProposalKindUpdate => 'Aktualizovat';

  @override
  String get aiCardReadMore => 'Číst více';

  @override
  String get aiCardShowLess => 'Skrýt podrobnosti';

  @override
  String get aiCardTitle => 'Souhrn AI';

  @override
  String get aiChatMessageCopied => 'Zkopírováno do schránky';

  @override
  String get aiConfigFailedToLoadModelsGeneric =>
      'Nepodařilo se načíst modely. Prosím, zkuste to znovu.';

  @override
  String get aiConfigNoModelsAvailable =>
      'Žádné AI modely zatím nejsou konfigurovány. Prosím, přidejte je v nastavení.';

  @override
  String get aiConfigNoSuitableModelsAvailable =>
      'Žádný model nesplňuje požadavky pro tento prompt. Prosím, nakonfigurujte modely, které podporují požadované schopnosti.';

  @override
  String get aiConfigSelectProviderModalTitle =>
      'Vyberte poskytovatele inferencí';

  @override
  String get aiConfigSelectProviderTypeModalTitle =>
      'Vyberte typ poskytovatele';

  @override
  String get aiConfigUseReasoningFieldLabel => 'Použít uvažování';

  @override
  String aiDeleteToastCascadeDescription(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Odebráno také $count modelů: $names',
      few: 'Odebrány také $count modely: $names',
      one: 'Odebrán také 1 model: $names',
    );
    return '$_temp0';
  }

  @override
  String aiDeleteToastErrorTitle(String name) {
    return 'Nepodařilo se smazat $name';
  }

  @override
  String get aiDeleteToastModelTitle => 'Model smazán';

  @override
  String get aiDeleteToastProfileTitle => 'Profil smazán';

  @override
  String get aiDeleteToastPromptTitle => 'Prompt smazán';

  @override
  String get aiDeleteToastProviderTitle => 'Poskytovatel smazán';

  @override
  String get aiDeleteToastSkillTitle => 'Dovednost smazána';

  @override
  String get aiDeleteToastUndoAction => 'Zpět';

  @override
  String get aiFormCancel => 'Zrušit';

  @override
  String get aiFormFixErrors => 'Prosím, opravte chyby před uložením';

  @override
  String get aiFormNoChanges => 'Žádné neuložené změny';

  @override
  String get aiImageAnalysisPickerDefaultBadge => 'Výchozí';

  @override
  String get aiImageAnalysisPickerTitle => 'Vyber model pro analýzu obrázků';

  @override
  String get aiImageGenerationPickerTitle =>
      'Vyber model pro generování obrázků';

  @override
  String get aiInferenceErrorAuthenticationTitle => 'Autentizace selhala';

  @override
  String get aiInferenceErrorConnectionFailedTitle => 'Připojení selhalo';

  @override
  String get aiInferenceErrorInvalidRequestTitle => 'Neplatný požadavek';

  @override
  String get aiInferenceErrorRateLimitTitle => 'Limit rychlosti překročen';

  @override
  String get aiInferenceErrorRetryButton => 'Zkusit znovu';

  @override
  String get aiInferenceErrorServerTitle => 'Chyba serveru';

  @override
  String get aiInferenceErrorSuggestionsTitle => 'Návrhy:';

  @override
  String get aiInferenceErrorTimeoutTitle => 'Požadavek vypršel';

  @override
  String get aiInferenceErrorUnknownTitle => 'Chyba';

  @override
  String get aiInternalsTitle => 'Interní informace agenta';

  @override
  String get aiModelDownloadCloseButton => 'Zavřít';

  @override
  String aiModelDownloadDialogDescription(String modelName) {
    return 'Lotti stáhne $modelName do cache MLX Audio a použije ho pro lokální zpracování řeči.';
  }

  @override
  String aiModelDownloadDialogTitle(String modelName) {
    return 'Instalovat $modelName';
  }

  @override
  String get aiModelDownloadInstallTooltip => 'Instalovat model';

  @override
  String get aiModelDownloadOpenProgressTooltip => 'Zobrazit průběh stahování';

  @override
  String get aiModelDownloadStatusChecking => 'Kontroluje se stav modelu';

  @override
  String aiModelDownloadStatusDownloading(int percent) {
    return 'Stahování $percent %';
  }

  @override
  String get aiModelDownloadStatusDownloadingIndeterminate => 'Stahování';

  @override
  String get aiModelDownloadStatusFailed => 'Stahování selhalo';

  @override
  String get aiModelDownloadStatusInstalled => 'Nainstalováno';

  @override
  String get aiModelDownloadStatusNotInstalled => 'Nenainstalováno';

  @override
  String get aiModelDownloadStatusUnsupported => 'Vyžaduje Apple Silicon';

  @override
  String get aiModelInstallChoiceCancelButton => 'Zrušit';

  @override
  String get aiModelInstallChoiceDescription =>
      'Nejdřív vyber lokální model pro převod řeči na text, který se má stáhnout. Ostatní můžeš nainstalovat později ze seznamu modelů.';

  @override
  String get aiModelInstallChoiceInstallButton => 'Instalovat model';

  @override
  String get aiModelInstallChoiceRecommended => 'Doporučeno';

  @override
  String get aiModelInstallChoiceTitle => 'Vybrat model MLX Audio';

  @override
  String get aiModelPickerByProviderLabel => 'Vyber poskytovatele';

  @override
  String get aiModelPickerCurrentDefaultLabel => 'Aktuální výchozí';

  @override
  String aiModelPickerProviderModelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modelů',
      few: '$count modely',
      one: '1 model',
    );
    return '$_temp0';
  }

  @override
  String aiOllamaModelInstalledSuccessfully(String modelName) {
    return 'Model „$modelName“ byl úspěšně nainstalován';
  }

  @override
  String get aiPickProviderBadgeDesktopOnly => 'POUZE DESKTOP';

  @override
  String get aiPickProviderBadgeNew => 'NOVÉ';

  @override
  String get aiPickProviderBadgeRecommended => 'DOPORUČENO';

  @override
  String get aiPickProviderContinueButton => 'Pokračovat';

  @override
  String get aiPickProviderDontShowAgainButton => 'Příště nezobrazovat';

  @override
  String get aiPickProviderFooterHint =>
      'Další poskytovatele můžeš přidat později v Nastavení → AI. Tvůj API klíč je uložen lokálně.';

  @override
  String get aiPickProviderModalTitle => 'Nastav AI funkce';

  @override
  String get aiPickProviderSubtitle =>
      'Vyber poskytovatele a začni. Modely a počáteční profil nastavíme automaticky.';

  @override
  String get aiProfileCardActiveBadge => 'Aktivní';

  @override
  String get aiProfileModelPickerSearchHint => 'Hledat modely…';

  @override
  String get aiProfileSlotModelMissing => 'chybí';

  @override
  String get aiPromptGenerationPickerTitle =>
      'Vyber model pro generování promptů';

  @override
  String get aiProviderAlibabaDescription =>
      'Rodina modelů Qwen od Alibaba Cloud přes DashScope API';

  @override
  String get aiProviderAlibabaName => 'Alibaba Cloud (Qwen)';

  @override
  String get aiProviderAnthropicDescription =>
      'Rodina AI asistentů Claude od Anthropic';

  @override
  String get aiProviderAnthropicName => 'Anthropic Claude';

  @override
  String get aiProviderCardDraftBadge => 'KONCEPT';

  @override
  String get aiProviderCardFixButton => 'Opravit';

  @override
  String aiProviderCardModelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modelů',
      few: '$count modely',
      one: '1 model',
    );
    return '$_temp0';
  }

  @override
  String aiProviderCardModelCountWithLastUsed(int count, String lastUsed) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modelů · naposledy použito $lastUsed',
      few: '$count modely · naposledy použity $lastUsed',
      one: '1 model · naposledy použit $lastUsed',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderCardOllamaHint => 'Ujisti se, že Ollama běží';

  @override
  String aiProviderCardStatusConnected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Připojeno · $count modelů',
      few: 'Připojeno · $count modely',
      one: 'Připojeno · 1 model',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderCardStatusConnectedShort => 'Připojeno';

  @override
  String get aiProviderCardStatusInvalidKey => 'Neplatný klíč';

  @override
  String get aiProviderCardStatusOffline =>
      'Offline · Ujisti se, že Ollama běží';

  @override
  String get aiProviderCardStatusOfflineShort => 'Offline';

  @override
  String get aiProviderConnectBackToProviders => 'Zpět na poskytovatele';

  @override
  String get aiProviderConnectBreadcrumbAdd => 'Přidat poskytovatele';

  @override
  String get aiProviderConnectFieldBaseUrlHint =>
      'Ponech prázdné pro použití oficiálního koncového bodu';

  @override
  String get aiProviderConnectFieldBaseUrlLabelOptional =>
      'Základní URL (volitelné)';

  @override
  String get aiProviderConnectFieldBaseUrlPlaceholder =>
      'https://api.example.com';

  @override
  String get aiProviderConnectFieldDisplayNameHint =>
      'Zobrazí se v tvém seznamu poskytovatelů';

  @override
  String get aiProviderConnectionCheckingLabel =>
      'Ověřuji klíč, načítám dostupné modely…';

  @override
  String aiProviderConnectionFailedBadResponseDetail(String type) {
    return 'Neočekávaný tvar odpovědi: $type';
  }

  @override
  String aiProviderConnectionFailedHttpDetail(int status, String message) {
    return 'HTTP $status · $message';
  }

  @override
  String get aiProviderConnectionFailedInvalidBaseUrlDetail =>
      'Základní URL musí obsahovat schéma http(s) a hostitele (např. https://api.example.com)';

  @override
  String aiProviderConnectionFailedNetworkDetail(String message) {
    return '$message';
  }

  @override
  String get aiProviderConnectionFailedTimeoutDetail => 'Požadavek vypršel';

  @override
  String aiProviderConnectionFailedTitle(String providerName) {
    return 'Nelze se připojit k $providerName. Zkontroluj klíč nebo síť.';
  }

  @override
  String get aiProviderConnectionRetestButton => 'Otestovat znovu';

  @override
  String get aiProviderConnectionRetryButton => 'Zkusit znovu';

  @override
  String aiProviderConnectionVerifiedSubtitle(int count, int ms) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modelů dostupných na tvém účtu · odpověď za $ms ms',
      few: '$count modely dostupné na tvém účtu · odpověď za $ms ms',
      one: '1 model dostupný na tvém účtu · odpověď za $ms ms',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderConnectionVerifiedTitle => 'Připojení ověřeno';

  @override
  String aiProviderConnectKeyHelperLink(String url) {
    return 'Klíč získáš na $url';
  }

  @override
  String get aiProviderConnectKeyHiddenLabel => 'Skryto';

  @override
  String get aiProviderConnectKeyPrivacyHint =>
      'Tvůj API klíč nikdy neopustí toto zařízení.';

  @override
  String aiProviderConnectPageTitle(String providerName) {
    return 'Připojit $providerName';
  }

  @override
  String get aiProviderConnectSaveAndContinue => 'Uložit a pokračovat';

  @override
  String get aiProviderConnectSaveAsDraft => 'Uložit jako koncept';

  @override
  String get aiProviderConnectSavedAsDraftToast => 'Uloženo jako koncept';

  @override
  String get aiProviderConnectStepChoose => 'Vyber poskytovatele';

  @override
  String get aiProviderConnectStepConnect => 'Připojit';

  @override
  String get aiProviderConnectStepReview => 'Zkontrolovat';

  @override
  String get aiProviderDetailActiveProfileTitle => 'Aktivní profil';

  @override
  String get aiProviderDetailAddModelButton => 'Přidat model';

  @override
  String get aiProviderDetailApiKeyLabel => 'API klíč';

  @override
  String get aiProviderDetailBackTooltip => 'Zpět';

  @override
  String get aiProviderDetailBaseUrlLabel => 'Základní URL';

  @override
  String get aiProviderDetailConnectionTitle => 'Připojení';

  @override
  String get aiProviderDetailDangerZoneTitle => 'Nebezpečná zóna';

  @override
  String get aiProviderDetailDisplayNameLabel => 'Zobrazované jméno';

  @override
  String get aiProviderDetailEditButton => 'Upravit';

  @override
  String get aiProviderDetailEditTooltip => 'Upravit poskytovatele';

  @override
  String get aiProviderDetailLoadError =>
      'Poskytovatele se nepodařilo načíst. Zkus to znovu z nastavení AI.';

  @override
  String get aiProviderDetailMissingMessage =>
      'Tento poskytovatel již není dostupný.';

  @override
  String aiProviderDetailModelsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Modelů · $count',
      many: 'Modelů · $count',
      few: 'Modely · $count',
      one: 'Model · 1',
      zero: 'Modely',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderDetailNoModelsMessage =>
      'Zatím žádné modely. Přidej jeden, abys mohl tohoto poskytovatele používat.';

  @override
  String get aiProviderDetailPageTitle => 'Detail poskytovatele';

  @override
  String get aiProviderDetailRemoveButton => 'Odstranit poskytovatele';

  @override
  String get aiProviderDetailRemoveDescription =>
      'Smaže poskytovatele a všechny modely, které jej používají. Tuto akci nelze vrátit.';

  @override
  String get aiProviderDetailRemoveTitle => 'Odstranit tohoto poskytovatele';

  @override
  String get aiProviderDetailValueUnset => 'Nenastaveno';

  @override
  String get aiProviderEmbeddedRuntimeHint =>
      'Běží přímo v procesu aplikace Apple. Není potřeba lokální server ani základní URL.';

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
  String get aiProviderMeliousDescription =>
      'Inference hostovaná v Evropě s dynamickým katalogem modelů, směrováním, zvukem a obrázky';

  @override
  String get aiProviderMeliousName => 'Melious.ai';

  @override
  String get aiProviderMistralDescription =>
      'Mistral AI cloudové API s nativním přepisem zvuku';

  @override
  String get aiProviderMistralName => 'Mistral';

  @override
  String get aiProviderMlxAudioDescription =>
      'Vestavěné modely MLX Audio pro lokální STT a TTS na Apple Silicon';

  @override
  String get aiProviderMlxAudioName => 'MLX Audio (lokálně)';

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
  String get aiProviderOmlxDescription =>
      'Lokální inference oMLX kompatibilní s OpenAI pro modely MLX';

  @override
  String get aiProviderOmlxName => 'oMLX (lokálně)';

  @override
  String get aiProviderOpenAiDescription => 'GPT modely od OpenAI';

  @override
  String get aiProviderOpenAiName => 'OpenAI';

  @override
  String get aiProviderOpenRouterDescription => 'Modely OpenRouter';

  @override
  String get aiProviderOpenRouterName => 'OpenRouter';

  @override
  String get aiProviderSelectContinue => 'Pokračovat';

  @override
  String get aiProviderSelectDontShowAgain => 'Příště nezobrazovat';

  @override
  String get aiProviderSetupOptionGeminiDescription =>
      'Multimodální modely s přepisem zvuku. Vyžaduje API klíč.';

  @override
  String get aiProviderSetupOptionMistralDescription =>
      'Evropská AI s uvažováním (Magistral) a zvukem (Voxtral).';

  @override
  String get aiProviderSetupOptionOpenAiDescription =>
      'GPT modely pro chat a uvažování. Vyžaduje API klíč s kreditem.';

  @override
  String get aiProviderTaglineAlibaba =>
      'Modely Qwen · multimodální · dlouhý kontext';

  @override
  String get aiProviderTaglineAnthropic => 'Rodina Claude · dlouhý kontext';

  @override
  String get aiProviderTaglineGemini => 'Multimodální · přepis zvuku';

  @override
  String get aiProviderTaglineMelious =>
      'Hostováno v EU · dynamický katalog · eko směrování';

  @override
  String get aiProviderTaglineMlxAudio =>
      'Vestavěné · Apple Silicon · lokální audio';

  @override
  String get aiProviderTaglineOllama => 'Běží lokálně · bez cloudových volání';

  @override
  String get aiProviderTaglineOmlx =>
      'Lokální MLX inference · kompatibilní s OpenAI';

  @override
  String get aiProviderTaglineOpenAi => 'Rodina GPT · vize + uvažování';

  @override
  String get aiProviderUnknownName => 'AI poskytovatel';

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
  String get aiRunningActivityOpenProgress => 'Zobrazit průběh AI';

  @override
  String get aiSettingsAddedLabel => 'Přidáno';

  @override
  String get aiSettingsAddModelButton => 'Přidat model';

  @override
  String get aiSettingsAddModelTooltip =>
      'Přidat tento model ke svému poskytovateli';

  @override
  String get aiSettingsAddProfileButton => 'Přidat profil';

  @override
  String get aiSettingsAddProviderButton => 'Přidat poskytovatele';

  @override
  String get aiSettingsClearAllFiltersTooltip => 'Vymazat všechny filtry';

  @override
  String get aiSettingsClearFiltersButton => 'Vymazat';

  @override
  String get aiSettingsCounterModels => 'Modely';

  @override
  String get aiSettingsCounterProfiles => 'Profily';

  @override
  String get aiSettingsCounterProviders => 'Poskytovatelé';

  @override
  String get aiSettingsEmptyDescription =>
      'Přidej jednoho a odemkni přepis, rozpoznávání obrázků, generování obrázků a sémantické vyhledávání.';

  @override
  String get aiSettingsEmptyTitle => 'Zatím žádní poskytovatelé';

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
  String get aiSettingsFtueBannerDescription =>
      'Trvá asi minutu. Lotti za tebe nastaví modely a počáteční profil.';

  @override
  String get aiSettingsFtueBannerStartButton => 'Spustit nastavení';

  @override
  String get aiSettingsFtueBannerTitle =>
      'Přidej svého prvního AI poskytovatele';

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
  String get aiSettingsNoProvidersConfigured =>
      'Nejsou nakonfigurovány žádní poskytovatelé AI';

  @override
  String get aiSettingsPageLead =>
      'Nakonfiguruj AI poskytovatele, modely, které Lotti může volat, a inferenční profily, které rozhodují, který model zpracovává který úkol.';

  @override
  String get aiSettingsPageTitle => 'Nastavení AI';

  @override
  String get aiSettingsReasoningLabel => 'Uvažování';

  @override
  String get aiSettingsSearchHint => 'Hledat poskytovatele, modely, profily...';

  @override
  String get aiSettingsSearchHintShort => 'Hledat';

  @override
  String get aiSettingsTabModels => 'Modely';

  @override
  String get aiSettingsTabProfiles => 'Profily';

  @override
  String get aiSettingsTabProviders => 'Poskytovatelé';

  @override
  String get aiSetupPreviewAcceptButton => 'Přijmout a dokončit';

  @override
  String get aiSetupPreviewAlreadyAddedSectionLabel => 'Již přidané';

  @override
  String aiSetupPreviewCategoryFooter(String categoryName) {
    return 'Vytvořit testovací kategorii $categoryName pro vyzkoušení.';
  }

  @override
  String aiSetupPreviewConnectedHeader(String providerName) {
    return '$providerName připojeno';
  }

  @override
  String get aiSetupPreviewCustomizeButton => 'Přizpůsobit';

  @override
  String get aiSetupPreviewLead =>
      'Zkontroluj, co Lotti přidá. Odškrtni, co nechceš — vždy to můžeš nastavit ručně později.';

  @override
  String get aiSetupPreviewLiveBadge => 'Živě';

  @override
  String aiSetupPreviewModalTitle(String providerName) {
    return 'Nastavení $providerName';
  }

  @override
  String get aiSetupPreviewModelsSectionLabel => 'Modely';

  @override
  String get aiSetupPreviewProfileSectionLabel => 'Inferenční profil';

  @override
  String get aiSetupPreviewProfileSetActiveBadge => 'Aktivovat';

  @override
  String aiSetupResultBulletCategoryCreated(String categoryName) {
    return 'Vytvořena testovací kategorie $categoryName';
  }

  @override
  String aiSetupResultBulletCategoryReused(String categoryName) {
    return 'Použije se existující testovací kategorie $categoryName';
  }

  @override
  String aiSetupResultBulletModels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nakonfigurováno $count modelů',
      few: 'Nakonfigurovány $count modely',
      one: 'Nakonfigurován 1 model',
    );
    return '$_temp0';
  }

  @override
  String aiSetupResultBulletProfile(String profileName) {
    return 'Vytvořen inferenční profil $profileName';
  }

  @override
  String aiSetupResultErrorsHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count problémů',
      few: '$count problémy',
      one: '1 problém',
    );
    return '$_temp0 při nastavení';
  }

  @override
  String aiSetupResultHeader(String providerName) {
    return '$providerName je připojeno';
  }

  @override
  String aiSetupResultKnownModelsMissing(String providerName) {
    return 'Nepodařilo se najít požadované konfigurace modelů pro $providerName';
  }

  @override
  String get aiSetupResultLead =>
      'Vše jsme za tebe nastavili. Funkce AI jsou připraveny v tvém deníku.';

  @override
  String aiSetupResultModalTitle(String providerName) {
    return '$providerName připraveno';
  }

  @override
  String get aiSetupResultStartUsingButton => 'Začít používat AI';

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
  String get aiSummaryPlayTooltip => 'Přečíst shrnutí';

  @override
  String get aiSummaryPreparingTooltip => 'Příprava zvuku';

  @override
  String get aiSummarySpeakTooltip => 'Přečíst souhrn nahlas lokálně';

  @override
  String get aiSummaryStopTooltip => 'Zastavit';

  @override
  String get aiSummaryThinkingLabel => 'Přemýšlí…';

  @override
  String get aiSummaryTtsUnavailable => 'Předčítání není k dispozici';

  @override
  String get aiTaskSummaryTitle => 'Shrnutí úkolu AI';

  @override
  String get aiTranscriptionPickerDefaultBadge => 'Výchozí';

  @override
  String get aiTranscriptionPickerTitle => 'Vyber model pro přepis';

  @override
  String get apiKeyAddPageTitle => 'Přidat poskytovatele';

  @override
  String get apiKeyAuthenticationDescription => 'Zabezpeč své připojení k API';

  @override
  String get apiKeyAuthenticationTitle => 'Ověření';

  @override
  String get apiKeyAvailableModelsDescription =>
      'Rychle přidej předkonfigurované modely pro tohoto poskytovatele';

  @override
  String get apiKeyAvailableModelsTitle => 'Dostupné modely';

  @override
  String get apiKeyBaseUrlLabel => 'Základní URL';

  @override
  String get apiKeyDisplayNameHint => 'Zadej přívětivý název';

  @override
  String get apiKeyDisplayNameLabel => 'Zobrazovaný název';

  @override
  String get apiKeyEditGoBackButton => 'Zpět';

  @override
  String get apiKeyEditLoadError =>
      'Nepodařilo se načíst konfiguraci API klíče';

  @override
  String get apiKeyEditLoadErrorRetry =>
      'Zkus to prosím znovu nebo kontaktuj podporu';

  @override
  String get apiKeyEditPageTitle => 'Upravit poskytovatele';

  @override
  String get apiKeyHideTooltip => 'Skrýt API klíč';

  @override
  String get apiKeyInputHint => 'Zadej svůj API klíč';

  @override
  String get apiKeyInputLabel => 'API klíč';

  @override
  String apiKeyKnownModelInputLabel(String modalities) {
    return 'Vstup: $modalities';
  }

  @override
  String apiKeyKnownModelOutputLabel(String modalities) {
    return 'Výstup: $modalities';
  }

  @override
  String get apiKeyProviderConfigDescription =>
      'Nakonfiguruj nastavení poskytovatele AI inference';

  @override
  String get apiKeyProviderConfigTitle => 'Konfigurace poskytovatele';

  @override
  String get apiKeyProviderTypeHint => 'Vyber typ poskytovatele';

  @override
  String get apiKeyProviderTypeLabel => 'Typ poskytovatele';

  @override
  String get apiKeyShowTooltip => 'Zobrazit API klíč';

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
  String backfillAdvancedRecoveryActions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count akcí',
      few: '$count akce',
      one: '1 akce',
    );
    return '$_temp0';
  }

  @override
  String get backfillAdvancedRecoveryTitle => 'Pokročilé obnovení';

  @override
  String get backfillAskPeersConfirmAccept => 'Zeptat se peerů';

  @override
  String backfillAskPeersConfirmContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Toto vrátí všech $count neřešitelných záznamů sekvenčního logu zpět na chybějící, aby se normální backfill znovu zeptal peerů. Peeři, kteří data stále mají, odpoví; skutečně neobnovitelné záznamy se znovu stáhnou po 7denní amnestii.',
      few:
          'Toto vrátí všechny $count neřešitelné záznamy sekvenčního logu zpět na chybějící, aby se normální backfill znovu zeptal peerů. Peeři, kteří data stále mají, odpoví; skutečně neobnovitelné záznamy se znovu stáhnou po 7denní amnestii.',
      one:
          'Toto vrátí 1 neřešitelný záznam sekvenčního logu zpět na chybějící, aby se normální backfill znovu zeptal peerů. Peeři, kteří data stále mají, odpoví; skutečně neobnovitelné záznamy se znovu stáhnou po 7denní amnestii.',
    );
    return '$_temp0';
  }

  @override
  String get backfillAskPeersConfirmTitle =>
      'Zeptat se peerů znovu na neřešitelné záznamy?';

  @override
  String get backfillAskPeersDescription =>
      'Vrátí každý neřešitelný záznam sekvenčního logu zpět na chybějící a nechá normální backfill znovu se zeptat peerů.';

  @override
  String get backfillAskPeersProcessing => 'Znovu otevírám…';

  @override
  String get backfillAskPeersTitle => 'Zeptat se peerů na neřešitelné';

  @override
  String backfillAskPeersTrigger(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zeptat se peerů na $count záznamů',
      few: 'Zeptat se peerů na $count záznamy',
      one: 'Zeptat se peerů na 1 záznam',
    );
    return '$_temp0';
  }

  @override
  String get backfillCatchUpDescription =>
      'Stáhni od peerů nedávné chybějící položky hned teď.';

  @override
  String backfillDevicesMeta(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zařízení',
      few: '$count zařízení',
      one: '1 zařízení',
    );
    return '$_temp0';
  }

  @override
  String get backfillManualDescription =>
      'Požádejte o všechny chybějící záznamy bez ohledu na jejich stáří. Použijte toto pro obnovení starších mezer ve synchronizaci.';

  @override
  String get backfillManualProcessing => 'Probíhá zpracování...';

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
  String get backfillReRequestTitle => 'Znovu požádat o čekající';

  @override
  String get backfillReRequestTrigger => 'Požádat znovu o čekající položky';

  @override
  String get backfillResetUnresolvableDescription =>
      'Resetuje záznamy označené jako neřešitelné zpět na chybějící, aby mohly být znovu požadovány. Použijte po opětovném naplnění sekvenčního logu.';

  @override
  String get backfillResetUnresolvableProcessing => 'Resetování...';

  @override
  String get backfillResetUnresolvableTitle => 'Resetovat neřešitelné';

  @override
  String get backfillResetUnresolvableTrigger =>
      'Resetovat neřešitelné záznamy';

  @override
  String get backfillRetireStuckConfirmAccept => 'Vyřadit nyní';

  @override
  String backfillRetireStuckConfirmContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Označí $count aktuálně otevřených (chybějících nebo požadovaných) záznamů sekvenčního logu jako neřešitelných. Použij k odblokování watermarku, když jsou záznamy zaseknuté, aniž by uplynulo 7denní okno amnestie. Záznamy lze později vzkřísit, pokud jejich data dorazí na disk s platnými vektorovými hodinami.',
      few:
          'Označí $count aktuálně otevřené (chybějící nebo požadované) záznamy sekvenčního logu jako neřešitelné. Použij k odblokování watermarku, když jsou záznamy zaseknuté, aniž by uplynulo 7denní okno amnestie. Záznamy lze později vzkřísit, pokud jejich data dorazí na disk s platnými vektorovými hodinami.',
      one:
          'Označí 1 aktuálně otevřený (chybějící nebo požadovaný) záznam sekvenčního logu jako neřešitelný. Použij k odblokování watermarku, když jsou záznamy zaseknuté, aniž by uplynulo 7denní okno amnestie. Záznamy lze později vzkřísit, pokud jejich data dorazí na disk s platnými vektorovými hodinami.',
    );
    return '$_temp0';
  }

  @override
  String get backfillRetireStuckConfirmTitle =>
      'Vyřadit zaseknuté záznamy nyní?';

  @override
  String get backfillRetireStuckDescription =>
      'Vynutí, aby se každý aktuálně otevřený chybějící nebo požadovaný záznam sekvenčního logu stal neřešitelným. Přeskakuje 7denní amnestii — používej jen pro zaseknuté řádky blokující watermark.';

  @override
  String get backfillRetireStuckProcessing => 'Vyřazování…';

  @override
  String get backfillRetireStuckTitle => 'Vyřadit zaseknuté záznamy';

  @override
  String backfillRetireStuckTrigger(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vyřadit $count zaseknutých záznamů',
      few: 'Vyřadit $count zaseknuté záznamy',
      one: 'Vyřadit 1 zaseknutý záznam',
    );
    return '$_temp0';
  }

  @override
  String get backfillSettingsSubtitle => 'Správa obnovy mezer v synchronizaci';

  @override
  String get backfillSettingsTitle => 'Synchronizace doplnění';

  @override
  String get backfillStatsBackfilled => 'Doplněno';

  @override
  String get backfillStatsBurned => 'Anulováno';

  @override
  String get backfillStatsDeleted => 'Smazáno';

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
  String get backfillStatusInboundQueue => 'Příchozí fronta';

  @override
  String get backfillStatusMissing => 'Chybí';

  @override
  String get backfillStatusSkipped => 'Přeskočeno';

  @override
  String get backfillToggleDescription =>
      'Žádá o chybějící položky za posledních 24 hodin.';

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
  String get categoryActiveSwitchDescription => 'Volitelné pro nové záznamy';

  @override
  String get categoryAiDefaultsDescription =>
      'Nastavte výchozí AI profil a šablonu agenta pro nové úkoly v této kategorii';

  @override
  String get categoryAiDefaultsTitle => 'Výchozí hodnoty AI';

  @override
  String get categoryCreationError => 'Nepodařilo se vytvořit kategorii.';

  @override
  String get categoryDayPlanDescription =>
      'Zpřístupnit tuto kategorii pro výběr v denním plánu';

  @override
  String get categoryDayPlanLabel => 'Denní plánování';

  @override
  String get categoryDefaultEventTemplateHint => 'Vyberte šablonu…';

  @override
  String get categoryDefaultEventTemplateLabel =>
      'Výchozí šablona agenta událostí';

  @override
  String get categoryDefaultLanguageDescription =>
      'Nastavte výchozí jazyk pro úkoly v této kategorii';

  @override
  String get categoryDefaultProfileHint => 'Vyberte profil…';

  @override
  String get categoryDefaultTemplateHint => 'Vyberte šablonu…';

  @override
  String get categoryDefaultTemplateLabel => 'Výchozí šablona agenta';

  @override
  String get categoryDeleteConfirm => 'ANO, SMAŽ TUTO KATEGORII';

  @override
  String get categoryDeleteConfirmation =>
      'Tuto akci nelze vrátit zpět. Všechny položky v této kategorii zůstanou, ale již nebudou přiřazeny k žádné kategorii.';

  @override
  String get categoryDeleteTitle => 'Smazat kategorii?';

  @override
  String get categoryFavoriteBadgeLabel => 'Oblíbená';

  @override
  String get categoryFavoriteDescription =>
      'Označit tuto kategorii jako oblíbenou';

  @override
  String get categoryIconChooseHint => 'Vyberte ikonu';

  @override
  String get categoryIconCreateHint => 'Vyberte ikonu';

  @override
  String get categoryIconEditHint => 'Vyberte jinou ikonu';

  @override
  String get categoryIconLabel => 'Ikona';

  @override
  String get categoryIconPickerTitle => 'Vybrat ikonu';

  @override
  String get categoryNameRequired => 'Název kategorie je povinný';

  @override
  String get categoryNotFound => 'Kategorie nenalezena';

  @override
  String get categoryPrivateBadgeLabel => 'Soukromá';

  @override
  String get categoryPrivateDescription =>
      'Viditelné pouze při zobrazení soukromých záznamů';

  @override
  String get categorySearchPlaceholder => 'Vyhledávat kategorie...';

  @override
  String get changeSetCardTitle => 'Proposed changes';

  @override
  String get changeSetConfirmAll => 'Confirm all';

  @override
  String changeSetConfirmAllPartialIssues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items had partial issues',
      one: '1 item had partial issues',
    );
    return '$_temp0';
  }

  @override
  String get changeSetConfirmError => 'Failed to apply change';

  @override
  String get changeSetItemConfirmed => 'Change applied';

  @override
  String changeSetItemConfirmedWithWarning(String warning) {
    return 'Applied with warning: $warning';
  }

  @override
  String get changeSetItemRejected => 'Change rejected';

  @override
  String changeSetPendingCount(int count) {
    return '$count pending';
  }

  @override
  String get changeSetSwipeConfirm => 'Confirm';

  @override
  String get changeSetSwipeReject => 'Reject';

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
  String checklistAiConfidenceLabel(String level) {
    return 'Jistota: $level';
  }

  @override
  String get checklistAiMarkComplete => 'Označit jako dokončeno';

  @override
  String get checklistAiSuggestionBody => 'Tato položka se zdá být dokončena:';

  @override
  String get checklistAiSuggestionTitle => 'Návrh AI';

  @override
  String get checklistAllDone => 'Všechny položky splněny!';

  @override
  String get checklistCollapseTooltip => 'Sbalit';

  @override
  String checklistCompletedShort(int completed, int total) {
    return '$completed/$total hotovo';
  }

  @override
  String get checklistDelete => 'Smazat kontrolní seznam?';

  @override
  String get checklistExpandTooltip => 'Rozbalit';

  @override
  String get checklistExportAsMarkdown =>
      'Exportovat kontrolní seznam jako Markdown';

  @override
  String get checklistExportFailed => 'Export selhal';

  @override
  String get checklistItemArchived => 'Položka archivována';

  @override
  String get checklistItemArchiveUndo => 'Zpět';

  @override
  String get checklistItemDeleteCancel => 'Zrušit';

  @override
  String get checklistItemDeleteConfirm => 'Potvrdit';

  @override
  String get checklistItemDeleted => 'Položka smazána';

  @override
  String get checklistItemDeleteWarning => 'Tuto akci nelze vrátit zpět.';

  @override
  String get checklistMarkdownCopied =>
      'Kontrolní seznam zkopírován jako Markdown';

  @override
  String get checklistMoreTooltip => 'Více';

  @override
  String get checklistNoneDone => 'Zatím žádné dokončené položky.';

  @override
  String get checklistNothingToExport => 'Žádné položky k exportu';

  @override
  String get checklistProgressSemantics => 'Průběh kontrolního seznamu';

  @override
  String get checklistShare => 'Sdílet';

  @override
  String get checklistShareHint => 'Dlouhé stisknutí pro sdílení';

  @override
  String get checklistsReorder => 'Přeuspořádat';

  @override
  String get clearButton => 'Vymazat';

  @override
  String get colorCustomLabel => 'Vlastní';

  @override
  String get colorLabel => 'Barva';

  @override
  String get commonError => 'Chyba';

  @override
  String get commonLoading => 'Načítání...';

  @override
  String get commonUnknown => 'Neznámé';

  @override
  String get completeHabitFailButton => 'Zmeškáno';

  @override
  String get completeHabitSkipButton => 'Přeskočit';

  @override
  String get completeHabitSuccessButton => 'Úspěch';

  @override
  String get configFlagAttemptEmbeddingDescription =>
      'Pokud je povoleno, aplikace se pokusí generovat vektory pro vaše položky, aby zlepšila vyhledávání a návrhy souvisejícího obsahu.';

  @override
  String get configFlagDailyOsNextEnabled => 'Použít nové agentní DailyOS';

  @override
  String get configFlagDailyOsNextEnabledDescription =>
      'Nahradí stávající rozhraní DailyOS novým hlasově řízeným tokem zachycení a smíření vedeným agentem. Raná ukázka — logika backendu je simulovaná.';

  @override
  String get configFlagEnableAiStreaming =>
      'Povolit AI streamování pro akce úkolů';

  @override
  String get configFlagEnableAiStreamingDescription =>
      'Streamujte AI odpovědi pro akce související s úkoly. Vypněte, pokud chcete odpovědi bufferovat a udržet plynulejší rozhraní.';

  @override
  String get configFlagEnableAiSummaryTts => 'Přehrávání AI souhrnů';

  @override
  String get configFlagEnableAiSummaryTtsDescription =>
      'Zobrazí tlačítko místního převodu textu na řeč u AI souhrnů úkolů. Vyžaduje nainstalovaný model MLX Audio TTS.';

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
  String get configFlagEnableEmbeddings => 'Generovat vektory';

  @override
  String get configFlagEnableEvents => 'Povolit události';

  @override
  String get configFlagEnableEventsDescription =>
      'Zobrazit funkci Události pro vytváření, sledování a správu událostí ve vašem deníku.';

  @override
  String get configFlagEnableForkHealing => 'Slučování větví agenta';

  @override
  String get configFlagEnableForkHealingDescription =>
      'Sloučí rozvětvené historie agenta z více zařízení při příštím probuzení.';

  @override
  String get configFlagEnableHabitsPage => 'Povolit stránku Návyků';

  @override
  String get configFlagEnableHabitsPageDescription =>
      'Zobrazit stránku Návyky v hlavní navigaci. Zde sledujte a spravujte své denní návyky.';

  @override
  String get configFlagEnableKnowledgeGraph => 'Znalostní graf';

  @override
  String get configFlagEnableKnowledgeGraphDescription =>
      'Zobrazit experimentální průzkumník znalostního grafu u úkolů — vizuální mapu propojení mezi úkoly, záznamy a projekty.';

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
  String get configFlagEnableOnboardingFtue => 'Nový onboarding (FTUE)';

  @override
  String get configFlagEnableOnboardingFtueDescription =>
      'Použij nový onboarding pro první nastavení AI místo výběru poskytovatele.';

  @override
  String get configFlagEnableProjects => 'Povolit projekty';

  @override
  String get configFlagEnableProjectsDescription =>
      'Zobrazit funkce správy projektů pro organizaci úkolů do projektů.';

  @override
  String get configFlagEnableSessionRatings => 'Povolit hodnocení relací';

  @override
  String get configFlagEnableSessionRatingsDescription =>
      'Po zastavení časovače zobrazit rychlé hodnocení relace.';

  @override
  String get configFlagEnableSyncedAlerts => 'Synchronizovaná upozornění';

  @override
  String get configFlagEnableSyncedAlertsDescription =>
      'Synchronizuj upozornění od AI a úkolů mezi zařízeními a dovol jim plánovat místní systémová oznámení.';

  @override
  String get configFlagEnableTooltip => 'Povolit nápovědy';

  @override
  String get configFlagEnableTooltipDescription =>
      'Zobrazit užitečné nápovědy v celé aplikaci, které vás provedou funkcemi.';

  @override
  String get configFlagEnableVectorSearch => 'Vektorové vyhledávání';

  @override
  String get configFlagEnableVectorSearchDescription =>
      'Zapne vektorové vyhledávání ve filtrech úkolů. Vyžaduje povolené embeddingy a spuštěnou Ollamu.';

  @override
  String get configFlagEnableWhatsNew => 'Zobrazit „Co je nového\"';

  @override
  String get configFlagEnableWhatsNewDescription =>
      'Zvýrazňuje nové funkce a změny ve stromu Nastavení.';

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
  String get configFlagShowSidebarWakeQueue =>
      'Zobrazit frontu probuzení v postranním panelu';

  @override
  String get configFlagShowSidebarWakeQueueDescription =>
      'Zobrazí frontu probuzení nad Nastavením — záhlaví, dvě nejbližší naplánovaná probuzení s odpočtem a odkaz na úplný seznam.';

  @override
  String get configFlagShowSyncActivityIndicator =>
      'Zobrazit indikátor aktivity synchronizace';

  @override
  String get configFlagShowSyncActivityIndicatorDescription =>
      'Zobrazit živou aktivitu synchronizace v postranním panelu — tx/rx LED proužek s hloubkou odchozí a příchozí fronty.';

  @override
  String get conflictApplyButton => 'Použít';

  @override
  String get conflictApplyFailedTitle => 'Konflikt se nepodařilo vyřešit';

  @override
  String conflictBannerAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'před $count dní',
      few: 'před $count dny',
      one: 'před 1 dnem',
    );
    return '$_temp0';
  }

  @override
  String conflictBannerAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'před $count h',
      one: 'před 1 h',
    );
    return '$_temp0';
  }

  @override
  String get conflictBannerAgoJustNow => 'právě teď';

  @override
  String conflictBannerAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'před $count min',
      one: 'před 1 min',
    );
    return '$_temp0';
  }

  @override
  String conflictBannerDivergedAgo(String entity, String ago) {
    return '$entity · odchýleno $ago';
  }

  @override
  String conflictBannerFieldsDifferList(String fields) {
    return 'Liší se: $fields';
  }

  @override
  String get conflictCombineApply => 'Použít sloučené';

  @override
  String get conflictCombineStartFrom => 'Vyjít z';

  @override
  String get conflictConfirmDeletion => 'Potvrdit smazání';

  @override
  String get conflictDeleteVsEditDescription =>
      'Tato položka byla na jednom zařízení upravena a na jiném smazána. Dokud se nerozhodneš, nic se neodstraní.';

  @override
  String get conflictDeleteVsEditTitle => 'Smazáno na jednom zařízení';

  @override
  String get conflictDetailEntryNotFoundTitle => 'Záznam nenalezen';

  @override
  String get conflictDetailLoadErrorTitle => 'Konflikt se nepodařilo načíst';

  @override
  String get conflictDetailNotFoundTitle => 'Konflikt nenalezen';

  @override
  String get conflictDiffRecommended => 'Doporučeno';

  @override
  String conflictDiffUnchanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count polí beze změny',
      few: '$count pole beze změny',
      one: '1 pole beze změny',
    );
    return '$_temp0';
  }

  @override
  String get conflictFieldBody => 'Text';

  @override
  String get conflictFieldCategory => 'kategorie';

  @override
  String get conflictFieldDuration => 'trvání';

  @override
  String get conflictFieldEnd => 'Konec';

  @override
  String get conflictFieldFlag => 'Označení';

  @override
  String get conflictFieldOther => 'Další podrobnosti';

  @override
  String get conflictFieldOtherDescription =>
      'Tyto verze se liší v podrobnostech, které zde nejsou zobrazeny jednotlivě.';

  @override
  String get conflictFieldPrivate => 'Soukromé';

  @override
  String get conflictFieldStarred => 'Oblíbené';

  @override
  String get conflictFieldStart => 'Začátek';

  @override
  String get conflictFieldTitle => 'Titulek';

  @override
  String get conflictFieldWordCount => 'počet slov';

  @override
  String get conflictFlagFollowUp => 'Vyžaduje pozornost';

  @override
  String get conflictFlagImport => 'Importováno';

  @override
  String get conflictFlagNone => 'Žádné';

  @override
  String get conflictFooterHelperLocalSelected =>
      'Zachová tvou místní úpravu a zahodí synchronizovanou verzi.';

  @override
  String get conflictFooterHelperPickASide => 'Vyber stranu pro použití.';

  @override
  String get conflictFooterHelperRemoteSelected =>
      'Přijme synchronizovanou verzi a zahodí tvou místní úpravu.';

  @override
  String conflictHeaderPillEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count záznamů',
      few: '$count záznamy',
      one: '1 záznam',
    );
    return '$_temp0';
  }

  @override
  String conflictHeaderPillFieldsDiffer(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count polí se liší',
      few: '$count pole se liší',
      one: '1 pole se liší',
    );
    return '$_temp0';
  }

  @override
  String get conflictKeepEdited => 'Zachovat upravenou verzi';

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
    return 'ID konfliktu: $id';
  }

  @override
  String get conflictMetaLocalEdit => 'místní úprava';

  @override
  String get conflictMetaVecPrefix => 'vec';

  @override
  String get conflictMetaViaSync => 'přes synchronizaci';

  @override
  String conflictNotificationBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count položek bylo upraveno na dvou zařízeních',
      few: '$count položky byly upraveny na dvou zařízeních',
      one: '1 položka byla upravena na dvou zařízeních',
    );
    return '$_temp0';
  }

  @override
  String get conflictNotificationTitle =>
      'Synchronizace vyžaduje tvou pozornost';

  @override
  String get conflictPageLeadDesktop =>
      'Rozdíly jsou zvýrazněny v textu. Klikni na stranu, kterou chceš použít, nebo otevři Upravit a sloučit pro kombinaci.';

  @override
  String get conflictPageLeadMobile =>
      'Rozdíly jsou zvýrazněny v textu. Klepni na stranu, kterou chceš použít.';

  @override
  String get conflictPageTitle => 'Konflikt synchronizace';

  @override
  String get conflictPickerCombine => 'Sloučit…';

  @override
  String get conflictPickerEditMerge => 'Upravit a sloučit…';

  @override
  String get conflictPickerUseFromSync => 'Použít ze synchronizace';

  @override
  String get conflictPickerUseThisDevice => 'Použít toto zařízení';

  @override
  String get conflictResolvedToast => 'Konflikt vyřešen';

  @override
  String get conflictsEmptyDescription =>
      'Všechno je teď synchronizované. Vyřešené položky zůstávají dostupné v druhém filtru.';

  @override
  String get conflictsEmptyTitle => 'Nebyly zjištěny žádné konflikty';

  @override
  String get conflictSideFromSync => 'ZE SYNCHRONIZACE';

  @override
  String get conflictSideThisDevice => 'TOTO ZAŘÍZENÍ';

  @override
  String get conflictsResolved => 'vyřešeno';

  @override
  String get conflictsUnresolved => 'nevyřešeno';

  @override
  String get conflictValueAbsent => 'Nenastaveno';

  @override
  String get conflictValueNo => 'Ne';

  @override
  String get conflictValueYes => 'Ano';

  @override
  String conflictWordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count slov',
      few: '$count slova',
      one: '$count slovo',
    );
    return '$_temp0';
  }

  @override
  String get copyAsMarkdown => 'Kopírovat jako Markdown';

  @override
  String get copyAsText => 'Kopírovat jako text';

  @override
  String get correctionExampleCancel => 'ZRUŠIT';

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
  String get coverArtChipActive => 'Obal';

  @override
  String get coverArtChipSet => 'Nastavit obal';

  @override
  String get coverArtGenerationComplete => 'Obálka je připravena!';

  @override
  String get coverArtGenerationDismissHint =>
      'Můžeš to zavřít — generování pokračuje na pozadí';

  @override
  String get createButton => 'Vytvořit';

  @override
  String get createCategoryTitle => 'Vytvořit kategorii';

  @override
  String get createEntryLabel => 'Vytvořit novou položku';

  @override
  String get createEntryTitle => 'Přidat';

  @override
  String get createNewLinkedTask => 'Vytvořit nový propojený úkol...';

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
  String get dailyOsDayPlan => 'Plán dne';

  @override
  String get dailyOsDaySummary => 'Souhrn dne';

  @override
  String get dailyOsDelete => 'Smazat';

  @override
  String get dailyOsDeletePlannedBlock => 'Smazat blok?';

  @override
  String get dailyOsDeletePlannedBlockConfirm =>
      'Tímto se odebere plánovaný blok z vaší časové osy.';

  @override
  String get dailyOsDraftMessage =>
      'Plán je ve stavu konceptu. Souhlasíte s jeho uzamčením.';

  @override
  String get dailyOsDueToday => 'Termín dnes';

  @override
  String get dailyOsDueTodayShort => 'Dnes';

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
  String get dailyOsEditPlannedBlock => 'Upravit plánovaný blok';

  @override
  String get dailyOsEndTime => 'Konec';

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
  String get dailyOsInvalidTimeRange => 'Neplatný časový rozsah';

  @override
  String get dailyOsNearLimit => 'Blízko limitu';

  @override
  String get dailyOsNextAgendaCapacityComfortable => 'Pohodové';

  @override
  String get dailyOsNextAgendaCapacityNearFull => 'Téměř plné';

  @override
  String get dailyOsNextAgendaCapacityNoPlan => 'Zatím žádný plán';

  @override
  String dailyOsNextAgendaCapacityOf(String capacity) {
    return 'z $capacity';
  }

  @override
  String get dailyOsNextAgendaCapacityOver => 'Přeplněno';

  @override
  String get dailyOsNextAgendaDonutLeft => 'volno';

  @override
  String get dailyOsNextAgendaDonutOver => 'navíc';

  @override
  String dailyOsNextAgendaHeadlineLeft(String duration) {
    return '$duration zbývá';
  }

  @override
  String dailyOsNextAgendaHeadlineOver(String duration) {
    return '$duration navíc';
  }

  @override
  String get dailyOsNextAgendaNoPlanBody =>
      'Tvůj zaznamenaný čas tu je tak jako tak — namluv check-in a já kolem něj navrhnu den.';

  @override
  String dailyOsNextAgendaNoPlanSummary(String duration) {
    return '$duration zatím zaznamenáno. Namluv check-in a já kolem toho navrhnu den.';
  }

  @override
  String get dailyOsNextAgendaNoPlanTitle => 'Na dnešek zatím žádný plán.';

  @override
  String get dailyOsNextAgendaStateDone => 'Hotovo';

  @override
  String get dailyOsNextAgendaStateInProgress => 'Probíhá';

  @override
  String get dailyOsNextAgendaStateOpen => 'Otevřené';

  @override
  String get dailyOsNextAgendaStateOverdue => 'Po termínu';

  @override
  String dailyOsNextAgendaSummary(String scheduled, String capacity) {
    return '$scheduled z $capacity naplánováno';
  }

  @override
  String dailyOsNextAgendaTrackedLegend(String duration, int completedCount) {
    return 'Zaznamenáno · $duration · $completedCount hotovo';
  }

  @override
  String get dailyOsNextCaptureCaptured => 'Rozumím.';

  @override
  String get dailyOsNextCaptureDoneCta => 'Hotovo';

  @override
  String get dailyOsNextCaptureErrorMicrophonePermissionDenied =>
      'Přístup k mikrofonu byl odepřen.';

  @override
  String get dailyOsNextCaptureErrorNoActiveRealtimeSession =>
      'Žádná aktivní relace v reálném čase.';

  @override
  String get dailyOsNextCaptureErrorNoAudioRecorded =>
      'Nebylo nahráno žádné audio.';

  @override
  String get dailyOsNextCaptureErrorRealtimeTranscriptionFailed =>
      'Přepis v reálném čase selhal.';

  @override
  String get dailyOsNextCaptureErrorRealtimeTranscriptionStartFailed =>
      'Přepis v reálném čase se nepodařilo spustit.';

  @override
  String get dailyOsNextCaptureErrorRecordingStartFailed =>
      'Nahrávání se nepodařilo spustit.';

  @override
  String get dailyOsNextCaptureErrorTranscriptionFailed => 'Přepis selhal.';

  @override
  String get dailyOsNextCaptureHeadlineCaptured => 'Sedí to takhle?';

  @override
  String get dailyOsNextCaptureHeadlineLead => 'Co máš dnes';

  @override
  String get dailyOsNextCaptureHeadlineListening => 'Poslouchám.';

  @override
  String get dailyOsNextCaptureHeadlineTail => 'na mysli?';

  @override
  String dailyOsNextCaptureHeadlineTailForDate(String date) {
    return 'na $date?';
  }

  @override
  String get dailyOsNextCaptureHeadlineTailTomorrow => 'na zítra?';

  @override
  String get dailyOsNextCaptureHeadlineTailYesterday => 'na včera?';

  @override
  String get dailyOsNextCaptureHeadlineTranscribing => 'Zapisuji…';

  @override
  String get dailyOsNextCaptureIdleClick => 'Klikni a mluv';

  @override
  String get dailyOsNextCaptureIdleExample =>
      '„Dopoledne hluboká práce, po obědě procházka, e-maily do pěti.“';

  @override
  String get dailyOsNextCaptureIdleHint =>
      'Klepni pro mluvení · místo toho napiš';

  @override
  String get dailyOsNextCaptureIdleTalk => 'Klepni pro mluvení';

  @override
  String get dailyOsNextCaptureListeningStatus => 'Poslouchám…';

  @override
  String dailyOsNextCapturePastPrompt(String date) {
    return 'Chceš ještě něco zapsat k $date?';
  }

  @override
  String get dailyOsNextCaptureReconcileCta => 'Zkontrolovat';

  @override
  String get dailyOsNextCapturesPanelTitle => 'Záznamy';

  @override
  String get dailyOsNextCaptureTranscribing => 'Přepisuji…';

  @override
  String get dailyOsNextCaptureTranscriptHint =>
      'Oprav cokoli, co přepis spletl, než začne plánování.';

  @override
  String get dailyOsNextCaptureTranscriptLabel => 'Zkontroluj přepis';

  @override
  String get dailyOsNextCaptureTypeInstead => 'Místo toho napiš';

  @override
  String get dailyOsNextCaptureVoiceButtonReset => 'Začít znovu';

  @override
  String get dailyOsNextCaptureVoiceButtonStart => 'Začít poslouchat';

  @override
  String get dailyOsNextCaptureVoiceButtonStop => 'Zastavit';

  @override
  String get dailyOsNextCategoryFilterAll => 'Všechny kategorie';

  @override
  String get dailyOsNextCategoryFilterDescription =>
      'Automatické zpracování Daily OS používá jen kategorie zapnuté pro denní plánování.';

  @override
  String get dailyOsNextCategoryFilterEmpty =>
      'Zatím nejsou aktivované žádné kategorie pro denní plánování.';

  @override
  String get dailyOsNextCategoryFilterIncludeAll => 'Zahrnout vše';

  @override
  String get dailyOsNextCategoryFilterTitle => 'Kategorie ke zpracování';

  @override
  String get dailyOsNextCategoryFilterTooltip =>
      'Vybrat kategorie pro zpracování v Daily OS';

  @override
  String dailyOsNextCommitCapacityNote(String scheduled, String capacity) {
    return '$scheduled z $capacity naplánováno. Pohodlná rezerva — jedno překvapení den zvládne.';
  }

  @override
  String get dailyOsNextCommitDraftOverline => 'TVŮJ DEN, NAVRŽENÝ';

  @override
  String get dailyOsNextCommitExplainer =>
      'Podpisem přepneš dnešek z návrhu na závazný.';

  @override
  String get dailyOsNextCommitFinalStepEyebrow => 'POSLEDNÍ KROK';

  @override
  String get dailyOsNextCommitHeadline => 'Udělej ho svým.';

  @override
  String get dailyOsNextCommitHoldHelper => 'Podrž vteřinu pro podpis';

  @override
  String get dailyOsNextCommitHoldWordDone => 'Závazné';

  @override
  String get dailyOsNextCommitHoldWordHolding => 'Drž dál';

  @override
  String get dailyOsNextCommitHoldWordIdle => 'Podrž';

  @override
  String get dailyOsNextCommitLockingIn => 'Zamykám…';

  @override
  String get dailyOsNextCommitShepherdSubline =>
      'Já provedu — práci uděláš ty.';

  @override
  String get dailyOsNextCommitSubCaption =>
      'I potom se mnou můžeš mluvit — ale kostra zůstává.';

  @override
  String get dailyOsNextCommitTitle => 'Uzamknout';

  @override
  String get dailyOsNextCommitTodayIsYours => 'Den je tvůj.';

  @override
  String get dailyOsNextDayBack => 'Zpět';

  @override
  String get dailyOsNextDayCheckInCta => 'Namluvit check-in';

  @override
  String get dailyOsNextDayDeleteDialogBody =>
      'Naplánované bloky pro tento den budou odstraněny. Tvoje záznamy a jejich audio nahrávky zůstávají v tvém deníku.';

  @override
  String get dailyOsNextDayDeleteDialogCancel => 'Zrušit';

  @override
  String get dailyOsNextDayDeleteDialogConfirm => 'Smazat';

  @override
  String get dailyOsNextDayDeleteDialogTitle => 'Smazat tento plán?';

  @override
  String get dailyOsNextDayLockInCta => 'Uzamknout';

  @override
  String get dailyOsNextDayMenuDeletePlan => 'Smazat plán';

  @override
  String get dailyOsNextDayMenuInspectAgent => 'Prozkoumat agenta';

  @override
  String get dailyOsNextDayMoreTooltip => 'Více';

  @override
  String get dailyOsNextDayRefineCta => 'Upravit';

  @override
  String get dailyOsNextDayRefineFooterHint =>
      'Mluv a přetvoř plán — každou změnu uvidíš, než se cokoli uloží.';

  @override
  String get dailyOsNextDayTitle => 'Tvůj den';

  @override
  String get dailyOsNextDayWhyChipLabel => 'PROČ';

  @override
  String get dailyOsNextDayWrapUpCta => 'Ukončit';

  @override
  String get dailyOsNextDraftingHeader => 'Připravuji tvůj den…';

  @override
  String get dailyOsNextDraftingNudgeAccept => 'Ano, chraň ranní hodiny';

  @override
  String get dailyOsNextDraftingNudgeDecline => 'Dnes ne';

  @override
  String get dailyOsNextDraftingReasoningOverline => '✦ ÚVAHA';

  @override
  String get dailyOsNextDraftingStatusAfternoon => 'Skládám odpoledne…';

  @override
  String get dailyOsNextDraftingStatusAlmost => 'Už to skoro je…';

  @override
  String get dailyOsNextDraftingStatusBreathing =>
      'Nechávám prostor k nadechnutí…';

  @override
  String get dailyOsNextDraftingStatusDeepWork =>
      'Hluboká práce jde na začátek…';

  @override
  String get dailyOsNextDraftingStatusMatching => 'Přiřazuji úkoly ke dni…';

  @override
  String get dailyOsNextDraftingStatusReading => 'Čtu tvůj check-in…';

  @override
  String get dailyOsNextDraftingStatusTimings => 'Kontroluji časy…';

  @override
  String get dailyOsNextDraftingStatusYesterday =>
      'Dívám se na včerejší rytmus…';

  @override
  String get dailyOsNextEditTitleHint => 'Upravit název';

  @override
  String get dailyOsNextGenericError =>
      'Něco se pokazilo. Zkus to za chvíli znovu.';

  @override
  String get dailyOsNextGreetingAfternoon => 'Dobré odpoledne.';

  @override
  String get dailyOsNextGreetingEvening => 'Dobrý večer.';

  @override
  String dailyOsNextGreetingHiName(String name) {
    return 'Ahoj $name 👋';
  }

  @override
  String get dailyOsNextGreetingMorning => 'Dobré ráno.';

  @override
  String get dailyOsNextKnowledgeConfirm => 'Potvrdit';

  @override
  String get dailyOsNextKnowledgeConfirmedHeader => 'Potvrzeno';

  @override
  String get dailyOsNextKnowledgeEdit => 'Upravit';

  @override
  String get dailyOsNextKnowledgeEditCancel => 'Zrušit';

  @override
  String get dailyOsNextKnowledgeEditHookHint => 'Jednořádkové shrnutí';

  @override
  String get dailyOsNextKnowledgeEditSave => 'Uložit';

  @override
  String get dailyOsNextKnowledgeEditStatementHint => 'Co si mám zapamatovat?';

  @override
  String get dailyOsNextKnowledgeEmpty =>
      'Zatím nic — zapamatuji si, co mi řekneš.';

  @override
  String dailyOsNextKnowledgeNudge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count postřehů — zkontrolovat',
      few: '$count postřehy — zkontrolovat',
      one: '1 postřeh — zkontrolovat',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextKnowledgeProposedHeader => 'Čeká na tvé potvrzení';

  @override
  String get dailyOsNextKnowledgeRetract => 'Zapomenout';

  @override
  String get dailyOsNextKnowledgeStale => 'Platí to stále?';

  @override
  String get dailyOsNextKnowledgeTitle => 'Co jsem se naučil';

  @override
  String get dailyOsNextParsedCardBreakLinkTooltip => 'Odpojit';

  @override
  String get dailyOsNextPlanViewAgenda => 'Agenda';

  @override
  String get dailyOsNextPlanViewDay => 'Den';

  @override
  String get dailyOsNextReconcileBadgeMatched => 'PROPOJENO';

  @override
  String get dailyOsNextReconcileBadgeNew => 'NOVÉ';

  @override
  String get dailyOsNextReconcileBadgeUpdate => 'AKTUALIZACE';

  @override
  String get dailyOsNextReconcileBuildDayCta => 'Sestavit můj den';

  @override
  String get dailyOsNextReconcileDecideOverline => 'STOJÍ ZA ROZHODNUTÍ';

  @override
  String get dailyOsNextReconcileDefaultBehaviorHint =>
      'Tvá rozhodnutí zde plynou do plánu — žádné rozhodnutí znamená „nech to být“.';

  @override
  String dailyOsNextReconcileError(String detail) {
    return 'Něco se pokazilo: $detail';
  }

  @override
  String get dailyOsNextReconcileHeadline => 'Tohle jsem zachytil.';

  @override
  String get dailyOsNextReconcileHeardEmpty =>
      'Karty ze záznamu se tu objeví, jakmile skončí parsování.';

  @override
  String get dailyOsNextReconcileHeardOverline => 'ZACHYCENO';

  @override
  String get dailyOsNextReconcileLowConfidence => 'nízká důvěra';

  @override
  String get dailyOsNextReconcileReRecord => 'Znovu nahrát';

  @override
  String get dailyOsNextReconcileVoiceHint =>
      'Zkontroluj rozhodnutí, než si poskládáš den';

  @override
  String get dailyOsNextRefineAccept => 'Přijmout';

  @override
  String get dailyOsNextRefineCurrentPlan => 'AKTUÁLNÍ PLÁN';

  @override
  String get dailyOsNextRefineDiffAdded => 'PŘIDÁNO';

  @override
  String get dailyOsNextRefineDiffDropped => 'ODSTRANĚNO';

  @override
  String get dailyOsNextRefineDiffMoved => 'PŘESUNUTO';

  @override
  String get dailyOsNextRefineHeadlineDiffReady => 'Tohle bych změnil.';

  @override
  String get dailyOsNextRefineHeadlineIdle => 'Co se má změnit?';

  @override
  String get dailyOsNextRefineHeadlineThinking => 'Předělávám tvůj plán…';

  @override
  String get dailyOsNextRefineKeepTalking => 'Mluv dál';

  @override
  String get dailyOsNextRefineLooksGood => 'Vypadá to dobře';

  @override
  String get dailyOsNextRefineNoChanges =>
      'Nevrátily se žádné změny plánu. Zkus to přeformulovat a znovu odeslat.';

  @override
  String get dailyOsNextRefineOverline => '🎤 ÚPRAVA';

  @override
  String get dailyOsNextRefineRevert => 'Vrátit';

  @override
  String get dailyOsNextRefineStatusAccepted => 'Uzamčeno.';

  @override
  String get dailyOsNextRefineStatusDiffReady => 'Tady je, co se změnilo.';

  @override
  String get dailyOsNextRefineStatusIdle => 'Klepni pro mluvení.';

  @override
  String get dailyOsNextRefineStatusListening => 'Poslouchám…';

  @override
  String get dailyOsNextRefineStatusThinking => '✦ Přepracovávám plán…';

  @override
  String get dailyOsNextRefineTitle => 'Upravit plán';

  @override
  String get dailyOsNextRenameFailed =>
      'Přejmenování se nepovedlo — zkus to znovu.';

  @override
  String get dailyOsNextShutdownCarryoverDrop => 'Zahodit';

  @override
  String get dailyOsNextShutdownCarryoverDropped => 'Zahozeno';

  @override
  String get dailyOsNextShutdownCarryoverOverline => 'PŘEVÁDÍ SE';

  @override
  String get dailyOsNextShutdownCarryoverPickDate => 'Vyber datum';

  @override
  String get dailyOsNextShutdownCarryoverScheduled => 'Naplánováno';

  @override
  String get dailyOsNextShutdownCloseDay => 'Uzavřít den';

  @override
  String get dailyOsNextShutdownCompletedOverline => 'CO JSI UDĚLAL';

  @override
  String get dailyOsNextShutdownMetricEnergy => 'ENERGIE';

  @override
  String dailyOsNextShutdownMetricEnergyDelta(String delta) {
    return '$delta vs. týden';
  }

  @override
  String get dailyOsNextShutdownMetricFlow => 'FLOW RELACE';

  @override
  String get dailyOsNextShutdownMetricFocus => 'ČAS FOKUSU';

  @override
  String get dailyOsNextShutdownMetricSwitches => 'PŘEPÍNÁNÍ KONTEXTU';

  @override
  String dailyOsNextShutdownMetricSwitchesAvg(String avg) {
    return 'průměr $avg tento týden';
  }

  @override
  String get dailyOsNextShutdownReflectionOverline => '💬 JEDNOŘÁDKOVÁ REFLEXE';

  @override
  String get dailyOsNextShutdownReflectionPlaceholder =>
      'např.: ráno ostré, odpoledne se táhlo po dlouhém kafi se Sarah.';

  @override
  String get dailyOsNextShutdownReflectionPrompt =>
      'Jak dnešek dopadl? (Naplní zítřejší návrh.)';

  @override
  String get dailyOsNextShutdownReflectionSpeak => 'Řekni to';

  @override
  String get dailyOsNextShutdownReflectionSubmit => 'Přeskočit';

  @override
  String get dailyOsNextShutdownReflectionThanks => 'Mám to — krmí zítřek.';

  @override
  String get dailyOsNextShutdownSaveAndClose => 'Uložit a zavřít';

  @override
  String get dailyOsNextShutdownTitle => 'Uzavřít den';

  @override
  String get dailyOsNextShutdownTomorrowOverline => '✦ NA ZÍTŘEK';

  @override
  String dailyOsNextStateDueOnDate(String date) {
    return 'Splatné $date';
  }

  @override
  String get dailyOsNextStateDueToday => 'Splatné dnes';

  @override
  String dailyOsNextStateInProgress(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Probíhá · $count relací',
      few: 'Probíhá · $count relace',
      one: 'Probíhá · 1 relace',
      zero: 'Probíhá',
    );
    return '$_temp0';
  }

  @override
  String dailyOsNextStateOverdue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Po termínu · $days dní',
      few: 'Po termínu · $days dny',
      one: 'Po termínu · 1 den',
      zero: 'Po termínu',
    );
    return '$_temp0';
  }

  @override
  String dailyOsNextStateOverdueOnDate(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Po termínu o $days dní k $date',
      few: 'Po termínu o $days dny k $date',
      one: 'Po termínu o 1 den k $date',
      zero: 'Po termínu k $date',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextStateRecurringMissed => 'Opakující · zmeškané';

  @override
  String get dailyOsNextTimelineActual => 'Skutečnost';

  @override
  String get dailyOsNextTimelineBoth => 'Plán a skutečnost';

  @override
  String get dailyOsNextTimelineMeridiemAm => 'AM';

  @override
  String get dailyOsNextTimelineMeridiemAmShort => 'am';

  @override
  String get dailyOsNextTimelineMeridiemPm => 'PM';

  @override
  String get dailyOsNextTimelineMeridiemPmShort => 'pm';

  @override
  String get dailyOsNextTimelinePlanned => 'Plán';

  @override
  String dailyOsNextTimelineSessionOf(int index, int total) {
    return 'Sezení $index z $total';
  }

  @override
  String get dailyOsNextTimelineShowBoth =>
      'Zobrazit plán a skutečnost společně';

  @override
  String get dailyOsNextTimelineShowPaged =>
      'Zobrazit plán a skutečnost posouváním';

  @override
  String get dailyOsNextTimelineSwipeHint =>
      'Přejeď na skutečnost · svislým štípnutím přiblížíš';

  @override
  String get dailyOsNextTimelineTracked => 'zaznamenáno';

  @override
  String dailyOsNextTimeSpentEarlierSessions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count starších záznamů',
      few: '$count starší záznamy',
      one: '1 starší záznam',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextTimeSpentShowLess => 'Zobrazit méně';

  @override
  String dailyOsNextTimeSpentSummary(String duration, int completedCount) {
    return '$duration · $completedCount hotovo';
  }

  @override
  String get dailyOsNextTimeSpentTitle => 'DNES ZATÍM';

  @override
  String get dailyOsNextTimeSpentTitlePast => 'STRÁVENÝ ČAS';

  @override
  String get dailyOsNextTriageConfirmDefer => 'Odloženo';

  @override
  String get dailyOsNextTriageConfirmDone => 'Označeno jako hotové';

  @override
  String get dailyOsNextTriageConfirmDoNow => 'Hotovo hned';

  @override
  String get dailyOsNextTriageConfirmDrop => 'Zahozeno';

  @override
  String get dailyOsNextTriageConfirmToday => 'Přidáno na dnes';

  @override
  String get dailyOsNextTriageDefer => 'Odložit';

  @override
  String get dailyOsNextTriageDone => 'Hotovo';

  @override
  String get dailyOsNextTriageDoNow => 'Udělat teď';

  @override
  String get dailyOsNextTriageDrop => 'Zahodit';

  @override
  String get dailyOsNextTriageToday => 'Dnes';

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
  String get dailyOsPlanCreated => 'Plán úspěšně vytvořen';

  @override
  String get dailyOsPlanCreatedDescription =>
      'Tvé časové bloky byly uloženy. Můžeš začít sledovat své úkoly.';

  @override
  String get dailyOsPlanned => 'Naplánováno';

  @override
  String get dailyOsPlanWithoutVoice => 'Plánovat bez hlasu';

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
  String get dailyOsSaveError => 'Plán se nepodařilo uložit';

  @override
  String get dailyOsSaveErrorDescription =>
      'Něco se pokazilo. Zkus to prosím znovu.';

  @override
  String get dailyOsSavePlan => 'Uložit plán';

  @override
  String get dailyOsSelectCategory => 'Vyberte kategorii';

  @override
  String get dailyOsSetTimeBlocks => 'Nastavit časové bloky';

  @override
  String get dailyOsSetTimeBlocksAddNew => 'Přidat nový časový blok';

  @override
  String get dailyOsSetTimeBlocksFavourites => 'Oblíbené';

  @override
  String get dailyOsSetTimeBlocksOther => 'Další kategorie';

  @override
  String get dailyOsSetTimeBlocksTapHint => 'Klepni pro přidání časového bloku';

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
  String get dashboardActiveLabel => 'Aktivní';

  @override
  String get dashboardActiveSwitchDescription =>
      'Zobrazuje se v seznamu panelů';

  @override
  String get dashboardAddChartsTitle => 'Grafy';

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
  String get dashboardAddMeasurementTooltip => 'Přidat měření';

  @override
  String get dashboardAddSurveyButton => 'Grafy průzkumů';

  @override
  String get dashboardAddSurveyTitle => 'Grafy průzkumů';

  @override
  String get dashboardAddWorkoutButton => 'Grafy cvičení';

  @override
  String get dashboardAddWorkoutTitle => 'Grafy cvičení';

  @override
  String get dashboardAggregationDailyAverage => 'Denní průměr';

  @override
  String get dashboardAggregationDailyMax => 'Denní maximum';

  @override
  String get dashboardAggregationDailyTotal => 'Denní součet';

  @override
  String get dashboardAggregationHourlyTotal => 'Hodinový součet';

  @override
  String get dashboardAggregationLabel => 'Typ agregace:';

  @override
  String get dashboardCategoryLabel => 'Kategorie';

  @override
  String get dashboardChartNoData => 'Žádná data v tomto rozsahu';

  @override
  String get dashboardCopyHint => 'Uložit a zkopírovat konfiguraci panelu';

  @override
  String get dashboardCopyLabel => 'Uložit a zkopírovat konfiguraci';

  @override
  String get dashboardDeleteConfirm => 'ANO, SMAZAT TENTO PANEL';

  @override
  String get dashboardDeleteHint => 'Smazat dashboard';

  @override
  String get dashboardDeleteQuestion =>
      'Opravdu chcete smazat tento dashboard?';

  @override
  String get dashboardDescriptionLabel => 'Popis (volitelné)';

  @override
  String get dashboardHealthBloodPressure => 'Krevní tlak';

  @override
  String get dashboardHealthDiastolic => 'Diastolický';

  @override
  String get dashboardHealthSystolic => 'Systolický';

  @override
  String get dashboardNameLabel => 'Název dashboardu';

  @override
  String get dashboardNotFound => 'Dashboard nenalezen';

  @override
  String get dashboardPrivateLabel => 'Soukromý';

  @override
  String get dashboardTakeSurveyTooltip => 'Vyplnit dotazník';

  @override
  String get defaultLanguage => 'Výchozí jazyk';

  @override
  String get deleteButton => 'Smazat';

  @override
  String get deleteDeviceLabel => 'Odstranit zařízení';

  @override
  String get designSystemActionVariantTitle => 'S akcí';

  @override
  String get designSystemActivatedLabel => 'Aktivní';

  @override
  String get designSystemAvatarAwayLabel => 'Nepřítomen';

  @override
  String get designSystemAvatarBusyLabel => 'Zaneprázdněn';

  @override
  String get designSystemAvatarConnectedLabel => 'Připojen';

  @override
  String get designSystemAvatarEnabledLabel => 'Aktivní';

  @override
  String get designSystemAvatarSizeMatrixTitle => 'Matice velikostí';

  @override
  String get designSystemAvatarStatusMatrixTitle => 'Matice stavů';

  @override
  String get designSystemBackLabel => 'Zpět';

  @override
  String get designSystemBreadcrumbCurrentLabel => 'Breadcrumbs';

  @override
  String get designSystemBreadcrumbDesignSystemLabel => 'Design System';

  @override
  String get designSystemBreadcrumbHomeLabel => 'Domů';

  @override
  String get designSystemBreadcrumbMobileLabel => 'Mobil';

  @override
  String get designSystemBreadcrumbProjectsLabel => 'Projekty';

  @override
  String get designSystemBreadcrumbSampleLabel => 'Breadcrumb';

  @override
  String get designSystemBreadcrumbTrailTitle => 'Ukázka breadcrumbů';

  @override
  String get designSystemCalendarPickerLabel => 'Výběr data';

  @override
  String get designSystemCalendarViewsTitle => 'Zobrazení kalendáře';

  @override
  String get designSystemCaptionDescriptionSample =>
      'Odebrání všech uživatelů zrušilo publikování tohoto projektu. Přidejte uživatele pro opětovné publikování.';

  @override
  String get designSystemCaptionIconLeftLabel => 'Ikona vlevo';

  @override
  String get designSystemCaptionIconTopLabel => 'Ikona nahoře';

  @override
  String get designSystemCaptionNoIconLabel => 'Bez ikony';

  @override
  String get designSystemCaptionTitleSample => 'Nadpis';

  @override
  String get designSystemCaptionVariantsTitle => 'Varianty captionů';

  @override
  String get designSystemCaptionWithActionsLabel => 'S akcemi';

  @override
  String get designSystemCaptionWithoutActionsLabel => 'Bez akcí';

  @override
  String get designSystemCheckboxLabel => 'Zaškrtávací políčko';

  @override
  String get designSystemContextMenuDeleteLabel => 'Smazat';

  @override
  String get designSystemContextMenuVariantsTitle =>
      'Varianty kontextového menu';

  @override
  String get designSystemCountdownVariantTitle => 'S odpočtem';

  @override
  String get designSystemDateCardsTitle => 'Datumové karty';

  @override
  String get designSystemDefaultLabel => 'Výchozí';

  @override
  String get designSystemDisabledLabel => 'Zakázáno';

  @override
  String get designSystemDividerLabelText => 'Štítek oddělovače';

  @override
  String get designSystemDropdownComboboxTitle => 'Kombobox';

  @override
  String get designSystemDropdownFieldLabel => 'Štítek';

  @override
  String get designSystemDropdownInputLabel => 'Vstup';

  @override
  String get designSystemDropdownListTitle => 'Rozbalovací seznam';

  @override
  String get designSystemDropdownMultiselectInputLabel => 'Vyber týmy';

  @override
  String get designSystemDropdownMultiselectTitle => 'Vícenásobný výběr';

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
  String get designSystemErrorLabel => 'Chyba';

  @override
  String get designSystemFileUploadClickLabel => 'Klikni pro nahrání';

  @override
  String get designSystemFileUploadCompleteLabel => 'Dokončeno';

  @override
  String get designSystemFileUploadDefaultLabel => 'Výchozí';

  @override
  String get designSystemFileUploadDragLabel => 'nebo přetáhni';

  @override
  String get designSystemFileUploadDropZoneSectionTitle => 'Oblast pro nahrání';

  @override
  String get designSystemFileUploadErrorLabel => 'Chyba';

  @override
  String get designSystemFileUploadFailedText => 'Nahrání selhalo';

  @override
  String get designSystemFileUploadHintText =>
      'SVG, PNG, JPG nebo GIF (max. 800×400px)';

  @override
  String get designSystemFileUploadHoverLabel => 'Najetí';

  @override
  String get designSystemFileUploadItemSectionTitle => 'Položky souborů';

  @override
  String get designSystemFileUploadRetryLabel => 'Zkusit znovu';

  @override
  String get designSystemFileUploadUploadingLabel => 'Nahrávání';

  @override
  String get designSystemFilledLabel => 'Vyplněné';

  @override
  String get designSystemHeaderApiDocumentationLabel => 'Dokumentace API';

  @override
  String get designSystemHeaderBackActionLabel => 'Zpět';

  @override
  String get designSystemHeaderDesktopSectionTitle => 'Desktop';

  @override
  String get designSystemHeaderHelpActionLabel => 'Nápověda';

  @override
  String get designSystemHeaderMobileSectionTitle => 'Mobil';

  @override
  String get designSystemHeaderNotificationsActionLabel => 'Oznámení';

  @override
  String get designSystemHeaderSearchActionLabel => 'Hledat';

  @override
  String get designSystemHorizontalLabel => 'Vodorovný';

  @override
  String get designSystemHoverLabel => 'Přejetí';

  @override
  String get designSystemInfoLabel => 'Info';

  @override
  String get designSystemInputErrorSample => 'Toto pole je povinné';

  @override
  String get designSystemInputHelperSample => 'Zadej své jméno';

  @override
  String get designSystemInputHintSample => 'Zástupný text...';

  @override
  String get designSystemInputLabelSample => 'Štítek';

  @override
  String get designSystemInputVariantsTitle => 'Varianty vstupního pole';

  @override
  String get designSystemInputWithErrorLabel => 'S chybou';

  @override
  String get designSystemInputWithHelperLabel => 'S nápovědou';

  @override
  String get designSystemInputWithIconsLabel => 'S ikonami';

  @override
  String get designSystemListItemActivatedLabel => 'Aktivní';

  @override
  String get designSystemListItemOneLineLabel => 'Jednořádkový';

  @override
  String get designSystemListItemSubtitleSample => 'Podtitulek';

  @override
  String get designSystemListItemTitleSample => 'Název';

  @override
  String get designSystemListItemTwoLinesLabel => 'Dvouřádkový';

  @override
  String get designSystemListItemVariantsTitle => 'Varianty položky seznamu';

  @override
  String get designSystemListItemWithDividerLabel => 'S oddělovačem';

  @override
  String get designSystemMediumLabel => 'Střední';

  @override
  String designSystemMyDailyDurationHoursMinutesCompact(
    int hours,
    int minutes,
  ) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get designSystemMyDailyEditPlanLabel => 'Upravit plán';

  @override
  String get designSystemMyDailyGreetingMorning => 'Dobré ráno.';

  @override
  String designSystemMyDailyGreetingWithName(String name) {
    return 'Ahoj, $name';
  }

  @override
  String get designSystemMyDailyHikeWithDanielaTitle => 'Túra s Danielou';

  @override
  String get designSystemMyDailyLunchBreakTitle => 'Obědová pauza';

  @override
  String get designSystemMyDailyMeetingsLabel => 'Schůzky';

  @override
  String get designSystemMyDailyMeetingWithDannyTitle => 'Schůzka s Dannym';

  @override
  String get designSystemMyDailyProfileActionLabel => 'Profil';

  @override
  String get designSystemMyDailySkiWithMattTitle => 'Jet lyžovat s Mattem';

  @override
  String get designSystemMyDailyTapToExpandLabel => 'Klepni pro rozbalení';

  @override
  String get designSystemNavigationCollapsedLabel => 'Sbalené';

  @override
  String get designSystemNavigationDailyFilterSectionTitle => 'Denní filtr';

  @override
  String get designSystemNavigationExpandedLabel => 'Rozbalené';

  @override
  String get designSystemNavigationFilterByBlockLabel =>
      'Filtrovat podle bloku';

  @override
  String get designSystemNavigationHikingLabel => 'Turistika';

  @override
  String get designSystemNavigationHolidayLabel => 'Dovolená';

  @override
  String get designSystemNavigationInsightsLabel => 'Přehledy';

  @override
  String get designSystemNavigationLottiTasksLabel => 'Úkoly Lotti';

  @override
  String get designSystemNavigationMyDailyLabel => 'Můj den';

  @override
  String get designSystemNavigationNewLabel => 'Nové';

  @override
  String get designSystemNavigationPlaceholderLabel => 'Zástupný text';

  @override
  String get designSystemNavigationSidebarSectionTitle =>
      'Varianty postranního panelu';

  @override
  String get designSystemNavigationSubComponentsSectionTitle => 'Podkomponenty';

  @override
  String get designSystemNavigationTabBarSectionTitle =>
      'Varianty lišty záložek';

  @override
  String get designSystemPressedLabel => 'Stisknuto';

  @override
  String get designSystemProgressBarChunkyLabel => 'Segmentovaný';

  @override
  String get designSystemProgressBarLabelAndPercentageLabel =>
      'Štítek + procento';

  @override
  String get designSystemProgressBarLabelOnlyLabel => 'Jen štítek';

  @override
  String get designSystemProgressBarOffLabel => 'Vypnuto';

  @override
  String get designSystemProgressBarPercentageOnlyLabel => 'Procento';

  @override
  String get designSystemProgressBarQuestBarLabel => 'Quest lišta';

  @override
  String get designSystemProgressBarQuestLabel => 'Štítek mega odměny';

  @override
  String get designSystemProgressBarSampleLabel => 'Štítek ukazatele průběhu';

  @override
  String get designSystemRadioButtonLabel => 'Přepínač';

  @override
  String get designSystemScrollbarSizesTitle => 'Velikosti posuvníku';

  @override
  String get designSystemSearchFilledText => 'Hledání Lotti';

  @override
  String get designSystemSearchHintLabel => 'Zadej uživatele';

  @override
  String get designSystemSelectedLabel => 'Vybrané';

  @override
  String get designSystemSizeScaleTitle => 'Škála velikostí';

  @override
  String get designSystemSmallLabel => 'Malý';

  @override
  String get designSystemSpinnerPlainLabel => 'Bez pozadí';

  @override
  String get designSystemSpinnerSkeletonPulseLabel => 'Pulz';

  @override
  String get designSystemSpinnerSkeletonsTitle => 'Skelety';

  @override
  String get designSystemSpinnerSkeletonWaveLabel => 'Vlna';

  @override
  String get designSystemSpinnerSpinnersTitle => 'Spinnery';

  @override
  String get designSystemSpinnerTrackLabel => 'Se stopou';

  @override
  String designSystemSplitButtonDropdownSemantics(String label) {
    return 'Otevřít možnosti pro $label';
  }

  @override
  String get designSystemStateMatrixTitle => 'Matice stavů';

  @override
  String get designSystemSuccessLabel => 'Úspěch';

  @override
  String get designSystemTabBarTitle => 'Panel záložek';

  @override
  String get designSystemTabPendingLabel => 'Čekající';

  @override
  String get designSystemTaskListBlockedLabel => 'Blokováno';

  @override
  String get designSystemTaskListDefaultLabel => 'Výchozí';

  @override
  String get designSystemTaskListHoverLabel => 'Přejetí';

  @override
  String get designSystemTaskListItemSectionTitle =>
      'Varianty položky seznamu úkolů';

  @override
  String get designSystemTaskListOnHoldLabel => 'Pozastaveno';

  @override
  String get designSystemTaskListOpenLabel => 'Otevřeno';

  @override
  String get designSystemTaskListPressedLabel => 'Stisknuto';

  @override
  String get designSystemTaskListSampleTime => '8:00-9:30';

  @override
  String get designSystemTaskListSampleTitle => 'Testování uživatelů';

  @override
  String get designSystemTaskListWithDividerLabel => 'S oddělovačem';

  @override
  String get designSystemTextareaErrorSample => 'Toto pole je povinné';

  @override
  String get designSystemTextareaHelperSample => 'Zadej svou zprávu zde';

  @override
  String get designSystemTextareaHintSample => 'Napiš něco...';

  @override
  String get designSystemTextareaLabelSample => 'Štítek';

  @override
  String get designSystemTextareaVariantsTitle => 'Varianty textarea';

  @override
  String get designSystemTextareaWithCounterLabel => 'S počítadlem';

  @override
  String get designSystemTextareaWithErrorLabel => 'S chybou';

  @override
  String get designSystemTextareaWithHelperLabel => 'S nápovědou';

  @override
  String get designSystemTimePickerFormatsTitle => 'Formáty času';

  @override
  String get designSystemTimePickerTwelveHourLabel => '12hodinový';

  @override
  String get designSystemTimePickerTwentyFourHourLabel => '24hodinový';

  @override
  String get designSystemTitleOnlyVariantTitle => 'Varianta pouze s názvem';

  @override
  String get designSystemToastDetailsLabel => 'Detaily oznámení';

  @override
  String get designSystemToggleLabel => 'Popisek přepínače';

  @override
  String get designSystemTooltipIconMessageSample =>
      'Užitečné informace o tomto poli';

  @override
  String get designSystemTooltipIconVariantsTitle => 'Ikona nápovědy';

  @override
  String get designSystemUndoLabel => 'Zpět';

  @override
  String get designSystemVariantMatrixTitle => 'Matice variant';

  @override
  String get designSystemVerticalLabel => 'Svislý';

  @override
  String get designSystemWarningLabel => 'Varování';

  @override
  String get designSystemWeeklyCalendarLabel => 'Týdenní kalendář';

  @override
  String get designSystemWithLabelLabel => 'Se štítkem';

  @override
  String get desktopEmptyStateSelectDashboard =>
      'Vyber nástěnku pro zobrazení podrobností';

  @override
  String get desktopEmptyStateSelectProject =>
      'Vyber projekt pro zobrazení podrobností';

  @override
  String get desktopEmptyStateSelectTask =>
      'Vyber úkol pro zobrazení podrobností';

  @override
  String deviceDeletedSuccess(String deviceName) {
    return 'Zařízení $deviceName bylo úspěšně odstraněno';
  }

  @override
  String deviceDeleteFailed(String error) {
    return 'Zařízení se nepodařilo odstranit: $error';
  }

  @override
  String get doneButton => 'Hotovo';

  @override
  String get editMenuTitle => 'Upravit';

  @override
  String get editorDiscardChanges => 'Zahodit změny';

  @override
  String get editorInsertDivider => 'Vložit oddělovač';

  @override
  String get editorMoreFormatting => 'Více formátování';

  @override
  String get editorPlaceholder => 'Zadejte poznámky...';

  @override
  String get embeddingSelectAll => 'Vybrat vše';

  @override
  String get embeddingUnselectAll => 'Zrušit výběr';

  @override
  String get enhancedPromptFormPreconfiguredPromptDescription =>
      'Vyberte z připravených šablon výzev';

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
  String get eventNameLabel => 'Událost:';

  @override
  String get eventsAddCoverPhoto => 'Přidat titulní fotku';

  @override
  String get eventsAddLabel => 'Přidat';

  @override
  String get eventsChangeCover => 'Změnit obálku';

  @override
  String get eventsDeleteEvent => 'Smazat událost';

  @override
  String get eventsFilterAll => 'Vše';

  @override
  String eventsMetricPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotek',
      few: '$count fotky',
      one: '1 fotka',
    );
    return '$_temp0';
  }

  @override
  String eventsMetricTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count úkolů',
      few: '$count úkoly',
      one: '1 úkol',
    );
    return '$_temp0';
  }

  @override
  String get eventsNewEvent => 'Nová událost';

  @override
  String get eventsPageTitle => 'Události';

  @override
  String get eventsPhotosSection => 'Fotky';

  @override
  String get eventsRecapAwaitingContent =>
      'Přidej fotku nebo poznámku a tady se objeví shrnutí.';

  @override
  String get eventsRecapUnavailable => 'Shrnutí se nepodařilo načíst.';

  @override
  String get eventsRegenerateSummary => 'Znovu vytvořit shrnutí';

  @override
  String get eventsSearchHint => 'Hledat události';

  @override
  String get eventsSectionUpcoming => 'Nadcházející';

  @override
  String get eventsStatusCancelled => 'Zrušeno';

  @override
  String get eventsStatusCompleted => 'Dokončeno';

  @override
  String get eventsStatusMissed => 'Zmeškáno';

  @override
  String get eventsStatusOngoing => 'Probíhá';

  @override
  String get eventsStatusPlanned => 'Naplánováno';

  @override
  String get eventsStatusPostponed => 'Odloženo';

  @override
  String get eventsStatusRescheduled => 'Přeplánováno';

  @override
  String get eventsStatusTentative => 'Předběžně';

  @override
  String get eventsSummaryTitle => 'Souhrn';

  @override
  String get eventsTasksEmpty => 'Propoj přípravný nebo navazující úkol';

  @override
  String get eventsTasksSection => 'Úkoly';

  @override
  String get eventsTimelineEmpty =>
      'Přidej fotky, poznámky nebo hlasovou poznámku';

  @override
  String get eventsTimelineSection => 'Časová osa';

  @override
  String get eventsTitleHint => 'Název události';

  @override
  String get eventsVoiceNote => 'Hlasová poznámka';

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
  String get filterSelectionNoMatches => 'Žádné shody';

  @override
  String get geminiThinkingModeHighDescription =>
      'Nejhlubší uvažování; může zvýšit latenci a cenu.';

  @override
  String get geminiThinkingModeHighLabel => 'Vysoké';

  @override
  String get geminiThinkingModeLowDescription =>
      'Nízké uvažování pro rychlé každodenní prompty.';

  @override
  String get geminiThinkingModeLowLabel => 'Nízké';

  @override
  String get geminiThinkingModeMediumDescription =>
      'Vyvážené uvažování pro pečlivější odpovědi.';

  @override
  String get geminiThinkingModeMediumLabel => 'Střední';

  @override
  String get geminiThinkingModeMinimalDescription =>
      'Nejrychlejší nastavení; Gemini může u složitých promptů pořád krátce uvažovat.';

  @override
  String get geminiThinkingModeMinimalLabel => 'Minimální';

  @override
  String get generateCoverArt => 'Vytvořit obálku';

  @override
  String get generateCoverArtSubtitle => 'Vytvořit obrázek z hlasového popisu';

  @override
  String get habitActiveFromLabel => 'Datum začátku';

  @override
  String get habitActiveSwitchDescription => 'Zobrazuje se na stránce Návyky';

  @override
  String get habitArchivedLabel => 'Archivováno';

  @override
  String get habitCategoryHint => 'Vyberte kategorii';

  @override
  String get habitCategoryLabel => 'Kategorie';

  @override
  String get habitCloseCompletionLabel => 'Zavřít záznam návyku';

  @override
  String habitCompleteSemanticLabel(String habit) {
    return 'Zaznamenat $habit';
  }

  @override
  String get habitCompletionStatusCompleted => 'Hotovo';

  @override
  String get habitCompletionStatusFailed => 'Nezdařeno';

  @override
  String get habitCompletionStatusOpen => 'Otevřeno';

  @override
  String get habitCompletionStatusSkipped => 'Přeskočeno';

  @override
  String get habitDashboardHint => 'Vyberte panel';

  @override
  String get habitDashboardLabel => 'Panel (volitelné)';

  @override
  String habitDayStatusSemantic(String habit, String status) {
    return '$habit, $status';
  }

  @override
  String get habitDeleteConfirm => 'ANO, SMAŽ TENTO ZVYK';

  @override
  String get habitDeleteQuestion => 'Chcete tento zvyk smazat?';

  @override
  String habitHeatmapDaySemantic(String date, int done, int total) {
    return '$date, $done z $total splněno';
  }

  @override
  String get habitLogOtherDayHint => 'Podržením zaznamenáš jiný den';

  @override
  String get habitNotRecordedLabel => 'Nezaznamenáno';

  @override
  String get habitPriorityLabel => 'Priorita';

  @override
  String get habitsAboveGoal => 'Podle plánu';

  @override
  String habitsActiveHabitsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aktivních návyků',
      few: '$count aktivní návyky',
      one: '1 aktivní návyk',
    );
    return '$_temp0';
  }

  @override
  String get habitsAllDoneToday => 'Dnes hotovo vše';

  @override
  String get habitsCompletedHeader => 'Dokončeno';

  @override
  String get habitsCompletionRateTitle => 'Míra plnění';

  @override
  String get habitsConsistencyTitle => 'Důslednost';

  @override
  String habitsDayFailedPercent(int percent) {
    return '$percent% zaznamenáno jako zmeškané';
  }

  @override
  String habitsDaySkippedPercent(int percent) {
    return '$percent% přeskočeno';
  }

  @override
  String habitsDaySuccessfulPercent(int percent) {
    return '$percent% úspěšně';
  }

  @override
  String get habitsDoneTodayLabel => 'Hotovo dnes';

  @override
  String get habitSectionOptionsTitle => 'Možnosti';

  @override
  String get habitSectionScheduleTitle => 'Rozvrh';

  @override
  String get habitsFilterAll => 'všechny';

  @override
  String get habitsFilterCompleted => 'hotovo';

  @override
  String get habitsFilterOpenNow => 'nyní';

  @override
  String get habitsFilterPendingLater => 'později';

  @override
  String get habitsGoalLineLabel => 'Cíl';

  @override
  String get habitsHeatmapEmpty =>
      'Přidej návyk a začni budovat svou důslednost';

  @override
  String get habitsHeatmapLess => 'Méně';

  @override
  String get habitsHeatmapMore => 'Více';

  @override
  String get habitShowAlertAtLabel => 'Zobrazit upozornění v';

  @override
  String get habitShowFromLabel => 'Zobrazit od';

  @override
  String habitsLaggardHint(String habit, int kept, int active) {
    return '$habit — splněno $kept z $active';
  }

  @override
  String get habitsOpenHeader => 'K splnění';

  @override
  String get habitsPendingLaterHeader => 'Později dnes';

  @override
  String habitsPointsToGoal(int points) {
    return '$points b. k cíli';
  }

  @override
  String get habitsRecordButton => 'Zaznamenat';

  @override
  String get habitsRollingAverageLabel => '7denní průměr';

  @override
  String get habitsStartStreakToday => 'Začni sérii ještě dnes';

  @override
  String habitsStreakLongCount(int count) {
    return '$count se sérií 7 dnů';
  }

  @override
  String habitsStreakShortCount(int count) {
    return '$count se sérií 3 dnů';
  }

  @override
  String get habitsTapForBreakdown => 'Klepnutím na den zobrazíš rozpis';

  @override
  String habitsToGoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'zbývá $count',
      few: 'zbývají $count',
      one: 'zbývá 1',
    );
    return '$_temp0';
  }

  @override
  String habitStreakDaysSemantic(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dní v řadě',
      few: '$count dny v řadě',
      one: '1 den v řadě',
    );
    return '$_temp0';
  }

  @override
  String get habitsVsPreviousWeek => 'vs. minulý týden';

  @override
  String get imageGenerationError => 'Nepodařilo se vygenerovat obrázek';

  @override
  String get imageGenerationGenerating => 'Generování obrázku...';

  @override
  String get imageGenerationProviderRejectedTitle =>
      'Poskytovatel obrázků tuto žádost odmítl';

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
  String get inactiveLabel => 'Neaktivní';

  @override
  String get inactiveSwitchDescription =>
      'Lze vybrat pro nové záznamy, když je zapnuto';

  @override
  String get inferenceProfileCreateTitle => 'Create Profile';

  @override
  String get inferenceProfileDescriptionLabel => 'Description';

  @override
  String get inferenceProfileDesktopOnly => 'Desktop Only';

  @override
  String get inferenceProfileDesktopOnlyDescription =>
      'Only available on desktop platforms (e.g. for local models)';

  @override
  String inferenceProfileDetailLoadError(String error) {
    return 'Profil se nepodařilo načíst: $error';
  }

  @override
  String get inferenceProfileDetailNotFound => 'Profil nenalezen';

  @override
  String get inferenceProfileEditTitle => 'Edit Profile';

  @override
  String get inferenceProfileImageGeneration => 'Image Generation';

  @override
  String get inferenceProfileImageRecognition => 'Image Recognition';

  @override
  String get inferenceProfileModelUnavailable =>
      'Model není dostupný — jeho poskytovatel byl možná odebrán';

  @override
  String get inferenceProfileNameLabel => 'Profile Name';

  @override
  String get inferenceProfileNameRequired => 'A profile name is required';

  @override
  String get inferenceProfilePinnedHostHelper =>
      'Když je nastaveno, pouze toto zařízení automaticky spouští inference pro synchronizované zvukové záznamy používající tento profil.';

  @override
  String get inferenceProfilePinnedHostLabel => 'Připnuté zařízení';

  @override
  String get inferenceProfilePinnedHostNoEligibleNodes =>
      'Žádné známé zařízení neoznamuje poskytovatele, které tento profil používá. Otevři nastavení synchronizačních uzlů na cílovém zařízení.';

  @override
  String get inferenceProfilePinnedHostNoneHelper =>
      'Synchronizované zvukové záznamy se nebudou automaticky přepisovat, dokud nebude připnuté nějaké zařízení.';

  @override
  String get inferenceProfilePinnedHostNoneLabel =>
      'Nepřipnuto (bez automatického spuštění)';

  @override
  String get inferenceProfilePinnedHostThisDeviceSuffix => ' (toto zařízení)';

  @override
  String get inferenceProfileSaveButton => 'Save';

  @override
  String get inferenceProfileSelectModel => 'Select a model…';

  @override
  String get inferenceProfileSelectProfile => 'Vyberte profil…';

  @override
  String get inferenceProfilesEmpty => 'No inference profiles yet';

  @override
  String inferenceProfileSkillModelRequired(String slotName) {
    return 'Vyžaduje nastavení modelu $slotName';
  }

  @override
  String get inferenceProfileSkillsSection => 'Automatizované dovednosti';

  @override
  String inferenceProfileSkillUsesModel(String slotName) {
    return 'Používá model $slotName';
  }

  @override
  String get inferenceProfilesTitle => 'Inference Profiles';

  @override
  String get inferenceProfileThinking => 'Thinking';

  @override
  String get inferenceProfileThinkingHighEnd => 'Thinking (High-End)';

  @override
  String get inferenceProfileThinkingRequired => 'A thinking model is required';

  @override
  String get inferenceProfileTranscription => 'Transcription';

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
  String get insightsChartCompareCaption => 'Toto období vs. předchozí';

  @override
  String get insightsChartCompareCaptionPartial =>
      'Toto období zatím vs. předchozí';

  @override
  String get insightsChartCompareHint => 'Porovnání v tabulce níže';

  @override
  String get insightsChartCumulativeCaption => 'Průběžný součet za období';

  @override
  String get insightsChartCumulativeShort =>
      'Zatím málo dní pro průběžný součet';

  @override
  String get insightsChartDailyCaption => 'Čas za den';

  @override
  String get insightsChartHourlyCaption => 'Čas za hodinu';

  @override
  String get insightsChartPerDay => 'Za den';

  @override
  String get insightsChartPerHour => 'Za hodinu';

  @override
  String get insightsChartPerWeek => 'Za týden';

  @override
  String get insightsChartRunningTotal => 'Průběžný součet';

  @override
  String get insightsChartTitle => 'Čas podle kategorie';

  @override
  String get insightsChartWeeklyCaption => 'Čas za týden';

  @override
  String get insightsChooseFocusCategories => 'Vybrat fokusové kategorie';

  @override
  String get insightsCompare => 'Porovnat';

  @override
  String get insightsCompareFullPeriod => 'celé období';

  @override
  String get insightsComparePrevious => 'Předchozí';

  @override
  String get insightsCompareSameDays => 'stejné dny';

  @override
  String get insightsCompareTooltip => 'Porovnat s předchozím obdobím';

  @override
  String get insightsCompareVs => 'vs';

  @override
  String get insightsDeletedCategory => 'Smazaná kategorie';

  @override
  String get insightsDeltaNew => 'nový';

  @override
  String get insightsEmptyBody =>
      'Čas, který zaznamenáš u záznamů a úkolů, se zobrazí tady.';

  @override
  String get insightsEmptyChart => 'V tomto období nejsou žádná data';

  @override
  String get insightsEmptyPreviousPeriod => 'Zobrazit předchozí období';

  @override
  String get insightsEmptyShowYear => 'Zobrazit tento rok';

  @override
  String get insightsEmptyTitle => 'V tomto období není zaznamenaný žádný čas';

  @override
  String get insightsFocusCategoriesEmpty => 'Zatím žádné aktivní kategorie.';

  @override
  String get insightsFocusCategoriesTitle => 'Fokusové kategorie';

  @override
  String get insightsKpiFocus => 'FOKUS';

  @override
  String get insightsKpiFocusHelp => 'Kategorie, které sleduješ';

  @override
  String get insightsKpiOther => 'OSTATNÍ';

  @override
  String get insightsKpiOtherHelp => 'Vše ostatní';

  @override
  String insightsKpiTopCategory(String category, String share) {
    return 'Nejvíce na $category · $share';
  }

  @override
  String get insightsKpiTotal => 'CELKEM';

  @override
  String get insightsLoadError => 'Data o čase se nepodařilo načíst';

  @override
  String get insightsOtherCategories => 'Ostatní';

  @override
  String get insightsPartialWeek => 'část týdne';

  @override
  String get insightsPeriodDay => 'Den';

  @override
  String get insightsPeriodJump => 'Přejít na datum';

  @override
  String get insightsPeriodMonth => 'Měsíc';

  @override
  String get insightsPeriodNext => 'Další období';

  @override
  String get insightsPeriodPrevious => 'Předchozí období';

  @override
  String get insightsPeriodQuarter => 'Čtvrtletí';

  @override
  String get insightsPeriodToDateSuffix => 'zatím';

  @override
  String get insightsPeriodWeek => 'Týden';

  @override
  String get insightsPeriodYear => 'Rok';

  @override
  String get insightsRangeMonthToDate => 'Tento měsíc zatím';

  @override
  String get insightsRangeMtd => 'Tento měsíc';

  @override
  String get insightsRangeYearToDate => 'Tento rok zatím';

  @override
  String get insightsRangeYtd => 'Tento rok';

  @override
  String get insightsRefreshError =>
      'Nepodařilo se obnovit — zobrazují se naposledy načtená data';

  @override
  String get insightsTableAvgPerDay => 'Ø/DEN';

  @override
  String get insightsTableCategory => 'KATEGORIE';

  @override
  String get insightsTableCompareNote => 'Změna oproti předchozímu období';

  @override
  String get insightsTableCurrent => 'AKTUÁLNÍ';

  @override
  String get insightsTableDelta => 'Změna';

  @override
  String get insightsTablePrevious => 'PŘEDCHOZÍ';

  @override
  String get insightsTableShare => 'PODÍL';

  @override
  String get insightsTableTotal => 'CELKEM';

  @override
  String get insightsTimeAnalysisTitle => 'Analýza času';

  @override
  String get insightsUncategorized => 'Bez kategorie';

  @override
  String get journalCopyImageLabel => 'Kopírovat obrázek';

  @override
  String get journalDateFromLabel => 'Datum od:';

  @override
  String get journalDateInvalid => 'Neplatné časové rozmezí';

  @override
  String get journalDateLabel => 'Datum';

  @override
  String get journalDateNowButton => 'Nyní';

  @override
  String get journalDateSaveButton => 'ULOŽIT';

  @override
  String get journalDateTimeRangeTitle => 'Datum a čas';

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
  String get journalDurationLabel => 'Doba trvání';

  @override
  String get journalEndDateLabel => 'Datum konce';

  @override
  String get journalEndsAnotherDayHint => 'Vyber samostatné datum konce';

  @override
  String get journalEndsAnotherDayLabel => 'Končí jiný den';

  @override
  String get journalEndTimeLabel => 'Čas konce';

  @override
  String get journalFilterEntryTypesTitle => 'Typy záznamů';

  @override
  String get journalFilterFlagged => 'Označené';

  @override
  String get journalFilterPrivate => 'Soukromé';

  @override
  String get journalFilterShowTitle => 'Zobrazit';

  @override
  String get journalFilterStarred => 'Oblíbené';

  @override
  String get journalHideLinkHint => 'Skrýt odkaz';

  @override
  String get journalHideMapHint => 'Skrýt mapu';

  @override
  String get journalLinkedEntriesActivityFilterAudio => 'Audio';

  @override
  String get journalLinkedEntriesActivityFilterCode => 'Kód';

  @override
  String get journalLinkedEntriesActivityFilterImages => 'Obrázky';

  @override
  String get journalLinkedEntriesActivityFilterTimer => 'Časovač';

  @override
  String get journalLinkedEntriesFilterModalTitle => 'Filtrovat a řadit';

  @override
  String get journalLinkedEntriesShowFlaggedOnly =>
      'Zobrazit pouze označené záznamy';

  @override
  String get journalLinkedEntriesShowHidden => 'Zobrazit skryté záznamy';

  @override
  String get journalLinkedEntriesSortLabel => 'Řadit podle';

  @override
  String get journalLinkedEntriesSortNewestFirst => 'Nejnovější první';

  @override
  String get journalLinkedEntriesSortOldestFirst => 'Nejstarší první';

  @override
  String get journalLinkedFromLabel => 'Odkaz z:';

  @override
  String get journalLinkFromHint => 'Odkaz z';

  @override
  String get journalLinkToHint => 'Odkaz na';

  @override
  String journalOvernightNextDay(String date) {
    return 'Končí $date (další den)';
  }

  @override
  String get journalPrivateTooltip => 'pouze soukromé';

  @override
  String get journalSearchHint => 'Hledat deník...';

  @override
  String get journalShareHint => 'Sdílet';

  @override
  String get journalShowLinkHint => 'Zobrazit odkaz';

  @override
  String get journalShowMapHint => 'Zobrazit mapu';

  @override
  String get journalStartDateLabel => 'Datum začátku';

  @override
  String get journalStartTimeLabel => 'Čas začátku';

  @override
  String get journalTodayButton => 'Dnes';

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
  String get knowledgeGraphEmpty => 'Zatím žádné odkazy k prozkoumání';

  @override
  String get knowledgeGraphError => 'Znalostní graf se nepodařilo načíst';

  @override
  String get knowledgeGraphTitle => 'Graf znalostí';

  @override
  String get knowledgeGraphTooltip => 'Prozkoumat odkazy';

  @override
  String get linkedFromCaption => 'z';

  @override
  String get linkedTaskImageBadge => 'Z propojené úlohy';

  @override
  String get linkedTasksMenuTooltip => 'Možnosti propojených úkolů';

  @override
  String get linkedTasksTitle => 'Propojené úkoly';

  @override
  String get linkedToCaption => 'na';

  @override
  String get linkExistingTask => 'Propojit existující úkol...';

  @override
  String get loggingDomainAgentRuntime => 'Běh agentů';

  @override
  String get loggingDomainAgentWorkflow => 'Pracovní postup agentů';

  @override
  String get loggingDomainAi => 'AI';

  @override
  String get loggingDomainCalendar => 'Kalendář a čas';

  @override
  String get loggingDomainChat => 'Chat';

  @override
  String get loggingDomainDailyOs => 'Daily OS';

  @override
  String get loggingDomainDatabase => 'Databáze';

  @override
  String get loggingDomainGeneral => 'Obecné';

  @override
  String get loggingDomainHabits => 'Návyky';

  @override
  String get loggingDomainHealth => 'Zdraví';

  @override
  String get loggingDomainLabels => 'Štítky';

  @override
  String get loggingDomainLocation => 'Poloha';

  @override
  String get loggingDomainNavigation => 'Navigace';

  @override
  String get loggingDomainNotifications => 'Oznámení';

  @override
  String get loggingDomainOnboarding => 'Onboarding a FTUE';

  @override
  String get loggingDomainPersistence => 'Perzistence';

  @override
  String get loggingDomainRatings => 'Hodnocení';

  @override
  String get loggingDomainScreenshots => 'Snímky obrazovky';

  @override
  String get loggingDomainSettings => 'Nastavení';

  @override
  String get loggingDomainSpeech => 'Řeč a zvuk';

  @override
  String get loggingDomainSync => 'Synchronizace';

  @override
  String get loggingDomainTasks => 'Úkoly a seznamy';

  @override
  String get loggingDomainTheming => 'Motivy';

  @override
  String get loggingDomainWhatsNew => 'Novinky';

  @override
  String get maintenanceDeleteAgentDb => 'Smazat databázi agentů';

  @override
  String get maintenanceDeleteAgentDbDescription =>
      'Smazat databázi agentů a restartovat aplikaci';

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
  String get maintenanceDeleteSyncDb => 'Smazat synchronizační databázi';

  @override
  String get maintenanceDeleteSyncDbDescription =>
      'Smazat synchronizační databázi';

  @override
  String get maintenanceGenerateEmbeddings => 'Generovat vektory';

  @override
  String get maintenanceGenerateEmbeddingsConfirm => 'ANO, GENEROVAT';

  @override
  String get maintenanceGenerateEmbeddingsDescription =>
      'Generovat vektory pro záznamy ve vybraných kategoriích';

  @override
  String get maintenanceGenerateEmbeddingsMessage =>
      'Vyber kategorie pro generování vektorů.';

  @override
  String maintenanceGenerateEmbeddingsProgress(
    int processed,
    int total,
    int embedded,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      embedded,
      locale: localeName,
      other: '$embedded vektorů vloženo',
      few: '$embedded vektory vloženy',
      one: '1 vektor vložen',
    );
    String _temp1 = intl.Intl.pluralLogic(
      embedded,
      locale: localeName,
      other: '$embedded vektorů vloženo',
      few: '$embedded vektory vloženy',
      one: '1 vektor vložen',
    );
    String _temp2 = intl.Intl.pluralLogic(
      embedded,
      locale: localeName,
      other: '$embedded vektorů vloženo',
      few: '$embedded vektory vloženy',
      one: '1 vektor vložen',
    );
    String _temp3 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$processed / $total záznamů ($_temp0)',
      few: '$processed / $total záznamy ($_temp1)',
      one: '$processed / $total záznam ($_temp2)',
    );
    return '$_temp3';
  }

  @override
  String get maintenancePopulatePhaseAgentEntities =>
      'Zpracování entit agentů...';

  @override
  String get maintenancePopulatePhaseAgentLinks =>
      'Zpracování propojení agentů...';

  @override
  String get maintenancePopulatePhaseJournal => 'Zpracování záznamů deníku...';

  @override
  String get maintenancePopulatePhaseLinks => 'Zpracování propojení záznamů...';

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
  String get maintenancePurgeSentOutbox =>
      'Vyčistit staré odeslané položky odchozí pošty';

  @override
  String get maintenancePurgeSentOutboxConfirm => 'ANO, VYČISTIT';

  @override
  String get maintenancePurgeSentOutboxDescription =>
      'Smazat řádky odchozí pošty odeslané před více než 7 dny a uvolnit místo na disku';

  @override
  String get maintenancePurgeSentOutboxQuestion =>
      'Vyčistit položky odchozí pošty odeslané před více než 7 dny? Tato akce smaže již odeslané řádky po blocích a spustí VACUUM pro uvolnění místa na disku. Čekající a chybové položky zůstanou zachovány.';

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
  String get maintenanceReSyncAgentEntities => 'Entity agentů';

  @override
  String get maintenanceReSyncDescription =>
      'Znovu synchronizovat zprávy ze serveru';

  @override
  String get maintenanceReSyncEntityTypes => 'Typy entit';

  @override
  String get maintenanceReSyncJournalEntities => 'Záznamy v deníku';

  @override
  String get maintenanceReSyncSelectAtLeastOne =>
      'Vyber alespoň jeden typ entity';

  @override
  String get maintenanceReSyncStart => 'Spustit';

  @override
  String get maintenanceSyncDefinitions =>
      'Synchronizovat měřitelné údaje, dashboardy, návyky, kategorie, AI nastavení';

  @override
  String get maintenanceSyncDefinitionsDescription =>
      'Synchronizovat měřitelné údaje, dashboardy, návyky, kategorie a AI nastavení';

  @override
  String get manageLinks => 'Spravovat propojení...';

  @override
  String get measurableDeleteConfirm => 'ANO, SMAŽ TUTO MĚŘITELNOU';

  @override
  String get measurableDeleteQuestion =>
      'Chcete tento měřitelný datový typ smazat?';

  @override
  String get measurableNotFound => 'Měřitelný typ nenalezen';

  @override
  String get measurementCommentHint => 'Přidat poznámku (volitelné)';

  @override
  String get measurementQuickAddLabel => 'Rychlé přidání';

  @override
  String get mediaShowInFileExplorerAction => 'Zobrazit v Průzkumníku souborů';

  @override
  String get mediaShowInFilesAction => 'Zobrazit v Souborech';

  @override
  String get mediaShowInFinderAction => 'Zobrazit ve Finderu';

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
  String get modelEditBackTooltip => 'Zpět';

  @override
  String get modelEditDescriptionHint => 'Popiš tento model';

  @override
  String get modelEditDescriptionLabel => 'Popis';

  @override
  String get modelEditDisplayNameHint => 'Přívětivý název pro tento model';

  @override
  String get modelEditDisplayNameLabel => 'Zobrazované jméno';

  @override
  String get modelEditFunctionCallingDescription =>
      'Tento model podporuje volání funkcí a nástrojů.';

  @override
  String get modelEditFunctionCallingLabel => 'Volání funkcí';

  @override
  String get modelEditGeminiThinkingModeLabel => 'Režim uvažování Gemini';

  @override
  String get modelEditInputModalitiesHint => 'Vyber vstupní typy';

  @override
  String get modelEditInputModalitiesLabel => 'Vstupní modality';

  @override
  String get modelEditLoadError => 'Nepodařilo se načíst konfiguraci modelu';

  @override
  String get modelEditMaxTokensHint =>
      'Volitelné — ponech prázdné pro neomezeno';

  @override
  String get modelEditMaxTokensLabel => 'Maximální počet completion tokenů';

  @override
  String get modelEditModalityNoneSelected => 'Nic nevybráno';

  @override
  String get modelEditOutputModalitiesHint => 'Vyber výstupní typy';

  @override
  String get modelEditOutputModalitiesLabel => 'Výstupní modality';

  @override
  String get modelEditPageTitle => 'Upravit model';

  @override
  String get modelEditProviderHint => 'Vyber poskytovatele';

  @override
  String get modelEditProviderLabel => 'Poskytovatel';

  @override
  String get modelEditProviderModelIdHint => 'např. gpt-4-turbo';

  @override
  String get modelEditProviderModelIdLabel => 'ID modelu u poskytovatele';

  @override
  String get modelEditReasoningDescription =>
      'Tento model používá rozšířené myšlení / řetězec úvah.';

  @override
  String get modelEditReasoningLabel => 'Model pro uvažování';

  @override
  String get modelEditSaveButton => 'Uložit';

  @override
  String get modelEditSectionCapabilities => 'Schopnosti';

  @override
  String get modelEditSectionIdentity => 'Identita';

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
  String get multiSelectAddButton => 'Přidat';

  @override
  String multiSelectAddButtonWithCount(int count) {
    return 'Přidat ($count)';
  }

  @override
  String get multiSelectNoItemsFound => 'Žádné položky nenalezeny';

  @override
  String navTabMoreSemanticsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Více, $count dalších sekcí',
      few: 'Více, $count další sekce',
      one: 'Více, 1 další sekce',
    );
    return '$_temp0';
  }

  @override
  String get navTabTitleCalendar => 'DailyOS';

  @override
  String get navTabTitleEvents => 'Události';

  @override
  String get navTabTitleHabits => 'Zvyky';

  @override
  String get navTabTitleInsights => 'Přehledy';

  @override
  String get navTabTitleJournal => 'Zápisník';

  @override
  String get navTabTitleMore => 'Více';

  @override
  String get navTabTitleProjects => 'Projekty';

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
  String get noTasksFound => 'Nebyly nalezeny žádné úkoly';

  @override
  String get noTasksToLink => 'Žádné dostupné úkoly k propojení';

  @override
  String get notificationBellEmptySemantics =>
      'Oznámení, žádná nepřečtená upozornění';

  @override
  String get notificationBellTooltip => 'Oznámení';

  @override
  String notificationBellUnseenSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Oznámení, $count nepřečtených upozornění',
      few: 'Oznámení, $count nepřečtená upozornění',
      one: 'Oznámení, 1 nepřečtené upozornění',
    );
    return '$_temp0';
  }

  @override
  String get notificationInboxDismiss => 'Zavřít oznámení';

  @override
  String get notificationInboxEmpty => 'Máš všechno přečtené.';

  @override
  String get notificationInboxError => 'Oznámení se nepodařilo načíst.';

  @override
  String get notificationInboxTitle => 'Oznámení';

  @override
  String get notificationSuggestionAttentionBodyFallback =>
      'Otevři úkol a zkontroluj jej.';

  @override
  String notificationSuggestionAttentionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count návrhů potřebuje tvou pozornost',
      few: '$count návrhy potřebují tvou pozornost',
      one: '1 návrh potřebuje tvou pozornost',
    );
    return '$_temp0';
  }

  @override
  String get onboardingApiKeyConnect => 'Připojit';

  @override
  String get onboardingApiKeyConnecting => 'Připojuji…';

  @override
  String get onboardingApiKeyEnterKeyHint =>
      'Zadej platný klíč pro pokračování.';

  @override
  String get onboardingApiKeyError =>
      'Připojení selhalo. Zkontroluj klíč a zkus to znovu.';

  @override
  String get onboardingApiKeyField => 'API klíč';

  @override
  String get onboardingApiKeyGetKeyAt => 'Klíč získáš na';

  @override
  String get onboardingApiKeyHide => 'Skrýt klíč';

  @override
  String get onboardingApiKeyInvalid =>
      'Tento klíč byl odmítnut. Zkontroluj ho a vlož ho znovu.';

  @override
  String get onboardingApiKeyLocalNote =>
      'Běží na tvém zařízení – klíč není potřeba.';

  @override
  String get onboardingApiKeyNoKeyHelp =>
      'Poprvé tady? Přihlas se, vytvoř API klíč a vlož ho – zdarma na začátek.';

  @override
  String get onboardingApiKeyReveal => 'Zobrazit klíč';

  @override
  String get onboardingApiKeyTitle => 'Vlož svůj API klíč';

  @override
  String onboardingApiKeyUnreachable(String providerName) {
    return 'Nepodařilo se spojit s $providerName. Zkontroluj klíč nebo připojení a zkus to znovu.';
  }

  @override
  String get onboardingApiKeyVerifying => 'Ověřuji…';

  @override
  String get onboardingCategoryAddOwn => 'Přidat vlastní';

  @override
  String get onboardingCategoryContinue => 'Pokračovat';

  @override
  String get onboardingCategoryExplanation =>
      'Lotti udržuje každou oblast tvého života v jejím vlastním prostoru, aby úkoly a návrhy zůstaly relevantní. Vyber si pár na začátek — kdykoli je můžeš změnit.';

  @override
  String get onboardingCategoryFamily => 'Rodina';

  @override
  String get onboardingCategoryFitness => 'Fitness';

  @override
  String get onboardingCategoryFriends => 'Přátelé';

  @override
  String get onboardingCategoryTitle => 'Kde má tvoje AI pracovat?';

  @override
  String get onboardingCategoryWhy => 'Proč oblasti?';

  @override
  String onboardingCategoryWhyDetail(String provider) {
    return 'Každá oblast může používat vlastní AI. $provider bude pohánět oblasti, které zde vybereš — později můžeš různým oblastem přiřadit různé AI.';
  }

  @override
  String get onboardingCategoryWork => 'Práce';

  @override
  String get onboardingConnectGeminiName => 'Gemini';

  @override
  String get onboardingConnectGeminiTagline => 'Spojené státy';

  @override
  String get onboardingConnectLessOptions => 'Méně možností';

  @override
  String get onboardingConnectMistralName => 'Mistral';

  @override
  String get onboardingConnectMistralTagline => 'Evropská unie';

  @override
  String get onboardingConnectMoreOptions => 'Další možnosti';

  @override
  String get onboardingConnectNotSure =>
      'Nevíš? Gemini je pro začátek nejjednodušší.';

  @override
  String get onboardingConnectOllamaName => 'Ollama';

  @override
  String get onboardingConnectOpenAiName => 'OpenAI';

  @override
  String get onboardingConnectQwenName => 'Qwen';

  @override
  String get onboardingConnectQwenTagline => 'Čína';

  @override
  String get onboardingConnectTitle =>
      'Vyber mozek, který promění tvá slova v úkoly';

  @override
  String get onboardingSuccessContinue => 'Začít';

  @override
  String get onboardingSuccessSubtitle =>
      'Tvůj AI mozek je připojený a promění tvá slova v úkoly.';

  @override
  String get onboardingSuccessTitle => 'Vše připraveno';

  @override
  String get onboardingWelcomeConnectButton => 'Připojit mozek';

  @override
  String get onboardingWelcomeMessage =>
      'Připoj svůj AI mozek, vyslov myšlenku a sleduj, jak se mění ve strukturovaný úkol.';

  @override
  String get onboardingWelcomeSkipButton => 'Nejdřív se rozhlédnout';

  @override
  String get onboardingWelcomeTitle => 'Mluv. Lotti z toho udělá plán.';

  @override
  String get optionalCategoryLabel => 'Kategorie (volitelné)';

  @override
  String get outboxActionRemove => 'Odebrat';

  @override
  String get outboxActionRetry => 'Zkusit znovu';

  @override
  String get outboxFailedReassurance =>
      'Stále uloženo v tomto zařízení – synchronizace proběhne, jakmile se problém vyřeší.';

  @override
  String get outboxFilterFailed => 'Selhalo';

  @override
  String get outboxFilterWaiting => 'Čeká';

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
  String get outboxMonitorFetchFailed =>
      'Odchozí poštu se nepodařilo načíst. Stáhněte dolů pro obnovení a zkuste to znovu.';

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
  String get outboxMonitorPayloadSizeLabel => 'Velikost';

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
  String get outboxMonitorVolumeChartTitle => 'Denní objem synchronizace';

  @override
  String get outboxRemoveConfirmMessage =>
      'Tato změna ještě nebyla synchronizována. Když ji zde odeberete, nedostane se na vaše ostatní zařízení. V tomto zařízení zůstane.';

  @override
  String get outboxRemoveConfirmTitle => 'Odebrat z fronty?';

  @override
  String get outboxRetryAll => 'Zkusit vše znovu';

  @override
  String get outboxShowDetails => 'Zobrazit technické podrobnosti';

  @override
  String get outboxStatusFailed => 'Nepodařilo se odeslat';

  @override
  String get outboxStatusSending => 'Odesílá se';

  @override
  String get outboxStatusSent => 'Odesláno';

  @override
  String get outboxStatusWaiting => 'Čeká na odeslání';

  @override
  String outboxSummaryFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count položek se nepodařilo odeslat',
      few: '$count položky se nepodařilo odeslat',
      one: '1 položku se nepodařilo odeslat',
    );
    return '$_temp0';
  }

  @override
  String outboxSummaryOffline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count položek se odešle po opětovném připojení',
      few: '$count položky se odešlou po opětovném připojení',
      one: '1 položka se odešle po opětovném připojení',
    );
    return '$_temp0';
  }

  @override
  String outboxSummarySending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Odesílá se $count položek…',
      few: 'Odesílají se $count položky…',
      one: 'Odesílá se 1 položka…',
    );
    return '$_temp0';
  }

  @override
  String get outboxSummarySynced => 'Vše synchronizováno';

  @override
  String outboxSummaryWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count položek čeká na odeslání',
      few: '$count položky čekají na odeslání',
      one: '1 položka čeká na odeslání',
    );
    return '$_temp0';
  }

  @override
  String outboxTriedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zkusil $count×',
      few: 'Zkusil $count×',
      one: 'Zkusil jednou',
    );
    return '$_temp0';
  }

  @override
  String get privateLabel => 'Soukromé';

  @override
  String get privateSwitchDescription =>
      'Viditelné pouze při zobrazení soukromých záznamů';

  @override
  String get projectAgentNotProvisioned =>
      'Pro tento projekt ještě nebyl nastaven žádný projektový agent.';

  @override
  String get projectAgentSectionTitle => 'Agent';

  @override
  String projectCountSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count projektů',
      few: '$count projekty',
      one: '$count projekt',
    );
    return '$_temp0';
  }

  @override
  String get projectCreateButton => 'Nový projekt';

  @override
  String get projectCreateTitle => 'Vytvořit projekt';

  @override
  String get projectDetailTitle => 'Detail projektu';

  @override
  String get projectErrorCreateFailed => 'Chyba při vytváření projektu.';

  @override
  String get projectErrorLoadFailed => 'Nepodařilo se načíst data projektu.';

  @override
  String get projectErrorLoadProjects => 'Chyba při načítání projektů';

  @override
  String get projectErrorUpdateFailed =>
      'Nepodařilo se aktualizovat projekt. Zkuste to prosím znovu.';

  @override
  String get projectFilterLabel => 'Projekt';

  @override
  String get projectHealthBandAtRisk => 'V ohrožení';

  @override
  String get projectHealthBandBlocked => 'Blokováno';

  @override
  String get projectHealthBandOnTrack => 'Na dobré cestě';

  @override
  String get projectHealthBandSurviving => 'Drží se';

  @override
  String get projectHealthBandWatch => 'Sledovat';

  @override
  String get projectHealthSectionTitle => 'Stav projektu';

  @override
  String projectHealthSummary(int projectCount, int taskCount) {
    String _temp0 = intl.Intl.pluralLogic(
      projectCount,
      locale: localeName,
      other: '$projectCount projektů',
      few: '$projectCount projekty',
      one: '$projectCount projekt',
    );
    String _temp1 = intl.Intl.pluralLogic(
      taskCount,
      locale: localeName,
      other: '$taskCount úkolů',
      few: '$taskCount úkoly',
      one: '$taskCount úkol',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get projectHealthTitle => 'Projekty';

  @override
  String projectLinkedTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count propojených úkolů',
      few: '$count propojené úkoly',
      one: '$count propojený úkol',
    );
    return '$_temp0';
  }

  @override
  String get projectLinkedTasks => 'Propojené úkoly';

  @override
  String get projectManageTooltip => 'Správa projektů';

  @override
  String get projectNoLinkedTasks => 'Zatím žádné propojené úkoly';

  @override
  String get projectNoProjects => 'Zatím žádné projekty';

  @override
  String get projectNotFound => 'Projekt nenalezen';

  @override
  String get projectPickerLabel => 'Projekt';

  @override
  String get projectPickerUnassigned => 'Žádný projekt';

  @override
  String get projectRecommendationDismissTooltip => 'Zahodit';

  @override
  String get projectRecommendationResolveTooltip => 'Označit jako vyřešené';

  @override
  String get projectRecommendationsTitle => 'Doporučené další kroky';

  @override
  String get projectRecommendationUpdateError =>
      'Doporučení se nepodařilo aktualizovat. Zkus to prosím znovu.';

  @override
  String get projectsFilterStatusLabel => 'Stav:';

  @override
  String get projectsFilterTooltip => 'Filtrovat projekty';

  @override
  String get projectShowcaseAiReportTitle => 'AI report';

  @override
  String projectShowcaseBlockedLegend(int count) {
    return '$count blokováno';
  }

  @override
  String projectShowcaseBlockedTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blokovaných úkolů',
      few: '$count blokované úkoly',
      one: '$count blokovaný úkol',
    );
    return '$_temp0';
  }

  @override
  String projectShowcaseCompletedLegend(int count) {
    return '$count dokončeno';
  }

  @override
  String get projectShowcaseDescriptionTitle => 'Popis';

  @override
  String projectShowcaseDueDate(String date) {
    return 'Termín $date';
  }

  @override
  String get projectShowcaseHealthScoreDescription =>
      'Tohle skóre vychází z rychlosti postupu úkolů, blokátorů a času do termínu.';

  @override
  String get projectShowcaseHealthScoreTitle => 'Skóre zdraví';

  @override
  String get projectShowcaseNoResults =>
      'Žádné projekty neodpovídají tvému hledání.';

  @override
  String get projectShowcaseOneOnOneReviewsTab => '1:1 hodnocení';

  @override
  String get projectShowcaseOngoing => 'Průběžně';

  @override
  String get projectShowcaseProjectTasksTab => 'Projektové úkoly';

  @override
  String get projectShowcaseSearchHint => 'Hledat projekty';

  @override
  String projectShowcaseSessionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sezení',
      few: '$count sezení',
      one: '$count sezení',
    );
    return '$_temp0';
  }

  @override
  String projectShowcaseTasksCompleted(int completed, int total) {
    return '$completed z $total úkolů dokončeno';
  }

  @override
  String projectShowcaseUpdatedHoursAgo(int hours) {
    return 'Aktualizováno před $hours hod. ↻';
  }

  @override
  String projectShowcaseUpdatedMinutesAgo(int minutes) {
    return 'Aktualizováno před $minutes min ↻';
  }

  @override
  String get projectShowcaseUsefulness => 'Užitečnost';

  @override
  String get projectShowcaseViewBlocker => 'Zobrazit blokátor';

  @override
  String get projectStatusActive => 'Aktivní';

  @override
  String get projectStatusArchived => 'Archivovaný';

  @override
  String get projectStatusChangeTitle => 'Změnit stav';

  @override
  String get projectStatusCompleted => 'Dokončený';

  @override
  String get projectStatusMonitoring => 'Sledování';

  @override
  String get projectStatusOnHold => 'Pozastavený';

  @override
  String get projectStatusOpen => 'Otevřený';

  @override
  String get projectSummaryOutdated => 'Shrnutí je zastaralé.';

  @override
  String projectSummaryOutdatedScheduled(String date, String time) {
    return 'Shrnutí je zastaralé. Další aktualizace $date v $time.';
  }

  @override
  String get projectTargetDateLabel => 'Cílové datum';

  @override
  String get projectTitleLabel => 'Název projektu';

  @override
  String get projectTitleRequired => 'Název projektu nesmí být prázdný';

  @override
  String get promptDefaultModelBadge => 'Výchozí';

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
  String get promptSelectionModalTitle => 'Vyberte přednastavenou výzvu';

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
  String get queueCatchUpNowButton => 'Dohnat nyní';

  @override
  String get queueCatchUpNowDone =>
      'Dohánění spuštěno — fronta se vyprazdňuje.';

  @override
  String queueCatchUpNowError(String reason) {
    return 'Dohánění selhalo: $reason';
  }

  @override
  String get queueDepthCardEmpty => 'Fronta je prázdná — worker je aktuální.';

  @override
  String get queueDepthCardLoading => 'Čtení hloubky fronty…';

  @override
  String get queueDepthCardTitle => 'Vstupní fronta';

  @override
  String get queueFetchAllHistoryCancel => 'Zrušit';

  @override
  String queueFetchAllHistoryCancelled(int events) {
    String _temp0 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: 'zatím načteno $events událostí',
      few: 'zatím načteny $events události',
      one: 'zatím načtena 1 událost',
      zero: 'zatím žádné události',
    );
    return 'Zrušeno — $_temp0.';
  }

  @override
  String get queueFetchAllHistoryClose => 'Zavřít';

  @override
  String get queueFetchAllHistoryDescription =>
      'Prochází celou viditelnou historii místnosti do fronty. Lze kdykoli zrušit; pozdější spuštění pokračuje tam, kde stránkování skončilo.';

  @override
  String queueFetchAllHistoryDone(int events, int pages) {
    String _temp0 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages stránkách',
      few: '$pages stránkách',
      one: '1 stránce',
    );
    String _temp1 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages stránkách',
      few: '$pages stránkách',
      one: '1 stránce',
    );
    String _temp2 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages stránkách',
      few: '$pages stránkách',
      one: '1 stránce',
    );
    String _temp3 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: 'Načteno $events událostí na $_temp0.',
      few: 'Načteny $events události na $_temp1.',
      one: 'Načtena 1 událost na $_temp2.',
      zero: 'Žádné události.',
    );
    return '$_temp3';
  }

  @override
  String queueFetchAllHistoryError(String reason) {
    return 'Načítání zastaveno: $reason';
  }

  @override
  String get queueFetchAllHistoryErrorUnknown =>
      'Načítání se neočekávaně zastavilo.';

  @override
  String queueFetchAllHistoryProgress(int events, int pages) {
    String _temp0 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: 'Strana $pages  ·  $events událostí načteno',
      few: 'Strana $pages  ·  $events události načteny',
      one: 'Strana $pages  ·  1 událost načtena',
    );
    return '$_temp0';
  }

  @override
  String get queueFetchAllHistoryTitle => 'Načítání historie';

  @override
  String queueSkippedBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count přeskočeno',
      few: '$count přeskočeny',
      one: '1 přeskočena',
    );
    return '$_temp0';
  }

  @override
  String queueSkippedCardBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count synchronizačních událostí, které fronta vzdala. Klepni na opakovat pro nový pokus.',
      few:
          '$count synchronizační události, které fronta vzdala. Klepni na opakovat pro nový pokus.',
      one:
          '1 synchronizační událost, kterou fronta vzdala. Klepni na opakovat pro nový pokus.',
    );
    return '$_temp0';
  }

  @override
  String get queueSkippedCardTitle => 'Přeskočené události';

  @override
  String get queueSkippedRetryAll => 'Opakovat přeskočené události';

  @override
  String queueSkippedRetryAllDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count událostí zařazeno k opakování.',
      few: '$count události zařazeny k opakování.',
      one: '1 událost zařazena k opakování.',
      zero: 'Žádné přeskočené události.',
    );
    return '$_temp0';
  }

  @override
  String queueSkippedRetryAllError(String reason) {
    return 'Opakování selhalo: $reason';
  }

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
      'Vyberte až 5 obrázků pro vedení vizuálního stylu AI';

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
  String get saveShortcutTooltip => 'Uložit — Ctrl+S (⌘S na Macu)';

  @override
  String get saveSuccessful => 'Úspěšně uloženo';

  @override
  String get searchHint => 'Hledat...';

  @override
  String get searchModeFullText => 'Plný text';

  @override
  String get searchModeVector => 'Vektor';

  @override
  String get searchTasksHint => 'Hledat úkoly...';

  @override
  String get selectButton => 'Vybrat';

  @override
  String get selectColor => 'Vyberte barvu';

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
  String get settingsAboutDailyOsPersonalizationTitle =>
      'Přizpůsobení Daily OS';

  @override
  String get settingsAboutDailyOsUserNameHelper =>
      'Používá se jen pro pozdrav Daily OS na tomto zařízení.';

  @override
  String get settingsAboutDailyOsUserNameLabel => 'Tvoje jméno';

  @override
  String get settingsAboutJournalEntries => 'Záznamy v deníku';

  @override
  String get settingsAboutPlatform => 'Platforma';

  @override
  String get settingsAboutTitle => 'O Lotti';

  @override
  String get settingsAboutVersion => 'Verze';

  @override
  String get settingsAboutYourData => 'Vaše data';

  @override
  String get settingsAdvancedAboutSubtitle => 'Zjistěte více o aplikaci Lotti';

  @override
  String get settingsAdvancedHealthImportSubtitle =>
      'Importujte zdravotní údaje z externích zdrojů';

  @override
  String get settingsAdvancedMaintenanceSubtitle =>
      'Provádějte údržbové úkoly pro optimalizaci výkonu aplikace';

  @override
  String get settingsAdvancedOutboxSubtitle =>
      'Spravujte položky synchronizace';

  @override
  String get settingsAdvancedSubtitle => 'Pokročilá nastavení a údržba';

  @override
  String get settingsAdvancedTitle => 'Pokročilá nastavení';

  @override
  String get settingsAgentsInstancesSubtitle => 'Běžící agenti';

  @override
  String get settingsAgentsPendingWakesSubtitle => 'Naplánované wake timery';

  @override
  String get settingsAgentsSoulsSubtitle => 'Dlouhodobé osobnosti agentů';

  @override
  String get settingsAgentsStatsSubtitle => 'Spotřeba tokenů a aktivita';

  @override
  String get settingsAgentsTemplatesSubtitle => 'Sdílené šablony agentů';

  @override
  String get settingsAiModelsSubtitle =>
      'Modely a schopnosti podle poskytovatele';

  @override
  String get settingsAiModelsTitle => 'Modely';

  @override
  String get settingsAiProfilesSubtitle => 'Poskytovatelé a modely';

  @override
  String get settingsAiProfilesTitle => 'Inferenční profily';

  @override
  String get settingsAiProvidersSubtitle =>
      'Připojení poskytovatelé AI a klíče';

  @override
  String get settingsAiProvidersTitle => 'Poskytovatelé';

  @override
  String get settingsAiSubtitle =>
      'Konfigurace poskytovatelů AI, modelů a promptů';

  @override
  String get settingsAiTitle => 'Nastavení AI';

  @override
  String get settingsBeamPageEditModelTitle => 'Upravit model';

  @override
  String get settingsBeamPageEditProfileTitle => 'Upravit profil';

  @override
  String get settingsCategoriesCreateTitle => 'Vytvořit kategorii';

  @override
  String get settingsCategoriesDetailsLabel => 'Upravit kategorii';

  @override
  String get settingsCategoriesEmptyState => 'Zatím žádné kategorie';

  @override
  String get settingsCategoriesEmptyStateHint =>
      'Vytvořte kategorii pro organizaci vašich záznamů';

  @override
  String get settingsCategoriesErrorLoading => 'Chyba při načítání kategorií';

  @override
  String get settingsCategoriesNameLabel => 'Název kategorie';

  @override
  String settingsCategoriesNoMatchQuery(String query) {
    return 'Žádné kategorie neodpovídají dotazu \"$query\"';
  }

  @override
  String get settingsCategoriesSearchHint => 'Hledat kategorie…';

  @override
  String get settingsCategoriesSubtitle => 'Kategorie s nastavením AI';

  @override
  String settingsCategoriesTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count úkolů',
      few: '$count úkoly',
      one: '$count úkol',
    );
    return '$_temp0';
  }

  @override
  String get settingsCategoriesTitle => 'Kategorie';

  @override
  String get settingsCelebrationsChecklistDescription =>
      'Cuknutí a jiskry, když odškrtneš položku';

  @override
  String get settingsCelebrationsChecklistTitle => 'Položky seznamu';

  @override
  String get settingsCelebrationsEnabledDescription =>
      'Hlavní vypínač efektů dokončení. Vypnuto skryje všechny animace; haptika má vlastní přepínač.';

  @override
  String get settingsCelebrationsEnabledTitle => 'Animace dokončení';

  @override
  String get settingsCelebrationsHabitsDescription =>
      'Záře a jiskry, když dokončíš návyk';

  @override
  String get settingsCelebrationsHabitsTitle => 'Návyky';

  @override
  String get settingsCelebrationsHapticsDescription =>
      'Krátké zavibrování, když něco dokončíš – nezávislé na animaci.';

  @override
  String get settingsCelebrationsHapticsTitle => 'Haptika při dokončení';

  @override
  String get settingsCelebrationsPreviewChecklistItem => 'Odškrtni mě';

  @override
  String get settingsCelebrationsPreviewDescription =>
      'Klepnutím na ovládací prvek přehraješ svůj styl.';

  @override
  String get settingsCelebrationsPreviewDone => 'Hotovo';

  @override
  String get settingsCelebrationsPreviewHabit => 'Návyk';

  @override
  String get settingsCelebrationsPreviewTitle => 'Vyzkoušet';

  @override
  String get settingsCelebrationsSectionDescription =>
      'Malá oslava, když něco dokončíš. Když některou vypneš, dokončení (i jeho vibrace) zůstane — jen se vynechá animace.';

  @override
  String get settingsCelebrationsSectionTitle => 'Oslavy při dokončení';

  @override
  String get settingsCelebrationsStyleDescription =>
      'Klepnutím na kartu zobrazíš náhled stylu a vybereš ho.';

  @override
  String get settingsCelebrationsStyleTitle => 'Styl';

  @override
  String get settingsCelebrationsSubtitle => 'Oslavy při dokončení';

  @override
  String get settingsCelebrationsTasksDescription =>
      'Záře a jiskry, když přesuneš úkol na Hotovo';

  @override
  String get settingsCelebrationsTasksTitle => 'Úkoly';

  @override
  String get settingsCelebrationsTitle => 'Animace';

  @override
  String get settingsCelebrationsVariantBubbles => 'Bubliny';

  @override
  String get settingsCelebrationsVariantConfetti => 'Konfety';

  @override
  String get settingsCelebrationsVariantEmbers => 'Žhavé uhlíky';

  @override
  String get settingsCelebrationsVariantFireworks => 'Ohňostroj';

  @override
  String get settingsCelebrationsVariantSparks => 'Jiskry';

  @override
  String get settingsConflictsTitle => 'Konflikty synchronizace';

  @override
  String get settingsDashboardDetailsLabel => 'Upravit panel';

  @override
  String get settingsDashboardSaveLabel => 'Uložit';

  @override
  String get settingsDashboardsCreateTitle => 'Vytvořit panel';

  @override
  String get settingsDashboardsEmptyState => 'Zatím žádné panely';

  @override
  String get settingsDashboardsEmptyStateHint =>
      'Klepněte na tlačítko + pro vytvoření prvního panelu.';

  @override
  String get settingsDashboardsErrorLoading => 'Chyba při načítání panelů';

  @override
  String settingsDashboardsNoMatchQuery(String query) {
    return 'Žádný panel neodpovídá \"$query\"';
  }

  @override
  String get settingsDashboardsSearchHint => 'Hledat panely';

  @override
  String get settingsDashboardsSubtitle => 'Přizpůsobit zobrazení panelu';

  @override
  String get settingsDashboardsTitle => 'Panely';

  @override
  String get settingsDefinitionsSubtitle =>
      'Návyky, kategorie, štítky, panely a měřitelné údaje';

  @override
  String get settingsDefinitionsTitle => 'Definice';

  @override
  String get settingsFlagsEmptySearch =>
      'Žádné příznaky neodpovídají vašemu hledání';

  @override
  String get settingsFlagsSearchHint => 'Hledat příznaky';

  @override
  String get settingsFlagsSubtitle => 'Konfigurace příznaků a možností';

  @override
  String get settingsFlagsTitle => 'Konfigurační příznaky';

  @override
  String get settingsHabitsCreateTitle => 'Vytvořit návyk';

  @override
  String get settingsHabitsDeleteTooltip => 'Smazat návyk';

  @override
  String get settingsHabitsDescriptionLabel => 'Popis (volitelné)';

  @override
  String get settingsHabitsDetailsLabel => 'Upravit návyk';

  @override
  String get settingsHabitsEmptyState => 'Zatím žádné návyky';

  @override
  String get settingsHabitsEmptyStateHint =>
      'Klepněte na tlačítko + pro vytvoření prvního návyku.';

  @override
  String get settingsHabitsErrorLoading => 'Chyba při načítání návyků';

  @override
  String get settingsHabitsNameLabel => 'Název návyku';

  @override
  String settingsHabitsNoMatchQuery(String query) {
    return 'Žádný návyk neodpovídá \"$query\"';
  }

  @override
  String get settingsHabitsPrivateLabel => 'Soukromé: ';

  @override
  String get settingsHabitsSaveLabel => 'Uložit';

  @override
  String get settingsHabitsSearchHint => 'Hledat návyky';

  @override
  String get settingsHabitsSubtitle => 'Spravovat návyky a rutiny';

  @override
  String get settingsHabitsTitle => 'Návyky';

  @override
  String get settingsHealthImportActivity => 'Importovat data aktivity';

  @override
  String get settingsHealthImportBloodPressure =>
      'Importovat data krevního tlaku';

  @override
  String get settingsHealthImportBodyMeasurement =>
      'Importovat data tělesných měr';

  @override
  String get settingsHealthImportFromDate => 'Začátek';

  @override
  String get settingsHealthImportHeartRate =>
      'Importovat data tepové frekvence';

  @override
  String get settingsHealthImportSleep => 'Importovat data spánku';

  @override
  String get settingsHealthImportTitle => 'Import zdraví';

  @override
  String get settingsHealthImportToDate => 'Konec';

  @override
  String get settingsHealthImportWorkout => 'Importovat data tréninků';

  @override
  String get settingsLabelsCategoriesAdd => 'Přidat kategorii';

  @override
  String get settingsLabelsCategoriesHeading => 'Použitelné kategorie';

  @override
  String get settingsLabelsCategoriesNone => 'Platí pro všechny kategorie';

  @override
  String get settingsLabelsCategoriesRemoveTooltip => 'Odstranit';

  @override
  String get settingsLabelsColorHeading => 'Barva';

  @override
  String get settingsLabelsColorSubheading => 'Rychlé přednastavení';

  @override
  String get settingsLabelsCreateTitle => 'Vytvořit štítek';

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
  String settingsLabelsNoMatchCreate(String query) {
    return 'Vytvořit štítek \"$query\"';
  }

  @override
  String settingsLabelsNoMatchQuery(String query) {
    return 'Žádný štítek neodpovídá \"$query\"';
  }

  @override
  String get settingsLabelsPrivateDescription =>
      'Viditelné pouze při zobrazení soukromých záznamů';

  @override
  String get settingsLabelsPrivateTitle => 'Soukromé';

  @override
  String get settingsLabelsSearchHint => 'Hledat štítky';

  @override
  String get settingsLabelsSubtitle => 'Organizujte úkoly barevnými štítky';

  @override
  String get settingsLabelsTitle => 'Štítky';

  @override
  String settingsLabelsUsageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count úkolů',
      few: '$count úkoly',
      one: '1 úkol',
    );
    return '$_temp0';
  }

  @override
  String get settingsLoggingDomainsSubtitle =>
      'Control which domains write to the log';

  @override
  String get settingsLoggingDomainsTitle => 'Logging Domains';

  @override
  String get settingsLoggingGlobalToggle => 'Enable Logging';

  @override
  String get settingsLoggingGlobalToggleSubtitle =>
      'Master switch for all logging';

  @override
  String get settingsLoggingSlowQueries => 'Pomalé databázové dotazy';

  @override
  String get settingsLoggingSlowQueriesSubtitle =>
      'Pomalé dotazy se zapisují do slow_queries-YYYY-MM-DD.log';

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
  String get settingsMatrixContinueVerificationLabel =>
      'Přijměte na jiném zařízení pro pokračování';

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
  String get settingsMatrixLastUpdated => 'Naposledy aktualizováno:';

  @override
  String get settingsMatrixListUnverifiedLabel => 'Neověřená zařízení';

  @override
  String get settingsMatrixMaintenanceSubtitle =>
      'Spustit úlohy údržby Matrix a nástroje pro obnovení';

  @override
  String get settingsMatrixMaintenanceTitle => 'Údržba';

  @override
  String get settingsMatrixMetrics => 'Metriky synchronizace';

  @override
  String get settingsMatrixNextPage => 'Další stránka';

  @override
  String get settingsMatrixNoUnverifiedLabel => 'Žádná neověřená zařízení';

  @override
  String get settingsMatrixPreviousPage => 'Předchozí stránka';

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
  String get settingsMatrixTitle => 'Nastavení synchronizace';

  @override
  String get settingsMatrixUnverifiedDevicesPage => 'Neověřená zařízení';

  @override
  String get settingsMatrixVerificationCancelledLabel =>
      'Zrušeno na jiném zařízení...';

  @override
  String get settingsMatrixVerificationSuccessConfirm => 'Rozumím';

  @override
  String settingsMatrixVerificationSuccessLabel(
    String deviceName,
    String deviceID,
  ) {
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
  String get settingsMeasurableAggregationHelper =>
      'Jak se záznamy jednoho dne kombinují v grafech';

  @override
  String get settingsMeasurableAggregationLabel => 'Výchozí agregace';

  @override
  String get settingsMeasurableDeleteTooltip => 'Smazat měřitelný typ';

  @override
  String get settingsMeasurableDescriptionLabel => 'Popis (volitelné)';

  @override
  String get settingsMeasurableDetailsLabel => 'Upravit měřitelný typ';

  @override
  String get settingsMeasurableNameLabel => 'Název měřitelného';

  @override
  String get settingsMeasurablePrivateLabel => 'Soukromé: ';

  @override
  String get settingsMeasurableSaveLabel => 'Uložit';

  @override
  String get settingsMeasurablesCreateTitle => 'Vytvořit měřitelný typ';

  @override
  String get settingsMeasurablesEmptyState => 'Zatím žádné měřitelné typy';

  @override
  String get settingsMeasurablesEmptyStateHint =>
      'Měřitelné typy jsou čísla sledovaná v čase — váha, voda, kroky.';

  @override
  String get settingsMeasurablesErrorLoading =>
      'Chyba při načítání měřitelných typů';

  @override
  String settingsMeasurablesNoMatchQuery(String query) {
    return 'Žádný měřitelný typ neodpovídá \"$query\"';
  }

  @override
  String get settingsMeasurablesSearchHint => 'Hledat měřitelné typy';

  @override
  String get settingsMeasurablesSubtitle =>
      'Konfigurace měřitelných datových typů';

  @override
  String get settingsMeasurablesTitle => 'Měřitelné typy';

  @override
  String get settingsMeasurableUnitLabel => 'Zkratka jednotky (volitelné)';

  @override
  String get settingsOnboardingMetricsSubtitle =>
      'FTUE trychtýř — instalace, aktivace, retence (ladění)';

  @override
  String get settingsOnboardingMetricsTitle => 'Metriky onboardingu';

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
  String get settingsSpeechSubtitle => 'Hlas a předčítání';

  @override
  String get settingsSpeechTitle => 'Řeč';

  @override
  String get settingsSyncConflictsSubtitle =>
      'Řešte konflikty synchronizace pro zajištění konzistence dat';

  @override
  String get settingsSyncNodeProfileCapabilitiesEmpty =>
      'Žádné detekovány — automatické spuštění inference pro synchronizovaný zvuk nebude na toto zařízení směrováno.';

  @override
  String get settingsSyncNodeProfileCapabilitiesLabel =>
      'Detekované AI schopnosti';

  @override
  String get settingsSyncNodeProfileCapabilityMlxAudio => 'MLX Audio (lokální)';

  @override
  String get settingsSyncNodeProfileCapabilityOllamaLlm => 'Ollama LLM';

  @override
  String get settingsSyncNodeProfileCapabilityOmlxLlm => 'oMLX LLM';

  @override
  String get settingsSyncNodeProfileCapabilityVoxtral => 'Voxtral (lokální)';

  @override
  String get settingsSyncNodeProfileCapabilityWhisper => 'Whisper (lokální)';

  @override
  String get settingsSyncNodeProfileDisplayNameHelper =>
      'Viditelné pro tvá další zařízení při výběru, ke kterému profil připnout.';

  @override
  String get settingsSyncNodeProfileDisplayNameLabel =>
      'Zobrazované jméno zařízení';

  @override
  String get settingsSyncNodeProfileKnownNodesEmpty =>
      'Žádné jiné zařízení dosud nepublikovalo profil.';

  @override
  String get settingsSyncNodeProfileKnownNodesTitle =>
      'Známá synchronizační zařízení';

  @override
  String get settingsSyncNodeProfileSaveButton => 'Uložit';

  @override
  String get settingsSyncNodeProfileSubtitle =>
      'Pojmenuj toto zařízení a zkontroluj schopnosti viditelné pro tvá další zařízení.';

  @override
  String get settingsSyncNodeProfileTitle => 'Toto zařízení';

  @override
  String get settingsSyncOutboxTitle => 'Synchronizace odeslané pošty';

  @override
  String get settingsSyncStatsSubtitle =>
      'Prohlédněte si metriky synchronizačního procesu';

  @override
  String get settingsSyncSubtitle =>
      'Nastavte synchronizaci a zobrazte statistiky';

  @override
  String get settingsThemingAutomatic => 'Automaticky';

  @override
  String get settingsThemingDark => 'Tmavé prostředí';

  @override
  String get settingsThemingLight => 'Světlé prostředí';

  @override
  String get settingsThemingSubtitle => 'Přizpůsobit vzhled a témata aplikace';

  @override
  String get settingsThemingTitle => 'Vzhled';

  @override
  String get settingsV2CategoryEmptyBody => 'Vyber pod-nastavení vlevo.';

  @override
  String get settingsV2DetailRootCrumb => 'Nastavení';

  @override
  String get settingsV2EmptyStateBody => 'Vyber sekci vlevo, abys mohl začít.';

  @override
  String get settingsV2ResizeHandleLabel => 'Změnit velikost stromu nastavení';

  @override
  String get settingsV2UnimplementedTitle => 'Panel zatím není k dispozici';

  @override
  String get settingsWhatsNewSubtitle =>
      'Podívej se na nejnovější aktualizace a funkce';

  @override
  String get settingsWhatsNewTitle => 'Co je nového';

  @override
  String get settingThemingDark => 'Tmavé téma';

  @override
  String get settingThemingLight => 'Světlé téma';

  @override
  String get sidebarRunningTimerLabel => 'Běžící časovač';

  @override
  String get sidebarRunningTimerStopTooltip => 'Zastavit časovač';

  @override
  String get sidebarToggleCollapseLabel => 'Sbalit postranní panel';

  @override
  String get sidebarToggleExpandLabel => 'Rozbalit postranní panel';

  @override
  String get sidebarWakesCancelTooltip => 'Zrušit agenta';

  @override
  String get sidebarWakesHeader => 'Agenti';

  @override
  String get sidebarWakesNow => 'nyní';

  @override
  String get sidebarWakesOpenList => 'Otevřít seznam';

  @override
  String get skillsSectionTitle => 'Dovednosti';

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
  String get speechModalSelectLanguage => 'Vyberte jazyk';

  @override
  String get speechModalTitle => 'Rozpoznávání řeči';

  @override
  String get speechSettingsModelDescription => 'Hlasový model v zařízení';

  @override
  String get speechSettingsModelDownloadsOnce => 'Stáhne se jednou';

  @override
  String get speechSettingsModelLabel => 'Model';

  @override
  String get speechSettingsRecommendedBadge => 'Doporučeno';

  @override
  String get speechSettingsSpeedDescription =>
      'Jak rychle se shrnutí předčítají';

  @override
  String get speechSettingsSpeedLabel => 'Rychlost čtení';

  @override
  String get speechSettingsVoiceDescription =>
      'Vyber hlas, který předčítá shrnutí';

  @override
  String get speechSettingsVoiceLabel => 'Hlas';

  @override
  String get speechVoiceGenderFemale => 'Ženský';

  @override
  String get speechVoiceGenderMale => 'Mužský';

  @override
  String get speechVoicePreviewTooltip => 'Přehrát ukázku hlasu';

  @override
  String get syncActivityInboxLabel => 'Příchozí';

  @override
  String syncActivityIndicatorSemantics(int outbox, int inbox) {
    return 'Aktivita synchronizace. Odchozí: $outbox. Příchozí: $inbox. Otevřít odchozí frontu synchronizace.';
  }

  @override
  String get syncActivityOutboxLabel => 'Odchozí';

  @override
  String get syncDeleteConfigConfirm => 'ANO, JSEM SI JISTÝ';

  @override
  String get syncDeleteConfigQuestion =>
      'Chcete smazat konfiguraci synchronizace?';

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
  String get syncNotLoggedInToast => 'Synchronizace není přihlášena';

  @override
  String get syncPayloadAgentBundle => 'Balíček agenta';

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
  String get syncPayloadConfigFlag => 'Konfigurační příznak';

  @override
  String get syncPayloadEntityDefinition => 'Definice entity';

  @override
  String get syncPayloadEntryLink => 'Odkaz na položku';

  @override
  String get syncPayloadJournalEntity => 'Položka deníku';

  @override
  String get syncPayloadNotification => 'Oznámení';

  @override
  String get syncPayloadNotificationStateUpdate => 'Aktualizace stavu oznámení';

  @override
  String get syncPayloadOutboxBundle => 'Odchozí balíček';

  @override
  String get syncPayloadSyncNodeProfile => 'Profil synchronizačního uzlu';

  @override
  String get syncPayloadThemingSelection => 'Výběr tématu';

  @override
  String get syncStepAgentEntities => 'Entity agentů';

  @override
  String get syncStepAgentLinks => 'Propojení agentů';

  @override
  String get syncStepAiSettings => 'AI nastavení';

  @override
  String get syncStepBackfillAgentEntityClocks => 'Doplnění hodin entit agentů';

  @override
  String get syncStepBackfillAgentLinkClocks =>
      'Doplnění hodin propojení agentů';

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
  String get taskActionBarAudioRecordingActive => 'Probíhá nahrávání zvuku';

  @override
  String get taskActionBarMoreActions => 'Další akce';

  @override
  String get taskActionBarOpenRunningTimer => 'Otevřít aktivní časovač';

  @override
  String get taskActionBarStopTracking => 'Zastavit sledování času';

  @override
  String get taskActionBarTrackTime => 'Sledovat čas';

  @override
  String get taskAgentCancelTimerTooltip => 'Cancel';

  @override
  String taskAgentCountdownTooltip(String countdown) {
    return 'Příští automatické spuštění za $countdown';
  }

  @override
  String get taskAgentCreateChipLabel => 'Přiřadit agenta';

  @override
  String taskAgentCreateError(String error) {
    return 'Nepodařilo se vytvořit agenta: $error';
  }

  @override
  String get taskAgentRunNowTooltip => 'Spustit nyní';

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
  String get taskEditTitleLabel => 'Upravit název úkolu';

  @override
  String get taskEstimateLabel => 'Odhad:';

  @override
  String taskEstimateProgressLabel(String tracked, String estimate) {
    return '$tracked z $estimate';
  }

  @override
  String taskEstimateTooltip(String tracked, String estimate) {
    return 'Zaznamenaný čas: $tracked z odhadovaných $estimate';
  }

  @override
  String taskLabelsMoreCount(int count) {
    return '+$count';
  }

  @override
  String get taskLabelsShowFewer => 'Zobrazit méně';

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
  String get taskLanguageLabel => 'Jazyk';

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
  String get taskLanguageSelectedLabel => 'Aktuálně vybráno';

  @override
  String get taskLanguageSerbian => 'Srbština';

  @override
  String get taskLanguageSetAction => 'Nastavit jazyk';

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
  String get taskPriorityHigh => 'Vysoká';

  @override
  String get taskPriorityLow => 'Nízká';

  @override
  String get taskPriorityMedium => 'Střední';

  @override
  String get taskPriorityUrgent => 'Naléhavá';

  @override
  String get tasksAddLabelButton => 'Přidat štítek';

  @override
  String get tasksAgentFilterAll => 'Vše';

  @override
  String get tasksAgentFilterHasAgent => 'Má agenta';

  @override
  String get tasksAgentFilterNoAgent => 'Bez agenta';

  @override
  String get tasksAgentFilterTitle => 'Agent';

  @override
  String get tasksFilterApplyTitle => 'Použít filtr';

  @override
  String get tasksFilterClearAll => 'Vymazat vše';

  @override
  String get tasksFilterTitle => 'Filtr úkolů';

  @override
  String get taskShowcaseAudio => 'Audio';

  @override
  String taskShowcaseCompletedCount(int completed, int total) {
    return '$completed / $total hotovo';
  }

  @override
  String taskShowcaseDueDate(String date) {
    return 'Termín: $date';
  }

  @override
  String get taskShowcaseJumpToSection => 'Přejít na sekci';

  @override
  String get taskShowcaseLinked => 'Propojené';

  @override
  String get taskShowcaseNoResults => 'Žádné úkoly neodpovídají tvému hledání.';

  @override
  String get taskShowcaseReadMore => 'Číst dále';

  @override
  String taskShowcaseRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nahrávek',
      few: '$count nahrávky',
      one: '1 nahrávka',
    );
    return '$_temp0';
  }

  @override
  String taskShowcaseTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count úkolů',
      few: '$count úkoly',
      one: '1 úkol',
    );
    return '$_temp0';
  }

  @override
  String get taskShowcaseTaskDescription => 'Popis úkolu';

  @override
  String get taskShowcaseTimeTracker => 'Sledování času';

  @override
  String get taskShowcaseTodo => 'Úkol';

  @override
  String get taskShowcaseTodos => 'Úkoly';

  @override
  String get tasksLabelFilterAll => 'Vše';

  @override
  String get tasksLabelFilterTitle => 'Štítek';

  @override
  String get tasksLabelFilterUnlabeled => 'Bez štítku';

  @override
  String get tasksLabelsDialogClose => 'Zavřít';

  @override
  String get tasksLabelsSheetApply => 'Použít';

  @override
  String get tasksLabelsSheetSearchHint => 'Hledat štítky…';

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
  String get tasksQuickFilterClear => 'Vymazat';

  @override
  String get tasksQuickFilterLabelsActiveTitle => 'Aktivní filtry štítků';

  @override
  String get tasksQuickFilterUnassignedLabel => 'Nepřiřazeno';

  @override
  String get tasksSavedFilterDeleteConfirmTooltip => 'Klepni znovu pro smazání';

  @override
  String get tasksSavedFilterDeleteTooltip => 'Smazat uložený filtr';

  @override
  String get tasksSavedFilterDragHandleSemantics => 'Přetáhni pro změnu pořadí';

  @override
  String get tasksSavedFilterRenameSemantics => 'Přejmenovat uložený filtr';

  @override
  String get tasksSavedFiltersSaveButtonLabel => 'Uložit';

  @override
  String get tasksSavedFiltersSavePopupCancel => 'Zrušit';

  @override
  String tasksSavedFiltersSavePopupHelper(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Aktivních $count filtrů. Uloženo na boční panel pod Úkoly.',
      few: 'Aktivní $count filtry. Uloženo na boční panel pod Úkoly.',
      one: 'Aktivní 1 filtr. Uloženo na boční panel pod Úkoly.',
    );
    return '$_temp0';
  }

  @override
  String get tasksSavedFiltersSavePopupHint =>
      'např. Blokované nebo pozastavené';

  @override
  String get tasksSavedFiltersSavePopupSave => 'Uložit';

  @override
  String get tasksSavedFiltersSavePopupTitle => 'Pojmenuj tento filtr';

  @override
  String get tasksSavedFilterToastDeleted => 'Filtr smazán';

  @override
  String tasksSavedFilterToastSaved(String name) {
    return 'Uloženo „$name“';
  }

  @override
  String tasksSavedFilterToastUpdated(String name) {
    return 'Aktualizováno „$name“';
  }

  @override
  String get tasksSearchModeLabel => 'Režim hledání';

  @override
  String get tasksShowCreationDate => 'Zobrazit datum vytvoření na kartách';

  @override
  String get tasksShowDueDate => 'Zobrazit datum splnění na kartách';

  @override
  String get tasksSortByCreationDate => 'Vytvořeno';

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
  String get taskTitleEmpty => 'Bez názvu';

  @override
  String get taskUntitled => '(bez názvu)';

  @override
  String get thinkingDisclosureCopied => 'Úvaha zkopírována';

  @override
  String get thinkingDisclosureCopy => 'Kopírovat úvahu';

  @override
  String get thinkingDisclosureHide => 'Skrýt úvahu';

  @override
  String get thinkingDisclosureShow => 'Zobrazit úvahu';

  @override
  String get thinkingDisclosureStateCollapsed => 'sbaleno';

  @override
  String get thinkingDisclosureStateExpanded => 'rozbaleno';

  @override
  String get timeEntryItemEnd => 'Konec';

  @override
  String get timeEntryItemRunning => 'Probíhá';

  @override
  String get timeEntryItemStart => 'Začátek';

  @override
  String get unlinkButton => 'Zrušit propojení';

  @override
  String get unlinkTaskConfirm =>
      'Opravdu chcete zrušit propojení tohoto úkolu?';

  @override
  String get unlinkTaskTitle => 'Zrušit propojení úkolu';

  @override
  String vectorSearchTiming(int elapsed, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${elapsed}ms, $count výsledků',
      few: '${elapsed}ms, $count výsledky',
      one: '${elapsed}ms, $count výsledek',
    );
    return '$_temp0';
  }

  @override
  String get viewMenuTitle => 'Zobrazit';

  @override
  String get viewMenuZoomIn => 'Přiblížit';

  @override
  String get viewMenuZoomOut => 'Oddálit';

  @override
  String get viewMenuZoomReset => 'Skutečná velikost';

  @override
  String get whatsNewDoneButton => 'Hotovo';

  @override
  String get whatsNewSkipButton => 'Přeskočit';
}

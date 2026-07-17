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
    return '$starIndex z $totalStars hvězdiček';
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
    return '$messageCount zpráv, $toolCallCount volání nástrojů · $shortId';
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
  String get agentEvolutionApprovalRate => 'Míra schválení';

  @override
  String get agentEvolutionChartMttrTrend => 'Trend MTTR';

  @override
  String get agentEvolutionChartSuccessRateTrend => 'Trend úspěšnosti';

  @override
  String get agentEvolutionChartVersionPerformance => 'Podle verze';

  @override
  String get agentEvolutionChartWakeHistory => 'Historie probuzení';

  @override
  String get agentEvolutionChatPlaceholder =>
      'Sdílej zpětnou vazbu nebo se zeptej na výkon…';

  @override
  String get agentEvolutionCurrentDirectives => 'Aktuální direktivy';

  @override
  String get agentEvolutionDashboardTitle => 'Výkon';

  @override
  String get agentEvolutionHistoryTitle => 'Historie vývoje';

  @override
  String get agentEvolutionMetricActive => 'Aktivní';

  @override
  String get agentEvolutionMetricAvgDuration => 'Průměrná doba trvání';

  @override
  String get agentEvolutionMetricFailures => 'Selhání';

  @override
  String get agentEvolutionMetricSuccess => 'Úspěch';

  @override
  String get agentEvolutionMetricWakes => 'Probuzení';

  @override
  String get agentEvolutionNoSessions => 'Zatím žádné relace vývoje';

  @override
  String get agentEvolutionNoteRecorded => 'Poznámka uložena';

  @override
  String get agentEvolutionProposalApprovalFailed =>
      'Schválení se nezdařilo — zkus to znovu';

  @override
  String get agentEvolutionProposalRationale => 'Odůvodnění';

  @override
  String get agentEvolutionProposalRejected =>
      'Návrh zamítnut — pokračuj v konverzaci';

  @override
  String get agentEvolutionProposalTitle => 'Navržené změny';

  @override
  String get agentEvolutionProposedDirectives => 'Navržené direktivy';

  @override
  String get agentEvolutionSessionAbandoned => 'Relace skončila bez změn';

  @override
  String agentEvolutionSessionCompleted(int version) {
    return 'Relace dokončena — vytvořena verze $version';
  }

  @override
  String get agentEvolutionSessionCount => 'Relace';

  @override
  String get agentEvolutionSessionError =>
      'Nepodařilo se zahájit relaci vývoje';

  @override
  String agentEvolutionSessionProgress(int sessionNumber, int totalSessions) {
    return 'Relace $sessionNumber z $totalSessions';
  }

  @override
  String get agentEvolutionSessionStarting => 'Zahajuji relaci vývoje…';

  @override
  String agentEvolutionSessionTitle(int sessionNumber) {
    return 'Vývoj č. $sessionNumber';
  }

  @override
  String agentEvolutionSoulCurrentField(String field) {
    return 'Aktuální — $field';
  }

  @override
  String agentEvolutionSoulProposedField(String field) {
    return 'Navrhované — $field';
  }

  @override
  String get agentEvolutionStatusAbandoned => 'Opuštěno';

  @override
  String get agentEvolutionStatusActive => 'Aktivní';

  @override
  String get agentEvolutionStatusCompleted => 'Dokončeno';

  @override
  String get agentEvolutionTimelineFeedbackLabel => 'Zpětná vazba';

  @override
  String get agentEvolutionVersionProposed => 'Navržena verze';

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
  String get agentObservationsEmpty => 'Zatím žádná zaznamenaná pozorování.';

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
  String get agentReportHistoryBadge => 'Zpráva';

  @override
  String get agentReportHistoryEmpty => 'Zatím žádné uložené snímky zpráv.';

  @override
  String get agentReportHistoryError =>
      'Při načítání historie zpráv došlo k chybě.';

  @override
  String get agentReportNone => 'Report zatím není k dispozici.';

  @override
  String get agentRitualReviewAction => 'Zahájit konverzaci';

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
  String get agentRitualReviewProposalSection => 'Aktuální návrh';

  @override
  String get agentRitualReviewSessionHistory => 'Historie relací';

  @override
  String get agentRitualReviewTitle => '1-on-1';

  @override
  String get agentRitualSummaryApprovedChangesHeading => 'Schválené změny';

  @override
  String get agentRitualSummaryConversationHeading => 'Konverzace';

  @override
  String get agentRitualSummaryRecapHeading => 'Shrnutí relace';

  @override
  String get agentRitualSummaryRoleAssistant => 'Agent';

  @override
  String get agentRitualSummaryRoleUser => 'Ty';

  @override
  String get agentRitualSummaryStartHint =>
      'Zahaj 1-on-1 a projdi, co ti vadilo, co fungovalo a co by se mělo změnit.';

  @override
  String get agentRitualSummarySubtitle =>
      'Nedávné 1-on-1, skutečná aktivita probuzení a domluvené změny.';

  @override
  String get agentRitualSummaryTokensSinceLast => 'Tokeny od posledního 1-on-1';

  @override
  String get agentRitualSummaryWakeHistory30Days =>
      'Aktivita probuzení (posledních 30 dní)';

  @override
  String get agentRitualSummaryWakesSinceLast =>
      'Probuzení od posledního 1-on-1';

  @override
  String get agentRunningIndicator => 'Běží';

  @override
  String get agentSessionProgressTitle => 'Průběh relace';

  @override
  String get agentSettingsSubtitle => 'Šablony, instance a sledování';

  @override
  String get agentSettingsTitle => 'Agenti';

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
  String get agentSoulFieldAntiSycophancy => 'Zásady proti pochlebování';

  @override
  String get agentSoulFieldCoachingStyle => 'Styl koučování';

  @override
  String get agentSoulFieldToneBounds => 'Hranice tónu';

  @override
  String get agentSoulFieldVoice => 'Hlas';

  @override
  String get agentSoulInfoTab => 'Info';

  @override
  String get agentSoulNoneAssigned => 'Žádná duše přiřazena';

  @override
  String get agentSoulNotFound => 'Duše nenalezena';

  @override
  String get agentSoulProposalSubtitle => 'Navržené změny osobnosti';

  @override
  String get agentSoulProposalTitle => 'Návrh změn osobnosti duše';

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
  String get agentTemplateAssignedLabel => 'Šablona';

  @override
  String get agentTemplateCreatedSuccess => 'Šablona vytvořena';

  @override
  String get agentTemplateCreateTitle => 'Vytvořit šablonu';

  @override
  String get agentTemplateDeleteConfirm =>
      'Smazat tuto šablonu? Tuto akci nelze vrátit zpět.';

  @override
  String get agentTemplateDeleteHasInstances =>
      'Nelze smazat: tuto šablonu používají aktivní agenti.';

  @override
  String get agentTemplateDisplayNameLabel => 'Název';

  @override
  String get agentTemplateEditTitle => 'Upravit šablonu';

  @override
  String get agentTemplateEvolveApprove => 'Schválit a uložit';

  @override
  String get agentTemplateEvolveReject => 'Zamítnout';

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
  String get agentTemplateMetricsTotalWakes => 'Celkový počet probuzení';

  @override
  String get agentTemplateNoneAssigned => 'Není přiřazena žádná šablona';

  @override
  String get agentTemplateNoTemplates =>
      'Nejsou k dispozici žádné šablony. Nejdřív vytvoř šablonu v Nastavení.';

  @override
  String get agentTemplateNotFound => 'Šablona nenalezena';

  @override
  String get agentTemplateNoVersions => 'Žádné verze';

  @override
  String get agentTemplateReportDirectiveHint =>
      'Definuj strukturu reportu, povinné sekce a pravidla formátování...';

  @override
  String get agentTemplateReportDirectiveLabel => 'Direktiva reportu';

  @override
  String get agentTemplateReportsEmpty => 'Zatím žádné zprávy.';

  @override
  String get agentTemplateReportsTab => 'Reporty';

  @override
  String get agentTemplateRollbackAction => 'Vrátit tuto verzi';

  @override
  String agentTemplateRollbackConfirm(int version) {
    return 'Vrátit na verzi $version? Agent tuto verzi použije při příštím probuzení.';
  }

  @override
  String get agentTemplateSaveNewVersion => 'Uložit';

  @override
  String get agentTemplateSelectTitle => 'Vybrat šablonu';

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
  String get agentTemplateStatusActive => 'Aktivní';

  @override
  String get agentTemplateStatusArchived => 'Archivovaná';

  @override
  String get agentTemplatesTitle => 'Šablony agentů';

  @override
  String get agentTemplateSwitchHint =>
      'Chceš-li použít jinou šablonu, znič tohoto agenta a vytvoř nového.';

  @override
  String get agentTemplateVersionHistoryTitle => 'Historie verzí';

  @override
  String agentTemplateVersionLabel(int version) {
    return 'Verze $version';
  }

  @override
  String get agentTemplateVersionSaved => 'Nová verze šablony uložena';

  @override
  String get agentThreadReportLabel =>
      'Zpráva vytvořená během tohoto probuzení';

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
  String get aggregationNone => 'Surové hodnoty';

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
  String aiConsumptionCallsLine(int count, int measured) {
    return 'AI volání: $count · dopad změřen u $measured';
  }

  @override
  String aiConsumptionCostLine(String cost) {
    return 'Náklady: $cost';
  }

  @override
  String aiConsumptionImpactLine(String energy, String carbon, String water) {
    return 'Dopad: $energy · $carbon CO₂e · $water vody';
  }

  @override
  String aiConsumptionLedgerCap(int limit) {
    return 'Zobrazuje nejnovějších $limit volání v tomto období';
  }

  @override
  String get aiConsumptionLedgerTitle => 'Nedávná volání';

  @override
  String get aiConsumptionMetricsNotReported => 'Nenahlášeno';

  @override
  String aiConsumptionTokensLabel(String tokens) {
    return '$tokens tokenů';
  }

  @override
  String aiConsumptionTokensLine(String input, String output) {
    return 'Tokeny: $input vstup · $output výstup';
  }

  @override
  String get aiConsumptionTypeAgentTurn => 'Tah agenta';

  @override
  String get aiConsumptionTypeAudioTranscription => 'Přepis';

  @override
  String get aiConsumptionTypeImageAnalysis => 'Analýza obrázku';

  @override
  String get aiConsumptionTypeImageGeneration => 'Generování obrázku';

  @override
  String get aiConsumptionTypePromptGeneration => 'Generování promptu';

  @override
  String get aiConsumptionTypeTextGeneration => 'Generování textu';

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
  String get aiImpactBreakdownBoth => 'Obojí';

  @override
  String get aiImpactBreakdownCategory => 'Podle kategorie';

  @override
  String get aiImpactBreakdownModel => 'Podle modelu';

  @override
  String get aiImpactCategoryTitle => 'Rozpad podle kategorií';

  @override
  String get aiImpactChartHint =>
      'Klepni na sloupec pro volání · na sérii pro izolaci';

  @override
  String get aiImpactChartShareCaption => 'Složení v čase';

  @override
  String get aiImpactChartShareSegment => 'Podíl';

  @override
  String aiImpactChartTitle(String metric) {
    return '$metric podle kategorie';
  }

  @override
  String aiImpactChartTitleModel(String metric) {
    return '$metric podle modelu';
  }

  @override
  String get aiImpactCoverageNote =>
      'Energie, CO₂e a náklady se měří jen u cloudových modelů.';

  @override
  String get aiImpactEmptyBody =>
      'AI volání z tvých úkolů a agentů se zobrazí zde.';

  @override
  String get aiImpactEmptyTitle => 'Žádné využití AI v tomto období';

  @override
  String get aiImpactKpiCarbon => 'CO₂E';

  @override
  String get aiImpactKpiCost => 'NÁKLADY';

  @override
  String aiImpactKpiDeltaBaseline(String period) {
    return 'vs $period';
  }

  @override
  String get aiImpactKpiEnergy => 'ENERGIE';

  @override
  String get aiImpactKpiRequests => 'POŽADAVKY';

  @override
  String get aiImpactKpiTokens => 'TOKENY';

  @override
  String get aiImpactLedgerClearFilter => 'Zobrazit vše';

  @override
  String get aiImpactLoadError => 'Data o dopadu AI se nepodařilo načíst';

  @override
  String get aiImpactLocationColumn => 'LOKACE';

  @override
  String get aiImpactLocationTitle => 'Dopad podle lokace';

  @override
  String get aiImpactLocationUnknown => 'Neznámé';

  @override
  String get aiImpactMetricCarbon => 'CO₂e';

  @override
  String get aiImpactMetricCost => 'Náklady';

  @override
  String get aiImpactMetricEnergy => 'Energie';

  @override
  String get aiImpactMetricRequests => 'Požadavky';

  @override
  String get aiImpactMetricTokens => 'Tokeny';

  @override
  String aiImpactModelCallsLabel(String count) {
    return '$count volání';
  }

  @override
  String get aiImpactModelColumn => 'MODEL';

  @override
  String get aiImpactModelCostHeavy => 'nákladné';

  @override
  String get aiImpactModelCoverageNote =>
      'Místní modely jsou z tohoto grafu vyloučené.';

  @override
  String get aiImpactModelOther => 'Ostatní modely';

  @override
  String aiImpactModelRatePerMillion(String cost) {
    return '$cost/1M tok';
  }

  @override
  String get aiImpactModelTitle => 'Rozpad podle modelů';

  @override
  String get aiImpactModelUnknown => 'Neznámý model';

  @override
  String get aiImpactRenewableColumn => 'OBNOVITELNÉ';

  @override
  String get aiImpactTitle => 'Dopad AI';

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
  String get aiSettingsAddModelErrorDescription =>
      'Při přidávání modelu se něco pokazilo. Zkus to prosím znovu.';

  @override
  String get aiSettingsAddModelErrorTitle => 'Model se nepodařilo přidat';

  @override
  String get aiSettingsAddModelTooltip =>
      'Přidat tento model ke svému poskytovateli';

  @override
  String get aiSettingsAddProfileButton => 'Přidat profil';

  @override
  String get aiSettingsAddProviderButton => 'Přidat poskytovatele';

  @override
  String get aiSettingsAgentWakeConcurrencyDescription =>
      'Zvol, kolik různých agentů může současně spouštět inferenci. Vyšší hodnoty zrychlí odpovědi, ale více zatíží poskytovatele i zařízení.';

  @override
  String get aiSettingsAgentWakeConcurrencyLabel => 'Souběžná probuzení agentů';

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
  String get aiSettingsRemoveModelTooltip =>
      'Odebrat tento model od svého poskytovatele';

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
  String get apiKeyDynamicModelsDescription =>
      'Prohledej živý katalog modelů tohoto poskytovatele a přidej jakýkoli model';

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
  String get audioRecordingDiscardDialogBody =>
      'Tahle nahrávka se smaže. Nevytvoří se žádný audiozáznam, přepis ani shrnutí úkolu.';

  @override
  String get audioRecordingDiscardDialogCancel => 'Pokračovat v nahrávání';

  @override
  String get audioRecordingDiscardDialogConfirm => 'Zahodit';

  @override
  String get audioRecordingDiscardDialogTitle => 'Zahodit nahrávku?';

  @override
  String get audioRecordingListening => 'Naslouchám...';

  @override
  String get audioRecordingPause => 'POZASTAVIT';

  @override
  String get audioRecordingRealtime => 'Živý přepis';

  @override
  String get audioRecordingResume => 'POKRAČOVAT';

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
      'Nastav výchozí AI profil a šablonu agenta pro nové úkoly v této kategorii';

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
  String get categoryDefaultEventTemplateHint => 'Vyber šablonu…';

  @override
  String get categoryDefaultEventTemplateLabel =>
      'Výchozí šablona agenta událostí';

  @override
  String get categoryDefaultLanguageDescription =>
      'Nastav výchozí jazyk pro úkoly v této kategorii';

  @override
  String get categoryDefaultProfileHint => 'Vyber profil…';

  @override
  String get categoryDefaultTemplateHint => 'Vyber šablonu…';

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
  String get categoryIconChooseHint => 'Vyber ikonu';

  @override
  String get categoryIconCreateHint => 'Vyber ikonu';

  @override
  String get categoryIconEditHint => 'Vyber jinou ikonu';

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
  String get changeSetCardTitle => 'Navržené změny';

  @override
  String get changeSetConfirmAll => 'Potvrdit vše';

  @override
  String changeSetConfirmAllPartialIssues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count položek mělo dílčí potíže',
      few: '$count položky měly dílčí potíže',
      one: '1 položka měla dílčí potíže',
    );
    return '$_temp0';
  }

  @override
  String get changeSetConfirmError => 'Nepodařilo se použít změnu';

  @override
  String get changeSetItemConfirmed => 'Změna použita';

  @override
  String changeSetItemConfirmedWithWarning(String warning) {
    return 'Použito s upozorněním: $warning';
  }

  @override
  String get changeSetItemRejected => 'Změna zamítnuta';

  @override
  String changeSetPendingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count čekajících',
      few: '$count čekající',
      one: '1 čekající',
    );
    return '$_temp0';
  }

  @override
  String get changeSetSwipeConfirm => 'Potvrdit';

  @override
  String get changeSetSwipeReject => 'Zamítnout';

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
  String get commandPaletteNoResults =>
      'Tvému hledání neodpovídají žádné dostupné příkazy';

  @override
  String get commandPaletteSearchHint => 'Hledat příkazy…';

  @override
  String get commandPaletteTitle => 'Paleta příkazů';

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
  String get configFlagDailyOsOnboardingEnabled => 'Průvodce Daily OS';

  @override
  String get configFlagDailyOsOnboardingEnabledDescription =>
      'Proveď nové uživatele Daily OS skutečným check-inem, který promění řeč v úkol a plán dne.';

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
  String get configFlagShowSyncActivityIndicator =>
      'Zobrazit indikátor aktivity synchronizace';

  @override
  String get configFlagShowSyncActivityIndicatorDescription =>
      'Zobrazí nenápadný stav synchronizace v postranním panelu; počty ve frontě se objeví jen tehdy, když něco čeká.';

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
  String get dailyOsDayPlan => 'Plán dne';

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
  String get dailyOsNextBlockEditCategoryLabel => 'Kategorie';

  @override
  String get dailyOsNextBlockEditFailed =>
      'Blok se nepodařilo upravit — zkus to znovu.';

  @override
  String get dailyOsNextBlockEditNameLabel => 'Název';

  @override
  String get dailyOsNextBlockEditOpenTask => 'Otevřít úkol';

  @override
  String get dailyOsNextBlockEditSave => 'Uložit změny';

  @override
  String get dailyOsNextBlockEditSaved => 'Plán byl upraven.';

  @override
  String get dailyOsNextBlockEditTimeLabel => 'Začátek a konec';

  @override
  String get dailyOsNextBlockEditTitle => 'Upravit blok';

  @override
  String get dailyOsNextBlockEditTooltip => 'Upravit blok';

  @override
  String get dailyOsNextBlockEditWhyLabel => 'Proč právě teď';

  @override
  String get dailyOsNextBlockMoveTooltip => 'Přesunout blok';

  @override
  String get dailyOsNextBlockResizeEndTooltip => 'Upravit konec';

  @override
  String get dailyOsNextBlockResizeStartTooltip => 'Upravit začátek';

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
  String get dailyOsNextDayMenuSettings => 'Nastavení Daily OS';

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
  String get dailyOsNextDraftingBackToDecisions => 'Zpět k rozhodnutím';

  @override
  String get dailyOsNextDraftingHeader => 'Připravuji tvůj den…';

  @override
  String get dailyOsNextDraftingNudgeAccept => 'Ano, chraň ranní hodiny';

  @override
  String get dailyOsNextDraftingNudgeDecline => 'Dnes ne';

  @override
  String get dailyOsNextDraftingProgressBlocks => 'Skládám bloky';

  @override
  String get dailyOsNextDraftingProgressMatching => 'Páruji úkoly';

  @override
  String get dailyOsNextDraftingProgressQueued => 'Ve frontě';

  @override
  String get dailyOsNextDraftingProgressReading => 'Čtu check-in';

  @override
  String get dailyOsNextDraftingProgressSaving => 'Ukládám plán';

  @override
  String get dailyOsNextDraftingProgressValidating => 'Ověřuji';

  @override
  String get dailyOsNextDraftingReasoningOverline => '✦ ÚVAHA';

  @override
  String get dailyOsNextDraftingRecoveryBody =>
      'Probuzení nevytvořilo plán. Zkus to znovu, nebo se vrať a uprav rozhodnutí před plánováním.';

  @override
  String get dailyOsNextDraftingRecoveryTitle => 'Plánování se zaseklo';

  @override
  String get dailyOsNextDraftingRetry => 'Zkusit znovu';

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
  String dailyOsNextReconcileDecisionProgress(int decided, int total) {
    return 'Zkontrolováno $decided z $total';
  }

  @override
  String get dailyOsNextReconcileDefaultBehaviorHint =>
      'Před sestavením dne zkontroluj karty. Vybrané akce půjdou do plánu; karty bez zásahu zůstanou, jak jsou.';

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
  String get dailyOsNextReconcileProcessing =>
      'Poslouchám znovu a propojuji s tvým dnem…';

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
  String get dailyOsNextReviewAddBuffer => 'Přidat rezervu';

  @override
  String get dailyOsNextReviewAddBufferPrompt =>
      'Přidej realistickou rezervu mezi plánované bloky, hlavně kolem přechodů a po náročné práci.';

  @override
  String get dailyOsNextReviewAdjust => 'Upravit';

  @override
  String get dailyOsNextReviewLooksGood => 'Vypadá dobře';

  @override
  String get dailyOsNextReviewMoveLighter => 'Lehčí později';

  @override
  String get dailyOsNextReviewMoveLighterPrompt =>
      'Přesuň lehčí nebo méně energetickou práci na později a nejsilnější soustředěné okno nech pro nejnáročnější úkol.';

  @override
  String get dailyOsNextReviewTooMuch => 'Je toho moc';

  @override
  String get dailyOsNextReviewTooMuchPrompt =>
      'Tenhle plán je na dnešek moc. Zmenši zátěž, chraň prostor k nadechnutí a nech jen nejdůležitější bloky.';

  @override
  String get dailyOsNextReviewWhyTitle => 'Proč se to dostalo do plánu';

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
  String get dailyOsNextTimelineArrange => 'Uspořádat bloky';

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
      'Přejeď na Skutečnost · svislým sevřením prstů přiblížíš';

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
  String get dailyOsOnboardingCoachCapture => 'Řekni, co ti leží v hlavě.';

  @override
  String get dailyOsOnboardingCoachDrafting =>
      'Plánovač vytváří nové úkoly a zasazuje práci do tvého dne.';

  @override
  String get dailyOsOnboardingCoachReconcile =>
      'Vyber, co patří do dneška. Nové položky se stanou úkoly, až sestavíš den.';

  @override
  String get dailyOsOnboardingSpotlightAction => 'Vyzkoušet';

  @override
  String get dailyOsOnboardingSpotlightDismiss => 'Teď ne';

  @override
  String get dailyOsOnboardingSpotlightMessage =>
      'Klepni sem a řekni, co ti leží v hlavě – proměním to v úkol a poskládám kolem toho tvůj den.';

  @override
  String get dailyOsOnboardingSpotlightTitle => 'Proměň řeč v plán';

  @override
  String get dailyOsSettingsChooseModelDescription =>
      'Přepiš pouze model uvažování plánovače.';

  @override
  String get dailyOsSettingsChooseModelTitle => 'Vybrat přepsání modelu';

  @override
  String get dailyOsSettingsChooseProfileDescription =>
      'Přepiš celý inferenční profil pro tento plánovač.';

  @override
  String get dailyOsSettingsChooseProfileTitle => 'Vybrat profil Daily OS';

  @override
  String get dailyOsSettingsDataDisclosure =>
      'Daily OS odesílá relevantní úkoly, záznamy, plány, naučené preference a další sestavený kontext plánování vybranému poskytovateli ke zpracování.';

  @override
  String get dailyOsSettingsDefaultProfileDescription =>
      'Daily OS ho použije, pokud instance plánovače nemá vlastní nastavení.';

  @override
  String get dailyOsSettingsDefaultProfileMissing => 'Vyber profil';

  @override
  String get dailyOsSettingsDefaultRestored =>
      'Výchozí nastavení Daily OS obnoveno';

  @override
  String get dailyOsSettingsDirectOverrideActive =>
      'Přímé přepsání modelu je aktivní.';

  @override
  String get dailyOsSettingsInferenceTitle => 'Výchozí inferenční profil';

  @override
  String get dailyOsSettingsInstanceCurrentSetup =>
      'Aktuální nastavení plánovače';

  @override
  String get dailyOsSettingsInstanceOverrideDescription =>
      'Použij výchozí profil Daily OS, vyber přepsání profilu nebo přepiš jen model uvažování tohoto plánovače.';

  @override
  String get dailyOsSettingsInstanceOverrideTitle => 'Inference pro Daily OS';

  @override
  String get dailyOsSettingsLocalDisclosure =>
      'Vybraný koncový bod je na tomto zařízení.';

  @override
  String dailyOsSettingsModelChanged(String model) {
    return 'Daily OS nyní používá $model';
  }

  @override
  String get dailyOsSettingsNameNudgeAction => 'Přidat jméno';

  @override
  String get dailyOsSettingsNameNudgeBody =>
      'Preferované jméno udělá check-iny osobnější. Plánovat můžeš i bez něj.';

  @override
  String get dailyOsSettingsNameNudgeTitle => 'Jak tě má Daily OS oslovovat?';

  @override
  String dailyOsSettingsProfileChanged(String profile) {
    return 'Daily OS nyní používá $profile';
  }

  @override
  String get dailyOsSettingsProfileOverrideActive =>
      'Přepsání profilu je aktivní';

  @override
  String dailyOsSettingsRemoteDisclosure(String provider, String host) {
    return 'Daily OS odesílá sestavený kontext plánování poskytovateli $provider na $host ke vzdálenému zpracování.';
  }

  @override
  String get dailyOsSettingsSetupAction => 'Nastavit Daily OS';

  @override
  String get dailyOsSettingsSetupRequiredBody =>
      'Daily OS potřebuje tvou volbu poskytovatele, než může zpracovat kontext plánování.';

  @override
  String get dailyOsSettingsSetupRequiredTitle => 'Vyber inferenční profil';

  @override
  String get dailyOsSettingsSubtitle =>
      'Zvol, jak tě má Daily OS oslovovat a který inferenční profil má plánovat tvé dny.';

  @override
  String get dailyOsSettingsTitle => 'Daily OS';

  @override
  String get dailyOsSettingsTreeSubtitle =>
      'Plánování, přizpůsobení a poskytovatel AI';

  @override
  String get dailyOsSettingsUseDefault => 'Použít výchozí nastavení Daily OS';

  @override
  String get dailyOsSettingsUseDefaultDescription =>
      'Použije profil vybraný v nastavení Daily OS.';

  @override
  String get dailyOsTodayButton => 'Dnes';

  @override
  String get dashboardActiveLabel => 'Aktivní';

  @override
  String get dashboardActiveSwitchDescription =>
      'Zobrazuje se v seznamu panelů';

  @override
  String get dashboardAddChartsTitle => 'Grafy';

  @override
  String get dashboardAddHabitButton => 'Návyky';

  @override
  String get dashboardAddHabitTitle => 'Návykové grafy';

  @override
  String get dashboardAddHealthButton => 'Zdraví';

  @override
  String get dashboardAddHealthTitle => 'Zdravotní grafy';

  @override
  String get dashboardAddMeasurementButton => 'Měření';

  @override
  String get dashboardAddMeasurementTitle => 'Přidat grafy měření';

  @override
  String get dashboardAddMeasurementTooltip => 'Přidat měření';

  @override
  String get dashboardAddSurveyButton => 'Průzkumy';

  @override
  String get dashboardAddSurveyTitle => 'Grafy průzkumů';

  @override
  String get dashboardAddWorkoutButton => 'Cvičení';

  @override
  String get dashboardAddWorkoutTitle => 'Grafy cvičení';

  @override
  String get dashboardAggregationApplyImmediately =>
      'Vyber souhrn. Změny se použijí hned.';

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
  String get dashboardAggregationTitle => 'Typ agregace';

  @override
  String get dashboardAvailableChartsDescription =>
      'Vyber typ, označ jeden nebo více grafů a přidej je.';

  @override
  String get dashboardAvailableChartsTitle => 'Přidat grafy podle typu';

  @override
  String get dashboardCategoryLabel => 'Kategorie';

  @override
  String get dashboardChartNoData => 'Žádná data v tomto rozsahu';

  @override
  String get dashboardConfigurationDescription =>
      'Ulož panel a zkopíruj jeho konfiguraci ve formátu JSON.';

  @override
  String get dashboardConfigurationTitle => 'Export konfigurace';

  @override
  String get dashboardCopyHint => 'Uložit a zkopírovat konfiguraci panelu';

  @override
  String get dashboardCopyLabel => 'Uložit a zkopírovat JSON';

  @override
  String get dashboardCurrentChartsDescription =>
      'Přetažením změníš pořadí. U grafů měření můžeš změnit agregaci.';

  @override
  String get dashboardCurrentChartsTitle => 'Grafy na tomto panelu';

  @override
  String get dashboardDeleteConfirm => 'ANO, SMAZAT TENTO PANEL';

  @override
  String get dashboardDeleteHint => 'Smazat panel';

  @override
  String get dashboardDeleteQuestion => 'Opravdu chceš smazat tento panel?';

  @override
  String get dashboardDescriptionLabel => 'Popis (volitelné)';

  @override
  String get dashboardEditAggregationLabel => 'Upravit agregaci';

  @override
  String get dashboardHealthBloodPressure => 'Krevní tlak';

  @override
  String get dashboardHealthDiastolic => 'Diastolický';

  @override
  String get dashboardHealthSystolic => 'Systolický';

  @override
  String dashboardMeasurementAddButtonWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Přidat $count grafů',
      few: 'Přidat $count grafy',
      one: 'Přidat 1 graf',
    );
    return '$_temp0';
  }

  @override
  String dashboardMeasurementAggregationFor(String name) {
    return 'Režim grafu pro $name';
  }

  @override
  String get dashboardMeasurementAggregationHelp =>
      'Vyber grafy měření. Před přidáním uprav režim grafu na vybraných řádcích.';

  @override
  String get dashboardNameLabel => 'Název panelu';

  @override
  String get dashboardNoChartsAdded => 'Zatím žádné grafy. Přidej jeden níže.';

  @override
  String get dashboardNoHabitsForCharts =>
      'Nejdřív si vytvoř návyk, abys mohl/a přidat grafy návyků.';

  @override
  String get dashboardNoMeasurablesForCharts =>
      'Nejdřív si vytvoř měřitelnou hodnotu, abys mohl/a přidat grafy měření.';

  @override
  String get dashboardNotFound => 'Panel nenalezen';

  @override
  String get dashboardPrivateLabel => 'Soukromý';

  @override
  String get dashboardRemoveChartLabel => 'Odebrat graf';

  @override
  String get dashboardReorderChartLabel => 'Změnit pořadí grafu';

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
      'Vyber panel, jehož podrobnosti chceš zobrazit';

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
  String get editorPlaceholder => 'Zadej poznámky...';

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
  String get goMenuTitle => 'Přejít';

  @override
  String get habitActiveFromLabel => 'Datum začátku';

  @override
  String get habitActiveSwitchDescription => 'Zobrazuje se na stránce Návyky';

  @override
  String get habitArchivedLabel => 'Archivováno';

  @override
  String get habitCategoryHint => 'Vyber kategorii';

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
  String get habitDashboardHint => 'Vyber panel';

  @override
  String get habitDashboardLabel => 'Panel (volitelné)';

  @override
  String habitDayStatusSemantic(String habit, String status) {
    return '$habit, $status';
  }

  @override
  String get habitDeleteConfirm => 'ANO, SMAŽ TENTO NÁVYK';

  @override
  String get habitDeleteQuestion => 'Chceš tento návyk smazat?';

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
  String get helpMenuCommandPalette => 'Paleta příkazů…';

  @override
  String get helpMenuKeyboardShortcuts => 'Klávesové zkratky…';

  @override
  String get helpMenuTitle => 'Nápověda';

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
  String get imageViewerDownloadFailed => 'Obrázek se nepodařilo uložit';

  @override
  String get imageViewerDownloadingTooltip => 'Ukládám obrázek';

  @override
  String get imageViewerDownloadPermissionDenied =>
      'Přístup k fotkám zamítnut – povol jej v Nastavení';

  @override
  String imageViewerDownloadSaved(String fileName) {
    return 'Uloženo $fileName';
  }

  @override
  String get imageViewerDownloadSavedToGallery => 'Uloženo do Fotek';

  @override
  String get imageViewerDownloadTooltip => 'Stáhnout obrázek';

  @override
  String get inactiveLabel => 'Neaktivní';

  @override
  String get inactiveSwitchDescription =>
      'Lze vybrat pro nové záznamy, když je zapnuto';

  @override
  String get inferenceProfileChooseModelTitle => 'Vyber model';

  @override
  String get inferenceProfileChooseTitle => 'Vyber profil inference';

  @override
  String get inferenceProfileCreateTitle => 'Vytvořit profil';

  @override
  String get inferenceProfileDescriptionLabel => 'Popis';

  @override
  String get inferenceProfileDesktopOnly => 'Jen pro počítač';

  @override
  String get inferenceProfileDesktopOnlyDescription =>
      'K dispozici jen na počítačových platformách (např. pro místní modely)';

  @override
  String inferenceProfileDetailLoadError(String error) {
    return 'Profil se nepodařilo načíst: $error';
  }

  @override
  String get inferenceProfileDetailNotFound => 'Profil nenalezen';

  @override
  String get inferenceProfileEditTitle => 'Upravit profil';

  @override
  String get inferenceProfileImageGeneration => 'Generování obrázků';

  @override
  String get inferenceProfileImageRecognition => 'Rozpoznávání obrázků';

  @override
  String get inferenceProfileModelUnavailable =>
      'Model není dostupný — jeho poskytovatel byl možná odebrán';

  @override
  String get inferenceProfileNameLabel => 'Název profilu';

  @override
  String get inferenceProfileNameRequired => 'Název profilu je povinný';

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
  String get inferenceProfileSaveButton => 'Uložit';

  @override
  String get inferenceProfileSelectModel => 'Vyber model…';

  @override
  String get inferenceProfileSelectProfile => 'Vyber profil…';

  @override
  String get inferenceProfilesEmpty => 'Zatím žádné inferenční profily';

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
  String get inferenceProfilesTitle => 'Inferenční profily';

  @override
  String get inferenceProfileThinking => 'Uvažování';

  @override
  String get inferenceProfileThinkingHighEnd => 'Uvažování (pokročilé)';

  @override
  String get inferenceProfileThinkingRequired =>
      'Je potřeba model pro uvažování';

  @override
  String get inferenceProfileTranscription => 'Přepis';

  @override
  String get inferenceProfileUnavailable =>
      'Inferenční profil není k dispozici';

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
  String get insightsChooseFocusCategories => 'Vybrat sledované kategorie';

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
  String get insightsFocusCategoriesTitle => 'Sledované kategorie';

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
  String get journalDateSaveButton => 'Uložit';

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
  String get journalFilterTitle => 'Filtrovat deník';

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
  String get journalSetEndDateTimeNowSemantic =>
      'Nastavit koncové datum a čas na teď';

  @override
  String get journalSetStartDateTimeNowSemantic =>
      'Nastavit počáteční datum a čas na teď';

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
  String get keyboardCommandActivate => 'Aktivovat zaměřenou položku';

  @override
  String get keyboardCommandCategoryCreation => 'Vytváření';

  @override
  String get keyboardCommandCategoryEditing => 'Úpravy';

  @override
  String get keyboardCommandCategoryGeneral => 'Obecné';

  @override
  String get keyboardCommandCategoryListsAndControls =>
      'Seznamy a ovládací prvky';

  @override
  String get keyboardCommandCategoryNavigation => 'Navigace';

  @override
  String get keyboardCommandCategoryView => 'Zobrazení';

  @override
  String get keyboardCommandCreateInContext => 'Vytvořit v aktuálním zobrazení';

  @override
  String get keyboardCommandFocusSearch => 'Zaměřit hledání';

  @override
  String get keyboardCommandMoveDown => 'Přesunout zaměřenou položku dolů';

  @override
  String get keyboardCommandMoveUp => 'Přesunout zaměřenou položku nahoru';

  @override
  String keyboardCommandNavigate(String destination) {
    return 'Přejít na $destination';
  }

  @override
  String get keyboardCommandNextRegion => 'Zaměřit další panel';

  @override
  String get keyboardCommandOpenPalette => 'Otevřít paletu příkazů';

  @override
  String get keyboardCommandPageDown => 'Posunout o stránku dolů';

  @override
  String get keyboardCommandPageUp => 'Posunout o stránku nahoru';

  @override
  String get keyboardCommandPreviousRegion => 'Zaměřit předchozí panel';

  @override
  String get keyboardCommandRefresh => 'Obnovit aktuální zobrazení';

  @override
  String get keyboardCommandRename => 'Přejmenovat zaměřenou položku';

  @override
  String get keyboardCommandSelectFirst => 'Vybrat první položku';

  @override
  String get keyboardCommandSelectLast => 'Vybrat poslední položku';

  @override
  String get keyboardCommandSelectNext => 'Vybrat další položku';

  @override
  String get keyboardCommandSelectPrevious => 'Vybrat předchozí položku';

  @override
  String get keyboardCommandToggle => 'Přepnout zaměřenou položku';

  @override
  String get keyboardKeyAlt => 'Alt';

  @override
  String get keyboardKeyArrowDown => 'Šipka dolů';

  @override
  String get keyboardKeyArrowLeft => 'Šipka doleva';

  @override
  String get keyboardKeyArrowRight => 'Šipka doprava';

  @override
  String get keyboardKeyArrowUp => 'Šipka nahoru';

  @override
  String get keyboardKeyControl => 'Ctrl';

  @override
  String get keyboardKeyDelete => 'Delete';

  @override
  String get keyboardKeyEnd => 'End';

  @override
  String get keyboardKeyEnter => 'Enter';

  @override
  String get keyboardKeyEscape => 'Esc';

  @override
  String get keyboardKeyHome => 'Home';

  @override
  String get keyboardKeyMinus => 'Mínus';

  @override
  String get keyboardKeyOr => 'nebo';

  @override
  String get keyboardKeyPageDown => 'Page Down';

  @override
  String get keyboardKeyPageUp => 'Page Up';

  @override
  String get keyboardKeyPlus => 'Plus';

  @override
  String get keyboardKeyShift => 'Shift';

  @override
  String get keyboardKeySpace => 'Mezerník';

  @override
  String get keyboardResizeDividerLabel => 'Změnit velikost panelů';

  @override
  String get keyboardShortcutsNoResults =>
      'Tvému hledání neodpovídají žádné zkratky';

  @override
  String get keyboardShortcutsSearchHint => 'Hledat zkratky…';

  @override
  String get keyboardShortcutsSubtitle =>
      'Všechny příkazy pro počítač a jejich aktuální klávesové kombinace.';

  @override
  String get keyboardShortcutsTitle => 'Klávesové zkratky';

  @override
  String knowledgeGraphAgeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'před $count dny',
      few: 'před $count dny',
      one: 'před 1 dnem',
    );
    return '$_temp0';
  }

  @override
  String knowledgeGraphAgeMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'před $count měsíci',
      few: 'před $count měsíci',
      one: 'před 1 měsícem',
    );
    return '$_temp0';
  }

  @override
  String get knowledgeGraphAgeToday => 'Dnes';

  @override
  String knowledgeGraphAgeWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'před $count týdny',
      few: 'před $count týdny',
      one: 'před 1 týdnem',
    );
    return '$_temp0';
  }

  @override
  String get knowledgeGraphAgeYesterday => 'Včera';

  @override
  String get knowledgeGraphBack => 'Zpět';

  @override
  String get knowledgeGraphCloseDetails => 'Zavřít podrobnosti';

  @override
  String get knowledgeGraphEmpty => 'Zatím žádné odkazy k prozkoumání';

  @override
  String get knowledgeGraphEntryLoadError =>
      'Tento záznam se nepodařilo načíst';

  @override
  String get knowledgeGraphEntryNotFound => 'Záznam nebyl nalezen';

  @override
  String get knowledgeGraphError => 'Znalostní graf se nepodařilo načíst';

  @override
  String knowledgeGraphLinkedSection(int count) {
    return 'PROPOJENO · $count';
  }

  @override
  String get knowledgeGraphMoreLinks => 'Další propojení';

  @override
  String knowledgeGraphNodeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count uzlů',
      few: '$count uzly',
      one: '1 uzel',
    );
    return '$_temp0';
  }

  @override
  String get knowledgeGraphNodeTypeAiSummary => 'Souhrn AI';

  @override
  String get knowledgeGraphNodeTypeAudioNote => 'Zvuková poznámka';

  @override
  String get knowledgeGraphNodeTypeChecklist => 'Kontrolní seznam';

  @override
  String get knowledgeGraphNodeTypeChecklistItem =>
      'Položka kontrolního seznamu';

  @override
  String get knowledgeGraphNodeTypeNote => 'Poznámka';

  @override
  String get knowledgeGraphNodeTypePhoto => 'Fotka';

  @override
  String get knowledgeGraphNodeTypeProject => 'Projekt';

  @override
  String get knowledgeGraphNodeTypeRating => 'Hodnocení';

  @override
  String get knowledgeGraphNodeTypeTask => 'Úkol';

  @override
  String get knowledgeGraphOpenDetails => 'Otevřít podrobnosti';

  @override
  String get knowledgeGraphRecenter => 'Znovu vystředit';

  @override
  String get knowledgeGraphRecentToOlder => 'Novější → starší';

  @override
  String get knowledgeGraphRelationAiSource => 'Zdroj AI';

  @override
  String get knowledgeGraphRelationChecklist => 'Kontrolní seznam';

  @override
  String get knowledgeGraphRelationInProject => 'V projektu';

  @override
  String get knowledgeGraphRelationLinkedTask => 'Propojený úkol';

  @override
  String get knowledgeGraphRelationNoteLog => 'Poznámka / záznam';

  @override
  String get knowledgeGraphRelationRating => 'Hodnocení';

  @override
  String get knowledgeGraphSummarySection => 'SOUHRN';

  @override
  String get knowledgeGraphTitle => 'Graf znalostí';

  @override
  String get knowledgeGraphTooltip => 'Prozkoumat odkazy';

  @override
  String knowledgeGraphWalkHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count uzlů',
      few: '$count uzly',
      one: '1 uzel',
    );
    return 'Klepni na uzel a přejdi dál · $_temp0';
  }

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
  String get matrixStatsCatchupBatches => 'Doháněcí dávky';

  @override
  String get matrixStatsCircuitOpens => 'Otevření přerušovače';

  @override
  String get matrixStatsConflicts => 'Konflikty';

  @override
  String get matrixStatsCopyDiagnostics => 'Kopírovat diagnostiku';

  @override
  String get matrixStatsCopyDiagnosticsTooltip =>
      'Kopírovat diagnostiku synchronizace do schránky';

  @override
  String get matrixStatsDbApplied => 'Aplikováno do databáze';

  @override
  String get matrixStatsDbApply => 'Aplikace do databáze';

  @override
  String get matrixStatsDbIgnoredVectorClock =>
      'Ignorováno databází (VectorClock)';

  @override
  String get matrixStatsDbMissingBase => 'Chybí základ databáze';

  @override
  String matrixStatsDroppedByType(Object type) {
    return 'Zahozeno ($type)';
  }

  @override
  String get matrixStatsEntryLinkNoops => 'Prázdné operace EntryLink';

  @override
  String get matrixStatsFailures => 'Selhání';

  @override
  String get matrixStatsFlushes => 'Vyprázdnění';

  @override
  String get matrixStatsForceRescan => 'Vynutit nové skenování';

  @override
  String get matrixStatsForceRescanTooltip =>
      'Vynutit nové skenování a dohnání nyní';

  @override
  String get matrixStatsLegend => 'Legenda';

  @override
  String get matrixStatsLegendTooltip =>
      'Legenda:\n• processed.<type> = zpracované synchronizační zprávy podle typu dat\n• droppedByType.<type> = zahazování podle typu po opakováních nebo ignorování starších zpráv\n• dbApplied = zapsané řádky databáze\n• dbIgnoredByVectorClock = starší nebo stejné příchozí údaje ignorované databází\n• conflictsCreated = zaznamenané souběžné vektorové hodiny\n• dbMissingBase = přeskočeno při čekání na chybějící závislost nebo základní řádek\n• staleAttachmentPurges = zastaralé popisy v mezipaměti vyčištěné před obnovením';

  @override
  String get matrixStatsProcessed => 'Zpracováno';

  @override
  String matrixStatsProcessedByType(Object type) {
    return 'Zpracováno ($type)';
  }

  @override
  String get matrixStatsRefresh => 'Obnovit';

  @override
  String get matrixStatsReliability => 'Spolehlivost';

  @override
  String get matrixStatsRetriesScheduled => 'Naplánovaná opakování';

  @override
  String get matrixStatsRetryNow => 'Zkusit znovu';

  @override
  String get matrixStatsRetryNowTooltip => 'Zkusit nyní znovu čekající selhání';

  @override
  String get matrixStatsSignalLatencyLast => 'Latence signálu (poslední ms)';

  @override
  String get matrixStatsSignalLatencyMax => 'Latence signálu (max. ms)';

  @override
  String get matrixStatsSignalLatencyMin => 'Latence signálu (min. ms)';

  @override
  String get matrixStatsSignals => 'Signály';

  @override
  String get matrixStatsSignalsClientStream => 'Signály (tok klienta)';

  @override
  String get matrixStatsSignalsConnectivity => 'Signály (připojení)';

  @override
  String get matrixStatsSignalsTimelineCallbacks =>
      'Signály (zpětná volání časové osy)';

  @override
  String get matrixStatsSkipped => 'Přeskočeno';

  @override
  String get matrixStatsSkippedRetryCap => 'Přeskočeno (limit opakování)';

  @override
  String get matrixStatsStaleAttachmentPurges => 'Vyčištěné zastaralé přílohy';

  @override
  String get matrixStatsThroughput => 'Propustnost';

  @override
  String get matrixStatsTopKpis => 'Hlavní ukazatele';

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
  String get measurementCommentSemantic => 'Poznámka, volitelná';

  @override
  String measurementObservedAtChangeSemantic(String dateTime) {
    return 'Naměřeno $dateTime. Změnit datum a čas.';
  }

  @override
  String get measurementQuickAddLabel => 'Rychlé zapsání';

  @override
  String measurementQuickLogSemantic(String value) {
    return 'Okamžitě zapsat $value';
  }

  @override
  String get measurementSaveError =>
      'Měření se nepodařilo uložit. Zkus to znovu.';

  @override
  String get measurementSetObservedAtNowSemantic =>
      'Nastavit datum a čas měření na teď';

  @override
  String get measurementTimeLabel => 'Čas';

  @override
  String measurementValueSemantic(String measurable) {
    return 'Hodnota pro $measurable';
  }

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
  String get navSidebarManualBrowserHint => 'Otevře se v prohlížeči';

  @override
  String get navSidebarManualLabel => 'Příručka';

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
  String get onboardingCaptureCategoryPrompt => 'Kam to má patřit?';

  @override
  String get onboardingCaptureListening => 'Poslouchám… klepni, až budeš hotov';

  @override
  String get onboardingCaptureOrbLabel => 'Nahraj svou myšlenku';

  @override
  String get onboardingCaptureRatherType => 'Raději psát?';

  @override
  String get onboardingCaptureReassurance => 'Vše budeš moct následně upravit.';

  @override
  String get onboardingCaptureThinking => 'Měním tvá slova v úkol…';

  @override
  String get onboardingCaptureTypePrompt => 'Napiš svou myšlenku';

  @override
  String get onboardingCategoryAddOwn => 'Přidat vlastní';

  @override
  String get onboardingCategoryContinue => 'Pokračovat';

  @override
  String get onboardingCategoryExplanation =>
      'Každá oblast života má vlastní prostor. Vyber, co se hodí — nebo přidej vlastní.';

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
      'Melious.ai je doporučená výchozí volba.';

  @override
  String get onboardingConnectOllamaName => 'Ollama';

  @override
  String get onboardingConnectOpenAiName => 'OpenAI';

  @override
  String get onboardingConnectQwenName => 'Qwen';

  @override
  String get onboardingConnectQwenTagline => 'Čína';

  @override
  String get onboardingConnectTitle => 'Vyber AI mozek pro své úkoly';

  @override
  String get onboardingFirstTaskCreatedHint =>
      'Klepni na svůj úkol a otevři ho';

  @override
  String get onboardingFirstTaskCreatedTitle => 'Tvůj první úkol je připraven';

  @override
  String get onboardingFirstTaskGuidance =>
      'Klepni, mluv a řekni, co potřebuješ udělat — Lotti z toho udělá skutečný úkol.';

  @override
  String get onboardingFirstTaskSuggestionDentist => 'Objednat se k zubaři';

  @override
  String get onboardingFirstTaskSuggestionMeeting =>
      'Připravit se na pondělní schůzku';

  @override
  String get onboardingFirstTaskSuggestionPlanWeek => 'Naplánovat můj týden';

  @override
  String get onboardingFirstTaskSuggestionsLabel =>
      'Ještě se ti nechce mluvit? Začni jedním z těchto:';

  @override
  String get onboardingFirstTaskTitle => 'Vytvoř svůj první úkol';

  @override
  String get onboardingMetricsActiveDays => 'Aktivní dny';

  @override
  String get onboardingMetricsActiveDaysInFirstSeven =>
      'Aktivní dny během prvních 7 dnů';

  @override
  String get onboardingMetricsBaselineCohort => 'Výchozí kohorta (před FTUE)';

  @override
  String get onboardingMetricsInstallFirstSeenUtc =>
      'První zaznamenaná instalace (UTC)';

  @override
  String get onboardingMetricsNo => 'ne';

  @override
  String get onboardingMetricsReachedRealAha =>
      'Dosaženo skutečného aha momentu';

  @override
  String get onboardingMetricsYes => 'ano';

  @override
  String get onboardingRecordingStyleAnalogue => 'Analogový — VU metr';

  @override
  String get onboardingRecordingStyleContinue => 'Pokračovat';

  @override
  String get onboardingRecordingStyleExplanation =>
      'Vyber vzhled pro mikrofon. Kdykoli ho můžeš změnit v Nastavení.';

  @override
  String get onboardingRecordingStyleModern => 'Moderní — energetická koule';

  @override
  String get onboardingRecordingStyleTitle => 'Jak má nahrávání vypadat?';

  @override
  String get onboardingRecordingStyleTryVoice => 'Vyzkoušej svým hlasem';

  @override
  String get onboardingSuccessContinue => 'Začít';

  @override
  String get onboardingSuccessSubtitle =>
      'Tvůj AI mozek je připojený a promění tvá slova v úkoly.';

  @override
  String get onboardingSuccessTitle => 'Vše připraveno';

  @override
  String get onboardingWelcomeConnectButton => 'Vybrat AI mozek';

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
  String get panasCompletionText => 'Děkujeme za vyplnění dotazníku PANAS!';

  @override
  String get panasCompletionTitle => 'Hotovo';

  @override
  String get panasEmotionActive => 'Aktivní';

  @override
  String get panasEmotionAfraid => 'Bojácný';

  @override
  String get panasEmotionAlert => 'Pozorný';

  @override
  String get panasEmotionAshamed => 'Zahanbený';

  @override
  String get panasEmotionAttentive => 'Soustředěný';

  @override
  String get panasEmotionDetermined => 'Odhodlaný';

  @override
  String get panasEmotionDistressed => 'V tísni';

  @override
  String get panasEmotionEnthusiastic => 'Plný nadšení';

  @override
  String get panasEmotionExcited => 'Vzrušený';

  @override
  String get panasEmotionGuilty => 'Provinilý';

  @override
  String get panasEmotionHostile => 'Nepřátelský';

  @override
  String get panasEmotionInspired => 'Inspirovaný';

  @override
  String get panasEmotionInterested => 'Zaujatý';

  @override
  String get panasEmotionIrritable => 'Podrážděný';

  @override
  String get panasEmotionJittery => 'Roztěkaný';

  @override
  String get panasEmotionNervous => 'Nervózní';

  @override
  String get panasEmotionProud => 'Hrdý';

  @override
  String get panasEmotionScared => 'Vystrašený';

  @override
  String get panasEmotionStrong => 'Silný';

  @override
  String get panasEmotionUpset => 'Rozčilený';

  @override
  String get panasInstructionFootnote =>
      'Watson, D., Clark, L. A., & Tellegen, A. (1988). Development and validation of brief measures of positive and negative affect: The PANAS scales. Journal of Personality and Social Psychology, 54(6), 1063–1070.';

  @override
  String get panasInstructionText =>
      'Uveď, do jaké míry se takto cítíš právě teď, v tomto okamžiku.\n\n1—Vůbec nebo jen velmi málo,\n2—Trochu,\n3—Středně,\n4—Docela hodně,\n5—Extrémně';

  @override
  String get panasInstructionTitle =>
      'Škála pozitivních a negativních emocí (PANAS; Watson et al., 1988)';

  @override
  String get panasScaleALittle => 'Trochu';

  @override
  String get panasScaleExtremely => 'Extrémně';

  @override
  String get panasScaleModerately => 'Středně';

  @override
  String get panasScaleQuiteABit => 'Docela hodně';

  @override
  String get panasScaleVerySlightlyOrNotAtAll => 'Vůbec nebo jen velmi málo';

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
  String get provisionedSyncBundleImported => 'Párovací balíček importován';

  @override
  String get provisionedSyncConfigureButton => 'Nastavit';

  @override
  String get provisionedSyncCopiedToClipboard => 'Zkopírováno do schránky';

  @override
  String get provisionedSyncDisconnect => 'Odpojit';

  @override
  String get provisionedSyncDone => 'Synchronizace úspěšně nakonfigurována';

  @override
  String get provisionedSyncError => 'Nastavení se nezdařilo';

  @override
  String get provisionedSyncErrorConfigurationFailed =>
      'Při nastavování došlo k chybě. Zkus to znovu.';

  @override
  String get provisionedSyncErrorLoginFailed =>
      'Přihlášení selhalo. Zkontroluj přihlašovací údaje a zkus to znovu.';

  @override
  String get provisionedSyncImportButton => 'Importovat';

  @override
  String get provisionedSyncImportHint => 'Sem vlož párovací balíček';

  @override
  String get provisionedSyncImportTitle => 'Nastavit synchronizaci';

  @override
  String get provisionedSyncInvalidBundle => 'Neplatný párovací balíček';

  @override
  String get provisionedSyncJoiningRoom =>
      'Připojování k synchronizační místnosti...';

  @override
  String get provisionedSyncLoggingIn => 'Přihlašování...';

  @override
  String get provisionedSyncPasteClipboard => 'Vložit ze schránky';

  @override
  String get provisionedSyncReady =>
      'Naskenuj tento QR kód na mobilním zařízení';

  @override
  String get provisionedSyncRetry => 'Zkusit znovu';

  @override
  String get provisionedSyncRotatingPassword => 'Zabezpečování účtu...';

  @override
  String get provisionedSyncScanButton => 'Naskenovat QR kód';

  @override
  String get provisionedSyncShowQr => 'Zobrazit párovací QR kód';

  @override
  String get provisionedSyncSubtitle =>
      'Nastav synchronizaci pomocí párovacího balíčku';

  @override
  String get provisionedSyncSummaryHomeserver => 'Server';

  @override
  String get provisionedSyncSummaryRoom => 'Místnost';

  @override
  String get provisionedSyncSummaryUser => 'Uživatel';

  @override
  String get provisionedSyncTitle => 'Nastavení synchronizace';

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
      'Nepodařilo se načíst obrázky. Zkus to prosím znovu.';

  @override
  String get referenceImageSelectionSubtitle =>
      'Vyber až 5 obrázků, které povedou vizuální styl AI';

  @override
  String get referenceImageSelectionTitle => 'Vyber referenční obrázky';

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
  String get sessionRatingCardLabel => 'Hodnocení sezení';

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
  String get sessionRatingEnergyQuestion => 'Kolik jsi měl/a energie?';

  @override
  String get sessionRatingFocusQuestion =>
      'Jak dobře ses dokázal/a soustředit?';

  @override
  String get sessionRatingNoteHint => 'Krátká poznámka (volitelné)';

  @override
  String get sessionRatingProductivityQuestion =>
      'Jak produktivní bylo toto sezení?';

  @override
  String get sessionRatingRateAction => 'Ohodnotit sezení';

  @override
  String get sessionRatingSaveButton => 'Uložit';

  @override
  String get sessionRatingSaveError =>
      'Nepodařilo se uložit hodnocení. Zkuste to prosím znovu.';

  @override
  String get sessionRatingSkipButton => 'Přeskočit';

  @override
  String get sessionRatingTitle => 'Ohodnoť toto sezení';

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
      'Používá se pro pozdrav Daily OS a synchronizuje se mezi tvými zařízeními.';

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
  String get settingsAdvancedManualLanguageSubtitle =>
      'Vyber jazyk, ve kterém se má otevřít příručka Lotti';

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
  String get settingsAiUsageSubtitle => 'Náklady, energie a CO₂e AI volání';

  @override
  String get settingsAiUsageTitle => 'Využití a dopad';

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
  String get settingsCelebrationsCustomizeTitle => 'Přizpůsobit';

  @override
  String get settingsCelebrationsCustomizeTooltip => 'Přizpůsobit tento styl';

  @override
  String get settingsCelebrationsEnabledDescription =>
      'Hlavní vypínač efektů dokončení. Vypnuto skryje všechny animace; haptika má vlastní přepínač.';

  @override
  String get settingsCelebrationsEnabledTitle => 'Animace dokončení';

  @override
  String get settingsCelebrationsGroupLook => 'Vzhled';

  @override
  String get settingsCelebrationsGroupMotion => 'Pohyb';

  @override
  String get settingsCelebrationsGroupShape => 'Tvar';

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
  String get settingsCelebrationsKnobClearCenter => 'Středová mezera';

  @override
  String get settingsCelebrationsKnobCount => 'Částice';

  @override
  String get settingsCelebrationsKnobDescClearCenter => 'Volné místo uprostřed';

  @override
  String get settingsCelebrationsKnobDescCount => 'Kolik částic vylétne';

  @override
  String get settingsCelebrationsKnobDescFallout => 'Jak daleko jiskry padají';

  @override
  String get settingsCelebrationsKnobDescFanSpread => 'Šířka vějíře';

  @override
  String get settingsCelebrationsKnobDescGlow => 'Síla záře';

  @override
  String get settingsCelebrationsKnobDescGravity => 'Jak rychle padají';

  @override
  String get settingsCelebrationsKnobDescHalo => 'Síla svatozáře';

  @override
  String get settingsCelebrationsKnobDescInnerRing =>
      'Velikost vnitřního prstence';

  @override
  String get settingsCelebrationsKnobDescLaunch => 'Prodleva před výbuchem';

  @override
  String get settingsCelebrationsKnobDescPop => 'Kdy prasknou';

  @override
  String get settingsCelebrationsKnobDescReach => 'Jak daleko doletí';

  @override
  String get settingsCelebrationsKnobDescRise => 'Jak vysoko stoupají';

  @override
  String get settingsCelebrationsKnobDescSize => 'Jak velká je každá částice';

  @override
  String get settingsCelebrationsKnobDescSpeedSpread => 'Rozdíl v rychlosti';

  @override
  String get settingsCelebrationsKnobDescSpin => 'Jak rychle se točí';

  @override
  String get settingsCelebrationsKnobDescSpread => 'Šířka rozstřiku';

  @override
  String get settingsCelebrationsKnobDescSway => 'Jak moc se kývají';

  @override
  String get settingsCelebrationsKnobDescSwell => 'Jak moc rostou';

  @override
  String get settingsCelebrationsKnobDescTrail => 'Délka stopy';

  @override
  String get settingsCelebrationsKnobDescTwinkle => 'Jak moc se třpytí';

  @override
  String get settingsCelebrationsKnobDescUpward => 'Jak silně stoupají';

  @override
  String get settingsCelebrationsKnobDescWobble => 'Jak moc se viklají';

  @override
  String get settingsCelebrationsKnobFallout => 'Dopad';

  @override
  String get settingsCelebrationsKnobFanSpread => 'Rozevření vějíře';

  @override
  String get settingsCelebrationsKnobGlow => 'Záře';

  @override
  String get settingsCelebrationsKnobGravity => 'Gravitace';

  @override
  String get settingsCelebrationsKnobHalo => 'Halo';

  @override
  String get settingsCelebrationsKnobInnerRing => 'Vnitřní prstenec';

  @override
  String get settingsCelebrationsKnobLaunch => 'Čas startu';

  @override
  String get settingsCelebrationsKnobPop => 'Bod prasknutí';

  @override
  String get settingsCelebrationsKnobReach => 'Dosah';

  @override
  String get settingsCelebrationsKnobRise => 'Výška stoupání';

  @override
  String get settingsCelebrationsKnobSize => 'Velikost';

  @override
  String get settingsCelebrationsKnobSpeedSpread => 'Proměnlivost rychlosti';

  @override
  String get settingsCelebrationsKnobSpin => 'Rotace';

  @override
  String get settingsCelebrationsKnobSpread => 'Úhel rozptylu';

  @override
  String get settingsCelebrationsKnobSway => 'Houpání';

  @override
  String get settingsCelebrationsKnobSwell => 'Bobtnání';

  @override
  String get settingsCelebrationsKnobTrail => 'Délka stopy';

  @override
  String get settingsCelebrationsKnobTwinkle => 'Třpyt';

  @override
  String get settingsCelebrationsKnobUpward => 'Stoupání';

  @override
  String get settingsCelebrationsKnobWobble => 'Chvění';

  @override
  String get settingsCelebrationsPlaygroundHint =>
      'Klepni na zvýrazněný řádek pro náhled';

  @override
  String get settingsCelebrationsPlaygroundLiveNote =>
      'Změny se okamžitě uloží a použijí všude';

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
  String get settingsCelebrationsPreviewSample1 => 'Ranní procházka';

  @override
  String get settingsCelebrationsPreviewSample2 => 'Dokončit zprávu';

  @override
  String get settingsCelebrationsPreviewSample3 => 'Zalít rostliny';

  @override
  String get settingsCelebrationsPreviewTitle => 'Vyzkoušet';

  @override
  String get settingsCelebrationsReplay => 'Přehrát znovu';

  @override
  String get settingsCelebrationsResetToast => 'Styl obnoven na výchozí';

  @override
  String get settingsCelebrationsResetToDefault => 'Obnovit výchozí';

  @override
  String get settingsCelebrationsResetUndo => 'Zpět';

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
  String get settingsCelebrationsVariantCombine => 'Zkombinovat dva';

  @override
  String get settingsCelebrationsVariantCombineDescription =>
      'Pokaždé dva náhodné styly přes sebe';

  @override
  String get settingsCelebrationsVariantConfetti => 'Konfety';

  @override
  String get settingsCelebrationsVariantEmbers => 'Žhavé uhlíky';

  @override
  String get settingsCelebrationsVariantFireworks => 'Ohňostroj';

  @override
  String get settingsCelebrationsVariantRandom => 'Náhodně';

  @override
  String get settingsCelebrationsVariantRandomDescription =>
      'Pokaždé jiný styl';

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
      'Klepni na tlačítko + a vytvoř první panel.';

  @override
  String get settingsDashboardsErrorLoading => 'Chyba při načítání panelů';

  @override
  String settingsDashboardsNoMatchQuery(String query) {
    return 'Žádný panel neodpovídá \"$query\"';
  }

  @override
  String get settingsDashboardsSearchHint => 'Hledat panely';

  @override
  String get settingsDashboardsSubtitle => 'Přizpůsob si zobrazení panelu';

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
  String get settingsKeyboardShortcutsSubtitle =>
      'Nauč se klávesové kombinace pro rychlejší navigaci a úpravy na počítači';

  @override
  String get settingsKeyboardShortcutsTitle => 'Klávesové zkratky';

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
      'Nastav, které oblasti zapisují do logu';

  @override
  String get settingsLoggingDomainsTitle => 'Oblasti protokolování';

  @override
  String get settingsLoggingGlobalToggle => 'Zapnout protokolování';

  @override
  String get settingsLoggingGlobalToggleSubtitle =>
      'Hlavní přepínač pro veškeré protokolování';

  @override
  String get settingsLoggingSlowQueries => 'Pomalé databázové dotazy';

  @override
  String get settingsLoggingSlowQueriesSubtitle =>
      'Pomalé dotazy se zapisují do slow_queries-YYYY-MM-DD.log';

  @override
  String get settingsMaintenanceOnboardingAnimationGallerySubtitle =>
      'Porovnej uvítací animace a stránku připojení živě (ladění)';

  @override
  String get settingsMaintenanceOnboardingAnimationGalleryTitle =>
      'Galerie animací onboardingu';

  @override
  String get settingsMaintenanceOnboardingWelcomeSubtitle =>
      'Náhled uvítání FTUE a dlaždic poskytovatelů (ladění)';

  @override
  String get settingsMaintenanceOnboardingWelcomeTitle =>
      'Zobrazit uvítání onboardingu';

  @override
  String get settingsMaintenanceTitle => 'Údržba';

  @override
  String get settingsManualLanguageCzechTitle => 'Čeština';

  @override
  String get settingsManualLanguageEnglishTitle => 'Angličtina';

  @override
  String get settingsManualLanguageFollowSystemSubtitle =>
      'Použij jazyk zařízení, pokud ho příručka podporuje; jinak angličtinu.';

  @override
  String get settingsManualLanguageFollowSystemTitle =>
      'Používat jazyk systému';

  @override
  String get settingsManualLanguageFrenchTitle => 'Francouzština';

  @override
  String get settingsManualLanguageGermanTitle => 'Němčina';

  @override
  String get settingsManualLanguagePortugueseTitle => 'Portugalština';

  @override
  String get settingsManualLanguageRomanianTitle => 'Rumunština';

  @override
  String get settingsManualLanguageTitle => 'Jazyk';

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
      'Diagnostické informace zkopírovány do schránky';

  @override
  String get settingsMatrixDiagnosticCopyButton => 'Kopírovat do schránky';

  @override
  String get settingsMatrixDiagnosticDialogTitle =>
      'Diagnostické informace synchronizace';

  @override
  String get settingsMatrixDiagnosticShowButton =>
      'Zobrazit diagnostické informace';

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
  String settingsMatrixSentMessageType(String eventType) {
    return 'Odesláno ($eventType)';
  }

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
  String get settingsOnboardingActionSubtitle =>
      'Znovu otevři uvítací postup — připoj svou AI a vytvoř úkol';

  @override
  String get settingsOnboardingMetricsSubtitle =>
      'FTUE trychtýř — instalace, aktivace, retence (ladění)';

  @override
  String get settingsOnboardingMetricsTitle => 'Metriky onboardingu';

  @override
  String get settingsOnboardingReplayTitle => 'Zopakovat onboarding';

  @override
  String get settingsOnboardingStartTitle => 'Spustit onboarding';

  @override
  String get settingsOnboardingStatusActivated => 'Máš vytvořený první AI úkol';

  @override
  String get settingsOnboardingStatusLoading => 'Načítání…';

  @override
  String get settingsOnboardingStatusNotActivated => 'Zatím nezahájeno';

  @override
  String get settingsOnboardingStatusTitle => 'Stav';

  @override
  String get settingsOnboardingSubtitle =>
      'Kdykoli si znovu spusť uvítací postup';

  @override
  String get settingsOnboardingTestResetConfirm => 'Resetovat';

  @override
  String get settingsOnboardingTestResetConfirmQuestion =>
      'Vymazat historii onboardingových výzev a metriky? Existující plány Daily OS zůstanou, takže pro otestování celého prvního průchodu Daily OS použij čistý profil.';

  @override
  String get settingsOnboardingTestResetSubtitle =>
      'Vymaže historii výzev a metriky; existující plány Daily OS zůstanou (ladění)';

  @override
  String get settingsOnboardingTestResetTitle =>
      'Resetovat testovací stav onboardingu';

  @override
  String get settingsOnboardingTitle => 'Onboarding';

  @override
  String get settingsOptionsTitle => 'Možnosti';

  @override
  String get settingsRecordingStyleExplanation =>
      'Vyber, jak má mikrofon vypadat při nahrávání.';

  @override
  String get settingsRecordingStyleSubtitle =>
      'VU metr nebo energetická koule při nahrávání';

  @override
  String get settingsRecordingStyleTitle => 'Styl nahrávání';

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
  String get sidebarActiveSectionTitle => 'Aktivita';

  @override
  String get sidebarActivityCollapseTooltip => 'Sbalit aktivitu';

  @override
  String get sidebarActivityExpandTooltip => 'Rozbalit aktivitu';

  @override
  String get sidebarAudioRecordingStatusLabel => 'Nahrávání';

  @override
  String get sidebarRunningTimerLabel => 'Běžící časovač';

  @override
  String get sidebarRunningTimerStopTooltip => 'Zastavit časovač';

  @override
  String get sidebarTimerStatusLabel => 'Časovač';

  @override
  String get sidebarToggleCollapseLabel => 'Sbalit postranní panel';

  @override
  String get sidebarToggleExpandLabel => 'Rozbalit postranní panel';

  @override
  String sidebarWakesActiveCount(int count) {
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
  String get sidebarWakesCancelTooltip => 'Zrušit agenta';

  @override
  String get sidebarWakesHeader => 'Agenti';

  @override
  String get sidebarWakesNow => 'nyní';

  @override
  String get sidebarWakesOpenList => 'Otevřít seznam';

  @override
  String get sidebarWakesOpenTask => 'Otevřít úkol';

  @override
  String sidebarWakesQueuedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ve frontě',
      few: '$count ve frontě',
      one: '1 ve frontě',
    );
    return '$_temp0';
  }

  @override
  String get sidebarWakesQueuedLabel => 'Ve frontě';

  @override
  String get sidebarWakesWorkingLabel => 'Pracuje';

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
  String get surveyBackButton => 'Zpět';

  @override
  String get surveyCancelConfirmation => 'Zrušit dotazník?';

  @override
  String get surveyChooseOneOption => 'Vyber jednu možnost';

  @override
  String get surveyChooseOneOrMoreOptions => 'Vyber jednu nebo více možností';

  @override
  String get surveyDiscardConfirmation => 'Zahodit výsledky a ukončit?';

  @override
  String get surveyInputNumberValidation => 'Zadej číslo';

  @override
  String get surveyNextButton => 'Další';

  @override
  String get surveyNoButton => 'Ne';

  @override
  String get surveyProgressOf => 'z';

  @override
  String get surveyTapToAnswer => 'Klepni pro odpověď';

  @override
  String get surveyValueAnd => 'a';

  @override
  String get surveyValueBetween => 'Musí být mezi';

  @override
  String get surveyYesButton => 'Ano';

  @override
  String get syncActivityIdle => 'nečinné';

  @override
  String get syncActivityInboxLabel => 'Příchozí';

  @override
  String syncActivityIndicatorSemantics(int outbox, int inbox) {
    return 'Aktivita synchronizace. Odchozí: $outbox. Příchozí: $inbox. Otevřít odchozí frontu synchronizace.';
  }

  @override
  String get syncActivityOutboxLabel => 'Odchozí';

  @override
  String get syncActivitySyncingTitle => 'Synchronizace';

  @override
  String get syncActivityTitle => 'Sync';

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
  String get syncPayloadConsumptionEvent => 'Spotřeba AI';

  @override
  String get syncPayloadDailyOsUserName => 'Jméno Daily OS';

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
  String get syncPayloadSavedTaskFilter => 'Uložený filtr úkolů';

  @override
  String get syncPayloadSavedTaskFilterDelete =>
      'Smazání uloženého filtru úkolů';

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
  String get syncStepSavedTaskFilters => 'Uložené filtry úkolů';

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
  String get taskAgentAttributionUnavailable => 'Autorství není dostupné';

  @override
  String get taskAgentAutomaticUpdatesLabel => 'Automatické aktualizace';

  @override
  String get taskAgentAutomaticUpdatesNeedsSetup =>
      'Než zapneš automatické aktualizace, vyber nastavení AI.';

  @override
  String get taskAgentCancelTimerTooltip =>
      'Zrušit čekající automatickou aktualizaci';

  @override
  String get taskAgentChooseModel => 'Vybrat model pro uvažování';

  @override
  String get taskAgentChooseProfile => 'Vyber profil inference';

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
  String get taskAgentCurrentSetupHeader => 'Aktuální nastavení';

  @override
  String get taskAgentCurrentSetupLabel => 'Aktuální nastavení';

  @override
  String get taskAgentDirectModelOverride => 'Přímé přepsání modelu';

  @override
  String get taskAgentDisableConfirmAction => 'Vypnout';

  @override
  String get taskAgentDisableConfirmBody =>
      'Aktuální zpráva zůstane viditelná, ale agent se nespustí, dokud nevybereš nastavení.';

  @override
  String get taskAgentDisableConfirmTitle => 'Vypnout AI pro tohoto agenta?';

  @override
  String get taskAgentInferenceProfileLabel => 'Inferenční profil';

  @override
  String get taskAgentModelPickerTitle => 'Vybrat model pro uvažování';

  @override
  String taskAgentNextUpdateIn(String countdown) {
    return 'Další aktualizace za $countdown';
  }

  @override
  String get taskAgentNoAiSetup => 'Bez nastavení AI';

  @override
  String get taskAgentNoAiSetupDescription =>
      'Pozastaví inferenci, dokud nevybereš profil nebo model.';

  @override
  String get taskAgentNoModelsAvailable =>
      'Nejsou dostupné žádné kompatibilní modely';

  @override
  String get taskAgentNoProfilesAvailable =>
      'Na tomto zařízení nejsou dostupné žádné profily';

  @override
  String get taskAgentNoProfileSelected => 'Žádné nastavení AI';

  @override
  String get taskAgentNoProfileSelectedDescription =>
      'Než agenta spustíš, vyber uložené nastavení nebo model.';

  @override
  String taskAgentProfileChangedToast(String profile) {
    return 'Pro všechny budoucí aktualizace agenta se bude používat $profile, dokud ho nezměníš.';
  }

  @override
  String get taskAgentProfileDefaultBadge => 'Výchozí model profilu';

  @override
  String get taskAgentReportOutdatedTitle => 'Tento souhrn je zastaralý';

  @override
  String get taskAgentReportUpToDate => 'Souhrn je aktuální';

  @override
  String get taskAgentRouteVia => 'přes';

  @override
  String get taskAgentRunNowTooltip => 'Spustit nyní';

  @override
  String get taskAgentSavingSetup => 'Ukládání nastavení agenta';

  @override
  String taskAgentSetupAndReportSemantics(String identity) {
    return 'Tato zpráva i aktuální nastavení používají $identity. Aktivuj pro změnu nastavení.';
  }

  @override
  String get taskAgentSetupBroken => 'Vybrané nastavení AI není dostupné';

  @override
  String taskAgentSetupChangedToast(String model) {
    return 'Pro všechny budoucí aktualizace se bude používat $model, dokud ho nezměníš.';
  }

  @override
  String get taskAgentSetupChoiceHelp =>
      'Vyber profil pro výchozí nastavení, nebo přepiš jen model pro uvažování.';

  @override
  String get taskAgentSetupOriginCategory =>
      'Zkopírováno z výchozího nastavení kategorie při vytvoření agenta';

  @override
  String get taskAgentSetupOriginDisabled => 'Vypnuto';

  @override
  String get taskAgentSetupOriginLegacy => 'Starší nastavení';

  @override
  String get taskAgentSetupOriginTemplate => 'Zkopírováno ze šablony';

  @override
  String get taskAgentSetupOriginUser =>
      'Toto nastavení jsi vybral pro tohoto agenta';

  @override
  String get taskAgentSetupPersistenceDescription =>
      'Změny platí pro každou budoucí aktualizaci, dokud je znovu nezměníš.';

  @override
  String taskAgentSetupSemantics(String identity) {
    return 'Aktuální nastavení: $identity. Aktivuj pro změnu nastavení.';
  }

  @override
  String get taskAgentSetupTitle => 'Nastavení agenta';

  @override
  String get taskAgentThinkingModelLabel => 'Model pro uvažování';

  @override
  String get taskAgentThisReportHeader => 'Tato zpráva';

  @override
  String get taskAgentTurnOffSetup => 'Vypnout AI pro tohoto agenta';

  @override
  String get taskAgentUseCategoryDefault =>
      'Zkopírovat výchozí nastavení kategorie';

  @override
  String get taskAgentUseCategoryDefaultDescription =>
      'Zkopíruje aktuální nastavení kategorie. Pozdější změny kategorie tohoto agenta neovlivní.';

  @override
  String get taskAgentUseProfileDefault => 'Použít výchozí model profilu';

  @override
  String get taskAgentWakeAgent => 'Probudit agenta';

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
  String get taskEstimateModalTitle => 'Odhad';

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
  String get tasksFilterTitle => 'Filtrovat úkoly';

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
  String get tasksSavedFiltersAllShort => 'Vše';

  @override
  String get tasksSavedFiltersAllTasks => 'Všechny úkoly';

  @override
  String get tasksSavedFiltersCustom => 'Vlastní';

  @override
  String get tasksSavedFiltersDeleteConfirmAction => 'Smazat';

  @override
  String tasksSavedFiltersDeleteConfirmMessage(String name) {
    return 'Smazat uložený filtr „$name“? Tuto akci nelze vrátit zpět.';
  }

  @override
  String tasksSavedFiltersDeleteConfirmNamed(String name) {
    return 'Potvrdit smazání $name';
  }

  @override
  String tasksSavedFiltersDeleteNamed(String name) {
    return 'Smazat $name';
  }

  @override
  String get tasksSavedFiltersDone => 'Hotovo';

  @override
  String get tasksSavedFiltersEdit => 'Upravit';

  @override
  String get tasksSavedFiltersFilterNameLabel => 'Název filtru';

  @override
  String get tasksSavedFiltersGroupSemantics => 'Filtry úkolů';

  @override
  String get tasksSavedFiltersManageTooltip => 'Spravovat filtry úkolů';

  @override
  String get tasksSavedFiltersRailButton => 'Filtry';

  @override
  String tasksSavedFiltersRenameNamed(String name) {
    return 'Přejmenovat $name';
  }

  @override
  String get tasksSavedFiltersReorderHelper =>
      'Přetažením nastavíš pořadí. Prvních pět filtrů se zobrazí v postranním panelu.';

  @override
  String get tasksSavedFiltersSaveAsNewButtonLabel => 'Uložit jako nový…';

  @override
  String get tasksSavedFiltersSaveAsNewDescription =>
      'Ponech stávající filtr beze změny a vytvoř samostatný.';

  @override
  String get tasksSavedFiltersSaveAsNewTitle => 'Uložit jako nový filtr';

  @override
  String get tasksSavedFiltersSaveButtonLabel => 'Uložit filtr…';

  @override
  String get tasksSavedFiltersSaveChoiceIntro =>
      'Zvol, jestli chceš aktualizovat uložený filtr, nebo vytvořit samostatný.';

  @override
  String get tasksSavedFiltersSaveChoiceTitle => 'Uložit filtr';

  @override
  String get tasksSavedFiltersSaveCurrentAs => 'Uložit aktuální filtr…';

  @override
  String get tasksSavedFiltersSaveError =>
      'Filtr se nepodařilo uložit. Zkus to znovu.';

  @override
  String get tasksSavedFiltersSavePageHelper =>
      'Dej filtru krátký název. Pořadí můžeš později změnit ve Filtrech úkolů.';

  @override
  String get tasksSavedFiltersSavePopupCancel => 'Zrušit';

  @override
  String get tasksSavedFiltersSavePopupHint =>
      'např. Blokované nebo pozastavené';

  @override
  String get tasksSavedFiltersSavePopupSave => 'Uložit';

  @override
  String get tasksSavedFiltersSavePopupTitle => 'Pojmenuj tento filtr';

  @override
  String get tasksSavedFiltersSheetTitle => 'Filtry úkolů';

  @override
  String get tasksSavedFiltersShowLess => 'Zobrazit méně';

  @override
  String tasksSavedFiltersShowMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dalších uložených filtrů',
      few: '$count další uložené filtry',
      one: '1 další uložený filtr',
    );
    return '$_temp0';
  }

  @override
  String tasksSavedFiltersTaskCount(int count) {
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
  String get tasksSavedFiltersUpdateButtonLabel => 'Aktualizovat filtr';

  @override
  String get tasksSavedFiltersUpdateExistingDescription =>
      'Nahraď jeho uložená kritéria aktuálním nastavením filtru.';

  @override
  String get tasksSavedFiltersUpdateExistingTitle =>
      'Aktualizovat stávající filtr';

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
  String get whatsNewBadgeNew => 'NOVÉ';

  @override
  String get whatsNewDoneButton => 'Hotovo';

  @override
  String get whatsNewSkipButton => 'Přeskočit';
}

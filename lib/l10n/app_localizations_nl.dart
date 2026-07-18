// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get activeLabel => 'Actief';

  @override
  String get addActionAddAudioRecording => 'Audio-opname';

  @override
  String get addActionAddChecklist => 'Checklist';

  @override
  String get addActionAddEvent => 'Gebeurtenis';

  @override
  String get addActionAddImageFromClipboard => 'Afbeelding plakken';

  @override
  String get addActionAddScreenshot => 'Schermafdruk';

  @override
  String get addActionAddTask => 'Taak';

  @override
  String get addActionAddText => 'Tekstinvoer';

  @override
  String get addActionAddTimer => 'Timer';

  @override
  String get addActionAddTimeRecording => 'Timerinvoer';

  @override
  String get addActionImportImage => 'Afbeelding importeren';

  @override
  String get addHabitCommentLabel => 'Opmerking';

  @override
  String get addHabitDateLabel => 'Voltooid op';

  @override
  String get addMeasurementCommentLabel => 'Opmerking';

  @override
  String get addMeasurementDateLabel => 'Waargenomen bij';

  @override
  String get addMeasurementSaveButton => 'Opslaan';

  @override
  String get addToDictionary => 'Toevoegen aan woordenboek';

  @override
  String get addToDictionaryDuplicate => 'Term bestaat al in woordenboek';

  @override
  String get addToDictionaryNoCategory =>
      'Kan niet toevoegen aan woordenboek: taak heeft geen categorie';

  @override
  String get addToDictionarySaveFailed => 'Opslaan woordenboek mislukt';

  @override
  String get addToDictionarySuccess => 'Term toegevoegd aan woordenboek';

  @override
  String get addToDictionaryTooLong => 'Te lang looptijd (max 50 tekens)';

  @override
  String agentABComparisonChoose(String option) {
    return 'Kies $option';
  }

  @override
  String agentABComparisonOption(String option) {
    return 'Optie $option';
  }

  @override
  String agentABComparisonPrefer(String option) {
    return 'Ik verkies optie $option';
  }

  @override
  String get agentBinaryChoiceNo => 'Nee';

  @override
  String get agentBinaryChoiceYes => 'Ja.';

  @override
  String get agentCategoryRatingsScaleMax => 'Eerst repareren';

  @override
  String get agentCategoryRatingsScaleMin => 'Laat maar.';

  @override
  String agentCategoryRatingsStarLabel(int starIndex, int totalStars) {
    return '$starIndex van $totalStars sterren';
  }

  @override
  String get agentCategoryRatingsSubmit => 'Gebruik deze prioriteiten';

  @override
  String get agentCategoryRatingsSubtitle =>
      'Hoe belangrijk is het dat ik elk van deze repareer? 1 betekent laat het met rust, 5 betekent het eerst oplossen.';

  @override
  String get agentCategoryRatingsTitle => 'Help me prioriteren';

  @override
  String agentControlsActionError(String error) {
    return 'Actie mislukt: $error';
  }

  @override
  String get agentControlsDeleteButton => 'permanent verwijderen';

  @override
  String get agentControlsDeleteDialogContent =>
      'Dit zal alle gegevens voor deze agent permanent verwijderen, inclusief de geschiedenis, rapporten en observaties. Dit kan niet ongedaan worden gemaakt.';

  @override
  String get agentControlsDeleteDialogTitle => 'Agent verwijderen?';

  @override
  String get agentControlsDestroyButton => 'Vernietigen';

  @override
  String get agentControlsDestroyDialogContent =>
      'Dit zal de agent permanent uitschakelen en de geschiedenis zal bewaard blijven voor controle.';

  @override
  String get agentControlsDestroyDialogTitle => 'Agent vernietigen?';

  @override
  String get agentControlsDestroyedMessage => 'Deze agent is vernietigd.';

  @override
  String get agentControlsPauseButton => 'Pauze';

  @override
  String get agentControlsReanalyzeButton => 'Heranalyseren';

  @override
  String get agentControlsResumeButton => 'Hervatten';

  @override
  String get agentConversationEmpty => 'Nog geen gesprekken.';

  @override
  String agentConversationThreadSummary(
    int messageCount,
    int toolCallCount,
    String shortId,
  ) {
    return '$messageCount berichten, $toolCallCount tool calls · $shortId';
  }

  @override
  String agentConversationTokenCount(String tokenCount) {
    return '$tokenCount tokens';
  }

  @override
  String get agentDefaultProfileLabel => 'Standaard inferentieprofiel';

  @override
  String agentDetailErrorLoading(String error) {
    return 'Fout bij laden: $error';
  }

  @override
  String get agentDetailNotFound => 'Agent niet gevonden.';

  @override
  String get agentDetailUnexpectedType => 'Onverwacht entiteitstype.';

  @override
  String get agentEvolutionApprovalRate => 'Goedkeuringssnelheid';

  @override
  String get agentEvolutionChartMttrTrend => 'MTTR Trend';

  @override
  String get agentEvolutionChartSuccessRateTrend => 'Trend voor succes';

  @override
  String get agentEvolutionChartVersionPerformance => 'Op versie';

  @override
  String get agentEvolutionChartWakeHistory => 'Wakegeschiedenis';

  @override
  String get agentEvolutionChatPlaceholder =>
      'Deel feedback of vraag naar prestaties...';

  @override
  String get agentEvolutionCurrentDirectives => 'Huidige richtlijnen';

  @override
  String get agentEvolutionDashboardTitle => 'Prestaties';

  @override
  String get agentEvolutionHistoryTitle => 'Evolution-geschiedenis';

  @override
  String get agentEvolutionMetricActive => 'Actief';

  @override
  String get agentEvolutionMetricAvgDuration => 'Gem. duur';

  @override
  String get agentEvolutionMetricFailures => 'Mislukt';

  @override
  String get agentEvolutionMetricSuccess => 'Succes';

  @override
  String get agentEvolutionMetricWakes => 'Wakker worden';

  @override
  String get agentEvolutionNoSessions => 'Nog geen evolutiesessies';

  @override
  String get agentEvolutionNoteRecorded => 'Notitie opgenomen';

  @override
  String get agentEvolutionProposalApprovalFailed => 'Goedkeuring mislukt';

  @override
  String get agentEvolutionProposalRationale => 'Rationeel';

  @override
  String get agentEvolutionProposalRejected => 'Voorstel verworpen';

  @override
  String get agentEvolutionProposalTitle => 'Voorgestelde wijzigingen';

  @override
  String get agentEvolutionProposedDirectives => 'Voorgestelde richtlijnen';

  @override
  String get agentEvolutionSessionAbandoned =>
      'Sessie beëindigd zonder wijzigingen';

  @override
  String agentEvolutionSessionCompleted(int version) {
    return 'Sessie voltooid $version aangemaakt';
  }

  @override
  String get agentEvolutionSessionCount => 'Sessies';

  @override
  String get agentEvolutionSessionError =>
      'Evolution-sessie starten is mislukt';

  @override
  String agentEvolutionSessionProgress(int sessionNumber, int totalSessions) {
    return 'Directoraat $sessionNumber van $totalSessions';
  }

  @override
  String get agentEvolutionSessionStarting => 'Evolution sessie starten...';

  @override
  String agentEvolutionSessionTitle(int sessionNumber) {
    return 'Evolution #$sessionNumber';
  }

  @override
  String agentEvolutionSoulCurrentField(String field) {
    return 'Huidige $field';
  }

  @override
  String agentEvolutionSoulProposedField(String field) {
    return 'Vooruitlopend $field';
  }

  @override
  String get agentEvolutionStatusAbandoned => 'Verlaten';

  @override
  String get agentEvolutionStatusActive => 'Actief';

  @override
  String get agentEvolutionStatusCompleted => 'Voltooid';

  @override
  String get agentEvolutionTimelineFeedbackLabel => 'Terugkoppeling';

  @override
  String get agentEvolutionVersionProposed => 'Voorgestelde versie';

  @override
  String get agentFeedbackCategoryAccuracy => 'Nauwkeurigheid';

  @override
  String get agentFeedbackCategoryBreakdownTitle => 'Indeling van de categorie';

  @override
  String get agentFeedbackCategoryCommunication => 'Mededeling';

  @override
  String get agentFeedbackCategoryGeneral => 'Algemeen';

  @override
  String get agentFeedbackCategoryPrioritization => 'Prioriteit';

  @override
  String get agentFeedbackCategoryTimeliness => 'Tijdigheid';

  @override
  String get agentFeedbackCategoryTooling => 'Gereedschap';

  @override
  String get agentFeedbackClassificationTitle => 'Indeling van feedback';

  @override
  String get agentFeedbackExcellenceTitle => 'Excellentienotities';

  @override
  String get agentFeedbackGrievancesTitle => 'Grieven';

  @override
  String get agentFeedbackHighPriorityTitle => 'Feedback met hoge prioriteit';

  @override
  String agentFeedbackItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count onderdelen',
      one: '1 onderdeel',
    );
    return '$_temp0';
  }

  @override
  String get agentFeedbackSourceDecision => 'Besluit';

  @override
  String get agentFeedbackSourceMetric => 'Metrisch';

  @override
  String get agentFeedbackSourceObservation => 'Opmerkingen';

  @override
  String get agentFeedbackSourceRating => 'Waardering';

  @override
  String get agentInstancesEmptyFiltered =>
      'Geen instantie die overeenkomt met uw filters.';

  @override
  String get agentInstancesFilterClearAll => 'Alles wissen';

  @override
  String get agentInstancesFilterClearSection => 'Wissen';

  @override
  String get agentInstancesFilterSectionSoul => 'Ziel';

  @override
  String get agentInstancesFilterSectionStatus => 'Status';

  @override
  String get agentInstancesFilterSectionType => 'Type';

  @override
  String agentInstancesGroupActiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count actief',
      one: '1 actief',
    );
    return '$_temp0';
  }

  @override
  String get agentInstancesGroupBySoul => 'Ziel';

  @override
  String get agentInstancesGroupByStatus => 'Status';

  @override
  String get agentInstancesGroupByType => 'Type';

  @override
  String get agentInstancesKindEvolution => 'Evolution';

  @override
  String get agentInstancesKindTaskAgent => 'Taakbeheerder';

  @override
  String get agentInstancesPageTitle => 'Ambtenaren';

  @override
  String agentInstancesResultCountAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count instanties',
      one: '1 instantie',
    );
    return '$_temp0';
  }

  @override
  String agentInstancesResultCountFiltered(int filtered, int total) {
    return '$filtered van $total';
  }

  @override
  String get agentInstancesSearchClear => 'Zoeken wissen';

  @override
  String get agentInstancesSearchPlaceholder => 'Zoeken naar instanties...';

  @override
  String get agentInstancesSortName => 'Naam';

  @override
  String get agentInstancesSortOldest => 'Oudste';

  @override
  String get agentInstancesSortRecent => 'Recent';

  @override
  String get agentInstancesTitle => 'Instanties';

  @override
  String get agentInstancesToolbarFilters => 'Filters';

  @override
  String get agentInstancesToolbarGroupBy => 'Groeperen op';

  @override
  String get agentInstancesUnassignedSoul => 'Niet toegewezen';

  @override
  String get agentLifecycleActive => 'Actief';

  @override
  String get agentLifecycleCreated => 'Aangemaakt';

  @override
  String get agentLifecycleDestroyed => 'Vernietigd';

  @override
  String get agentLifecycleDormant => 'Slapend';

  @override
  String get agentMessageKindAction => 'Actie';

  @override
  String get agentMessageKindMilestone => 'Mijlpaal';

  @override
  String get agentMessageKindObservation => 'Opmerkingen';

  @override
  String get agentMessageKindRetraction => 'Intrekking';

  @override
  String get agentMessageKindSummary => 'Samenvatting';

  @override
  String get agentMessageKindSystem => 'Systeem';

  @override
  String get agentMessageKindSystemPrompt => 'Systeemprompt';

  @override
  String get agentMessageKindThought => 'Dacht';

  @override
  String get agentMessageKindToolResult => 'Resultaat gereedschap';

  @override
  String get agentMessageKindUser => 'Gebruiker';

  @override
  String get agentMessagePayloadEmpty => '(geen inhoud)';

  @override
  String get agentMessagesEmpty => 'Nog geen berichten.';

  @override
  String agentMessagesErrorLoading(String error) {
    return 'Kon berichten niet laden: $error';
  }

  @override
  String get agentObservationsEmpty => 'Nog geen waarnemingen.';

  @override
  String agentPendingWakesActivityHourDetail(
    String hour,
    int count,
    String reasons,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count activeringen',
      one: '1 activering',
    );
    return '$hour: $_temp0 ($reasons)';
  }

  @override
  String get agentPendingWakesActivityTitle => 'Wake Activity (24u)';

  @override
  String agentPendingWakesActivityTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count totale activeringen',
      one: '1 totale activering',
    );
    return '$_temp0';
  }

  @override
  String get agentPendingWakesDeleteTooltip => 'Wakker worden verwijderen';

  @override
  String get agentPendingWakesEmptyFiltered =>
      'Geen wakes die overeenkomen met je filters.';

  @override
  String get agentPendingWakesFilterSectionType => 'Type';

  @override
  String get agentPendingWakesGroupByType => 'Type';

  @override
  String get agentPendingWakesPendingLabel => 'In afwachting';

  @override
  String agentPendingWakesRunningHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nu aan de gang ($count)',
      one: 'Nu aan het werk',
    );
    return '$_temp0';
  }

  @override
  String get agentPendingWakesScheduledLabel => 'Gepland';

  @override
  String get agentPendingWakesSearchPlaceholder => 'Zoek wordt wakker...';

  @override
  String get agentPendingWakesSortDueLatest => 'Uiterlijk';

  @override
  String get agentPendingWakesSortDueSoonest => 'Binnenkort te betalen';

  @override
  String get agentPendingWakesTitle => 'Wake Cycles';

  @override
  String get agentReportHistoryBadge => 'Verslag';

  @override
  String get agentReportHistoryEmpty => 'Nog geen foto\'s van het rapport.';

  @override
  String get agentReportHistoryError =>
      'Er is een fout opgetreden bij het laden van de rapportgeschiedenis.';

  @override
  String get agentReportNone => 'Nog geen rapport beschikbaar.';

  @override
  String get agentRitualReviewAction => 'Gesprek starten';

  @override
  String get agentRitualReviewNegativeSignals => 'Negatief';

  @override
  String get agentRitualReviewNeutralSignals => 'Neutraal';

  @override
  String get agentRitualReviewNoFeedback =>
      'Geen feedbacksignalen in dit venster';

  @override
  String get agentRitualReviewNoNegativeSignals =>
      'Geen negatieve feedbacksignalen in dit tabblad';

  @override
  String get agentRitualReviewNoNeutralSignals =>
      'Geen neutrale feedbacksignalen in dit tabblad';

  @override
  String get agentRitualReviewNoPositiveSignals =>
      'Geen positieve feedbacksignalen in dit tabblad';

  @override
  String get agentRitualReviewPositiveSignals => 'Positief';

  @override
  String get agentRitualReviewProposalSection => 'Huidig voorstel';

  @override
  String get agentRitualReviewSessionHistory => 'Sessiegeschiedenis';

  @override
  String get agentRitualReviewTitle => '1-op-1';

  @override
  String get agentRitualSummaryApprovedChangesHeading =>
      'Goedgekeurde wijzigingen';

  @override
  String get agentRitualSummaryConversationHeading => 'Gesprek';

  @override
  String get agentRitualSummaryRecapHeading => 'Sessie Hersluiten';

  @override
  String get agentRitualSummaryRoleAssistant => 'Agent';

  @override
  String get agentRitualSummaryRoleUser => 'Jij';

  @override
  String get agentRitualSummaryStartHint =>
      'Start een 1-op-1 om te bekijken wat je dwarszat, wat werkte en wat er daarna zou moeten veranderen.';

  @override
  String get agentRitualSummarySubtitle =>
      'Recente 1-op-1\'s, echte wake activiteit, en de veranderingen waar je mee akkoord ging.';

  @override
  String get agentRitualSummaryTokensSinceLast =>
      'Tokens sinds de laatste 1-op-1';

  @override
  String get agentRitualSummaryWakeHistory30Days =>
      'Wakker worden (laatste 30 dagen)';

  @override
  String get agentRitualSummaryWakesSinceLast =>
      'Wakker worden sinds de laatste 1-op-1';

  @override
  String get agentRunningIndicator => 'Uitvoeren';

  @override
  String get agentSessionProgressTitle => 'Voortgang van de zitting';

  @override
  String get agentSettingsSubtitle => 'Sjablonen, instanties en monitoring';

  @override
  String get agentSettingsTitle => 'Middelen';

  @override
  String get agentSoulAntiSycophancyLabel => 'Antisycophancybeleid';

  @override
  String get agentSoulAssignedTemplatesTitle => 'Toegewezen sjablonen';

  @override
  String get agentSoulAssignmentLabel => 'Ziel';

  @override
  String get agentSoulCoachingStyleLabel => 'Coaching Style';

  @override
  String get agentSoulCreatedSuccess => 'Ziel aangemaakt';

  @override
  String get agentSoulCreateTitle => 'Ziel aanmaken';

  @override
  String get agentSoulDeleteConfirmBody =>
      'Dit zal de ziel en al zijn versies verwijderen.';

  @override
  String get agentSoulDeleteConfirmTitle => 'Ziel verwijderen';

  @override
  String get agentSoulDetailTitle => 'Zieldetail';

  @override
  String get agentSoulDisplayNameLabel => 'Naam';

  @override
  String get agentSoulEvolutionHistoryTitle => 'Ziel Evolution geschiedenis';

  @override
  String get agentSoulEvolutionNoSessions => 'Nog geen zielen evolutiesessies';

  @override
  String get agentSoulFieldAntiSycophancy => 'Antisycophancy';

  @override
  String get agentSoulFieldCoachingStyle => 'Coaching Style';

  @override
  String get agentSoulFieldToneBounds => 'Toongrenzen';

  @override
  String get agentSoulFieldVoice => 'Stem';

  @override
  String get agentSoulInfoTab => 'Informatie';

  @override
  String get agentSoulNoneAssigned => 'Geen ziel toegewezen';

  @override
  String get agentSoulNotFound => 'Ziel niet gevonden';

  @override
  String get agentSoulProposalSubtitle =>
      'Voorgestelde persoonlijkheidsveranderingen';

  @override
  String get agentSoulProposalTitle => 'Soul Personality Voorstel';

  @override
  String get agentSoulReviewHeroSubtitle =>
      'Verfijn persoonlijkheid over alle sjablonen die deze ziel delen. De evolution agent ziet feedback van elke sjabloon die deze persoonlijkheid gebruikt.';

  @override
  String get agentSoulReviewStartAction => 'Persoonlijkheidstoets starten';

  @override
  String get agentSoulReviewStartHint =>
      'Start een persoonlijkheidsgerichte sessie om feedback te beoordelen en stem, toon, coaching stijl en directheid te ontwikkelen.';

  @override
  String agentSoulReviewTemplateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count templates die deze ziel delen',
      one: '1 template delen van deze ziel',
    );
    return '$_temp0';
  }

  @override
  String get agentSoulReviewTitle => 'Ziel 1-op-1';

  @override
  String get agentSoulRollbackAction => 'Terug naar deze versie draaien';

  @override
  String agentSoulRollbackConfirm(int version) {
    return 'Terugdraaien naar versie $version? Alle sjablonen met behulp van deze ziel zal oppakken van de verandering.';
  }

  @override
  String get agentSoulSelectTitle => 'Selecteer Ziel';

  @override
  String get agentSoulsEmptyFiltered =>
      'Geen zielen die overeenkomen met je filters.';

  @override
  String get agentSoulSettingsTab => 'Instellingen';

  @override
  String get agentSoulsSearchPlaceholder => 'Zoek zielen...';

  @override
  String get agentSoulsTitle => 'Zielen';

  @override
  String get agentSoulToneBoundsLabel => 'Toongrenzen';

  @override
  String get agentSoulVersionHistoryTitle => 'Versiegeschiedenis';

  @override
  String agentSoulVersionLabel(int version) {
    return 'Versie $version';
  }

  @override
  String get agentSoulVersionSaved => 'Nieuwe ziel versie opgeslagen';

  @override
  String get agentSoulVoiceDirectiveLabel => 'Spraakrichtlijn';

  @override
  String get agentStateConsecutiveFailures => 'Consecutieve storingen';

  @override
  String agentStateErrorLoading(String error) {
    return 'Laden van status is mislukt: $error';
  }

  @override
  String get agentStateHeading => 'State Info';

  @override
  String get agentStateLastWake => 'Laatste wake';

  @override
  String get agentStateNextWake => 'Volgende wake';

  @override
  String get agentStateRevision => 'Herziening';

  @override
  String get agentStateSleepingUntil => 'Slapen tot';

  @override
  String get agentStateWakeCount => 'Wakker worden';

  @override
  String get agentStatsAllDayLegend => 'De hele dag';

  @override
  String get agentStatsAverageLabel => 'Gemiddelde';

  @override
  String agentStatsByTimeLegend(String time) {
    return 'Dagelijks per $time';
  }

  @override
  String get agentStatsCacheRateLabel => 'Cache rate';

  @override
  String get agentStatsDailyUsageHeading => 'Dagelijks gebruik';

  @override
  String get agentStatsInputLabel => 'Invoer';

  @override
  String get agentStatsNoUsage =>
      'Geen gebruik van token geregistreerd in de afgelopen 7 dagen.';

  @override
  String get agentStatsOutputLabel => 'Uitvoer';

  @override
  String agentStatsSourceActiveFor(String duration) {
    return 'Actief voor $duration';
  }

  @override
  String get agentStatsSourceActivityHeading => 'Agentactiviteit';

  @override
  String agentStatsSourceWakes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count activeringen',
      one: '1 activering',
    );
    return '$_temp0';
  }

  @override
  String get agentStatsTabTitle => 'Statistieken';

  @override
  String get agentStatsThoughtsLabel => 'Gedachten';

  @override
  String get agentStatsTodayLabel => 'Vandaag';

  @override
  String get agentStatsTokensPerWakeLabel => 'Tokens / Wake';

  @override
  String get agentStatsTokensUnit => 'tokens';

  @override
  String agentStatsUsageAboveAverage(String time) {
    return 'Je gebruikt vandaag meer tokens dan je normaal doet door $time.';
  }

  @override
  String agentStatsUsageBelowAverage(String time) {
    return 'Je gebruikt vandaag minder tokens dan je normaal doet door $time.';
  }

  @override
  String get agentStatsWakesLabel => 'Wakker worden';

  @override
  String get agentSuggestionTimeEntryUpdateCurrent => 'Lopend';

  @override
  String get agentSuggestionTimeEntryUpdateNoChange => '(ongewijzigd)';

  @override
  String get agentSuggestionTimeEntryUpdateProposed => 'Voorgesteld';

  @override
  String get agentSuggestionTimeEntryUpdateUnavailable =>
      'Oorspronkelijk item niet beschikbaar';

  @override
  String get agentTabActivity => 'Activiteit';

  @override
  String get agentTabConversations => 'Gesprekken';

  @override
  String get agentTabObservations => 'Opmerkingen';

  @override
  String get agentTabReports => 'Verslagen';

  @override
  String get agentTabStats => 'Statistieken';

  @override
  String get agentTemplateAggregateTokenUsageHeading =>
      'Geaggregeerd Tokengebruik';

  @override
  String get agentTemplateAssignedLabel => 'Sjabloon';

  @override
  String get agentTemplateCreatedSuccess => 'Sjabloon aangemaakt';

  @override
  String get agentTemplateCreateTitle => 'Sjabloon aanmaken';

  @override
  String get agentTemplateDeleteConfirm =>
      'Deze sjabloon verwijderen? Dit kan niet ongedaan worden gemaakt.';

  @override
  String get agentTemplateDeleteHasInstances =>
      'Kan niet verwijderen: actieve agenten gebruiken dit sjabloon.';

  @override
  String get agentTemplateDisplayNameLabel => 'Naam';

  @override
  String get agentTemplateEditTitle => 'Sjabloon bewerken';

  @override
  String get agentTemplateEvolveApprove => 'Afstemming & Opslaan';

  @override
  String get agentTemplateEvolveReject => 'Weigeren';

  @override
  String get agentTemplateGeneralDirectiveHint =>
      'Definieer de persoonlijkheid, instrumenten, doelstellingen en interactiestijl van de agent...';

  @override
  String get agentTemplateGeneralDirectiveLabel => 'Algemene richtlijn';

  @override
  String get agentTemplateInstanceBreakdownHeading => 'Verdeling per ingang';

  @override
  String get agentTemplateKindDayAgent => 'Dagagent';

  @override
  String get agentTemplateKindEventAgent => 'Gebeurtenisagent';

  @override
  String get agentTemplateKindImprover => 'Sjabloonverbeteraar';

  @override
  String get agentTemplateKindProjectAgent => 'Projectagent';

  @override
  String get agentTemplateKindTaskAgent => 'Taakbeheerder';

  @override
  String get agentTemplateMetricsTotalWakes => 'Totaal Wakker worden';

  @override
  String get agentTemplateNoneAssigned => 'Geen sjabloon toegewezen';

  @override
  String get agentTemplateNoTemplates =>
      'Geen sjablonen beschikbaar. Maak er eerst een in Instellingen.';

  @override
  String get agentTemplateNotFound => 'Sjabloon niet gevonden';

  @override
  String get agentTemplateNoVersions => 'Geen versies';

  @override
  String get agentTemplateReportDirectiveHint =>
      'Definieer de rapportstructuur, vereiste secties en opmaakregels...';

  @override
  String get agentTemplateReportDirectiveLabel => 'Verslagleggingsrichtlijn';

  @override
  String get agentTemplateReportsEmpty => 'Nog geen rapporten.';

  @override
  String get agentTemplateReportsTab => 'Verslagen';

  @override
  String get agentTemplateRollbackAction => 'Terug naar deze versie draaien';

  @override
  String agentTemplateRollbackConfirm(int version) {
    return 'Terugdraaien naar versie $version? De agent zal deze versie gebruiken op zijn volgende wake.';
  }

  @override
  String get agentTemplateSaveNewVersion => 'Opslaan';

  @override
  String get agentTemplateSelectTitle => 'Selecteer sjabloon';

  @override
  String get agentTemplatesEmptyFiltered =>
      'Geen sjablonen die overeenkomen met uw filters.';

  @override
  String get agentTemplateSettingsTab => 'Instellingen';

  @override
  String get agentTemplatesFilterSectionKind => 'Aardig';

  @override
  String get agentTemplatesGroupByKind => 'Aardig';

  @override
  String get agentTemplatesGroupNone => 'Alles';

  @override
  String get agentTemplatesSearchPlaceholder => 'Sjablonen zoeken...';

  @override
  String get agentTemplateStatsTab => 'Statistieken';

  @override
  String get agentTemplateStatusActive => 'Actief';

  @override
  String get agentTemplateStatusArchived => 'Gearchiveerd';

  @override
  String get agentTemplatesTitle => 'Agent-sjablonen';

  @override
  String get agentTemplateSwitchHint =>
      'Om een ander sjabloon te gebruiken, vernietig dit middel en maak een nieuwe.';

  @override
  String get agentTemplateVersionHistoryTitle => 'Versiegeschiedenis';

  @override
  String agentTemplateVersionLabel(int version) {
    return 'Versie $version';
  }

  @override
  String get agentTemplateVersionSaved => 'Nieuwe versie opgeslagen';

  @override
  String get agentThreadReportLabel =>
      'Verslag dat tijdens deze wake is opgesteld';

  @override
  String get agentTokenUsageCachedTokens => 'Gekacheld';

  @override
  String get agentTokenUsageEmpty =>
      'Nog geen gebruik van token geregistreerd.';

  @override
  String agentTokenUsageErrorLoading(String error) {
    return 'Laden van token is mislukt: $error';
  }

  @override
  String get agentTokenUsageHeading => 'Token gebruik';

  @override
  String get agentTokenUsageInputTokens => 'Invoer';

  @override
  String get agentTokenUsageModel => 'Model';

  @override
  String get agentTokenUsageOutputTokens => 'Uitvoer';

  @override
  String get agentTokenUsageThoughtsTokens => 'Gedachten';

  @override
  String get agentTokenUsageTotalTokens => 'Totaal';

  @override
  String get agentTokenUsageWakeCount => 'Wakker worden';

  @override
  String get aggregationDailyAvg => 'Daggemiddelde';

  @override
  String get aggregationDailyMax => 'Dagelijks maximum';

  @override
  String get aggregationDailySum => 'Dagelijks bedrag';

  @override
  String get aggregationHourlySum => 'Uurbedrag';

  @override
  String get aggregationNone => 'Grondwaarden';

  @override
  String get aiAssistantTitle => 'Genereren...';

  @override
  String get aiBatchToggleTooltip => 'Overschakelen naar standaard opname';

  @override
  String get aiCapabilityChipImageGeneration => 'Beeldgeneratie';

  @override
  String get aiCapabilityChipImageRecognition => 'Beeldherkenning';

  @override
  String get aiCapabilityChipThinking => 'Denken';

  @override
  String get aiCapabilityChipTranscription => 'Omschrijving';

  @override
  String aiCardHistoryToggle(int count) {
    return 'Geschiedenis · $count';
  }

  @override
  String get aiCardMenuActionDelete => 'Verwijderen';

  @override
  String get aiCardMenuActionEdit => 'Bewerken';

  @override
  String get aiCardMenuTooltip => 'Meer acties';

  @override
  String get aiCardOpenAgentInternals => 'Open agent internals';

  @override
  String get aiCardProposalConfirmed => 'Bevestigd';

  @override
  String get aiCardProposalDismissed => 'Ingerukt';

  @override
  String get aiCardProposalKindAdd => 'Toevoegen';

  @override
  String get aiCardProposalKindDue => 'Verloopdatum';

  @override
  String get aiCardProposalKindEstimate => 'Raming';

  @override
  String get aiCardProposalKindLabel => 'Label';

  @override
  String get aiCardProposalKindPriority => 'Prioriteit';

  @override
  String get aiCardProposalKindRemove => 'Verwijderen';

  @override
  String get aiCardProposalKindStatus => 'Status';

  @override
  String get aiCardProposalKindUpdate => 'Bijwerken';

  @override
  String get aiCardReadMore => 'Lees meer';

  @override
  String get aiCardShowLess => 'Minder tonen';

  @override
  String get aiCardTitle => 'Samenvatting van de AI';

  @override
  String get aiChatAssistantResponding => 'De assistent antwoordt';

  @override
  String get aiChatMessageCopied => 'Gekopieerd naar het klembord';

  @override
  String get aiConfigFailedToLoadModelsGeneric =>
      'Laden van modellen is mislukt. Probeer het opnieuw.';

  @override
  String get aiConfigNoModelsAvailable =>
      'Er zijn nog geen AI-modellen geconfigureerd. Voeg er een toe in instellingen.';

  @override
  String get aiConfigNoSuitableModelsAvailable =>
      'Geen modellen voldoen aan de eisen voor deze prompt. Stel modellen in die de vereiste mogelijkheden ondersteunen.';

  @override
  String get aiConfigSelectProviderModalTitle =>
      'Selecteer Inferentie Provider';

  @override
  String get aiConfigSelectProviderTypeModalTitle =>
      'Selecteer het type provider';

  @override
  String get aiConfigUseReasoningFieldLabel => 'Redenering gebruiken';

  @override
  String aiConsumptionCallsLine(int count, int measured) {
    return 'AI roept: $count · impact gemeten voor $measured';
  }

  @override
  String aiConsumptionCostLine(String cost) {
    return 'Kosten: $cost';
  }

  @override
  String aiConsumptionImpactLine(String energy, String carbon, String water) {
    return 'Effect: $energy · $carbon CO2e $water water';
  }

  @override
  String aiConsumptionLedgerCap(int limit) {
    return 'Nieuwste tonen $limit oproepen in deze periode';
  }

  @override
  String get aiConsumptionLedgerTitle => 'Recente oproepen';

  @override
  String get aiConsumptionMetricsNotReported => 'Niet gerapporteerd';

  @override
  String aiConsumptionTokensLabel(String tokens) {
    return '$tokens tokens';
  }

  @override
  String aiConsumptionTokensLine(String input, String output) {
    return 'Tokens: $input in · $output uit';
  }

  @override
  String get aiConsumptionTypeAgentTurn => 'Agent Turn';

  @override
  String get aiConsumptionTypeAudioTranscription => 'Omschrijving';

  @override
  String get aiConsumptionTypeImageAnalysis => 'Afbeeldingsanalyse';

  @override
  String get aiConsumptionTypeImageGeneration => 'Beeldgeneratie';

  @override
  String get aiConsumptionTypePromptGeneration => 'Snelle generatie';

  @override
  String get aiConsumptionTypeTextGeneration => 'Tekstgeneratie';

  @override
  String aiDeleteToastCascadeDescription(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ook verwijderd $count modellen: $names',
      one: 'Ook verwijderd 1 model: $names',
    );
    return '$_temp0';
  }

  @override
  String aiDeleteToastErrorTitle(String name) {
    return 'Kon niet verwijderen $name';
  }

  @override
  String get aiDeleteToastModelTitle => 'Model geschrapt';

  @override
  String get aiDeleteToastProfileTitle => 'Profiel verwijderd';

  @override
  String get aiDeleteToastPromptTitle => 'Waarschuwing verwijderd';

  @override
  String get aiDeleteToastProviderTitle => 'Verlener verwijderd';

  @override
  String get aiDeleteToastSkillTitle => 'Vaardigheid verwijderd';

  @override
  String get aiDeleteToastUndoAction => 'Ongedaan maken';

  @override
  String get aiFormCancel => 'Annuleren';

  @override
  String get aiFormFixErrors => 'Foutherstel voordat u opslaat';

  @override
  String get aiFormNoChanges => 'Geen niet opgeslagen wijzigingen';

  @override
  String get aiImageAnalysisPickerDefaultBadge => 'Standaard';

  @override
  String get aiImageAnalysisPickerTitle => 'Kies een model voor beeldanalyse';

  @override
  String get aiImageGenerationPickerTitle =>
      'Kies een model voor het genereren van afbeeldingen';

  @override
  String get aiImpactBreakdownBoth => 'Beide';

  @override
  String get aiImpactBreakdownCategory => 'Per categorie';

  @override
  String get aiImpactBreakdownModel => 'Op model';

  @override
  String get aiImpactCategoryTitle => 'Indeling naar categorie';

  @override
  String get aiImpactChartHint =>
      'Tik op een balk om te scope calls · tik op een serie om te isoleren';

  @override
  String get aiImpactChartShareCaption =>
      'Samenstelling in de loop van de tijd';

  @override
  String get aiImpactChartShareSegment => 'Delen';

  @override
  String aiImpactChartTitle(String metric) {
    return '$metric per categorie';
  }

  @override
  String aiImpactChartTitleModel(String metric) {
    return '$metric op model';
  }

  @override
  String get aiImpactCoverageNote =>
      'Energie, CO2e en kosten worden alleen gemeten voor cloudmodellen.';

  @override
  String get aiImpactEmptyBody =>
      'Al belt van je taken en agenten zullen hier komen.';

  @override
  String get aiImpactEmptyTitle => 'Geen AI-gebruik in dit bereik';

  @override
  String get aiImpactKpiCarbon => 'CO2E';

  @override
  String get aiImpactKpiCost => 'KOSTEN';

  @override
  String aiImpactKpiDeltaBaseline(String period) {
    return 'vs $period';
  }

  @override
  String get aiImpactKpiEnergy => 'ENERGIE';

  @override
  String get aiImpactKpiRequests => 'VERZOEKEN';

  @override
  String get aiImpactKpiTokens => 'TOKENS';

  @override
  String get aiImpactLedgerClearFilter => 'Alles tonen';

  @override
  String get aiImpactLoadError => 'Kon AI-effectgegevens niet laden';

  @override
  String get aiImpactLocationColumn => 'PLAATS';

  @override
  String get aiImpactLocationTitle => 'Invloed op de locatie';

  @override
  String get aiImpactLocationUnknown => 'Onbekend';

  @override
  String get aiImpactMetricCarbon => 'CO2e';

  @override
  String get aiImpactMetricCost => 'Kosten';

  @override
  String get aiImpactMetricEnergy => 'Energie';

  @override
  String get aiImpactMetricRequests => 'Verzoeken';

  @override
  String get aiImpactMetricTokens => 'Tokens';

  @override
  String aiImpactModelCallsLabel(String count) {
    return '$count oproepen';
  }

  @override
  String get aiImpactModelColumn => 'MODEL';

  @override
  String get aiImpactModelCostHeavy => 'kosten-zwaar';

  @override
  String get aiImpactModelCoverageNote =>
      'Lokale modellen zijn uitgesloten van deze grafiek.';

  @override
  String get aiImpactModelOther => 'Andere modellen';

  @override
  String aiImpactModelRatePerMillion(String cost) {
    return '$cost/1M tok';
  }

  @override
  String get aiImpactModelTitle => 'Modelindeling';

  @override
  String get aiImpactModelUnknown => 'Onbekend model';

  @override
  String get aiImpactRenewableColumn => 'HERNIEUWBARE';

  @override
  String get aiImpactTitle => 'AI Impact';

  @override
  String get aiInferenceErrorAuthenticationTitle => 'Aanmelding mislukt';

  @override
  String get aiInferenceErrorConnectionFailedTitle => 'Verbinding mislukt';

  @override
  String get aiInferenceErrorInvalidRequestTitle => 'Ongeldig verzoek';

  @override
  String get aiInferenceErrorRateLimitTitle => 'Maximumwaarde overschreden';

  @override
  String get aiInferenceErrorRetryButton => 'Opnieuw proberen';

  @override
  String get aiInferenceErrorServerTitle => 'Serverfout';

  @override
  String get aiInferenceErrorSuggestionsTitle => 'Suggesties:';

  @override
  String get aiInferenceErrorTimeoutTitle =>
      'Verzoek om beëindiging van de termijn';

  @override
  String get aiInferenceErrorUnknownTitle => 'Fout';

  @override
  String get aiInternalsTitle => 'Agent internals';

  @override
  String get aiModelDownloadCloseButton => 'Sluiten';

  @override
  String aiModelDownloadDialogDescription(String modelName) {
    return 'Lotti zal downloaden $modelName in de MLX Audio cache en gebruik het voor lokale spraakverwerking.';
  }

  @override
  String aiModelDownloadDialogTitle(String modelName) {
    return 'Installeren $modelName';
  }

  @override
  String get aiModelDownloadInstallTooltip => 'Model installeren';

  @override
  String get aiModelDownloadOpenProgressTooltip => 'Downloadvoortgang tonen';

  @override
  String get aiModelDownloadStatusChecking => 'Modelstatus controleren';

  @override
  String aiModelDownloadStatusDownloading(int percent) {
    return 'Downloaden $percent%';
  }

  @override
  String get aiModelDownloadStatusDownloadingIndeterminate => 'Downloaden';

  @override
  String get aiModelDownloadStatusFailed => 'Downloaden is mislukt';

  @override
  String get aiModelDownloadStatusInstalled => 'Geïnstalleerd';

  @override
  String get aiModelDownloadStatusNotInstalled => 'Niet geïnstalleerd';

  @override
  String get aiModelDownloadStatusUnsupported => 'Apple Silicium vereist';

  @override
  String get aiModelInstallChoiceCancelButton => 'Annuleren';

  @override
  String get aiModelInstallChoiceDescription =>
      'Kies het lokale spraak-tekstmodel om eerst te downloaden. U kunt de anderen later installeren uit de lijst met modellen.';

  @override
  String get aiModelInstallChoiceInstallButton => 'Model installeren';

  @override
  String get aiModelInstallChoiceRecommended => 'Aanbevolen';

  @override
  String get aiModelInstallChoiceTitle => 'Kies MLX Audio model';

  @override
  String get aiModelPickerByProviderLabel => 'Kies een provider';

  @override
  String get aiModelPickerCurrentDefaultLabel => 'Huidige standaard';

  @override
  String aiModelPickerProviderModelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modellen',
      one: '1 model',
    );
    return '$_temp0';
  }

  @override
  String aiOllamaModelInstalledSuccessfully(String modelName) {
    return 'Model \"$modelName\" met succes geïnstalleerd!';
  }

  @override
  String get aiPickProviderBadgeDesktopOnly => 'ALLEEN DESKTOP';

  @override
  String get aiPickProviderBadgeNew => 'NIEUW';

  @override
  String get aiPickProviderBadgeRecommended => 'AANGEVALDE';

  @override
  String get aiPickProviderContinueButton => 'Doorgaan';

  @override
  String get aiPickProviderDontShowAgainButton => 'Kom niet meer opdagen.';

  @override
  String get aiPickProviderFooterHint =>
      'U kunt later meer providers toevoegen in Instellingen → AI. Uw API-sleutel wordt lokaal opgeslagen.';

  @override
  String get aiPickProviderModalTitle => 'AI-functies instellen';

  @override
  String get aiPickProviderSubtitle =>
      'Kies een provider om te beginnen. We zetten modellen en een startprofiel automatisch op.';

  @override
  String get aiProfileCardActiveBadge => 'Actief';

  @override
  String get aiProfileModelPickerSearchHint => 'Zoeken naar modellen...';

  @override
  String get aiProfileSlotModelMissing => 'ontbrekend';

  @override
  String get aiPromptGenerationPickerTitle => 'Kies een prompt generatie model';

  @override
  String get aiProviderAlibabaDescription =>
      'Alibaba Cloud\'s Qwen-familie van modellen via DashScope API';

  @override
  String get aiProviderAlibabaName => 'Alibaba Cloud (Qwen)';

  @override
  String get aiProviderAnthropicDescription =>
      'Anthropics Claude familie van AI assistenten';

  @override
  String get aiProviderAnthropicName => 'Antropische Claude';

  @override
  String get aiProviderCardDraftBadge => 'ONTWERP';

  @override
  String get aiProviderCardFixButton => 'Fix';

  @override
  String aiProviderCardModelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modellen',
      one: '1 model',
    );
    return '$_temp0';
  }

  @override
  String aiProviderCardModelCountWithLastUsed(int count, String lastUsed) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modellen · laatst gebruikt $lastUsed',
      one: '1 model · laatst gebruikt $lastUsed',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderCardOllamaHint => 'Zorg ervoor dat Ollama draait';

  @override
  String aiProviderCardStatusConnected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Verbonden · $count modellen',
      one: 'Verbonden · 1 model',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderCardStatusConnectedShort => 'Verbonden';

  @override
  String get aiProviderCardStatusInvalidKey => 'Ongeldige sleutel';

  @override
  String get aiProviderCardStatusOffline =>
      'Offline · Zorg ervoor dat Ollama draait';

  @override
  String get aiProviderCardStatusOfflineShort => 'Offline';

  @override
  String get aiProviderConnectBackToProviders => 'Terug naar providers';

  @override
  String get aiProviderConnectBreadcrumbAdd => 'Leverancier toevoegen';

  @override
  String get aiProviderConnectFieldBaseUrlHint =>
      'Laat leeg om het officiële eindpunt te gebruiken';

  @override
  String get aiProviderConnectFieldBaseUrlLabelOptional =>
      'Basis-URL (facultatief)';

  @override
  String get aiProviderConnectFieldBaseUrlPlaceholder =>
      'https://api.example.com';

  @override
  String get aiProviderConnectFieldDisplayNameHint =>
      'Getoond in uw provider lijst';

  @override
  String get aiProviderConnectionCheckingLabel =>
      'Sleutel controleren, beschikbare modellen weergeven...';

  @override
  String aiProviderConnectionFailedBadResponseDetail(String type) {
    return 'Onverwachte responsvorm: $type';
  }

  @override
  String aiProviderConnectionFailedHttpDetail(int status, String message) {
    return 'HTTP $status · $message';
  }

  @override
  String get aiProviderConnectionFailedInvalidBaseUrlDetail =>
      'Basis-URL moet http(s) schema en host bevatten (bv. https://api.example.com)';

  @override
  String aiProviderConnectionFailedNetworkDetail(String message) {
    return '$message';
  }

  @override
  String get aiProviderConnectionFailedTimeoutDetail => 'Verzoek is getimed';

  @override
  String aiProviderConnectionFailedTitle(String providerName) {
    return 'Kon niet bereiken ${providerName}Controleer de sleutel of uw netwerk.';
  }

  @override
  String get aiProviderConnectionRetestButton => 'Opnieuw testen';

  @override
  String get aiProviderConnectionRetryButton => 'Opnieuw proberen';

  @override
  String aiProviderConnectionVerifiedSubtitle(int count, int ms) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count modellen beschikbaar op uw account · gereageerd in ${ms}ms',
      one: '1 model beschikbaar op uw rekening · gereageerd in ${ms}ms',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderConnectionVerifiedTitle => 'Verbinding geverifieerd';

  @override
  String aiProviderConnectKeyHelperLink(String url) {
    return 'Pak een sleutel bij $url';
  }

  @override
  String get aiProviderConnectKeyHiddenLabel => 'Verborgen';

  @override
  String get aiProviderConnectKeyPrivacyHint =>
      'Je API sleutel blijft nooit achter bij je apparaat.';

  @override
  String aiProviderConnectPageTitle(String providerName) {
    return 'Verbinden $providerName';
  }

  @override
  String get aiProviderConnectSaveAndContinue => 'Opslaan & doorgaan';

  @override
  String get aiProviderConnectSaveAsDraft => 'Als concept opslaan';

  @override
  String get aiProviderConnectSavedAsDraftToast => 'Opgeslagen als concept';

  @override
  String get aiProviderConnectStepChoose => 'Kies provider';

  @override
  String get aiProviderConnectStepConnect => 'Verbinden';

  @override
  String get aiProviderConnectStepReview => 'Evaluatie';

  @override
  String get aiProviderDetailActiveProfileTitle => 'Actief profiel';

  @override
  String get aiProviderDetailAddModelButton => 'Model toevoegen';

  @override
  String get aiProviderDetailApiKeyLabel => 'API-sleutel';

  @override
  String get aiProviderDetailBackTooltip => 'Terug';

  @override
  String get aiProviderDetailBaseUrlLabel => 'Basis-URL';

  @override
  String get aiProviderDetailConnectionTitle => 'Verbinding';

  @override
  String get aiProviderDetailDangerZoneTitle => 'Gevaarszone';

  @override
  String get aiProviderDetailDisplayNameLabel => 'Naam tonen';

  @override
  String get aiProviderDetailEditButton => 'Bewerken';

  @override
  String get aiProviderDetailEditTooltip => 'Verwerker bewerken';

  @override
  String get aiProviderDetailLoadError =>
      'Kon deze provider niet laden. Probeer het opnieuw vanuit de lijst met instellingen voor AI.';

  @override
  String get aiProviderDetailMissingMessage =>
      'Deze provider is niet meer beschikbaar.';

  @override
  String aiProviderDetailModelsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Modellen · $count',
      one: 'Modellen · 1',
      zero: 'Modellen',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderDetailNoModelsMessage =>
      'Nog geen modellen. Voeg er een toe om met deze provider te beginnen.';

  @override
  String get aiProviderDetailPageTitle => 'Gegevens van de aanbieder';

  @override
  String get aiProviderDetailRemoveButton => 'Verwijder provider';

  @override
  String get aiProviderDetailRemoveDescription =>
      'Verwijdert de provider en elk model dat ervan afhangt. Dit kan niet ongedaan worden gemaakt.';

  @override
  String get aiProviderDetailRemoveTitle => 'Deze provider verwijderen';

  @override
  String get aiProviderDetailValueUnset => 'Niet ingesteld';

  @override
  String get aiProviderEmbeddedRuntimeHint =>
      'Runs ingebed in het Apple-appproces. Er is geen lokale server of basis-URL vereist.';

  @override
  String get aiProviderGeminiDescription => 'Google Gemini AI modellen';

  @override
  String get aiProviderGeminiName => 'Google Gemini';

  @override
  String get aiProviderGenericOpenAiDescription =>
      'API compatibel met OpenAI-formaat';

  @override
  String get aiProviderGenericOpenAiName => 'OpenAI Compatible';

  @override
  String get aiProviderMeliousDescription =>
      'Europese hosted gevolgtrekking met een dynamische modelcatalogus, routing, audio en afbeeldingen';

  @override
  String get aiProviderMeliousName => 'Melious.ai';

  @override
  String get aiProviderMistralDescription =>
      'Mistral AI cloud API met native audio transcriptie';

  @override
  String get aiProviderMistralName => 'Mistral';

  @override
  String get aiProviderMlxAudioDescription =>
      'Ingebed MLX Audio modellen voor lokale STT en TTS op Apple Silicium';

  @override
  String get aiProviderMlxAudioName => 'MLX-audio (lokaal)';

  @override
  String get aiProviderNebiusAiStudioDescription =>
      'Nebius AI Studio\'s modellen';

  @override
  String get aiProviderNebiusAiStudioName => 'Nebius AI Studio';

  @override
  String get aiProviderOllamaDescription => 'Lokaal gevolg geven met Ollama';

  @override
  String get aiProviderOllamaName => 'Ollama';

  @override
  String get aiProviderOmlxDescription =>
      'Lokale OpenAI-compatibele oMLX-inferentie voor MLX-modellen';

  @override
  String get aiProviderOmlxName => 'oMLX (lokaal)';

  @override
  String get aiProviderOpenAiDescription => 'OpenAI\'s GPT-modellen';

  @override
  String get aiProviderOpenAiName => 'OpenAI';

  @override
  String get aiProviderOpenRouterDescription => 'OpenRouters modellen';

  @override
  String get aiProviderOpenRouterName => 'OpenRouter';

  @override
  String get aiProviderTaglineAlibaba =>
      'Qwen modellen · multimodaal · lange context';

  @override
  String get aiProviderTaglineAnthropic => 'Claude familie · lange context';

  @override
  String get aiProviderTaglineGemini => 'Multimodal · audio transcriptie';

  @override
  String get aiProviderTaglineMelious =>
      'EU-gehoste · dynamische catalogus · eco routing';

  @override
  String get aiProviderTaglineMlxAudio =>
      'Ingebed · Apple Silicon · lokale audio';

  @override
  String get aiProviderTaglineOllama => 'Lokaal draait · geen cloudgesprekken';

  @override
  String get aiProviderTaglineOmlx =>
      'Lokale MLX-inferentie · OpenAI-compatibel';

  @override
  String get aiProviderTaglineOpenAi => 'GPT-familie · zicht + redenering';

  @override
  String get aiProviderUnknownName => 'AI-aanbieder';

  @override
  String get aiProviderVoxtralDescription =>
      'Lokale Voxtral transcriptie (tot 30 min audio, 13 talen)';

  @override
  String get aiProviderVoxtralName => 'Voxtral (lokaal)';

  @override
  String get aiProviderWhisperDescription =>
      'Lokale Whisper transcriptie met OpenAI-compatibele API';

  @override
  String get aiProviderWhisperName => 'Fluisteren (lokaal)';

  @override
  String get aiRealtimeToggleTooltip => 'Overschakelen naar live transcriptie';

  @override
  String get aiResponseDeleteCancel => 'Annuleren';

  @override
  String get aiResponseDeleteConfirm => 'Verwijderen';

  @override
  String get aiResponseDeleteError =>
      'Verwijderen van AI-antwoord is mislukt. Probeer het opnieuw.';

  @override
  String get aiResponseDeleteTitle => 'AI-respons verwijderen';

  @override
  String get aiResponseDeleteWarning =>
      'Weet u zeker dat u dit AI-antwoord wilt verwijderen? Dit kan niet ongedaan worden gemaakt.';

  @override
  String get aiResponseTypeAudioTranscription => 'Audio-transcriptie';

  @override
  String get aiResponseTypeChecklistUpdates => 'Checklist Updates';

  @override
  String get aiResponseTypeImageAnalysis => 'Afbeeldingsanalyse';

  @override
  String get aiResponseTypeImagePromptGeneration => 'Afbeeldingsprompt';

  @override
  String get aiResponseTypePromptGeneration => 'Gegenereerd verzoek';

  @override
  String get aiResponseTypeTaskSummary => 'Taakoverzicht';

  @override
  String get aiRunningActivityOpenProgress => 'AI-voortgang tonen';

  @override
  String get aiSettingsAddedLabel => 'Toegevoegd';

  @override
  String get aiSettingsAddModelButton => 'Model toevoegen';

  @override
  String get aiSettingsAddModelErrorDescription =>
      'Er is iets misgegaan bij het toevoegen van het model. Probeer het opnieuw.';

  @override
  String get aiSettingsAddModelErrorTitle => 'Kon model niet toevoegen';

  @override
  String get aiSettingsAddModelTooltip => 'Voeg dit model toe aan uw provider';

  @override
  String get aiSettingsAddProfileButton => 'Profiel toevoegen';

  @override
  String get aiSettingsAddProviderButton => 'Leverancier toevoegen';

  @override
  String get aiSettingsAgentWakeConcurrencyDescription =>
      'Kies hoeveel verschillende agenten in één keer gevolgtrekkingen kunnen uitvoeren. Hogere waarden reageren sneller maar gebruiken meer provider- en apparaatcapaciteit.';

  @override
  String get aiSettingsAgentWakeConcurrencyLabel =>
      'Gelijktijdige toediening van het middel';

  @override
  String get aiSettingsClearAllFiltersTooltip => 'Alle filters wissen';

  @override
  String get aiSettingsClearFiltersButton => 'Wissen';

  @override
  String get aiSettingsCounterModels => 'Modellen';

  @override
  String get aiSettingsCounterProfiles => 'Profielen';

  @override
  String get aiSettingsCounterProviders => 'Aanbieders';

  @override
  String get aiSettingsEmptyDescription =>
      'Voeg er een toe om transcriptie, beeldherkenning, beeldgeneratie en semantische zoekopdrachten te ontgrendelen.';

  @override
  String get aiSettingsEmptyTitle => 'Nog geen providers';

  @override
  String aiSettingsFilterByCapabilityTooltip(String capability) {
    return 'Filteren op $capability vermogen';
  }

  @override
  String aiSettingsFilterByProviderTooltip(String provider) {
    return 'Filteren op $provider';
  }

  @override
  String get aiSettingsFilterByReasoningTooltip =>
      'Filteren op redeneervermogen';

  @override
  String get aiSettingsFtueBannerDescription =>
      'Lotti zal modellen en een startprofiel voor je opzetten.';

  @override
  String get aiSettingsFtueBannerStartButton => 'Startinstellingen';

  @override
  String get aiSettingsFtueBannerTitle => 'Voeg uw eerste AI provider toe';

  @override
  String get aiSettingsModalityAudio => 'Audio';

  @override
  String get aiSettingsModalityText => 'Tekst';

  @override
  String get aiSettingsModalityVision => 'Gezicht';

  @override
  String get aiSettingsNoModelsConfigured => 'Geen AI-modellen geconfigureerd';

  @override
  String get aiSettingsNoProvidersConfigured =>
      'Geen AI providers geconfigureerd';

  @override
  String get aiSettingsPageLead =>
      'Configure AI providers, de modellen Lotti kunnen bellen, en de gevolgtrekkingen profielen die bepalen welke model verwerkt welke taak.';

  @override
  String get aiSettingsPageTitle => 'AI-instellingen';

  @override
  String get aiSettingsReasoningLabel => 'Redenering';

  @override
  String get aiSettingsRemoveModelTooltip =>
      'Verwijder dit model van uw provider';

  @override
  String get aiSettingsSearchHint => 'Zoekproviders, modellen, profielen...';

  @override
  String get aiSettingsSearchHintShort => 'Zoeken';

  @override
  String get aiSettingsTabModels => 'Modellen';

  @override
  String get aiSettingsTabProfiles => 'Profielen';

  @override
  String get aiSettingsTabProviders => 'Aanbieders';

  @override
  String get aiSetupPreviewAcceptButton => '& Afronden accepteren';

  @override
  String get aiSetupPreviewAlreadyAddedSectionLabel => 'Reeds toegevoegd';

  @override
  String aiSetupPreviewCategoryFooter(String categoryName) {
    return 'Stel een testcategorie in $categoryName om het uit te proberen.';
  }

  @override
  String aiSetupPreviewConnectedHeader(String providerName) {
    return '$providerName verbonden';
  }

  @override
  String get aiSetupPreviewCustomizeButton => 'Aanpassen';

  @override
  String get aiSetupPreviewLead =>
      'Bekijk wat Lotti zal toevoegen. Controleer alles wat je niet wilt, je kunt het altijd later met de hand instellen.';

  @override
  String get aiSetupPreviewLiveBadge => 'Levende';

  @override
  String aiSetupPreviewModalTitle(String providerName) {
    return '$providerName setup';
  }

  @override
  String get aiSetupPreviewModelsSectionLabel => 'Modellen';

  @override
  String get aiSetupPreviewProfileSectionLabel => 'Inferentieprofiel';

  @override
  String get aiSetupPreviewProfileSetActiveBadge => 'Actief instellen';

  @override
  String aiSetupResultBulletCategoryCreated(String categoryName) {
    return 'Stel een testcategorie in $categoryName om het uit te proberen';
  }

  @override
  String aiSetupResultBulletCategoryReused(String categoryName) {
    return 'Hergebruik van bestaande testcategorie $categoryName';
  }

  @override
  String aiSetupResultBulletModels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Geconfigureerd $count modellen',
      one: '1 model geconfigureerd',
    );
    return '$_temp0';
  }

  @override
  String aiSetupResultBulletProfile(String profileName) {
    return 'Inferentieprofiel aangemaakt $profileName';
  }

  @override
  String aiSetupResultErrorsHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count problemen',
      one: '1 probleem',
    );
    return '$_temp0 tijdens de configuratie';
  }

  @override
  String aiSetupResultHeader(String providerName) {
    return '$providerName is verbonden';
  }

  @override
  String aiSetupResultKnownModelsMissing(String providerName) {
    return 'Kon niet vinden wat nodig is $providerName modelconfiguraties';
  }

  @override
  String get aiSetupResultLead => 'We hebben alles voor je geregeld.';

  @override
  String aiSetupResultModalTitle(String providerName) {
    return '$providerName klaar';
  }

  @override
  String get aiSetupResultStartUsingButton => 'Begin met het gebruik van AI';

  @override
  String get aiSetupWizardCreatesOptimized =>
      'Maakt geoptimaliseerde modellen, prompts en een testcategorie';

  @override
  String aiSetupWizardDescription(String providerName) {
    return 'Stel modellen, prompts en testcategorie op of ververs ze voor $providerName';
  }

  @override
  String get aiSetupWizardRunButton => 'Instellen';

  @override
  String get aiSetupWizardRunLabel => 'Instellen-assistent uitvoeren';

  @override
  String get aiSetupWizardRunningButton => 'Rennen...';

  @override
  String get aiSetupWizardSafeToRunMultiple =>
      'Veilig meerdere keren draaien - bestaande items worden bewaard';

  @override
  String get aiSetupWizardTitle => 'AI-instellingsassistent';

  @override
  String get aiSummaryPlayTooltip => 'Samenvatting afspelen';

  @override
  String get aiSummaryPreparingTooltip => 'Audio wordt voorbereid';

  @override
  String get aiSummarySpeakTooltip => 'Samenvatting lokaal voorlezen';

  @override
  String get aiSummaryStopTooltip => 'Stoppen';

  @override
  String get aiSummaryThinkingLabel => 'Denken...';

  @override
  String get aiSummaryTtsUnavailable => 'Tekst-tot-spraak is niet beschikbaar';

  @override
  String get aiTaskSummaryTitle => 'Samenvatting van de AI-taak';

  @override
  String get aiTranscriptionPickerDefaultBadge => 'Standaard';

  @override
  String get aiTranscriptionPickerTitle => 'Kies een transcriptiemodel';

  @override
  String get apiKeyAddPageTitle => 'Aanbieder toevoegen';

  @override
  String get apiKeyAuthenticationDescription => 'Beveilig uw API-verbinding';

  @override
  String get apiKeyAuthenticationTitle => 'Authenticatie';

  @override
  String get apiKeyAvailableModelsDescription =>
      'Quick-add voorgeconfigureerde modellen voor deze provider';

  @override
  String get apiKeyAvailableModelsTitle => 'Beschikbare modellen';

  @override
  String get apiKeyBaseUrlLabel => 'Basis-URL';

  @override
  String get apiKeyDisplayNameHint => 'Een vriendschappelijke naam invoeren';

  @override
  String get apiKeyDisplayNameLabel => 'Naam tonen';

  @override
  String get apiKeyDynamicModelsDescription =>
      'Zoek in de live modelcatalogus van deze provider en voeg elk model toe';

  @override
  String get apiKeyEditGoBackButton => 'Ga terug';

  @override
  String get apiKeyEditLoadError =>
      'Laden van API-sleutelconfiguratie is mislukt';

  @override
  String get apiKeyEditLoadErrorRetry =>
      'Probeer opnieuw of contacteer ondersteuning';

  @override
  String get apiKeyEditPageTitle => 'Aanbieder bewerken';

  @override
  String get apiKeyHideTooltip => 'API-sleutel verbergen';

  @override
  String get apiKeyInputHint => 'Voer uw API-sleutel in';

  @override
  String get apiKeyInputLabel => 'API-sleutel';

  @override
  String apiKeyKnownModelInputLabel(String modalities) {
    return 'In: $modalities';
  }

  @override
  String apiKeyKnownModelOutputLabel(String modalities) {
    return 'Uit: $modalities';
  }

  @override
  String get apiKeyProviderConfigDescription =>
      'Configureer uw AI-inferentieproviderinstellingen';

  @override
  String get apiKeyProviderConfigTitle => 'Configuratie van de provider';

  @override
  String get apiKeyProviderTypeHint => 'Selecteer een providertype';

  @override
  String get apiKeyProviderTypeLabel => 'Type aanbieder';

  @override
  String get apiKeyShowTooltip => 'API-sleutel tonen';

  @override
  String get audioRecordingCancel => 'Annuleren';

  @override
  String get audioRecordingDiscardDialogBody =>
      'Deze opname wordt verwijderd. Er zal geen audio-invoer, transcript of taaksamenvatting worden aangemaakt.';

  @override
  String get audioRecordingDiscardDialogCancel => 'Blijf opnemen';

  @override
  String get audioRecordingDiscardDialogConfirm => 'Gooien';

  @override
  String get audioRecordingDiscardDialogTitle => 'Opname weggooien?';

  @override
  String get audioRecordingListening => 'Luisteren...';

  @override
  String get audioRecordingPause => 'Pauzeren';

  @override
  String get audioRecordingRealtime => 'Levende omschrijving';

  @override
  String get audioRecordingResume => 'Hervatten';

  @override
  String get audioRecordings => 'Audio-opnames';

  @override
  String get audioRecordingStandard => 'Standaard';

  @override
  String get audioRecordingStop => 'Stoppen';

  @override
  String backfillAdvancedRecoveryActions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count acties',
      one: '1 actie',
    );
    return '$_temp0';
  }

  @override
  String get backfillAdvancedRecoveryTitle => 'Geavanceerd herstel';

  @override
  String get backfillAskPeersConfirmAccept => 'Vragen aan gelijken';

  @override
  String backfillAskPeersConfirmContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Hiermee worden alle $count onherstelbare vermeldingen in het sequentielogboek weer als ontbrekend gemarkeerd, zodat de normale inhaalslag andere apparaten opnieuw bevraagt. Apparaten die de gegevens nog hebben, reageren; echt onherstelbare vermeldingen worden na het amnestievenster van zeven dagen opnieuw als onherstelbaar aangemerkt.',
      one:
          'Hiermee wordt 1 onherstelbare vermelding in het sequentielogboek weer als ontbrekend gemarkeerd, zodat de normale inhaalslag andere apparaten opnieuw bevraagt. Apparaten die de gegevens nog hebben, reageren; echt onherstelbare vermeldingen worden na het amnestievenster van zeven dagen opnieuw als onherstelbaar aangemerkt.',
    );
    return '$_temp0';
  }

  @override
  String get backfillAskPeersConfirmTitle =>
      'Vragen collega\'s opnieuw om onoplosbaar items?';

  @override
  String get backfillAskPeersDescription =>
      'Draai elke niet op te lossen sequence-log entry terug naar ontbrekende en laat de normale backfill sweep opnieuw vragen peers.';

  @override
  String get backfillAskPeersProcessing => 'Heropenen...';

  @override
  String get backfillAskPeersTitle => 'Vragen aan gelijken voor onoplosbaar';

  @override
  String backfillAskPeersTrigger(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vraag naar collega\'s $count items',
      one: 'Vraag peers om 1 ingang',
    );
    return '$_temp0';
  }

  @override
  String get backfillCatchUpDescription =>
      'Trek recente ontbrekende items uit van collega\'s nu.';

  @override
  String backfillDevicesMeta(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count apparaat-ID\'s',
      one: '1 apparaat-ID',
    );
    return '$_temp0';
  }

  @override
  String get backfillManualDescription =>
      'Verzoek alle ontbrekende items ongeacht leeftijd. Gebruik dit om oudere synchronisatiekloven te herstellen.';

  @override
  String get backfillManualProcessing => 'Bezig met verwerken...';

  @override
  String get backfillManualTitle => 'Handmatig backfill';

  @override
  String get backfillManualTrigger => 'Verzoek ontbrekende items';

  @override
  String get backfillReRequestDescription =>
      'Re-verzoeken die werden aangevraagd maar nooit ontvangen. Gebruik dit wanneer de antwoorden vastzitten.';

  @override
  String get backfillReRequestProcessing => 'Her-verzoek...';

  @override
  String get backfillReRequestTitle => 'Heraanvraag in afwachting';

  @override
  String get backfillReRequestTrigger => 'In te vullen';

  @override
  String get backfillResetUnresolvableDescription =>
      'Ingangen die gemarkeerd zijn als niet-oplosbare terugzetten naar ontbrekende gegevens, zodat ze opnieuw kunnen worden aangevraagd. Gebruik na herpopulatie van de volgordelog.';

  @override
  String get backfillResetUnresolvableProcessing => 'Herstellen...';

  @override
  String get backfillResetUnresolvableTitle => 'Onoplosbaar herstellen';

  @override
  String get backfillResetUnresolvableTrigger => 'Onoplosbare items herstellen';

  @override
  String get backfillRetireStuckConfirmAccept => 'Ga nu met pensioen.';

  @override
  String backfillRetireStuckConfirmContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Dit markeert $count momenteel-openen (ontbrekende of gevraagde) sequence-log ingangen als niet-oplosbaar. Gebruik dit om het watermerk te deblokkeren wanneer de ingangen een tijdje vastzitten zonder dat het 7-daagse amnestie venster is voorbijgegaan. Inzendingen kunnen nog steeds worden opgewekt als hun lading later op de schijf aankomt met een geldige vectorklok.',
      one:
          'Dit markeert 1 momenteel open (ontbrekende of gevraagde) sequence-log invoer als niet op te lossen. Gebruik dit om het watermerk te deblokkeren wanneer de ingangen zijn vastgezet voor een tijdje zonder de 7-daagse amnestie venster is voorbij. Inzendingen kunnen nog steeds worden opgewekt als hun lading later aankomt op de schijf met een geldige vector klok.',
    );
    return '$_temp0';
  }

  @override
  String get backfillRetireStuckConfirmTitle => 'Nu met pensioen?';

  @override
  String get backfillRetireStuckDescription =>
      'Dwing elke momenteel geopende of gevraagde reeks-log invoer tot onoplosbaar. Sla de 7-daagse amnestie ..gebruik alleen voor vastzittende rijen blokkeren van het watermerk.';

  @override
  String get backfillRetireStuckProcessing => 'Met pensioen...';

  @override
  String get backfillRetireStuckTitle => 'Geplakte items met pensioen';

  @override
  String backfillRetireStuckTrigger(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Met pensioen gaan $count vastgelopen items',
      one: 'Terugtrekken 1 vastgelopen ingang',
    );
    return '$_temp0';
  }

  @override
  String get backfillSettingsSubtitle => 'Sync gap recovery beheren';

  @override
  String get backfillSettingsTitle => 'Synchronisatie van backfill';

  @override
  String get backfillStatsBackfilled => 'Achterin gevuld';

  @override
  String get backfillStatsBurned => 'Verbrand';

  @override
  String get backfillStatsDeleted => 'Verwijderd';

  @override
  String get backfillStatsMissing => 'Ontbrekend';

  @override
  String get backfillStatsNoData => 'Geen synchronisatiegegevens beschikbaar';

  @override
  String get backfillStatsReceived => 'Ontvangen';

  @override
  String get backfillStatsRefresh => 'Statistieken vernieuwen';

  @override
  String get backfillStatsRequested => 'Verzoek';

  @override
  String get backfillStatsTitle => 'Synchronisatiestatistieken';

  @override
  String get backfillStatsTotalEntries => 'Totaal aantal vermeldingen';

  @override
  String get backfillStatsUnresolvable => 'Onoplosbaar';

  @override
  String get backfillStatusInboundQueue => 'Inkomende wachtrij';

  @override
  String get backfillStatusMissing => 'Ontbrekend';

  @override
  String get backfillStatusSkipped => 'Overgeslagen';

  @override
  String get backfillToggleDescription =>
      'Verzoek om ontbrekende gegevens van de laatste 24 uur.';

  @override
  String get backfillToggleTitle => 'Automatische backfill';

  @override
  String get basicSettings => 'Basisinstellingen';

  @override
  String get calendarHasPlanLabel => 'Heeft een plan';

  @override
  String get calendarTodayLabel => 'Vandaag';

  @override
  String get cancelButton => 'Annuleren';

  @override
  String get categoryActiveDescription =>
      'Inactieve categorieën zullen niet in selectielijsten verschijnen';

  @override
  String get categoryActiveSwitchDescription =>
      'Selecteerbaar voor nieuwe items';

  @override
  String get categoryAiDefaultsDescription =>
      'Standaard AI-profiel en agent-sjabloon instellen voor nieuwe taken in deze categorie';

  @override
  String get categoryAiDefaultsTitle => 'AI standaard';

  @override
  String get categoryCreationError =>
      'Aanmaken van categorie is mislukt. Probeer het opnieuw.';

  @override
  String get categoryDayPlanDescription =>
      'Maak deze categorie beschikbaar voor selectie in het dagplan';

  @override
  String get categoryDayPlanLabel => 'Dagplanning';

  @override
  String get categoryDefaultEventTemplateHint => 'Selecteer een sjabloon';

  @override
  String get categoryDefaultEventTemplateLabel =>
      'Standaard gebeurtenisagent-sjabloon';

  @override
  String get categoryDefaultLanguageDescription =>
      'Een standaardtaal instellen voor taken in deze categorie';

  @override
  String get categoryDefaultProfileHint => 'Selecteer een profiel';

  @override
  String get categoryDefaultTemplateHint => 'Selecteer een sjabloon';

  @override
  String get categoryDefaultTemplateLabel => 'Standaard agent template';

  @override
  String get categoryDeleteConfirm => 'Ja, delete deze CATEGORIE';

  @override
  String get categoryDeleteConfirmation =>
      'Deze actie kan niet ongedaan worden gemaakt. Alle items in deze categorie blijven behouden maar zullen niet langer worden gecategoriseerd.';

  @override
  String get categoryDeleteTitle => 'Categorie verwijderen?';

  @override
  String get categoryFavoriteBadgeLabel => 'Favoriet';

  @override
  String get categoryFavoriteDescription =>
      'Deze categorie markeren als favoriet';

  @override
  String get categoryIconChooseHint => 'Selecteer een pictogram';

  @override
  String get categoryIconCreateHint => 'Selecteer een pictogram';

  @override
  String get categoryIconEditHint => 'Selecteer een ander pictogram';

  @override
  String get categoryIconLabel => 'Pictogram';

  @override
  String get categoryIconPickerTitle => 'Pictogram kiezen';

  @override
  String get categoryNameRequired => 'Categorienaam is vereist';

  @override
  String get categoryNotFound => 'Categorie niet gevonden';

  @override
  String get categoryPrivateBadgeLabel => 'Privé';

  @override
  String get categoryPrivateDescription =>
      'Alleen zichtbaar wanneer privé-items getoond worden';

  @override
  String get categorySearchPlaceholder => 'Zoeken in categorieën...';

  @override
  String get changeSetCardTitle => 'Voorgestelde wijzigingen';

  @override
  String get changeSetConfirmAll => 'Alles bevestigen';

  @override
  String changeSetConfirmAllPartialIssues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count punten hadden gedeeltelijke problemen',
      one: '1 punt had gedeeltelijke problemen',
    );
    return '$_temp0';
  }

  @override
  String get changeSetConfirmError => 'Toepassen van wijziging is mislukt';

  @override
  String get changeSetItemConfirmed => 'Toegepaste wijziging';

  @override
  String changeSetItemConfirmedWithWarning(String warning) {
    return 'Toegepast met waarschuwing: $warning';
  }

  @override
  String get changeSetItemRejected => 'Wijziging verworpen';

  @override
  String changeSetPendingCount(int count) {
    return '$count in behandeling';
  }

  @override
  String get changeSetSwipeConfirm => 'Bevestigen';

  @override
  String get changeSetSwipeReject => 'Weigeren';

  @override
  String get chatInputCancelRealtime => 'Annuleren (Esc)';

  @override
  String get chatInputCancelRecording => 'Opname annuleren (Esc)';

  @override
  String get chatInputConfigureModel => 'Model instellen';

  @override
  String get chatInputHintDefault => 'Vraag naar uw taken en productiviteit...';

  @override
  String get chatInputHintSelectModel =>
      'Selecteer een model om te beginnen met chatten';

  @override
  String get chatInputListening => 'Luisteren...';

  @override
  String get chatInputPleaseWait => 'Wacht even...';

  @override
  String get chatInputProcessing => 'Bezig met verwerken...';

  @override
  String get chatInputRecordVoice => 'Voicemail opnemen';

  @override
  String get chatInputSendTooltip => 'Bericht versturen';

  @override
  String get chatInputStartRealtime => 'Live transcriptie starten';

  @override
  String get chatInputStopRealtime => 'Stop live transcriptie';

  @override
  String get chatInputStopTranscribe => 'Stoppen en transcriberen';

  @override
  String get checklistAddItem => 'Een nieuw item toevoegen';

  @override
  String checklistAiConfidenceLabel(String level) {
    return 'Vertrouwen: $level';
  }

  @override
  String get checklistAiMarkComplete => 'Markeren voltooid';

  @override
  String get checklistAiSuggestionBody => 'Deze post lijkt te zijn ingevuld:';

  @override
  String get checklistAiSuggestionTitle => 'AI Suggestie';

  @override
  String get checklistAllDone => 'Alle items klaar!';

  @override
  String get checklistCollapseTooltip => 'Inklappen';

  @override
  String checklistCompletedShort(int completed, int total) {
    return '$completed\'$total klaar';
  }

  @override
  String get checklistDelete => 'Checklist verwijderen?';

  @override
  String get checklistExpandTooltip => 'Uitvouwen';

  @override
  String get checklistExportAsMarkdown => 'Checklist exporteren als markdown';

  @override
  String get checklistExportFailed => 'Exporteren mislukt';

  @override
  String get checklistItemArchived => 'Gearchiveerd item';

  @override
  String get checklistItemArchiveUndo => 'Ongedaan maken';

  @override
  String get checklistItemDeleteCancel => 'Annuleren';

  @override
  String get checklistItemDeleteConfirm => 'Bevestigen';

  @override
  String get checklistItemDeleted => 'Item verwijderd';

  @override
  String get checklistItemDeleteWarning =>
      'Deze actie kan niet ongedaan worden gemaakt.';

  @override
  String get checklistMarkdownCopied => 'Checklist gekopieerd als Markdown';

  @override
  String get checklistMoreTooltip => 'Meer';

  @override
  String get checklistNoneDone => 'Nog geen voltooide items.';

  @override
  String get checklistNothingToExport => 'Geen items om uit te voeren';

  @override
  String get checklistProgressSemantics => 'Voortgang van de controlelijst';

  @override
  String get checklistShare => 'Delen';

  @override
  String get checklistShareHint => 'Lange pers om te delen';

  @override
  String get checklistsReorder => 'Herschikken';

  @override
  String get clearButton => 'Wissen';

  @override
  String get colorCustomLabel => 'Aangepast';

  @override
  String get colorLabel => 'Kleur';

  @override
  String get commandPaletteNoResults =>
      'Geen beschikbare commando\'s die overeenkomen met uw zoekopdracht';

  @override
  String get commandPaletteSearchHint => 'Zoeken op commando\'s...';

  @override
  String get commandPaletteTitle => 'Opdrachtpalet';

  @override
  String get commonError => 'Fout';

  @override
  String get commonLoading => 'Laden...';

  @override
  String get commonUnknown => 'Onbekend';

  @override
  String get completeHabitFailButton => 'Gemiste';

  @override
  String get completeHabitSkipButton => 'Overslaan';

  @override
  String get completeHabitSuccessButton => 'Succes';

  @override
  String get configFlagAttemptEmbeddingDescription =>
      'Wanneer ingeschakeld zal de app proberen om inbeddingen te genereren voor uw inzendingen om zoekopdrachten en gerelateerde inhoudsuggesties te verbeteren.';

  @override
  String get configFlagDailyOsOnboardingEnabled =>
      'Dagelijkse doorloop van het besturingssysteem';

  @override
  String get configFlagDailyOsOnboardingEnabledDescription =>
      'Begeleid de eerste keer Dagelijkse OS gebruikers door een echte check-in die spraak verandert in een taak en een dagplan.';

  @override
  String get configFlagEnableAiStreaming =>
      'AI-streaming inschakelen voor taakacties';

  @override
  String get configFlagEnableAiStreamingDescription =>
      'Stream AI-responsen voor taakgerelateerde acties. Schakel de bufferresponsen uit en houd de UI soepeler.';

  @override
  String get configFlagEnableAiSummaryTts => 'AI samenvatting afspelen';

  @override
  String get configFlagEnableAiSummaryTtsDescription =>
      'Toon de lokale tekst-naar-spraak-knop op taak AI samenvattingen. Vereist een geïnstalleerd MLX Audio TTS model.';

  @override
  String get configFlagEnableDashboardsPage => 'Dashboards-pagina inschakelen';

  @override
  String get configFlagEnableDashboardsPageDescription =>
      'Toon de Dashboards pagina in de hoofdnavigatie. Bekijk uw gegevens en inzichten in aanpasbare dashboards.';

  @override
  String get configFlagEnableEmbeddings => 'Inbeddingen genereren';

  @override
  String get configFlagEnableEvents => 'Gebeurtenissen inschakelen';

  @override
  String get configFlagEnableEventsDescription =>
      'Toon de functie Evenementen om gebeurtenissen aan te maken, te volgen en te beheren in uw journal.';

  @override
  String get configFlagEnableForkHealing => 'Agent vork genezing';

  @override
  String get configFlagEnableForkHealingDescription =>
      'Genees uiteenlopende agent geschiedenissen van multi-apparaat gebruik door ze samen te voegen bij de volgende wake.';

  @override
  String get configFlagEnableHabitsPage => 'Gewoontespagina inschakelen';

  @override
  String get configFlagEnableHabitsPageDescription =>
      'Toon de Habits pagina in de hoofdnavigatie. Volg en beheer uw dagelijkse gewoonten hier.';

  @override
  String get configFlagEnableLogging => 'Loggen inschakelen';

  @override
  String get configFlagEnableLoggingDescription =>
      'Schakel gedetailleerde logging in voor debugdoeleinden. Dit kan de prestaties beïnvloeden.';

  @override
  String get configFlagEnableMatrix => 'Matrix-synchronisatie inschakelen';

  @override
  String get configFlagEnableMatrixDescription =>
      'Schakel de integratie van Matrix in om uw items te synchroniseren tussen apparaten en met andere Matrix-gebruikers.';

  @override
  String get configFlagEnableNotifications =>
      'Notificatieberichten inschakelen?';

  @override
  String get configFlagEnableNotificationsDescription =>
      'Ontvang meldingen voor herinneringen, updates en belangrijke gebeurtenissen.';

  @override
  String get configFlagEnableProjects => 'Projecten inschakelen';

  @override
  String get configFlagEnableProjectsDescription =>
      'Functies voor projectbeheer tonen voor het organiseren van taken in projecten.';

  @override
  String get configFlagEnableSessionRatings =>
      'Sessie-waarderingen inschakelen';

  @override
  String get configFlagEnableSessionRatingsDescription =>
      'Vraag om een snelle sessie rating wanneer u een timer stopt.';

  @override
  String get configFlagEnableTooltip => 'Hulpballonnen inschakelen';

  @override
  String get configFlagEnableTooltipDescription =>
      'Toon handige tooltips in de hele app om u door functies te leiden.';

  @override
  String get configFlagEnableVectorSearch => 'Zoekopdracht voor vector';

  @override
  String get configFlagEnableVectorSearchDescription =>
      'Activeer vector zoeken in taakfilters. Vereist inbeddingen ingeschakeld te zijn en Ollama draait.';

  @override
  String get configFlagEnableWhatsNew => 'Toon wat nieuw is';

  @override
  String get configFlagEnableWhatsNewDescription =>
      'Nieuwe functies en wijzigingen in de instellingenboom markeren.';

  @override
  String get configFlagPrivate => 'Privé-items tonen?';

  @override
  String get configFlagPrivateDescription =>
      'Schakel dit in om uw inzendingen standaard privé te maken. Privé-items zijn alleen zichtbaar voor u.';

  @override
  String get configFlagRecordLocation => 'Location van het record';

  @override
  String get configFlagRecordLocationDescription =>
      'Automatisch uw locatie registreren met nieuwe items. Dit helpt bij locatie-gebaseerde organisatie en zoeken.';

  @override
  String get configFlagResendAttachments => 'Bijlages opnieuw versturen';

  @override
  String get configFlagResendAttachmentsDescription =>
      'Schakel dit in om mislukte bijlageuploads automatisch opnieuw te verzenden wanneer de verbinding hersteld is.';

  @override
  String get configFlagShowSyncActivityIndicator =>
      'Sync-activiteitsindicator tonen';

  @override
  String get configFlagShowSyncActivityIndicatorDescription =>
      'Een status van rustige synchronisatie tonen in de zijbalk; wachtrijtellingen verschijnen alleen terwijl het werk nog in behandeling is.';

  @override
  String get conflictApplyButton => 'Toepassen';

  @override
  String get conflictApplyFailedTitle => 'Kon resolutie niet toepassen';

  @override
  String conflictBannerAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dagen geleden',
      one: '1 dag geleden',
    );
    return '$_temp0';
  }

  @override
  String conflictBannerAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count h geleden',
      one: '1 uur geleden',
    );
    return '$_temp0';
  }

  @override
  String get conflictBannerAgoJustNow => 'Nu net.';

  @override
  String conflictBannerAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min geleden',
      one: '1 min geleden',
    );
    return '$_temp0';
  }

  @override
  String conflictBannerDivergedAgo(String entity, String ago) {
    return '$entity · diversified $ago';
  }

  @override
  String conflictBannerFieldsDifferList(String fields) {
    return 'Verschil in: $fields';
  }

  @override
  String get conflictCombineApply => 'Samen toepassen';

  @override
  String get conflictCombineStartFrom => 'Beginnen vanaf';

  @override
  String get conflictConfirmDeletion => 'Verwijdering bevestigen';

  @override
  String get conflictDeleteVsEditDescription =>
      'Dit item is op het ene apparaat bewerkt en op het andere verwijderd. Er wordt niets verwijderd totdat u hebt gekozen.';

  @override
  String get conflictDeleteVsEditTitle => 'Verwijderd op één apparaat';

  @override
  String get conflictDetailEntryNotFoundTitle => 'Niet gevonden';

  @override
  String get conflictDetailLoadErrorTitle => 'Kon conflict niet laden';

  @override
  String get conflictDetailNotFoundTitle => 'Conflict niet gevonden';

  @override
  String get conflictDiffRecommended => 'Aanbevolen';

  @override
  String conflictDiffUnchanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count velden ongewijzigd',
      one: '1 veld ongewijzigd',
    );
    return '$_temp0';
  }

  @override
  String get conflictFieldBody => 'Lichaam';

  @override
  String get conflictFieldCategory => 'Categorie';

  @override
  String get conflictFieldDuration => 'Duur';

  @override
  String get conflictFieldEnd => 'Einde';

  @override
  String get conflictFieldFlag => 'Vlag';

  @override
  String get conflictFieldOther => 'Overige details';

  @override
  String get conflictFieldOtherDescription =>
      'Deze versies verschillen in details die hier niet afzonderlijk worden weergegeven.';

  @override
  String get conflictFieldPrivate => 'Privé';

  @override
  String get conflictFieldStarred => 'Sterren';

  @override
  String get conflictFieldStart => 'Begin';

  @override
  String get conflictFieldTitle => 'Titel';

  @override
  String get conflictFieldWordCount => 'aantal woorden';

  @override
  String get conflictFlagFollowUp => 'Follow-up nodig';

  @override
  String get conflictFlagImport => 'Geïmporteerd';

  @override
  String get conflictFlagNone => 'Geen';

  @override
  String get conflictFooterHelperLocalSelected =>
      'Houdt uw lokale bewerking en gooit de gesynchroniseerde versie weg.';

  @override
  String get conflictFooterHelperPickASide => 'Kies een kant om aan te passen.';

  @override
  String get conflictFooterHelperRemoteSelected =>
      'Zal de gesynchroniseerde versie accepteren en uw lokale bewerking verwerpen.';

  @override
  String conflictHeaderPillEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 vermelding',
    );
    return '$_temp0';
  }

  @override
  String conflictHeaderPillFieldsDiffer(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count velden verschillen',
      one: '1 veld verschilt',
    );
    return '$_temp0';
  }

  @override
  String get conflictKeepEdited => 'De bewerkte versie behouden';

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
    return 'Conflict-ID: $id';
  }

  @override
  String get conflictMetaLocalEdit => 'lokale bewerking';

  @override
  String get conflictMetaVecPrefix => 'vec';

  @override
  String get conflictMetaViaSync => 'via synchroniseren';

  @override
  String conflictNotificationBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items werden bewerkt op twee apparaten',
      one: '1 ingang werd bewerkt op twee apparaten',
    );
    return '$_temp0';
  }

  @override
  String get conflictNotificationTitle => 'Synchroniseren moet je beoordelen';

  @override
  String get conflictPageLeadDesktop =>
      'Verschillen in lijn gemarkeerd. Klik op een kant om die versie te gebruiken, of open Bewerken & samenvoegen om ze te combineren.';

  @override
  String get conflictPageLeadMobile =>
      'Verschillen in lijn gemarkeerd. Tik op een kant om die versie te gebruiken.';

  @override
  String get conflictPageTitle => 'Conflict synchroniseren';

  @override
  String get conflictPickerCombine => 'Combineer...';

  @override
  String get conflictPickerEditMerge => 'Bewerken & samenvoegen...';

  @override
  String get conflictPickerUseFromSync => 'Gebruik vanuit synchronisatie';

  @override
  String get conflictPickerUseThisDevice => 'Gebruik dit apparaat';

  @override
  String get conflictResolvedToast => 'Conflict opgelost';

  @override
  String get conflictsEmptyDescription =>
      'Alles is nu in sync. Opgelost items blijven beschikbaar in de andere filter.';

  @override
  String get conflictsEmptyTitle => 'Geen conflicten gevonden';

  @override
  String get conflictSideFromSync => 'VAN SYNC';

  @override
  String get conflictSideThisDevice => 'DIT DOEL';

  @override
  String get conflictsResolved => 'opgelost';

  @override
  String get conflictsUnresolved => 'onopgelost';

  @override
  String get conflictValueAbsent => 'Niet ingesteld';

  @override
  String get conflictValueNo => 'Nee';

  @override
  String get conflictValueYes => 'Ja.';

  @override
  String conflictWordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count woorden',
      one: '$count Woord',
    );
    return '$_temp0';
  }

  @override
  String get copyAsMarkdown => 'Kopiëren als markdown';

  @override
  String get copyAsText => 'Als tekst kopiëren';

  @override
  String get correctionExampleCancel => 'AFWIJKEN';

  @override
  String correctionExamplePending(int seconds) {
    return 'Correctie opslaan in ${seconds}S...';
  }

  @override
  String get correctionExamplesEmpty =>
      'Nog geen correcties vastgelegd. Bewerk een checklist-item om uw eerste voorbeeld toe te voegen.';

  @override
  String get correctionExamplesSectionDescription =>
      'Wanneer u handmatig checklist items corrigeert, worden deze correcties hier opgeslagen en gebruikt om AI suggesties te verbeteren.';

  @override
  String get correctionExamplesSectionTitle =>
      'Voorbeelden van correctie van de Checklist';

  @override
  String correctionExamplesWarning(int count, int max) {
    return 'Dat heb je. $count correcties. Alleen de meest recente $max zal worden gebruikt in AI-prompts. Overweeg het verwijderen van oude of redundante voorbeelden.';
  }

  @override
  String get coverArtChipActive => 'Omhulsel';

  @override
  String get coverArtChipSet => 'Dekking instellen';

  @override
  String get coverArtGenerationComplete => 'Dek de kunst klaar!';

  @override
  String get coverArtGenerationDismissHint =>
      'U kunt deze .. generatie blijft op de achtergrond';

  @override
  String get createButton => 'Aanmaken';

  @override
  String get createCategoryTitle => 'Categorie aanmaken';

  @override
  String get createEntryLabel => 'Nieuwe item aanmaken';

  @override
  String get createEntryTitle => 'Toevoegen';

  @override
  String get createNewLinkedTask => 'Nieuwe verbonden taak aanmaken...';

  @override
  String get customColor => 'Aangepaste kleur';

  @override
  String get dailyOsDayPlan => 'Dagplan';

  @override
  String get dailyOsNextAgendaCapacityComfortable => 'Comfortabel';

  @override
  String get dailyOsNextAgendaCapacityNearFull => 'Bijna vol';

  @override
  String get dailyOsNextAgendaCapacityNoPlan => 'Nog geen plan';

  @override
  String dailyOsNextAgendaCapacityOf(String capacity) {
    return 'van $capacity';
  }

  @override
  String get dailyOsNextAgendaCapacityOver => 'Overcapaciteit';

  @override
  String get dailyOsNextAgendaDonutLeft => 'links';

  @override
  String get dailyOsNextAgendaDonutOver => 'over';

  @override
  String dailyOsNextAgendaHeadlineLeft(String duration) {
    return '$duration links';
  }

  @override
  String dailyOsNextAgendaHeadlineOver(String duration) {
    return '$duration over';
  }

  @override
  String get dailyOsNextAgendaNoPlanBody =>
      'Je getraceerde tijd is hier, hoe dan ook. Spreek een check-in en ik zal er een dag omheen opstellen.';

  @override
  String dailyOsNextAgendaNoPlanSummary(String duration) {
    return '$duration Spreek een check-in en ik zal er een dag omheen tekenen.';
  }

  @override
  String get dailyOsNextAgendaNoPlanTitle => 'Nog geen plan voor vandaag.';

  @override
  String get dailyOsNextAgendaStateDone => 'Klaar';

  @override
  String get dailyOsNextAgendaStateInProgress => 'In behandeling';

  @override
  String get dailyOsNextAgendaStateOpen => 'Openen';

  @override
  String get dailyOsNextAgendaStateOverdue => 'Te laat';

  @override
  String dailyOsNextAgendaSummary(String scheduled, String capacity) {
    return '$scheduled van $capacity vastgelegd';
  }

  @override
  String dailyOsNextAgendaTrackedLegend(String duration, int completedCount) {
    return 'Getraceerd · $duration · $completedCount klaar';
  }

  @override
  String get dailyOsNextBlockEditCategoryLabel => 'Categorie';

  @override
  String get dailyOsNextBlockEditFailed =>
      'Kon het blok niet bijwerken . Probeer het opnieuw.';

  @override
  String get dailyOsNextBlockEditNameLabel => 'Titel';

  @override
  String get dailyOsNextBlockEditOpenTask => 'Open taak';

  @override
  String get dailyOsNextBlockEditSave => 'Wijzigingen opslaan';

  @override
  String get dailyOsNextBlockEditSaved => 'Schema bijgewerkt.';

  @override
  String get dailyOsNextBlockEditTimeLabel => '& Einde starten';

  @override
  String get dailyOsNextBlockEditTitle => 'Blok bewerken';

  @override
  String get dailyOsNextBlockEditTooltip => 'Blok bewerken';

  @override
  String get dailyOsNextBlockEditWhyLabel => 'Waarom deze keer?';

  @override
  String get dailyOsNextBlockMoveTooltip => 'Blok verplaatsen';

  @override
  String get dailyOsNextBlockResizeEndTooltip => 'Einde aanpassen';

  @override
  String get dailyOsNextBlockResizeStartTooltip => 'Start aanpassen';

  @override
  String get dailyOsNextCaptureCaptured => 'Begrepen.';

  @override
  String get dailyOsNextCaptureDoneCta => 'Klaar';

  @override
  String get dailyOsNextCaptureErrorMicrophonePermissionDenied =>
      'Microfoon toestemming werd geweigerd.';

  @override
  String get dailyOsNextCaptureErrorNoActiveRealtimeSession =>
      'Geen actieve real-time sessie.';

  @override
  String get dailyOsNextCaptureErrorNoAudioRecorded =>
      'Er is geen audio opgenomen.';

  @override
  String get dailyOsNextCaptureErrorRealtimeTranscriptionFailed =>
      'Realtime transcriptie mislukt.';

  @override
  String get dailyOsNextCaptureErrorRealtimeTranscriptionStartFailed =>
      'Realtime transcriptie kon niet starten.';

  @override
  String get dailyOsNextCaptureErrorRecordingStartFailed =>
      'Opname kon niet beginnen.';

  @override
  String get dailyOsNextCaptureErrorTranscriptionFailed =>
      'De transcriptie is mislukt.';

  @override
  String get dailyOsNextCaptureHeadlineCaptured => 'Ziet dit er goed uit?';

  @override
  String get dailyOsNextCaptureHeadlineLead => 'Wat is er aan de hand?';

  @override
  String get dailyOsNextCaptureHeadlineListening => 'Ik luister.';

  @override
  String get dailyOsNextCaptureHeadlineTail => 'Voor vandaag?';

  @override
  String dailyOsNextCaptureHeadlineTailForDate(String date) {
    return 'voor $date?';
  }

  @override
  String get dailyOsNextCaptureHeadlineTailTomorrow => 'Voor morgen?';

  @override
  String get dailyOsNextCaptureHeadlineTailYesterday => 'Voor gisteren?';

  @override
  String get dailyOsNextCaptureHeadlineTranscribing => 'Dat opschrijven...';

  @override
  String get dailyOsNextCaptureIdleClick => 'Klik om te praten';

  @override
  String get dailyOsNextCaptureIdleExample =>
      '..diep werk vanmorgen, een wandeling na de lunch, e-mails voor vijf.';

  @override
  String get dailyOsNextCaptureIdleHint =>
      'Tik op om te praten · type in plaats daarvan';

  @override
  String get dailyOsNextCaptureIdleTalk => 'Tik op om te praten';

  @override
  String get dailyOsNextCaptureListeningStatus => 'Luisteren...';

  @override
  String dailyOsNextCapturePastPrompt(String date) {
    return 'Alles wat je nog wilt volgen van $date?';
  }

  @override
  String get dailyOsNextCaptureReconcileCta => 'Evaluatie';

  @override
  String get dailyOsNextCapturesPanelTitle => 'Opnames';

  @override
  String get dailyOsNextCaptureTranscribing => 'Afschrijven...';

  @override
  String get dailyOsNextCaptureTranscriptHint =>
      'Maak alles goed wat het transcript fout deed voordat het gepland werd.';

  @override
  String get dailyOsNextCaptureTranscriptLabel => 'Beoordeling transcript';

  @override
  String get dailyOsNextCaptureTypeInstead => 'Type in plaats daarvan';

  @override
  String get dailyOsNextCaptureVoiceButtonReset => 'Overnieuw beginnen';

  @override
  String get dailyOsNextCaptureVoiceButtonStart => 'Begin met luisteren';

  @override
  String get dailyOsNextCaptureVoiceButtonStop => 'Stop met luisteren.';

  @override
  String get dailyOsNextCategoryFilterAll => 'Alle categorieën';

  @override
  String get dailyOsNextCategoryFilterDescription =>
      'Alleen categorieën die zijn ingeschakeld voor dagplanning worden gearriveerd voor Daily OS geautomatiseerde verwerking.';

  @override
  String get dailyOsNextCategoryFilterEmpty =>
      'Nog geen categorieën voor dagplanning.';

  @override
  String get dailyOsNextCategoryFilterIncludeAll => 'Alles opnemen';

  @override
  String get dailyOsNextCategoryFilterTitle => 'Verwerkingscategorieën';

  @override
  String get dailyOsNextCategoryFilterTooltip =>
      'Kies Dagelijkse OS-verwerkingscategorieën';

  @override
  String dailyOsNextCommitCapacityNote(String scheduled, String capacity) {
    return '$scheduled van $capacity Comfortabele marge . U kunt een verrassing absorberen.';
  }

  @override
  String get dailyOsNextCommitDraftOverline => 'UW DAG, GEPROBICEERD';

  @override
  String get dailyOsNextCommitExplainer =>
      'Teken af om vandaag van ontwerp naar committed te gaan.';

  @override
  String get dailyOsNextCommitFinalStepEyebrow => 'SLOTSTEL';

  @override
  String get dailyOsNextCommitHeadline => 'Maak er jouw kans van.';

  @override
  String get dailyOsNextCommitHoldHelper => 'Wacht even om af te tekenen.';

  @override
  String get dailyOsNextCommitHoldWordDone => 'Vastgelegd';

  @override
  String get dailyOsNextCommitHoldWordHolding => 'Blijf houden';

  @override
  String get dailyOsNextCommitHoldWordIdle => 'Wacht.';

  @override
  String get dailyOsNextCommitLockingIn => 'Ik sluit me aan...';

  @override
  String get dailyOsNextCommitShepherdSubline =>
      'Ik zal het herderen, jij doet het werk.';

  @override
  String get dailyOsNextCommitSubCaption =>
      'Je kunt nog steeds met me praten, maar de botten blijven zitten.';

  @override
  String get dailyOsNextCommitTitle => 'Sluit het op.';

  @override
  String get dailyOsNextCommitTodayIsYours => 'Vandaag is het van jou.';

  @override
  String get dailyOsNextDayBack => 'Terug';

  @override
  String get dailyOsNextDayCheckInCta => 'Spreek een check-in';

  @override
  String get dailyOsNextDayDeleteDialogBody =>
      'De opgestelde blokken voor deze dag zullen worden verwijderd. Opnames en hun audio opnames blijven in uw dagboek.';

  @override
  String get dailyOsNextDayDeleteDialogCancel => 'Annuleren';

  @override
  String get dailyOsNextDayDeleteDialogConfirm => 'Verwijderen';

  @override
  String get dailyOsNextDayDeleteDialogTitle => 'Dit plan verwijderen?';

  @override
  String get dailyOsNextDayLockInCta => 'Insluiten';

  @override
  String get dailyOsNextDayMenuDeletePlan => 'Plan verwijderen';

  @override
  String get dailyOsNextDayMenuInspectAgent => 'Inspecteur';

  @override
  String get dailyOsNextDayMenuSettings => 'Dagelijkse OS-instellingen';

  @override
  String get dailyOsNextDayMoreTooltip => 'Meer';

  @override
  String get dailyOsNextDayRefineCta => 'Verfijnen';

  @override
  String get dailyOsNextDayRefineFooterHint =>
      'Praat met het plan te wijzigen . . Je zult elke verandering te zien voordat er iets wordt opgeslagen.';

  @override
  String get dailyOsNextDayTitle => 'Jouw dag';

  @override
  String get dailyOsNextDayWhyChipLabel => 'WAAROM';

  @override
  String get dailyOsNextDayWrapUpCta => 'Afsluiten';

  @override
  String get dailyOsNextDraftingBackToDecisions => 'Terug naar de beslissingen';

  @override
  String get dailyOsNextDraftingHeader => 'Je dag opstellen...';

  @override
  String get dailyOsNextDraftingNudgeAccept => 'Ja, bescherm de ochtenden.';

  @override
  String get dailyOsNextDraftingNudgeDecline => 'Vandaag niet.';

  @override
  String get dailyOsNextDraftingProgressBlocks => 'Tekenblokken';

  @override
  String get dailyOsNextDraftingProgressMatching => 'Afstemming van taken';

  @override
  String get dailyOsNextDraftingProgressQueued => 'In wachtrij';

  @override
  String get dailyOsNextDraftingProgressReading => 'Inchecken bij lezen';

  @override
  String get dailyOsNextDraftingProgressSaving => 'Opslaan van plan';

  @override
  String get dailyOsNextDraftingProgressValidating => 'Valideren';

  @override
  String get dailyOsNextDraftingReasoningOverline =>
      '• De reden waarom ik het niet weet.';

  @override
  String get dailyOsNextDraftingRecoveryBody =>
      'De wake heeft geen plan gemaakt. Probeer het opnieuw, of ga terug en pas de beslissingen voor het opstellen.';

  @override
  String get dailyOsNextDraftingRecoveryTitle => 'Opstellen is vertraagd';

  @override
  String get dailyOsNextDraftingRetry => 'Probeer het opnieuw';

  @override
  String get dailyOsNextDraftingStatusAfternoon => 'De namiddag...';

  @override
  String get dailyOsNextDraftingStatusAlmost => 'Bijna...';

  @override
  String get dailyOsNextDraftingStatusBreathing =>
      'Ruimte verlaten om te ademen...';

  @override
  String get dailyOsNextDraftingStatusDeepWork => 'Eerst diep werk plaatsen...';

  @override
  String get dailyOsNextDraftingStatusMatching =>
      'Taken aanpassen aan jouw dag...';

  @override
  String get dailyOsNextDraftingStatusReading => 'Je check-in lezen...';

  @override
  String get dailyOsNextDraftingStatusTimings =>
      'Dubbele controle van de timings...';

  @override
  String get dailyOsNextDraftingStatusYesterday =>
      'Kijkend naar het ritme van gisteren...';

  @override
  String get dailyOsNextEditTitleHint => 'Titel bewerken';

  @override
  String get dailyOsNextGenericError => 'Er is iets misgegaan.';

  @override
  String get dailyOsNextGreetingAfternoon => 'Goedemiddag.';

  @override
  String get dailyOsNextGreetingEvening => 'Goedenavond.';

  @override
  String dailyOsNextGreetingHiName(String name) {
    return 'Hoi. $name  👋';
  }

  @override
  String get dailyOsNextGreetingMorning => 'Goedemorgen.';

  @override
  String get dailyOsNextKnowledgeConfirm => 'Bevestigen';

  @override
  String get dailyOsNextKnowledgeConfirmedHeader => 'Bevestigd';

  @override
  String get dailyOsNextKnowledgeEdit => 'Bewerken';

  @override
  String get dailyOsNextKnowledgeEditCancel => 'Annuleren';

  @override
  String get dailyOsNextKnowledgeEditHookHint => 'Overzicht met één regel';

  @override
  String get dailyOsNextKnowledgeEditSave => 'Opslaan';

  @override
  String get dailyOsNextKnowledgeEditStatementHint =>
      'Wat moet ik me herinneren?';

  @override
  String get dailyOsNextKnowledgeEmpty =>
      'Nog niets. Ik zal onthouden wat je me vertelt.';

  @override
  String dailyOsNextKnowledgeNudge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dingen die ik merkte .. beoordeling',
      one: '1 ding dat ik merkte .. beoordeling',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextKnowledgeProposedHeader => 'Wacht op uw bevestiging.';

  @override
  String get dailyOsNextKnowledgeRetract => 'Vergeet';

  @override
  String get dailyOsNextKnowledgeStale => 'Nog steeds waar?';

  @override
  String get dailyOsNextKnowledgeTitle => 'Wat ik geleerd heb.';

  @override
  String get dailyOsNextParsedCardBreakLinkTooltip => 'Verwijzing verbreken';

  @override
  String get dailyOsNextPlanViewAgenda => 'Agenda';

  @override
  String get dailyOsNextPlanViewDay => 'Dag';

  @override
  String get dailyOsNextReconcileBadgeMatched => 'VERZAMELD';

  @override
  String get dailyOsNextReconcileBadgeNew => 'NIEUW';

  @override
  String get dailyOsNextReconcileBadgeUpdate => 'BIJWERKEN';

  @override
  String get dailyOsNextReconcileBuildDayCta => 'Bouw mijn dag';

  @override
  String get dailyOsNextReconcileDecideOverline => 'WORth DECIDING OP';

  @override
  String dailyOsNextReconcileDecisionProgress(int decided, int total) {
    return '$decided van $total herzien';
  }

  @override
  String get dailyOsNextReconcileDefaultBehaviorHint =>
      'Bekijk de kaarten voordat u uw dag bouwt. Uitverkoren acties voeden zich met het plan; kaarten alleen blijven zoals ze zijn.';

  @override
  String dailyOsNextReconcileError(String detail) {
    return 'Er ging iets mis. $detail';
  }

  @override
  String get dailyOsNextReconcileHeadline => 'Hier is wat ik gehoord heb.';

  @override
  String get dailyOsNextReconcileHeardEmpty =>
      'Hier verschijnen de opnamekaarten zodra ze zijn ontleden.';

  @override
  String get dailyOsNextReconcileHeardOverline => 'HOOR';

  @override
  String get dailyOsNextReconcileLowConfidence => 'laag vertrouwen';

  @override
  String get dailyOsNextReconcileProcessing =>
      'Terug luisteren en je dag aanpassen...';

  @override
  String get dailyOsNextReconcileReRecord => 'Heropname';

  @override
  String get dailyOsNextReconcileVoiceHint =>
      'Beoordelen besluiten voordat u uw dag bouwt';

  @override
  String get dailyOsNextRefineAccept => 'Accepteren';

  @override
  String get dailyOsNextRefineCurrentPlan => 'LOPEND PLAN';

  @override
  String get dailyOsNextRefineDiffAdded => 'TOEGEVOEGD';

  @override
  String get dailyOsNextRefineDiffDropped => 'GEDROP';

  @override
  String get dailyOsNextRefineDiffMoved => 'VERMOVEERD';

  @override
  String get dailyOsNextRefineHeadlineDiffReady =>
      'Hier is wat ik zou veranderen.';

  @override
  String get dailyOsNextRefineHeadlineIdle => 'Wat moet er veranderen?';

  @override
  String get dailyOsNextRefineHeadlineThinking => 'Je plan herwerkt...';

  @override
  String get dailyOsNextRefineKeepTalking => 'Blijf praten.';

  @override
  String get dailyOsNextRefineLooksGood => 'Ziet er goed uit.';

  @override
  String get dailyOsNextRefineNoChanges =>
      'Geen planwijzigingen kwamen terug, herword het en probeer het opnieuw.';

  @override
  String get dailyOsNextRefineOverline => '• HERFINANCIERING';

  @override
  String get dailyOsNextRefineRevert => 'Terugdraaien';

  @override
  String get dailyOsNextRefineStatusAccepted => 'Opgesloten.';

  @override
  String get dailyOsNextRefineStatusDiffReady => 'Dit is veranderd.';

  @override
  String get dailyOsNextRefineStatusIdle => 'Tik op praten.';

  @override
  String get dailyOsNextRefineStatusListening => 'Luisteren...';

  @override
  String get dailyOsNextRefineStatusThinking => '.. Herwerken van het plan...';

  @override
  String get dailyOsNextRefineTitle => 'Het plan verfijnen';

  @override
  String get dailyOsNextRenameFailed => 'Kon de naam van';

  @override
  String get dailyOsNextReviewAddBuffer => 'Buffer toevoegen';

  @override
  String get dailyOsNextReviewAddBufferPrompt =>
      'Voeg een realistische buffer toe tussen de geplande blokken, vooral rond overgangen en na veeleisend werk.';

  @override
  String get dailyOsNextReviewAdjust => 'Aanpassen';

  @override
  String get dailyOsNextReviewLooksGood => 'Ziet er goed uit.';

  @override
  String get dailyOsNextReviewMoveLighter => 'Aansteker verplaatsen';

  @override
  String get dailyOsNextReviewMoveLighterPrompt =>
      'Beweeg het lichtere of minder energie werk later, en houd het sterkste focusvenster voor de meest veeleisende taak.';

  @override
  String get dailyOsNextReviewTooMuch => 'Te veel.';

  @override
  String get dailyOsNextReviewTooMuchPrompt =>
      'Dit plan is te veel voor vandaag. Verminder de lading, bescherm ademruimte, en houd alleen de belangrijkste blokken.';

  @override
  String get dailyOsNextReviewWhyTitle => 'Waarom zijn ze in de buurt gekomen?';

  @override
  String get dailyOsNextShutdownCarryoverDrop => 'Laat vallen';

  @override
  String get dailyOsNextShutdownCarryoverDropped => 'Gedropt';

  @override
  String get dailyOsNextShutdownCarryoverOverline => 'RIJDEN VOORUIT';

  @override
  String get dailyOsNextShutdownCarryoverPickDate => 'Kies een datum';

  @override
  String get dailyOsNextShutdownCarryoverScheduled => 'Gepland';

  @override
  String get dailyOsNextShutdownCloseDay => 'Sluit de dag';

  @override
  String get dailyOsNextShutdownCompletedOverline => 'Wat je deed.';

  @override
  String get dailyOsNextShutdownMetricEnergy => 'ENERGIE';

  @override
  String dailyOsNextShutdownMetricEnergyDelta(String delta) {
    return '$delta vs. week';
  }

  @override
  String get dailyOsNextShutdownMetricFlow => 'ZESTIES VAN DE BLOEM';

  @override
  String get dailyOsNextShutdownMetricFocus => 'FOCUS TIJD';

  @override
  String get dailyOsNextShutdownMetricSwitches => 'CONTEXT-SWITS';

  @override
  String dailyOsNextShutdownMetricSwitchesAvg(String avg) {
    return 'avg $avg deze week';
  }

  @override
  String get dailyOsNextShutdownReflectionOverline => 'ÉÉN LIJNE VERVORMING';

  @override
  String get dailyOsNextShutdownReflectionPlaceholder =>
      'Bijvoorbeeld, de ochtend was scherp, de middag gesleept na de koffie met Sarah duurde lang.';

  @override
  String get dailyOsNextShutdownReflectionPrompt =>
      'Hoe is vandaag geland? (Dit voedt de tocht van morgen.)';

  @override
  String get dailyOsNextShutdownReflectionSpeak => 'Zeg het.';

  @override
  String get dailyOsNextShutdownReflectionSubmit => 'Overslaan';

  @override
  String get dailyOsNextShutdownReflectionThanks => 'Ik heb het morgen.';

  @override
  String get dailyOsNextShutdownSaveAndClose => '& Sluiten opslaan';

  @override
  String get dailyOsNextShutdownTitle => 'Sluit de dag af';

  @override
  String get dailyOsNextShutdownTomorrowOverline => '✦ FOR TOMORROW';

  @override
  String dailyOsNextStateDueOnDate(String date) {
    return 'Verloopdatum $date';
  }

  @override
  String get dailyOsNextStateDueToday => 'Vervalt vandaag';

  @override
  String dailyOsNextStateInProgress(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In uitvoering $count sessies',
      one: 'Aan de gang · 1 zitting',
      zero: 'In behandeling',
    );
    return '$_temp0';
  }

  @override
  String dailyOsNextStateOverdue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dagen te laat',
      one: '1 dag te laat',
      zero: 'Te laat',
    );
    return '$_temp0';
  }

  @override
  String dailyOsNextStateOverdueOnDate(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Vervallen door $days dagen $date',
      one: 'Overschrijding met 1 dag $date',
      zero: 'Overschrijding van de termijn $date',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextStateRecurringMissed => 'Terugkerend · gemist';

  @override
  String get dailyOsNextTimelineActual => 'Werkelijk';

  @override
  String get dailyOsNextTimelineArrange => 'Blokjes ordenen';

  @override
  String get dailyOsNextTimelineBoth => 'Plan en werkelijke';

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
    return 'Directoraat $index van $total';
  }

  @override
  String get dailyOsNextTimelineShowBoth => 'Plan en werkelijke samen tonen';

  @override
  String get dailyOsNextTimelineShowPaged =>
      'Bewegingsbaar plan en werkelijke tonen';

  @override
  String get dailyOsNextTimelineSwipeHint =>
      'Veeg voor werkelijke · knijp verticaal naar zoom';

  @override
  String get dailyOsNextTimelineTracked => 'traced';

  @override
  String dailyOsNextTimeSpentEarlierSessions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eerdere sessies',
      one: '1 vorige zitting',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextTimeSpentShowLess => 'Minder tonen';

  @override
  String dailyOsNextTimeSpentSummary(String duration, int completedCount) {
    return '$duration · $completedCount klaar';
  }

  @override
  String get dailyOsNextTimeSpentTitle => 'Vandaag zo ver';

  @override
  String get dailyOsNextTimeSpentTitlePast => 'TERMIJN';

  @override
  String get dailyOsNextTriageConfirmDefer => 'Afgeleid';

  @override
  String get dailyOsNextTriageConfirmDone => 'Gemarkeerd';

  @override
  String get dailyOsNextTriageConfirmDoNow => 'Klaar nu';

  @override
  String get dailyOsNextTriageConfirmDrop => 'Gedropt';

  @override
  String get dailyOsNextTriageConfirmToday => 'Toegevoegd aan vandaag';

  @override
  String get dailyOsNextTriageDefer => 'Uitstel';

  @override
  String get dailyOsNextTriageDone => 'Klaar';

  @override
  String get dailyOsNextTriageDoNow => 'Nu';

  @override
  String get dailyOsNextTriageDrop => 'Laat vallen';

  @override
  String get dailyOsNextTriageToday => 'Vandaag';

  @override
  String get dailyOsOnboardingCoachCapture => 'Zeg wat je aandacht trekt.';

  @override
  String get dailyOsOnboardingCoachDrafting =>
      'De planner creëert nieuwe taken en past het werk in uw dag.';

  @override
  String get dailyOsOnboardingCoachReconcile =>
      'Kies wat er vandaag hoort. Nieuwe items worden taken als je de dag opbouwt.';

  @override
  String get dailyOsOnboardingSpotlightAction => 'Probeer het.';

  @override
  String get dailyOsOnboardingSpotlightDismiss => 'Niet nu.';

  @override
  String get dailyOsOnboardingSpotlightMessage =>
      'Tik hier en zeg wat er op je gedachten . . Ik zal het in een taak en bouw je dag rond het.';

  @override
  String get dailyOsOnboardingSpotlightTitle => 'Praat in een plan veranderen';

  @override
  String get dailyOsSettingsChooseModelDescription =>
      'Overschrijf alleen het denkmodel van de planner.';

  @override
  String get dailyOsSettingsChooseModelTitle => 'Kies modeloverschrijven';

  @override
  String get dailyOsSettingsChooseProfileDescription =>
      'Overschrijf het volledige inleidende profiel van deze planner.';

  @override
  String get dailyOsSettingsChooseProfileTitle => 'Kies dagelijks OS-profiel';

  @override
  String get dailyOsSettingsDataDisclosure =>
      'Dagelijkse OS stuurt relevante taken, captures, plannen, geleerde voorkeuren, en andere samengestelde planning context naar de geselecteerde provider voor verwerking.';

  @override
  String get dailyOsSettingsDefaultProfileDescription =>
      'Gebruikt door Daily OS tenzij de planner instantie een override heeft.';

  @override
  String get dailyOsSettingsDefaultProfileMissing => 'Kies een profiel';

  @override
  String get dailyOsSettingsDefaultRestored =>
      'Standaard dagelijks besturingssysteem hersteld';

  @override
  String get dailyOsSettingsDirectOverrideActive =>
      'Direct model override is actief.';

  @override
  String get dailyOsSettingsInferenceTitle => 'Standaard inferentieprofiel';

  @override
  String get dailyOsSettingsInstanceCurrentSetup =>
      'Huidige planner-configuratie';

  @override
  String get dailyOsSettingsInstanceOverrideDescription =>
      'Gebruik het standaardprofiel van het dagelijks besturingssysteem, kies een profieloverride of override alleen het denkmodel van deze planner.';

  @override
  String get dailyOsSettingsInstanceOverrideTitle => 'Dagelijkse OS-inferentie';

  @override
  String get dailyOsSettingsLocalDisclosure =>
      'Het geselecteerde eindpunt is op dit apparaat.';

  @override
  String dailyOsSettingsModelChanged(String model) {
    return 'Dagelijks besturingssysteem gebruikt nu $model';
  }

  @override
  String get dailyOsSettingsNameNudgeAction => 'Naam toevoegen';

  @override
  String get dailyOsSettingsNameNudgeBody =>
      'Een voorkeursnaam toevoegen maakt check-ins persoonlijker. U kunt zonder deze plannen blijven plannen.';

  @override
  String get dailyOsSettingsNameNudgeTitle => 'Hoe moet Daily OS u aanpakken?';

  @override
  String dailyOsSettingsProfileChanged(String profile) {
    return 'Dagelijks besturingssysteem gebruikt nu $profile';
  }

  @override
  String get dailyOsSettingsProfileOverrideActive =>
      'Profieloverschrijven actief';

  @override
  String dailyOsSettingsRemoteDisclosure(String provider, String host) {
    return 'Dagelijkse OS stuurt de samengestelde planning context naar $provider op $host voor verwerking op afstand.';
  }

  @override
  String get dailyOsSettingsSetupAction => 'Dagelijkse OS instellen';

  @override
  String get dailyOsSettingsSetupRequiredBody =>
      'Dagelijkse besturingssysteem heeft uw provider keuze nodig voordat het uw planning context kan verwerken.';

  @override
  String get dailyOsSettingsSetupRequiredTitle => 'Kies een inferentieprofiel';

  @override
  String get dailyOsSettingsSubtitle =>
      'Kies hoe Daily OS u aanspreekt en welk gevolggevingsprofiel uw dagen plant.';

  @override
  String get dailyOsSettingsTitle => 'Dagelijks besturingssysteem';

  @override
  String get dailyOsSettingsTreeSubtitle =>
      'Planning, personalisatie en AI provider';

  @override
  String get dailyOsSettingsUseDefault => 'Dagelijkse OS-standaard gebruiken';

  @override
  String get dailyOsSettingsUseDefaultDescription =>
      'Volg het profiel dat geselecteerd is in de Daily OS-instellingen.';

  @override
  String get dailyOsTodayButton => 'Vandaag';

  @override
  String get dashboardActiveLabel => 'Actief';

  @override
  String get dashboardActiveSwitchDescription =>
      'In de dashboardslijst getoond';

  @override
  String get dashboardAddChartsTitle => 'Grafieken';

  @override
  String get dashboardAddHabitButton => 'Gewoontes';

  @override
  String get dashboardAddHabitTitle => 'Gewoontegrafieken';

  @override
  String get dashboardAddHealthButton => 'Gezondheid';

  @override
  String get dashboardAddHealthTitle => 'Gezondheidskaarten';

  @override
  String get dashboardAddMeasurementButton => 'Metingen';

  @override
  String get dashboardAddMeasurementTitle => 'Meetkaarten toevoegen';

  @override
  String get dashboardAddMeasurementTooltip => 'Meting toevoegen';

  @override
  String get dashboardAddSurveyButton => 'Enquêtes';

  @override
  String get dashboardAddSurveyTitle => 'Overzichtsgrafieken';

  @override
  String get dashboardAddWorkoutButton => 'Uitwerkingen';

  @override
  String get dashboardAddWorkoutTitle => 'Werkschema\'s';

  @override
  String get dashboardAggregationApplyImmediately =>
      'Kies een samenvatting. Wijzigingen zijn onmiddellijk van toepassing.';

  @override
  String get dashboardAggregationDailyAverage => 'Daggemiddelde';

  @override
  String get dashboardAggregationDailyMax => 'Dagelijks max.';

  @override
  String get dashboardAggregationDailyTotal => 'Dagelijks totaal';

  @override
  String get dashboardAggregationHourlyTotal => 'Totaal uur';

  @override
  String get dashboardAggregationLabel => 'Samenvoegtype:';

  @override
  String get dashboardAggregationTitle => 'Samenvoegtype';

  @override
  String get dashboardAvailableChartsDescription =>
      'Kies een type, selecteer een of meer grafieken, voeg ze dan toe.';

  @override
  String get dashboardAvailableChartsTitle =>
      'Toevoegen van grafieken per type';

  @override
  String get dashboardCategoryLabel => 'Categorie';

  @override
  String get dashboardChartNoData => 'Geen gegevens in dit bereik';

  @override
  String get dashboardConfigurationDescription =>
      'Sla het dashboard op en kopieer vervolgens de JSON configuratie.';

  @override
  String get dashboardConfigurationTitle => 'Export configuratie';

  @override
  String get dashboardCopyHint => '& Kopieer dashboard-configuratie opslaan';

  @override
  String get dashboardCopyLabel => 'JSON opslaan en kopiëren';

  @override
  String get dashboardCurrentChartsDescription =>
      'Sleep naar herschikken. Meetkaarten kunnen worden geselecteerd om hun aggregatie te wijzigen.';

  @override
  String get dashboardCurrentChartsTitle => 'Grafieken op dit dashboard';

  @override
  String get dashboardDeleteConfirm => 'Ja, delete dit DASHBOARD';

  @override
  String get dashboardDeleteHint => 'Dashboard verwijderen';

  @override
  String get dashboardDeleteQuestion => 'Wilt u dit dashboard verwijderen?';

  @override
  String get dashboardDescriptionLabel => 'Beschrijving (facultatief)';

  @override
  String get dashboardEditAggregationLabel => 'samengevoegd bewerken';

  @override
  String get dashboardHealthBloodPressure => 'Bloeddruk';

  @override
  String get dashboardHealthDiastolic => 'Diastomisch';

  @override
  String get dashboardHealthSystolic => 'Systolisch';

  @override
  String dashboardMeasurementAddButtonWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Toevoegen $count grafieken',
      one: 'Toevoegen 1 grafiek',
    );
    return '$_temp0';
  }

  @override
  String dashboardMeasurementAggregationFor(String name) {
    return 'Grafiekmodus voor $name';
  }

  @override
  String get dashboardMeasurementAggregationHelp =>
      'Selecteer meetkaarten. Pas de grafiekmodus aan in de geselecteerde rijen voordat u deze toevoegt.';

  @override
  String get dashboardNameLabel => 'Naam dashboard';

  @override
  String get dashboardNoChartsAdded => 'Nog geen grafieken toegevoegd.';

  @override
  String get dashboardNoHabitsForCharts =>
      'Maak eerst een gewoonte om gewoontediagrammen toe te voegen.';

  @override
  String get dashboardNoMeasurablesForCharts =>
      'Maak eerst een meetbaar om meetkaarten toe te voegen.';

  @override
  String get dashboardNotFound => 'Dashboard niet gevonden';

  @override
  String get dashboardPrivateLabel => 'Privé';

  @override
  String get dashboardRemoveChartLabel => 'Grafiek verwijderen';

  @override
  String get dashboardReorderChartLabel => 'Kaart herschikken';

  @override
  String get dashboardTakeSurveyTooltip => 'Onderzoek uitvoeren';

  @override
  String get defaultLanguage => 'Standaardtaal';

  @override
  String get deleteButton => 'Verwijderen';

  @override
  String get deleteDeviceLabel => 'Apparaat verwijderen';

  @override
  String get designSystemActionVariantTitle => 'Met actie';

  @override
  String get designSystemActivatedLabel => 'Geactiveerd';

  @override
  String get designSystemAvatarAwayLabel => 'Weg';

  @override
  String get designSystemAvatarBusyLabel => 'Bezet';

  @override
  String get designSystemAvatarConnectedLabel => 'Verbonden';

  @override
  String get designSystemAvatarEnabledLabel => 'Ingeschakeld';

  @override
  String get designSystemAvatarSizeMatrixTitle => 'Matrixgrootte';

  @override
  String get designSystemAvatarStatusMatrixTitle => 'Statusmatrix';

  @override
  String get designSystemBackLabel => 'Terug';

  @override
  String get designSystemBreadcrumbCurrentLabel => 'Broodkruimels';

  @override
  String get designSystemBreadcrumbDesignSystemLabel => 'Ontwerpsysteem';

  @override
  String get designSystemBreadcrumbHomeLabel => 'Begin';

  @override
  String get designSystemBreadcrumbMobileLabel => 'Mobiel';

  @override
  String get designSystemBreadcrumbProjectsLabel => 'Projecten';

  @override
  String get designSystemBreadcrumbSampleLabel => 'Broodkruimels';

  @override
  String get designSystemBreadcrumbTrailTitle => 'Broodkruimelpad';

  @override
  String get designSystemCalendarPickerLabel => 'Agendapicker';

  @override
  String get designSystemCalendarViewsTitle => 'Agendaweergaven';

  @override
  String get designSystemCaptionDescriptionSample =>
      'Verwijderen van alle gebruikers ongepubliceerd dit project. Voeg gebruikers om het opnieuw te publiceren.';

  @override
  String get designSystemCaptionIconLeftLabel => 'Links pictogram';

  @override
  String get designSystemCaptionIconTopLabel => 'Bovenpictogram';

  @override
  String get designSystemCaptionNoIconLabel => 'Geen pictogram';

  @override
  String get designSystemCaptionTitleSample => 'Titel';

  @override
  String get designSystemCaptionVariantsTitle => 'Bijschrift Varianten';

  @override
  String get designSystemCaptionWithActionsLabel => 'Met acties';

  @override
  String get designSystemCaptionWithoutActionsLabel => 'Zonder maatregelen';

  @override
  String get designSystemCheckboxLabel => 'Controlevakje';

  @override
  String get designSystemContextMenuDeleteLabel => 'Verwijderen';

  @override
  String get designSystemContextMenuVariantsTitle => 'Context menu Varianten';

  @override
  String get designSystemCountdownVariantTitle => 'Met aftellen';

  @override
  String get designSystemDateCardsTitle => 'Datumkaarten';

  @override
  String get designSystemDefaultLabel => 'Standaard';

  @override
  String get designSystemDisabledLabel => 'Uitgeschakeld';

  @override
  String get designSystemDividerLabelText => 'Verdeellabel';

  @override
  String get designSystemDropdownComboboxTitle => 'Combobox';

  @override
  String get designSystemDropdownFieldLabel => 'Label';

  @override
  String get designSystemDropdownInputLabel => 'Invoer';

  @override
  String get designSystemDropdownListTitle => 'Lijst met uitloop';

  @override
  String get designSystemDropdownMultiselectInputLabel => 'Selecteer teams';

  @override
  String get designSystemDropdownMultiselectTitle => 'Meer selecteren';

  @override
  String get designSystemDropdownOptionAnalytics => 'Analytics';

  @override
  String get designSystemDropdownOptionBackend => 'Backend';

  @override
  String get designSystemDropdownOptionDesign => 'Ontwerp';

  @override
  String get designSystemDropdownOptionFrontend => 'Frontend';

  @override
  String get designSystemDropdownOptionGrowth => 'Groei';

  @override
  String get designSystemDropdownOptionMobile => 'Mobiel';

  @override
  String get designSystemDropdownOptionQa => 'QA';

  @override
  String get designSystemErrorLabel => 'Fout';

  @override
  String get designSystemFileUploadClickLabel => 'Klik om te uploaden';

  @override
  String get designSystemFileUploadCompleteLabel => 'Voltooid';

  @override
  String get designSystemFileUploadDefaultLabel => 'Standaard';

  @override
  String get designSystemFileUploadDragLabel => 'of sleep en drop';

  @override
  String get designSystemFileUploadDropZoneSectionTitle =>
      'Gebied waar de vangst plaatsvindt';

  @override
  String get designSystemFileUploadErrorLabel => 'Fout';

  @override
  String get designSystemFileUploadFailedText => 'Uploaden mislukt';

  @override
  String get designSystemFileUploadHintText =>
      'SVG, PNG, JPG of GIF (max. 800×400px)';

  @override
  String get designSystemFileUploadHoverLabel => 'Hover';

  @override
  String get designSystemFileUploadItemSectionTitle => 'Bestandsitems';

  @override
  String get designSystemFileUploadRetryLabel => 'Opnieuw proberen';

  @override
  String get designSystemFileUploadUploadingLabel => 'Uploaden';

  @override
  String get designSystemFilledLabel => 'Voltooid';

  @override
  String get designSystemHeaderApiDocumentationLabel => 'API-documentatie';

  @override
  String get designSystemHeaderBackActionLabel => 'Terug';

  @override
  String get designSystemHeaderDesktopSectionTitle => 'Bureaublad';

  @override
  String get designSystemHeaderHelpActionLabel => 'Hulp';

  @override
  String get designSystemHeaderMobileSectionTitle => 'Mobiel';

  @override
  String get designSystemHeaderNotificationsActionLabel => 'Kennisgevingen';

  @override
  String get designSystemHeaderSearchActionLabel => 'Zoeken';

  @override
  String get designSystemHorizontalLabel => 'Horizontaal';

  @override
  String get designSystemHoverLabel => 'Hover';

  @override
  String get designSystemInfoLabel => 'Informatie';

  @override
  String get designSystemInputErrorSample => 'Dit veld is vereist';

  @override
  String get designSystemInputHelperSample => 'Voer uw naam in';

  @override
  String get designSystemInputHintSample => 'Plaatshouder...';

  @override
  String get designSystemInputLabelSample => 'Label';

  @override
  String get designSystemInputVariantsTitle => 'Invoervarianten';

  @override
  String get designSystemInputWithErrorLabel => 'Met fout';

  @override
  String get designSystemInputWithHelperLabel => 'Met hulptekst';

  @override
  String get designSystemInputWithIconsLabel => 'Met pictogrammen';

  @override
  String get designSystemListItemActivatedLabel => 'Geactiveerd';

  @override
  String get designSystemListItemOneLineLabel => 'Eén regel';

  @override
  String get designSystemListItemSubtitleSample => 'Ondertiteling';

  @override
  String get designSystemListItemTitleSample => 'Titel';

  @override
  String get designSystemListItemTwoLinesLabel => 'Twee regels';

  @override
  String get designSystemListItemVariantsTitle => 'Lijst Item Varianten';

  @override
  String get designSystemListItemWithDividerLabel => 'met scheidingswand';

  @override
  String get designSystemMediumLabel => 'Middel';

  @override
  String designSystemMyDailyDurationHoursMinutesCompact(
    int hours,
    int minutes,
  ) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get designSystemNavigationCollapsedLabel => 'Ingestort';

  @override
  String get designSystemNavigationDailyFilterSectionTitle =>
      'Dagelijks filter';

  @override
  String get designSystemNavigationExpandedLabel => 'Uitbreid';

  @override
  String get designSystemNavigationFilterByBlockLabel => 'Filteren op blok';

  @override
  String get designSystemNavigationHikingLabel => 'Wandelen';

  @override
  String get designSystemNavigationHolidayLabel => 'Vakantie';

  @override
  String get designSystemNavigationInsightsLabel => 'Inzichten';

  @override
  String get designSystemNavigationLottiTasksLabel => 'Taken van Lotti';

  @override
  String get designSystemNavigationMyDailyLabel => 'Mijn dag';

  @override
  String get designSystemNavigationNewLabel => 'Nieuw';

  @override
  String get designSystemNavigationPlaceholderLabel => 'Plaatshouder';

  @override
  String get designSystemNavigationSidebarSectionTitle => 'Zijbalk Varianten';

  @override
  String get designSystemNavigationSubComponentsSectionTitle =>
      'Subcomponenten';

  @override
  String get designSystemNavigationTabBarSectionTitle =>
      'Tabbladbalk Varianten';

  @override
  String get designSystemPressedLabel => 'Gedrukt';

  @override
  String get designSystemProgressBarChunkyLabel => 'Chunky';

  @override
  String get designSystemProgressBarLabelAndPercentageLabel =>
      'Label + percentage';

  @override
  String get designSystemProgressBarLabelOnlyLabel => 'Alleen label';

  @override
  String get designSystemProgressBarOffLabel => 'Uit';

  @override
  String get designSystemProgressBarPercentageOnlyLabel => 'Percentage';

  @override
  String get designSystemProgressBarQuestBarLabel => 'Quest-balk';

  @override
  String get designSystemProgressBarQuestLabel => 'Mega prijzenlabel';

  @override
  String get designSystemProgressBarSampleLabel => 'Voortgangsbalk-label';

  @override
  String get designSystemRadioButtonLabel => 'Radioknop';

  @override
  String get designSystemScrollbarSizesTitle => 'Schuifbalkgroottes';

  @override
  String get designSystemSearchClearLabel => 'Zoekopdracht wissen';

  @override
  String get designSystemSearchFilledText => 'Lotti-zoekopdracht';

  @override
  String get designSystemSearchHintLabel => 'Type gebruiker';

  @override
  String get designSystemSelectedLabel => 'Geselecteerd';

  @override
  String get designSystemSizeScaleTitle => 'Grootteschaal';

  @override
  String get designSystemSmallLabel => 'Klein';

  @override
  String get designSystemSpinnerPlainLabel => 'Normaal';

  @override
  String get designSystemSpinnerSkeletonPulseLabel => 'Pols';

  @override
  String get designSystemSpinnerSkeletonsTitle => 'Skeletten';

  @override
  String get designSystemSpinnerSkeletonWaveLabel => 'Golf';

  @override
  String get designSystemSpinnerSpinnersTitle => 'Spinners';

  @override
  String get designSystemSpinnerTrackLabel => 'met track';

  @override
  String designSystemSplitButtonDropdownSemantics(String label) {
    return 'Openen $label opties';
  }

  @override
  String get designSystemStateMatrixTitle => 'Statusmatrix';

  @override
  String get designSystemSuccessLabel => 'Succes';

  @override
  String get designSystemTabBarTitle => 'Tabbalk';

  @override
  String get designSystemTabPendingLabel => 'In afwachting';

  @override
  String get designSystemTaskListBlockedLabel => 'Geblokkeerd';

  @override
  String get designSystemTaskListDefaultLabel => 'Standaard';

  @override
  String get designSystemTaskListHoverLabel => 'Hover';

  @override
  String get designSystemTaskListItemSectionTitle => 'Taaklijst Item Varianten';

  @override
  String get designSystemTaskListOnHoldLabel => 'In wacht';

  @override
  String get designSystemTaskListOpenLabel => 'Openen';

  @override
  String get designSystemTaskListPressedLabel => 'Gedrukt';

  @override
  String get designSystemTaskListSampleTime => '8:00-9:30';

  @override
  String get designSystemTaskListSampleTitle => 'Gebruikerstest';

  @override
  String get designSystemTaskListWithDividerLabel => 'met scheidingswand';

  @override
  String get designSystemTextareaErrorSample => 'Dit veld is vereist';

  @override
  String get designSystemTextareaHelperSample => 'Voer hier uw bericht in';

  @override
  String get designSystemTextareaHintSample => 'Typ iets...';

  @override
  String get designSystemTextareaLabelSample => 'Label';

  @override
  String get designSystemTextareaVariantsTitle => 'Tekstgebied Varianten';

  @override
  String get designSystemTextareaWithCounterLabel => 'met teller';

  @override
  String get designSystemTextareaWithErrorLabel => 'Met fout';

  @override
  String get designSystemTextareaWithHelperLabel => 'Met hulptekst';

  @override
  String get designSystemTimePickerFormatsTitle => 'Tijdsformaten';

  @override
  String get designSystemTimePickerTwelveHourLabel => '12 uur';

  @override
  String get designSystemTimePickerTwentyFourHourLabel => '24 uur';

  @override
  String get designSystemTitleOnlyVariantTitle => 'Alleen titel Variant';

  @override
  String get designSystemToastDetailsLabel => 'Kennisgevings-gegevens';

  @override
  String get designSystemToggleLabel => 'Schakel label in/uit';

  @override
  String get designSystemTooltipIconMessageSample =>
      'Hulpzame informatie over dit veld';

  @override
  String get designSystemTooltipIconVariantsTitle =>
      'Pictogram voor gereedschapsbalk';

  @override
  String get designSystemUndoLabel => 'Ongedaan maken';

  @override
  String get designSystemVariantMatrixTitle => 'Variant Matrix';

  @override
  String get designSystemVerticalLabel => 'Verticaal';

  @override
  String get designSystemWarningLabel => 'Waarschuwing';

  @override
  String get designSystemWeeklyCalendarLabel => 'Wekelijkse agenda';

  @override
  String get designSystemWithLabelLabel => 'Met label';

  @override
  String get desktopEmptyStateSelectDashboard =>
      'Selecteer een dashboard om details te bekijken';

  @override
  String get desktopEmptyStateSelectProject =>
      'Selecteer een project om details te bekijken';

  @override
  String get desktopEmptyStateSelectTask =>
      'Selecteer een taak om details te bekijken';

  @override
  String deviceDeletedSuccess(String deviceName) {
    return 'Apparaat $deviceName verwijderd met succes';
  }

  @override
  String deviceDeleteFailed(String error) {
    return 'Verwijderen van apparaat is mislukt: $error';
  }

  @override
  String get doneButton => 'Klaar';

  @override
  String get editMenuTitle => 'Bewerken';

  @override
  String get editorDiscardChanges => 'Wijzigingen verwerpen';

  @override
  String get editorInsertDivider => 'Schakel de scheidingstekens in';

  @override
  String get editorMoreFormatting => 'Meer opmaak';

  @override
  String get editorPlaceholder => 'Notities invoeren...';

  @override
  String get embeddingSelectAll => 'Alles selecteren';

  @override
  String get embeddingUnselectAll => 'Alles deselecteren';

  @override
  String get enhancedPromptFormPreconfiguredPromptDescription =>
      'Kies uit kant-en-klare prompt templates';

  @override
  String get enterCategoryName => 'Categorienaam invoeren';

  @override
  String get entryActions => 'Acties';

  @override
  String get entryLabelsActionSubtitle =>
      'Labels toewijzen om dit item te organiseren';

  @override
  String get entryLabelsActionTitle => 'Etiketten';

  @override
  String get entryLabelsEditTooltip => 'Labels bewerken';

  @override
  String get entryLabelsHeaderTitle => 'Etiketten';

  @override
  String get entryLabelsNoLabels => 'Geen labels toegewezen';

  @override
  String get entryTypeLabelAiResponse => 'AI-respons';

  @override
  String get entryTypeLabelChecklist => 'Checklist';

  @override
  String get entryTypeLabelChecklistItem => 'Te doen';

  @override
  String get entryTypeLabelHabitCompletionEntry => 'Gewoonte';

  @override
  String get entryTypeLabelJournalAudio => 'Audio';

  @override
  String get entryTypeLabelJournalEntry => 'Tekst';

  @override
  String get entryTypeLabelJournalEvent => 'Gebeurtenis';

  @override
  String get entryTypeLabelJournalImage => 'Foto';

  @override
  String get entryTypeLabelMeasurementEntry => 'Gemeten';

  @override
  String get entryTypeLabelQuantitativeEntry => 'Gezondheid';

  @override
  String get entryTypeLabelSurveyEntry => 'Onderzoek';

  @override
  String get entryTypeLabelTask => 'Taak';

  @override
  String get entryTypeLabelWorkoutEntry => 'Workout';

  @override
  String get eventNameLabel => 'Gebeurtenis:';

  @override
  String get eventsAddCoverPhoto => 'Hoesfoto toevoegen';

  @override
  String get eventsAddLabel => 'Toevoegen';

  @override
  String get eventsChangeCover => 'Verander dekking';

  @override
  String get eventsDeleteEvent => 'Gebeurtenis verwijderen';

  @override
  String get eventsFilterAll => 'Alles';

  @override
  String eventsMetricPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count foto\'s',
      one: '1 foto',
    );
    return '$_temp0';
  }

  @override
  String eventsMetricTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count taken',
      one: '1 taak',
    );
    return '$_temp0';
  }

  @override
  String get eventsNewEvent => 'Nieuwe gebeurtenis';

  @override
  String get eventsPageTitle => 'Gebeurtenissen';

  @override
  String get eventsPhotosSection => 'Foto\'s';

  @override
  String get eventsRecapAwaitingContent =>
      'Voeg een foto of notitie toe en de samenvatting verschijnt hier.';

  @override
  String get eventsRecapUnavailable => 'Kon de samenvatting niet laden.';

  @override
  String get eventsRegenerateSummary => 'Samenvatting regenereren';

  @override
  String get eventsSearchHint => 'Gebeurtenissen zoeken';

  @override
  String get eventsSectionUpcoming => 'Binnenkort';

  @override
  String get eventsStatusCancelled => 'Geannuleerd';

  @override
  String get eventsStatusCompleted => 'Voltooid';

  @override
  String get eventsStatusMissed => 'Gemiste';

  @override
  String get eventsStatusOngoing => 'Lopende';

  @override
  String get eventsStatusPlanned => 'Gepland';

  @override
  String get eventsStatusPostponed => 'Uitgesteld';

  @override
  String get eventsStatusRescheduled => 'Herschikt';

  @override
  String get eventsStatusTentative => 'Voorlopig';

  @override
  String get eventsSummaryTitle => 'Samenvatting';

  @override
  String get eventsTasksEmpty => 'Koppel een voorbereidings- of vervolgtaak';

  @override
  String get eventsTasksSection => 'Taken';

  @override
  String get eventsTimelineEmpty =>
      'Foto\'s, notities of een spraakmemo toevoegen';

  @override
  String get eventsTimelineSection => 'Tijdslijn';

  @override
  String get eventsTitleHint => 'Titel van de gebeurtenis';

  @override
  String get eventsVoiceNote => 'Stemnotitie';

  @override
  String get favoriteLabel => 'Favoriet';

  @override
  String get fileMenuNewEllipsis => 'Nieuw...';

  @override
  String get fileMenuNewEntry => 'Nieuwe invoer';

  @override
  String get fileMenuNewScreenshot => 'Schermafdruk';

  @override
  String get fileMenuNewTask => 'Taak';

  @override
  String get fileMenuTitle => 'Bestand';

  @override
  String get filterSelectionNoMatches => 'Geen overeenkomsten';

  @override
  String get geminiThinkingModeHighDescription =>
      'De diepste redenering; kan latency en kosten verhogen.';

  @override
  String get geminiThinkingModeHighLabel => 'Hoog';

  @override
  String get geminiThinkingModeLowDescription =>
      'Lage redenatie voor snelle dagelijkse prompts.';

  @override
  String get geminiThinkingModeLowLabel => 'Laag';

  @override
  String get geminiThinkingModeMediumDescription =>
      'Evenwichtige redenering voor meer zorgvuldige antwoorden.';

  @override
  String get geminiThinkingModeMediumLabel => 'Middel';

  @override
  String get geminiThinkingModeMinimalDescription =>
      'Snelste instelling; Tweelingen kunnen nog kort denken op complexe aanwijzingen.';

  @override
  String get geminiThinkingModeMinimalLabel => 'Minimaal';

  @override
  String get generateCoverArt => 'Omslagkunst genereren';

  @override
  String get generateCoverArtSubtitle =>
      'Afbeelding aanmaken van spraakbeschrijving';

  @override
  String get goMenuTitle => 'Ga';

  @override
  String get habitActiveFromLabel => 'Begindatum';

  @override
  String get habitActiveSwitchDescription => 'Getoond op de pagina Habits';

  @override
  String get habitArchivedLabel => 'Gearchiveerd';

  @override
  String get habitCategoryHint => 'Een categorie selecteren';

  @override
  String get habitCategoryLabel => 'Categorie';

  @override
  String get habitCloseCompletionLabel => 'Afronding van de gewoonte sluiten';

  @override
  String habitCompleteSemanticLabel(String habit) {
    return 'Opname $habit';
  }

  @override
  String get habitCompletionStatusCompleted => 'Voltooid';

  @override
  String get habitCompletionStatusFailed => 'Fout';

  @override
  String get habitCompletionStatusOpen => 'Openen';

  @override
  String get habitCompletionStatusSkipped => 'Overgeslagen';

  @override
  String get habitDashboardHint => 'Een dashboard selecteren';

  @override
  String get habitDashboardLabel => 'Dashboard (facultatief)';

  @override
  String habitDayStatusSemantic(String habit, String status) {
    return '$habit, $status';
  }

  @override
  String get habitDeleteConfirm => 'Ja, delete dit habit';

  @override
  String get habitDeleteQuestion => 'Wilt u deze gewoonte verwijderen?';

  @override
  String habitHeatmapDaySemantic(String date, int done, int total) {
    return '$date, $done van $total klaar';
  }

  @override
  String get habitLogOtherDayHint => 'Wacht om een andere dag in te loggen';

  @override
  String get habitNotRecordedLabel => 'Niet geregistreerd';

  @override
  String get habitPriorityLabel => 'Prioriteit';

  @override
  String get habitsAboveGoal => 'Op het spoor';

  @override
  String habitsActiveHabitsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count actieve gewoonten',
      one: '1 actieve gewoonte',
    );
    return '$_temp0';
  }

  @override
  String get habitsAllDoneToday => 'Alles klaar vandaag';

  @override
  String get habitsChartUseDynamicBaseline => 'Dynamische basislijn gebruiken';

  @override
  String get habitsChartUseZeroBaseline => 'Nulbasislijn gebruiken';

  @override
  String get habitsCompletedHeader => 'Voltooid';

  @override
  String get habitsCompletionRateTitle => 'Afrondingspercentage';

  @override
  String get habitsConsistencyTitle => 'Samenhang';

  @override
  String habitsDayFailedPercent(int percent) {
    return '$percent% geregistreerd mislukt';
  }

  @override
  String habitsDaySkippedPercent(int percent) {
    return '$percent% overgeslagen';
  }

  @override
  String habitsDaySuccessfulPercent(int percent) {
    return '$percent% succesvol';
  }

  @override
  String get habitsDoneTodayLabel => 'Vandaag klaar';

  @override
  String get habitSectionOptionsTitle => 'Opties';

  @override
  String get habitSectionScheduleTitle => 'Schema';

  @override
  String get habitsFilterAll => 'alle';

  @override
  String get habitsFilterCompleted => 'klaar';

  @override
  String get habitsFilterOpenNow => 'vervallen';

  @override
  String get habitsFilterPendingLater => 'later';

  @override
  String get habitsGoalLineLabel => 'Doel';

  @override
  String get habitsHeatmapEmpty =>
      'Voeg een gewoonte toe om uw consistentie te bouwen';

  @override
  String get habitsHeatmapLess => 'Minder';

  @override
  String get habitsHeatmapMore => 'Meer';

  @override
  String get habitShowAlertAtLabel => 'Alert tonen op';

  @override
  String get habitShowFromLabel => 'Tonen van';

  @override
  String habitsLaggardHint(String habit, int kept, int active) {
    return '$habit  — kept  $kept van $active';
  }

  @override
  String get habitsOpenHeader => 'Vervallen';

  @override
  String get habitsPendingLaterHeader => 'Later vandaag';

  @override
  String habitsPointsToGoal(int points) {
    String _temp0 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: '$points pts to goal',
      one: '1 pt tot doel',
    );
    return '$_temp0';
  }

  @override
  String get habitsRecordButton => 'Opname';

  @override
  String get habitsRollingAverageLabel => '7 dagen';

  @override
  String get habitsStartStreakToday => 'Begin vandaag met een streak';

  @override
  String habitsStreakLongCount(int count) {
    return '$count op een 7-daagse streep';
  }

  @override
  String habitsStreakShortCount(int count) {
    return '$count op een 3-daagse streep';
  }

  @override
  String get habitsTapForBreakdown => 'Tik op een dag voor de instorting';

  @override
  String habitsToGoCount(int count) {
    return '$count om te gaan';
  }

  @override
  String habitStreakDaysSemantic(int count) {
    return '$count-dagstreak';
  }

  @override
  String get habitsVsPreviousWeek => 'vs vorige week';

  @override
  String get helpMenuCommandPalette => 'Commandopalet...';

  @override
  String get helpMenuKeyboardShortcuts => 'Sneltoetsen...';

  @override
  String get helpMenuTitle => 'Hulp';

  @override
  String get imageGenerationError => 'Kon afbeelding niet aanmaken';

  @override
  String get imageGenerationGenerating => 'Afbeelding aanmaken...';

  @override
  String get imageGenerationProviderRejectedTitle =>
      'De image provider heeft dit verzoek afgewezen';

  @override
  String imageGenerationWithReferences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Gebruik $count referentieafbeeldingen',
      one: '1 referentieafbeelding gebruiken',
      zero: 'Geen referentieafbeeldingen',
    );
    return '$_temp0';
  }

  @override
  String get imagePromptGenerationCardTitle => 'AI-afbeeldingsprompt';

  @override
  String get imagePromptGenerationCopiedSnackbar =>
      'Afbeeldingsprompt gekopieerd naar klembord';

  @override
  String get imagePromptGenerationCopyButton => 'Waarschuwing kopiëren';

  @override
  String get imagePromptGenerationCopyTooltip =>
      'Afbeeldingsprompt naar klembord kopiëren';

  @override
  String get imagePromptGenerationExpandTooltip => 'Volledige prompt tonen';

  @override
  String get imagePromptGenerationFullPromptLabel =>
      'Volledige afbeeldingsprompt:';

  @override
  String get images => 'Afbeeldingen';

  @override
  String get imageViewerDownloadFailed => 'Kon afbeelding niet opslaan';

  @override
  String get imageViewerDownloadingTooltip => 'Afbeelding opslaan';

  @override
  String get imageViewerDownloadPermissionDenied => 'Fototoegang geweigerd';

  @override
  String imageViewerDownloadSaved(String fileName) {
    return 'Opgeslagen $fileName';
  }

  @override
  String get imageViewerDownloadSavedToGallery => 'Opgeslagen in foto\'s';

  @override
  String get imageViewerDownloadTooltip => 'Afbeelding downloaden';

  @override
  String get inactiveLabel => 'Inactief';

  @override
  String get inactiveSwitchDescription =>
      'Kan worden gekozen voor nieuwe items wanneer op';

  @override
  String get inferenceProfileChooseModelTitle => 'Kies een model';

  @override
  String get inferenceProfileChooseTitle => 'Kies een inferentieprofiel';

  @override
  String get inferenceProfileCreateTitle => 'Profiel aanmaken';

  @override
  String get inferenceProfileDescriptionLabel => 'Omschrijving';

  @override
  String get inferenceProfileDesktopOnly => 'Alleen bureaublad';

  @override
  String get inferenceProfileDesktopOnlyDescription =>
      'Alleen beschikbaar op desktopplatforms (bv. voor lokale modellen)';

  @override
  String inferenceProfileDetailLoadError(String error) {
    return 'Kon profiel niet laden: $error';
  }

  @override
  String get inferenceProfileDetailNotFound => 'Profiel niet gevonden';

  @override
  String get inferenceProfileEditTitle => 'Profiel bewerken';

  @override
  String get inferenceProfileImageGeneration => 'Afbeeldingsgeneratie';

  @override
  String get inferenceProfileImageRecognition => 'Beeldherkenning';

  @override
  String get inferenceProfileModelUnavailable =>
      'Model niet beschikbaar . . zijn provider kan zijn verwijderd';

  @override
  String get inferenceProfileNameLabel => 'Profielnaam';

  @override
  String get inferenceProfileNameRequired => 'Een profielnaam is vereist';

  @override
  String get inferenceProfilePinnedHostHelper =>
      'Wanneer ingesteld, alleen dit apparaat automatisch-runs gevolggeving voor gesynchroniseerde audio-items die dit profiel gebruiken.';

  @override
  String get inferenceProfilePinnedHostLabel => 'Gepind apparaat';

  @override
  String get inferenceProfilePinnedHostNoEligibleNodes =>
      'Geen bekende apparaten adverteren de providers die dit profiel gebruikt. Open Sync knooppuntinstellingen op het doelapparaat.';

  @override
  String get inferenceProfilePinnedHostNoneHelper =>
      'Gesynchroniseerde audio-items worden niet automatisch getranscribeerd wanneer geen apparaat is gepind.';

  @override
  String get inferenceProfilePinnedHostNoneLabel =>
      'Niet gepind (geen autotrigger)';

  @override
  String get inferenceProfilePinnedHostThisDeviceSuffix => ' (dit apparaat)';

  @override
  String get inferenceProfileSaveButton => 'Opslaan';

  @override
  String get inferenceProfileSelectModel => 'Kies een model...';

  @override
  String get inferenceProfileSelectProfile => 'Kies een profiel...';

  @override
  String get inferenceProfilesEmpty => 'Nog geen gevolgtrekkingensprofielen';

  @override
  String inferenceProfileSkillModelRequired(String slotName) {
    return 'Vereist $slotName in te stellen model';
  }

  @override
  String get inferenceProfileSkillsSection => 'Geautomatiseerde vaardigheden';

  @override
  String inferenceProfileSkillUsesModel(String slotName) {
    return 'Gebruik $slotName model';
  }

  @override
  String get inferenceProfilesTitle => 'Inferentieprofielen';

  @override
  String get inferenceProfileThinking => 'Denken';

  @override
  String get inferenceProfileThinkingHighEnd => 'Denken (High-End)';

  @override
  String get inferenceProfileThinkingRequired => 'Een denkmodel is vereist';

  @override
  String get inferenceProfileTranscription => 'Omschrijving';

  @override
  String get inferenceProfileUnavailable =>
      'Inferentieprofiel niet beschikbaar';

  @override
  String get inputDataTypeAudioFilesDescription =>
      'Gebruik audiobestanden als invoer';

  @override
  String get inputDataTypeAudioFilesName => 'Audiobestanden';

  @override
  String get inputDataTypeImagesDescription =>
      'Afbeeldingen als invoer gebruiken';

  @override
  String get inputDataTypeImagesName => 'Afbeeldingen';

  @override
  String get inputDataTypeTaskDescription =>
      'Gebruik de huidige taak als invoer';

  @override
  String get inputDataTypeTaskName => 'Taak';

  @override
  String get inputDataTypeTasksListDescription =>
      'Een lijst van taken als invoer gebruiken';

  @override
  String get inputDataTypeTasksListName => 'Takenlijst';

  @override
  String get insightsChartCompareCaption => 'Deze periode vs. de vorige';

  @override
  String get insightsChartCompareCaptionPartial =>
      'Deze periode tot dusver vs. de vorige';

  @override
  String get insightsChartCompareHint =>
      'Vergelijking weergegeven in onderstaande tabel';

  @override
  String get insightsChartCumulativeCaption => 'Totaal over het bereik lopen';

  @override
  String get insightsChartCumulativeShort =>
      'Nog niet genoeg dagen voor een hardlooptotaal';

  @override
  String get insightsChartDailyCaption => 'Tijd per dag';

  @override
  String get insightsChartHourlyCaption => 'Tijd per uur';

  @override
  String get insightsChartPerDay => 'Per dag';

  @override
  String get insightsChartPerHour => 'Per uur';

  @override
  String get insightsChartPerWeek => 'Per week';

  @override
  String get insightsChartRunningTotal => 'Totaal';

  @override
  String get insightsChartTitle => 'Tijd per categorie';

  @override
  String get insightsChartWeeklyCaption => 'Tijd per week';

  @override
  String get insightsChooseFocusCategories => 'Kies focuscategorieën';

  @override
  String get insightsCompare => 'Vergelijken';

  @override
  String get insightsCompareFullPeriod => 'volledige periode';

  @override
  String get insightsComparePrevious => 'Vorige';

  @override
  String get insightsCompareSameDays => 'dezelfde dagen';

  @override
  String get insightsCompareTooltip => 'Vergelijk met de vorige periode';

  @override
  String get insightsCompareVs => 'vs';

  @override
  String get insightsDeletedCategory => 'Verwijderde categorie';

  @override
  String get insightsDeltaNew => 'nieuw';

  @override
  String get insightsEmptyBody =>
      'Tijd die je bijhoudt bij inzendingen en taken zal hier verschijnen.';

  @override
  String get insightsEmptyChart => 'Geen gegevens in dit bereik';

  @override
  String get insightsEmptyPreviousPeriod => 'De vorige periode tonen';

  @override
  String get insightsEmptyShowYear => 'Bekijk dit jaar';

  @override
  String get insightsEmptyTitle => 'Geen getraceerde tijd in dit bereik';

  @override
  String get insightsFocusCategoriesEmpty => 'Nog geen actieve categorieën.';

  @override
  String get insightsFocusCategoriesTitle => 'Focuscategorieën';

  @override
  String get insightsKpiFocus => 'FOCUS';

  @override
  String get insightsKpiFocusHelp => 'Categorieën die je bekijkt';

  @override
  String get insightsKpiOther => 'OVERIGE';

  @override
  String get insightsKpiOtherHelp => 'Al het andere';

  @override
  String insightsKpiTopCategory(String category, String share) {
    return 'Meest op $category · $share';
  }

  @override
  String get insightsKpiTotal => 'TOTAAL';

  @override
  String get insightsLoadError => 'Kon tijdgegevens niet laden';

  @override
  String get insightsOtherCategories => 'Overige gevallen';

  @override
  String get insightsPartialWeek => 'gedeeltelijke week';

  @override
  String get insightsPeriodDay => 'Dag';

  @override
  String get insightsPeriodJump => 'Naar een datum springen';

  @override
  String get insightsPeriodMonth => 'Maand';

  @override
  String get insightsPeriodNext => 'Volgende periode';

  @override
  String get insightsPeriodPrevious => 'Vorige periode';

  @override
  String get insightsPeriodQuarter => 'Kwartaal';

  @override
  String get insightsPeriodToDateSuffix => 'tot dusver';

  @override
  String get insightsPeriodWeek => 'Week';

  @override
  String get insightsPeriodYear => 'Jaar';

  @override
  String get insightsRangeMonthToDate => 'Deze maand tot nu toe';

  @override
  String get insightsRangeMtd => 'Deze maand';

  @override
  String get insightsRangeYearToDate => 'Tot dusver dit jaar';

  @override
  String get insightsRangeYtd => 'Dit jaar';

  @override
  String get insightsRefreshError => 'Kon niet vernieuwen';

  @override
  String get insightsTableAvgPerDay => 'AVG/DAG';

  @override
  String get insightsTableCategory => 'CATEGORIE';

  @override
  String get insightsTableCompareNote => 'Verandering is vs de vorige periode';

  @override
  String get insightsTableCurrent => 'HUIDIGE';

  @override
  String get insightsTableDelta => 'Verschil';

  @override
  String get insightsTablePrevious => 'VOORAFGAANDE';

  @override
  String get insightsTableShare => 'DELEN';

  @override
  String get insightsTableTotal => 'TOTAAL';

  @override
  String get insightsTimeAnalysisTitle => 'Tijdsanalyse';

  @override
  String get insightsUncategorized => 'Niet-gecategoriseerd';

  @override
  String get journalCopyImageLabel => 'Afbeelding kopiëren';

  @override
  String get journalDateFromLabel => 'Datum van:';

  @override
  String get journalDateInvalid => 'Ongeldige datumbereik';

  @override
  String get journalDateLabel => 'Datum';

  @override
  String get journalDateNowButton => 'Nu';

  @override
  String get journalDateSaveButton => 'Opslaan';

  @override
  String get journalDateTimeRangeTitle => 'Datum & tijd';

  @override
  String get journalDateToLabel => 'Datum tot:';

  @override
  String get journalDeleteConfirm => 'Ja, trek deze inzending in.';

  @override
  String get journalDeleteHint => 'item verwijderen';

  @override
  String get journalDeleteQuestion => 'Wilt u dit journaal item verwijderen?';

  @override
  String get journalDurationLabel => 'Duur';

  @override
  String get journalEndDateLabel => 'Einddatum';

  @override
  String get journalEndsAnotherDayHint => 'Kies een aparte einddatum';

  @override
  String get journalEndsAnotherDayLabel => 'Eindigt op een andere dag';

  @override
  String get journalEndTimeLabel => 'Eindtijd';

  @override
  String get journalEntryExpandLabel => 'Item uitklappen';

  @override
  String get journalFilterEntryTypesTitle => 'Typen invoer';

  @override
  String get journalFilterFlagged => 'Gevlagd';

  @override
  String get journalFilterPrivate => 'Privé';

  @override
  String get journalFilterShowTitle => 'Tonen';

  @override
  String get journalFilterStarred => 'Sterren';

  @override
  String get journalFilterTitle => 'Filter journaal';

  @override
  String get journalHideLinkHint => 'Verwijzing verbergen';

  @override
  String get journalHideMapHint => 'Kaart verbergen';

  @override
  String get journalLinkedEntriesActivityFilterAudio => 'Audio';

  @override
  String get journalLinkedEntriesActivityFilterCode => 'Rubriek';

  @override
  String get journalLinkedEntriesActivityFilterImages => 'Afbeeldingen';

  @override
  String get journalLinkedEntriesActivityFilterTimer => 'Timer';

  @override
  String get journalLinkedEntriesFilterModalTitle => 'Filteren & sorteren';

  @override
  String get journalLinkedEntriesShowFlaggedOnly =>
      'Alleen gemarkeerde items tonen';

  @override
  String get journalLinkedEntriesShowHidden => 'Verborgen items tonen';

  @override
  String get journalLinkedEntriesSortLabel => 'Sorteren op';

  @override
  String get journalLinkedEntriesSortNewestFirst => 'Eerst nieuwste';

  @override
  String get journalLinkedEntriesSortOldestFirst => 'Oudste eerst';

  @override
  String get journalLinkedFromLabel => 'Verbonden met:';

  @override
  String get journalLinkFromHint => 'Link van';

  @override
  String get journalLinkToHint => 'Link naar';

  @override
  String journalOvernightNextDay(String date) {
    return 'Einde $date (volgende dag)';
  }

  @override
  String get journalPrivateTooltip => 'uitsluitend privé';

  @override
  String get journalSearchHint => 'Zoekdagboek...';

  @override
  String get journalSetEndDateTimeNowSemantic =>
      'Einddatum en tijd instellen op nu';

  @override
  String get journalSetStartDateTimeNowSemantic =>
      'Begindatum en -tijd instellen op nu';

  @override
  String get journalShareHint => 'Delen';

  @override
  String get journalShowLinkHint => 'Verwijzing tonen';

  @override
  String get journalShowMapHint => 'Kaart tonen';

  @override
  String get journalStartDateLabel => 'Begindatum';

  @override
  String get journalStartTimeLabel => 'Begintijd';

  @override
  String get journalTodayButton => 'Vandaag';

  @override
  String get journalToggleFlaggedTitle => 'Gevlagd';

  @override
  String get journalTogglePrivateTitle => 'Privé';

  @override
  String get journalToggleStarredTitle => 'Favoriet';

  @override
  String get journalUnlinkConfirm => 'Ja, onvindbare inval.';

  @override
  String get journalUnlinkHint => 'Verbinding verbreken';

  @override
  String get journalUnlinkQuestion =>
      'Weet u zeker dat u dit item wilt losmaken?';

  @override
  String get keyboardCommandActivate => 'Gericht item activeren';

  @override
  String get keyboardCommandCategoryCreation => 'Aanmaken';

  @override
  String get keyboardCommandCategoryEditing => 'Bewerken';

  @override
  String get keyboardCommandCategoryGeneral => 'Algemeen';

  @override
  String get keyboardCommandCategoryListsAndControls => 'Lijsten en controles';

  @override
  String get keyboardCommandCategoryNavigation => 'Navigatie';

  @override
  String get keyboardCommandCategoryView => 'Beeld';

  @override
  String get keyboardCommandCreateInContext => 'In huidige weergave aanmaken';

  @override
  String get keyboardCommandFocusSearch => 'Focus zoeken';

  @override
  String get keyboardCommandMoveDown =>
      'Gerichte item naar beneden verplaatsen';

  @override
  String get keyboardCommandMoveUp => 'Gerichte item omhoog verplaatsen';

  @override
  String keyboardCommandNavigate(String destination) {
    return 'Ga naar $destination';
  }

  @override
  String get keyboardCommandNextRegion => 'Volgende paneel focussen';

  @override
  String get keyboardCommandOpenPalette => 'Open commandopalet';

  @override
  String get keyboardCommandPageDown => 'Eén pagina omlaag verplaatsen';

  @override
  String get keyboardCommandPageUp => 'Eén pagina omhoog verplaatsen';

  @override
  String get keyboardCommandPreviousRegion => 'Vorig paneel focussen';

  @override
  String get keyboardCommandRefresh => 'Huidige weergave vernieuwen';

  @override
  String get keyboardCommandRename => 'Gerichte item hernoemen';

  @override
  String get keyboardCommandSelectFirst => 'Eerste item selecteren';

  @override
  String get keyboardCommandSelectLast => 'Laatste item selecteren';

  @override
  String get keyboardCommandSelectNext => 'Volgende item selecteren';

  @override
  String get keyboardCommandSelectPrevious => 'Vorige item selecteren';

  @override
  String get keyboardCommandToggle => 'Gericht item aan/uit';

  @override
  String get keyboardKeyAlt => 'Alt';

  @override
  String get keyboardKeyArrowDown => 'Pijl omlaag';

  @override
  String get keyboardKeyArrowLeft => 'Pijl links';

  @override
  String get keyboardKeyArrowRight => 'Pijl rechts';

  @override
  String get keyboardKeyArrowUp => 'Pijl omhoog';

  @override
  String get keyboardKeyControl => 'Ctrl';

  @override
  String get keyboardKeyDelete => 'Verwijderen';

  @override
  String get keyboardKeyEnd => 'Einde';

  @override
  String get keyboardKeyEnter => 'Enter';

  @override
  String get keyboardKeyEscape => 'Ontsnappen';

  @override
  String get keyboardKeyHome => 'Begin';

  @override
  String get keyboardKeyMinus => 'Min';

  @override
  String get keyboardKeyOr => 'of';

  @override
  String get keyboardKeyPageDown => 'Pagina omlaag';

  @override
  String get keyboardKeyPageUp => 'Pagina Omhoog';

  @override
  String get keyboardKeyPlus => 'Plus';

  @override
  String get keyboardKeyShift => 'Shift';

  @override
  String get keyboardKeySpace => 'Ruimte';

  @override
  String get keyboardResizeDividerLabel => 'Pannen verkleinen';

  @override
  String keyboardResizeDividerValue(int value, int min, int max) {
    return 'Panelen aanpassen, $value pixels. Bereik $min tot $max pixels.';
  }

  @override
  String get keyboardShortcutsNoResults =>
      'Geen sneltoetsen gevonden voor uw zoekopdracht';

  @override
  String get keyboardShortcutsSearchHint => 'Sneltoetsen zoeken...';

  @override
  String get keyboardShortcutsSubtitle =>
      'Elke desktop commando en de huidige toetsenbord combinatie.';

  @override
  String get keyboardShortcutsTitle => 'Sneltoetsen';

  @override
  String knowledgeGraphAgeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dagen geleden',
      one: '1 dag geleden',
    );
    return '$_temp0';
  }

  @override
  String knowledgeGraphAgeMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count maanden geleden',
      one: '1 maand geleden',
    );
    return '$_temp0';
  }

  @override
  String get knowledgeGraphAgeToday => 'vandaag';

  @override
  String knowledgeGraphAgeWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weken geleden',
      one: '1 week geleden',
    );
    return '$_temp0';
  }

  @override
  String get knowledgeGraphAgeYesterday => 'gisteren';

  @override
  String get knowledgeGraphBack => 'Terug';

  @override
  String get knowledgeGraphCloseDetails => 'Details sluiten';

  @override
  String get knowledgeGraphEmpty => 'Nog geen links te verkennen';

  @override
  String get knowledgeGraphEntryLoadError => 'Kon dit item niet laden';

  @override
  String get knowledgeGraphEntryNotFound => 'Niet gevonden';

  @override
  String get knowledgeGraphError => 'Kon de kennisgrafiek niet laden';

  @override
  String knowledgeGraphLinkedSection(int count) {
    return 'GELINKEERD $count';
  }

  @override
  String get knowledgeGraphMoreLinks => 'meer links';

  @override
  String knowledgeGraphNodeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nodes',
      one: '1 knoop',
    );
    return '$_temp0';
  }

  @override
  String get knowledgeGraphNodeTypeAiSummary => 'Samenvatting van de AI';

  @override
  String get knowledgeGraphNodeTypeAudioNote => 'Geluidsnotitie';

  @override
  String get knowledgeGraphNodeTypeChecklist => 'Checklist';

  @override
  String get knowledgeGraphNodeTypeChecklistItem => 'Controlelijst-item';

  @override
  String get knowledgeGraphNodeTypeNote => 'Opmerking';

  @override
  String get knowledgeGraphNodeTypePhoto => 'Foto';

  @override
  String get knowledgeGraphNodeTypeProject => 'Project';

  @override
  String get knowledgeGraphNodeTypeRating => 'Waardering';

  @override
  String get knowledgeGraphNodeTypeTask => 'Taak';

  @override
  String get knowledgeGraphOpenDetails => 'Open details';

  @override
  String get knowledgeGraphRecenter => 'Recent';

  @override
  String get knowledgeGraphRecentToOlder => 'recent → ouder';

  @override
  String get knowledgeGraphRelationAiSource => 'AI bron';

  @override
  String get knowledgeGraphRelationChecklist => 'checklist';

  @override
  String get knowledgeGraphRelationInProject => 'in project';

  @override
  String get knowledgeGraphRelationLinkedTask => 'verbonden taak';

  @override
  String get knowledgeGraphRelationNoteLog => 'notitie / log';

  @override
  String get knowledgeGraphRelationRating => 'rating';

  @override
  String get knowledgeGraphSummarySection => 'SAMENVATTING';

  @override
  String get knowledgeGraphTitle => 'Kennisgrafiek';

  @override
  String get knowledgeGraphTooltip => 'Verkennen van links';

  @override
  String knowledgeGraphWalkHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nodes',
      one: '1 knoop',
    );
    return 'Tik op een knooppunt om te lopen · $_temp0';
  }

  @override
  String get linkedFromCaption => 'van';

  @override
  String get linkedTaskImageBadge => 'Van verbonden taak';

  @override
  String get linkedTasksMenuTooltip => 'Gekoppelde takenopties';

  @override
  String get linkedTasksTitle => 'Gekoppelde taken';

  @override
  String get linkedToCaption => 'tot';

  @override
  String get linkExistingTask => 'Bestaande taak koppelen...';

  @override
  String get loggingDomainAgentRuntime => 'Agent runtime';

  @override
  String get loggingDomainAgentWorkflow => 'Werkstroom van het agentschap';

  @override
  String get loggingDomainAi => 'AI';

  @override
  String get loggingDomainCalendar => 'Agenda & tijd';

  @override
  String get loggingDomainChat => 'Gesprek';

  @override
  String get loggingDomainDailyOs => 'Dagelijks besturingssysteem';

  @override
  String get loggingDomainDatabase => 'Database';

  @override
  String get loggingDomainGeneral => 'Algemeen';

  @override
  String get loggingDomainHabits => 'Gewoontes';

  @override
  String get loggingDomainHealth => 'Gezondheid';

  @override
  String get loggingDomainLabels => 'Etiketten';

  @override
  String get loggingDomainLocation => 'Locatie';

  @override
  String get loggingDomainNavigation => 'Navigatie';

  @override
  String get loggingDomainNotifications => 'Kennisgevingen';

  @override
  String get loggingDomainOnboarding => 'Aan boord gaan van & FTUE';

  @override
  String get loggingDomainPersistence => 'Persistentie';

  @override
  String get loggingDomainRatings => 'Waarderingen';

  @override
  String get loggingDomainScreenshots => 'Schermafbeeldingen';

  @override
  String get loggingDomainSettings => 'Instellingen';

  @override
  String get loggingDomainSpeech => 'Spraak & audio';

  @override
  String get loggingDomainSync => 'Synchroniseren';

  @override
  String get loggingDomainTasks => 'Taken & controlelijsten';

  @override
  String get loggingDomainTheming => 'Thema';

  @override
  String get loggingDomainWhatsNew => 'Wat is er nieuw?';

  @override
  String get maintenanceDeleteAgentDb => 'Database verwijderen';

  @override
  String get maintenanceDeleteAgentDbDescription =>
      'Database verwijderen en app herstarten';

  @override
  String get maintenanceDeleteDatabaseConfirm => 'Ja, DELETE DATABASE';

  @override
  String maintenanceDeleteDatabaseQuestion(String databaseName) {
    return 'Weet u zeker dat u wilt verwijderen $databaseName Database?';
  }

  @override
  String get maintenanceDeleteEditorDb => 'Editordatabase verwijderen';

  @override
  String get maintenanceDeleteEditorDbDescription =>
      'Editor concepts database verwijderen';

  @override
  String get maintenanceDeleteSyncDb => 'Synchronisatiedatabase verwijderen';

  @override
  String get maintenanceDeleteSyncDbDescription => 'Sync-database verwijderen';

  @override
  String get maintenanceGenerateEmbeddings => 'Inbeddingen genereren';

  @override
  String get maintenanceGenerateEmbeddingsConfirm => 'Ja, Generate.';

  @override
  String get maintenanceGenerateEmbeddingsDescription =>
      'Inbeddingen voor items in geselecteerde categorieën genereren';

  @override
  String get maintenanceGenerateEmbeddingsMessage =>
      'Selecteer categorieën om inbeddingen voor te genereren.';

  @override
  String maintenanceGenerateEmbeddingsProgress(
    int processed,
    int total,
    int embedded,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$processed \' $total vermeldingen ($embedded ingesloten)',
      one: '$processed \' $total vermelding ($embedded ingesloten)',
    );
    return '$_temp0';
  }

  @override
  String get maintenancePopulatePhaseAgentEntities =>
      'Bezig met verwerken van agent entiteiten...';

  @override
  String get maintenancePopulatePhaseAgentLinks => 'Verwerkers...';

  @override
  String get maintenancePopulatePhaseJournal => 'Journalen worden verwerkt...';

  @override
  String get maintenancePopulatePhaseLinks => 'Verwerken van invoerlinks...';

  @override
  String get maintenancePopulateSequenceLog =>
      'Sync-sequentielogboek populeren';

  @override
  String maintenancePopulateSequenceLogComplete(int count) {
    return '$count geïndexeerde vermeldingen';
  }

  @override
  String get maintenancePopulateSequenceLogConfirm => 'Ja, populaat';

  @override
  String get maintenancePopulateSequenceLogDescription =>
      'Bestaande items indexeren voor backfill ondersteuning';

  @override
  String get maintenancePopulateSequenceLogMessage =>
      'Dit zal alle journaal-items scannen en ze toevoegen aan het sync-sequentielogboek. Dit maakt backfill-responsen mogelijk voor items die zijn gemaakt voordat deze functie is toegevoegd.';

  @override
  String get maintenancePurgeDeleted => 'Verwijderde items verwijderen';

  @override
  String get maintenancePurgeDeletedConfirm => 'Ja, alles zuiveren.';

  @override
  String get maintenancePurgeDeletedDescription =>
      'Alle verwijderde items permanent verwijderen';

  @override
  String get maintenancePurgeDeletedMessage =>
      'Weet u zeker dat u alle verwijderde items wilt verwijderen? Deze actie kan niet ongedaan worden gemaakt.';

  @override
  String get maintenancePurgeSentOutbox =>
      'Oude verzonden postvak UIT verwijderen';

  @override
  String get maintenancePurgeSentOutboxConfirm => 'Ja, schat.';

  @override
  String get maintenancePurgeSentOutboxDescription =>
      'Verwijder verzonden outbox rijen ouder dan 7 dagen en recupereer schijf';

  @override
  String get maintenancePurgeSentOutboxQuestion =>
      'Verwijder verzonden postvak UIT items ouder dan 7 dagen? Dit verwijdert reeds verzonden rijen in blokken en draait VACUUM om schijf terug te vorderen. In afwachting en fout items worden bewaard.';

  @override
  String get maintenanceRecreateFts5 =>
      'Volledige tekst-index opnieuw aanmaken';

  @override
  String get maintenanceRecreateFts5Confirm => 'Ja, RECREATE INDEX';

  @override
  String get maintenanceRecreateFts5Description =>
      'Volledige-tekstzoekindex opnieuw aanmaken';

  @override
  String get maintenanceRecreateFts5Message =>
      'Weet u zeker dat u de volledige tekstindex wilt namaken? Dit kan enige tijd duren.';

  @override
  String get maintenanceReSync => 'Berichten opnieuw synchroniseren';

  @override
  String get maintenanceReSyncAgentEntities => 'Agententiteiten';

  @override
  String get maintenanceReSyncDescription =>
      'Berichten van de server opnieuw synchroniseren';

  @override
  String get maintenanceReSyncEntityTypes => 'Soorten entiteiten';

  @override
  String get maintenanceReSyncJournalEntities => 'Journalentiteiten';

  @override
  String get maintenanceReSyncSelectAtLeastOne =>
      'Selecteer ten minste één entiteittype';

  @override
  String get maintenanceReSyncStart => 'Begin';

  @override
  String get maintenanceSyncDefinitions =>
      'Meetbare gegevens synchroniseren, dashboards, gewoonten, categorieën, AI-instellingen';

  @override
  String get maintenanceSyncDefinitionsDescription =>
      'Meetbare gegevens synchroniseren, dashboards, gewoonten, categorieën en AI-instellingen';

  @override
  String get manageLinks => 'Links beheren...';

  @override
  String get matrixStatsCatchupBatches => 'Inhaalpartijen';

  @override
  String get matrixStatsCircuitOpens => 'Circuit opent';

  @override
  String get matrixStatsConflicts => 'Conflicten';

  @override
  String get matrixStatsCopyDiagnostics => 'Diagnostiek kopiëren';

  @override
  String get matrixStatsCopyDiagnosticsTooltip =>
      'Sync diagnostics kopiëren naar het klembord';

  @override
  String get matrixStatsDbApplied => 'DB Toegepast';

  @override
  String get matrixStatsDbApply => 'DB toepassen';

  @override
  String get matrixStatsDbIgnoredVectorClock => 'DB-geïngeneerd (Vectorklok)';

  @override
  String get matrixStatsDbMissingBase => 'DB Ontbrekende basis';

  @override
  String matrixStatsDroppedByType(Object type) {
    return 'Gedropt ($type)';
  }

  @override
  String get matrixStatsEntryLinkNoops => 'EntryLink No-ops';

  @override
  String get matrixStatsFailures => 'Mislukt';

  @override
  String get matrixStatsFlushes => 'Flushes';

  @override
  String get matrixStatsForceRescan => 'Herscanen forceren';

  @override
  String get matrixStatsForceRescanTooltip => 'Herscannen en nu inhalen.';

  @override
  String get matrixStatsLegend => 'Legende';

  @override
  String get matrixStatsLegendTooltip =>
      'Legende: • verwerkt.<type> = verwerkt sync berichten per payload type • droppedByType.<type> = per type druppels na retrie- of ouder bericht negeert • dbToegepast = database rijen geschreven • dbIgnoredByVectorClock = oudere of identieke inkomende gegevens genegeerd door de database • conflictenCreated = gelijktijdige vector klokken gelogd • dbMissingBase = overgeslagen terwijl wachtte op een ontbrekende afhankelijkheid of basisrij • trueAttachmentPurges = gecached stamdescriptoren geklaard voordat ze werden ververst';

  @override
  String get matrixStatsProcessed => 'Bewerkt';

  @override
  String matrixStatsProcessedByType(Object type) {
    return 'Verwerkt ($type)';
  }

  @override
  String get matrixStatsRefresh => 'Verversen';

  @override
  String get matrixStatsReliability => 'Betrouwbaarheid';

  @override
  String get matrixStatsRetriesScheduled => 'Geplande herstart';

  @override
  String get matrixStatsRetryNow => 'Nu opnieuw proberen';

  @override
  String get matrixStatsRetryNowTooltip =>
      'Herstarten van nog niet-afgebroken programma';

  @override
  String get matrixStatsSignalLatencyLast => 'Signaallekkage (laatste ms)';

  @override
  String get matrixStatsSignalLatencyMax => 'Signaallekkage (max ms)';

  @override
  String get matrixStatsSignalLatencyMin => 'Signaalsterkte (min ms)';

  @override
  String get matrixStatsSignals => 'Signalen';

  @override
  String get matrixStatsSignalsClientStream => 'Signalen (clientstream)';

  @override
  String get matrixStatsSignalsConnectivity => 'Signalen (connectiviteit)';

  @override
  String get matrixStatsSignalsTimelineCallbacks =>
      'Signalen (tijdlijn terugroep)';

  @override
  String get matrixStatsSkipped => 'Overgeslagen';

  @override
  String get matrixStatsSkippedRetryCap => 'Overgeslagen (herhalingskap)';

  @override
  String get matrixStatsStaleAttachmentPurges => 'Stambijlagen';

  @override
  String get matrixStatsThroughput => 'Doorvoer';

  @override
  String get matrixStatsTopKpis => 'Top KPI\'s';

  @override
  String get measurableDeleteConfirm => 'Ja, delete dit metasurable';

  @override
  String get measurableDeleteQuestion =>
      'Wilt u dit meetbare gegevenstype verwijderen?';

  @override
  String get measurableNotFound => 'Maattabel niet gevonden';

  @override
  String get measurementCommentHint => 'Nota toevoegen (facultatief)';

  @override
  String get measurementCommentSemantic => 'Opmerking, facultatief';

  @override
  String measurementObservedAtChangeSemantic(String dateTime) {
    return 'Waargenomen bij $dateTime. Wijziging datum en tijd.';
  }

  @override
  String get measurementQuickAddLabel => 'Snel loggen';

  @override
  String measurementQuickLogSemantic(String value) {
    return 'Log $value onmiddellijk';
  }

  @override
  String get measurementSaveError =>
      'Kon deze meting niet opslaan. Probeer het opnieuw.';

  @override
  String get measurementSetObservedAtNowSemantic =>
      'Stel de waargenomen datum en tijd in tot nu';

  @override
  String get measurementTimeLabel => 'Tijd';

  @override
  String measurementValueSemantic(String measurable) {
    return 'Waarde voor $measurable';
  }

  @override
  String get mediaShowInFileExplorerAction => 'Toon in bestandsverkenner';

  @override
  String get mediaShowInFilesAction => 'In bestanden tonen';

  @override
  String get mediaShowInFinderAction => 'Toon in zoeker';

  @override
  String get modalityAudioDescription => 'Audiobewerkingsmogelijkheden';

  @override
  String get modalityAudioName => 'Audio';

  @override
  String get modalityImageDescription => 'Afbeeldingsbewerkingsmogelijkheden';

  @override
  String get modalityImageName => 'Afbeelding';

  @override
  String get modalityTextDescription => 'Tekstgebaseerde inhoud en verwerking';

  @override
  String get modalityTextName => 'Tekst';

  @override
  String get modelAddPageTitle => 'Model toevoegen';

  @override
  String get modelEditBackTooltip => 'Terug';

  @override
  String get modelEditDescriptionHint => 'Beschrijf dit model';

  @override
  String get modelEditDescriptionLabel => 'Omschrijving';

  @override
  String get modelEditDisplayNameHint => 'Een vriendelijke naam voor dit model';

  @override
  String get modelEditDisplayNameLabel => 'Naam tonen';

  @override
  String get modelEditFunctionCallingDescription =>
      'Dit model ondersteunt functie en tool calling.';

  @override
  String get modelEditFunctionCallingLabel => 'Functie aanroepen';

  @override
  String get modelEditGeminiThinkingModeLabel => 'Tweelingen denken modus';

  @override
  String get modelEditInputModalitiesHint => 'Selecteer invoertypen';

  @override
  String get modelEditInputModalitiesLabel => 'Invoervoorwaarden';

  @override
  String get modelEditLoadError => 'Laden van modelconfiguratie is mislukt';

  @override
  String get modelEditMaxTokensHint => 'Optioneel';

  @override
  String get modelEditMaxTokensLabel => 'Max. aanvultekens';

  @override
  String get modelEditModalityNoneSelected => 'Geen geselecteerd';

  @override
  String get modelEditOutputModalitiesHint => 'Selecteer uitvoertypen';

  @override
  String get modelEditOutputModalitiesLabel => 'Uitvoermodaliteiten';

  @override
  String get modelEditPageTitle => 'Model bewerken';

  @override
  String get modelEditProviderHint => 'Selecteer een provider';

  @override
  String get modelEditProviderLabel => 'Aanbieder';

  @override
  String get modelEditProviderModelIdHint => 'bv. gpt-4-turbo';

  @override
  String get modelEditProviderModelIdLabel =>
      'ID van het model van de aanbieder';

  @override
  String get modelEditReasoningDescription =>
      'Dit model maakt gebruik van uitgebreid denken / keten-van-denken.';

  @override
  String get modelEditReasoningLabel => 'Redeneringsmodel';

  @override
  String get modelEditSaveButton => 'Opslaan';

  @override
  String get modelEditSectionCapabilities => 'Mogelijkheden';

  @override
  String get modelEditSectionIdentity => 'Identiteit';

  @override
  String modelManagementSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count model$_temp0 geselecteerd';
  }

  @override
  String get multiSelectAddButton => 'Toevoegen';

  @override
  String multiSelectAddButtonWithCount(int count) {
    return 'Toevoegen ($count)';
  }

  @override
  String get multiSelectNoItemsFound => 'Geen items gevonden';

  @override
  String get navSidebarManualBrowserHint => 'Opent in uw browser';

  @override
  String get navSidebarManualLabel => 'Handmatig';

  @override
  String navTabMoreSemanticsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Meer. $count aanvullende bestemmingen',
      one: 'Meer, 1 extra bestemming',
    );
    return '$_temp0';
  }

  @override
  String get navTabTitleCalendar => 'DailyOS';

  @override
  String get navTabTitleEvents => 'Gebeurtenissen';

  @override
  String get navTabTitleHabits => 'Gewoontes';

  @override
  String get navTabTitleInsights => 'Inzichten';

  @override
  String get navTabTitleJournal => 'Logboek';

  @override
  String get navTabTitleMore => 'Meer';

  @override
  String get navTabTitleProjects => 'Projecten';

  @override
  String get navTabTitleSettings => 'Instellingen';

  @override
  String get navTabTitleTasks => 'Taken';

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
  String get noDefaultLanguage => 'Geen standaardtaal';

  @override
  String get noTasksFound => 'Geen taken gevonden';

  @override
  String get noTasksToLink => 'Geen taken beschikbaar om te koppelen';

  @override
  String get notificationBellEmptySemantics =>
      'Meldingen, geen ongelezen waarschuwingen';

  @override
  String get notificationBellTooltip => 'Kennisgevingen';

  @override
  String notificationBellUnseenSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'signaleringen',
      one: 'alarm',
    );
    return 'Kennisgevingen, $count ongelezen $_temp0';
  }

  @override
  String get notificationInboxDismiss => 'Mededeling verwerpen';

  @override
  String get notificationInboxEmpty => 'Je bent helemaal bij.';

  @override
  String get notificationInboxError => 'Kon notificatieberichten niet laden.';

  @override
  String get notificationInboxTitle => 'Kennisgevingen';

  @override
  String get notificationSuggestionAttentionBodyFallback =>
      'Open de taak om te beoordelen.';

  @override
  String notificationSuggestionAttentionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count suggesties hebben uw aandacht nodig',
      one: '1 suggestie heeft uw aandacht nodig',
    );
    return '$_temp0';
  }

  @override
  String get onboardingApiKeyConnect => 'Verbinden';

  @override
  String get onboardingApiKeyConnecting => 'Verbinden...';

  @override
  String get onboardingApiKeyEnterKeyHint =>
      'Voer een geldige sleutel in om door te gaan.';

  @override
  String get onboardingApiKeyError =>
      'Kon geen verbinding maken. Controleer je sleutel en probeer het opnieuw.';

  @override
  String get onboardingApiKeyField => 'API-sleutel';

  @override
  String get onboardingApiKeyGetKeyAt => 'Pak een sleutel bij';

  @override
  String get onboardingApiKeyHide => 'Sleutel verbergen';

  @override
  String get onboardingApiKeyInvalid =>
      'Die sleutel is geweigerd, dubbel gecontroleerd en opnieuw geplakt.';

  @override
  String get onboardingApiKeyLocalNote =>
      'Runs op uw apparaat .. geen sleutel nodig.';

  @override
  String get onboardingApiKeyNoKeyHelp =>
      'Hier nieuw? Meld je aan, maak een API-toets en plak deze vervolgens gratis om te beginnen.';

  @override
  String get onboardingApiKeyReveal => 'Sleutel tonen';

  @override
  String get onboardingApiKeyTitle => 'Plak je API-sleutel';

  @override
  String onboardingApiKeyUnreachable(String providerName) {
    return 'Kon niet bereiken ${providerName}Controleer de sleutel of uw verbinding en probeer het opnieuw.';
  }

  @override
  String get onboardingApiKeyVerifying => 'Verifiëren...';

  @override
  String get onboardingCaptureCategoryPrompt => 'Waar moet dit land zijn?';

  @override
  String get onboardingCaptureListening => 'Luisteren... tik als je klaar bent';

  @override
  String get onboardingCaptureOrbLabel => 'Neem je gedachten op.';

  @override
  String get onboardingCaptureRatherType => '- Nogal type?';

  @override
  String get onboardingCaptureReassurance => 'Dan kun je alles aanpassen.';

  @override
  String get onboardingCaptureThinking =>
      'Je woorden veranderen in een taak...';

  @override
  String get onboardingCaptureTypePrompt => 'Typ je gedachten';

  @override
  String get onboardingCategoryAddOwn => 'Voeg je eigen';

  @override
  String get onboardingCategoryContinue => 'Doorgaan';

  @override
  String get onboardingCategoryExplanation =>
      'Elk gebied van je leven krijgt zijn eigen ruimte. Kies een die past .. of voeg je eigen.';

  @override
  String get onboardingCategoryFamily => 'Familie';

  @override
  String get onboardingCategoryFitness => 'Fitness';

  @override
  String get onboardingCategoryFriends => 'Vrienden';

  @override
  String get onboardingCategoryTitle => 'Waar moet je AI werken?';

  @override
  String get onboardingCategoryWhy => 'Waarom gebieden?';

  @override
  String onboardingCategoryWhyDetail(String provider) {
    return 'Elk gebied kan zijn eigen AI gebruiken. $provider zal de gebieden die u hier kiest stroom . Later kunt u verschillende gebieden verschillende AI\'s.';
  }

  @override
  String get onboardingCategoryWork => 'Werk';

  @override
  String get onboardingConnectGeminiName => 'Gemini';

  @override
  String get onboardingConnectGeminiTagline => 'Verenigde Staten';

  @override
  String get onboardingConnectLessOptions => 'Minder opties';

  @override
  String get onboardingConnectMistralName => 'Mistral';

  @override
  String get onboardingConnectMistralTagline => 'Europese Unie';

  @override
  String get onboardingConnectMoreOptions => 'Meer opties';

  @override
  String get onboardingConnectNotSure =>
      'Melious.ai is de aanbevolen standaard.';

  @override
  String get onboardingConnectOllamaName => 'Ollama';

  @override
  String get onboardingConnectOpenAiName => 'OpenAI';

  @override
  String get onboardingConnectQwenName => 'Qwen';

  @override
  String get onboardingConnectQwenTagline => 'China';

  @override
  String get onboardingConnectTitle => 'Kies de AI-hersenen voor uw taken';

  @override
  String get onboardingFirstTaskCreatedHint =>
      'Tik op uw taak om het te openen';

  @override
  String get onboardingFirstTaskCreatedTitle => 'Je eerste taak is klaar.';

  @override
  String get onboardingFirstTaskGuidance =>
      'Tik op om te praten en te zeggen wat moet doen . . Lotti maakt het in een echte taak.';

  @override
  String get onboardingFirstTaskSuggestionDentist =>
      'Boek een afspraak bij de tandarts';

  @override
  String get onboardingFirstTaskSuggestionMeeting =>
      'Bereid je voor op de vergadering van maandag';

  @override
  String get onboardingFirstTaskSuggestionPlanWeek => 'Plan mijn week';

  @override
  String get onboardingFirstTaskSuggestionsLabel => 'Begin met één van deze:';

  @override
  String get onboardingFirstTaskTitle => 'Maak je eerste taak aan';

  @override
  String get onboardingMetricsActiveDays => 'Actieve dagen';

  @override
  String get onboardingMetricsActiveDaysInFirstSeven =>
      'Actieve dagen in eerste 7';

  @override
  String get onboardingMetricsBaselineCohort => 'Basiscohort (pre-FTUE)';

  @override
  String get onboardingMetricsInstallFirstSeenUtc =>
      'Installeer eerst gezien (UTC)';

  @override
  String get onboardingMetricsNo => 'nee';

  @override
  String get onboardingMetricsReachedRealAha => 'Reached real aha';

  @override
  String get onboardingMetricsYes => 'ja';

  @override
  String get onboardingRecordingStyleAnalogue => 'Absolute';

  @override
  String get onboardingRecordingStyleContinue => 'Doorgaan';

  @override
  String get onboardingRecordingStyleExplanation =>
      'Kies een zoekopdracht voor de microfoon. Je kunt het op elk moment wijzigen in Instellingen.';

  @override
  String get onboardingRecordingStyleModern => 'Moderne energiebol';

  @override
  String get onboardingRecordingStyleTitle => 'Hoe moet het opnemen voelen?';

  @override
  String get onboardingRecordingStyleTryVoice => 'Probeer het met je stem';

  @override
  String get onboardingSuccessContinue => 'Aan de slag';

  @override
  String get onboardingSuccessSubtitle =>
      'Je AI-hersenen zijn verbonden en klaar om je woorden in taken te veranderen.';

  @override
  String get onboardingSuccessTitle => 'Je bent helemaal klaar.';

  @override
  String get onboardingWelcomeConnectButton => 'Kies uw AI-hersenen';

  @override
  String get onboardingWelcomeMessage =>
      'Sluit je AI-hersenen aan, spreek dan een gedachte en kijk hoe het een gestructureerde taak wordt.';

  @override
  String get onboardingWelcomeSkipButton => 'Kijk eerst om je heen.';

  @override
  String get onboardingWelcomeTitle => 'Lotti maakt er een plan van.';

  @override
  String get optionalCategoryLabel => 'Categorie (facultatief)';

  @override
  String get outboxActionRemove => 'Verwijderen';

  @override
  String get outboxActionRetry => 'Opnieuw proberen';

  @override
  String get outboxFailedReassurance =>
      'Nog steeds opgeslagen op dit apparaat . . Het zal synchroniseren zodra het probleem opgelost.';

  @override
  String get outboxFilterFailed => 'Fout';

  @override
  String get outboxFilterWaiting => 'Wachten';

  @override
  String get outboxMonitorAttachmentLabel => 'Bijlage';

  @override
  String get outboxMonitorDelete => 'verwijderen';

  @override
  String get outboxMonitorDeleteConfirmLabel => 'Verwijderen';

  @override
  String get outboxMonitorDeleteConfirmMessage =>
      'Weet u zeker dat u dit synchronisatie-item wilt verwijderen? Deze actie kan niet ongedaan worden gemaakt.';

  @override
  String get outboxMonitorDeleteFailed =>
      'Verwijderen mislukt. Probeer het opnieuw.';

  @override
  String get outboxMonitorDeleteSuccess => 'Item verwijderd';

  @override
  String get outboxMonitorEmptyDescription =>
      'Er zijn geen synchronisatie-items in deze weergave.';

  @override
  String get outboxMonitorEmptyTitle => 'Outbox is leeg';

  @override
  String get outboxMonitorFetchFailed =>
      'Kon de outbox niet laden. Trek om te vernieuwen en probeer het opnieuw.';

  @override
  String get outboxMonitorLabelError => 'fout';

  @override
  String get outboxMonitorLabelPending => 'in behandeling';

  @override
  String get outboxMonitorLabelSent => 'verzonden';

  @override
  String get outboxMonitorLabelSuccess => 'succes';

  @override
  String get outboxMonitorNoAttachment => 'geen bijlage';

  @override
  String get outboxMonitorPayloadSizeLabel => 'Grootte';

  @override
  String get outboxMonitorRetries => 'opnieuw';

  @override
  String get outboxMonitorRetriesLabel => 'Herhalingen';

  @override
  String get outboxMonitorRetry => 'opnieuw proberen';

  @override
  String get outboxMonitorRetryConfirmLabel => 'Nu opnieuw proberen';

  @override
  String get outboxMonitorRetryConfirmMessage =>
      'Dit synchronisatie-item nu opnieuw proberen?';

  @override
  String get outboxMonitorRetryFailed =>
      'Opnieuw proberen mislukt. Probeer het opnieuw.';

  @override
  String get outboxMonitorRetryQueued => 'Gepland opnieuw proberen';

  @override
  String get outboxMonitorSubjectLabel => 'Onderwerp';

  @override
  String get outboxMonitorVolumeChartTitle => 'Dagelijks synchroniseren volume';

  @override
  String get outboxRemoveConfirmMessage =>
      'Deze verandering is nog niet gesynchroniseerd. Het verwijderen van het hier betekent dat het niet bij je andere apparaten zal komen. Het blijft op dit apparaat.';

  @override
  String get outboxRemoveConfirmTitle => 'Uit de wachtrij verwijderen?';

  @override
  String get outboxRetryAll => 'Alles opnieuw proberen';

  @override
  String get outboxShowDetails => 'Technische details tonen';

  @override
  String get outboxStatusFailed => 'Kon niet verzenden';

  @override
  String get outboxStatusSending => 'Verzenden';

  @override
  String get outboxStatusSent => 'Verzonden';

  @override
  String get outboxStatusWaiting => 'Wachten om te verzenden';

  @override
  String outboxSummaryFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items konden niet verzonden worden',
      one: '1 item kon niet versturen',
    );
    return '$_temp0';
  }

  @override
  String outboxSummaryOffline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items zullen versturen wanneer u opnieuw verbinding maakt',
      one: '1 item zal versturen wanneer u opnieuw verbinding maakt',
    );
    return '$_temp0';
  }

  @override
  String outboxSummarySending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Verzenden $count items...',
      one: 'Een item versturen...',
    );
    return '$_temp0';
  }

  @override
  String get outboxSummarySynced => 'Alles is gesynchroniseerd.';

  @override
  String outboxSummaryWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items die wachten om te versturen',
      one: '1 item wacht om te versturen',
    );
    return '$_temp0';
  }

  @override
  String outboxTriedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Geprobeerd $count tijden',
      one: 'Ik heb het ooit geprobeerd.',
    );
    return '$_temp0';
  }

  @override
  String get panasCompletionText => 'Bedankt voor het invullen van de Panatas!';

  @override
  String get panasCompletionTitle => 'Afgewerkt';

  @override
  String get panasEmotionActive => 'Actief';

  @override
  String get panasEmotionAfraid => 'Bang';

  @override
  String get panasEmotionAlert => 'Waarschuwing';

  @override
  String get panasEmotionAshamed => 'Beschaamd';

  @override
  String get panasEmotionAttentive => 'Aanwezig';

  @override
  String get panasEmotionDetermined => 'Vastgesteld';

  @override
  String get panasEmotionDistressed => 'Gestresst';

  @override
  String get panasEmotionEnthusiastic => 'Enthousiaste';

  @override
  String get panasEmotionExcited => 'Opgewonden';

  @override
  String get panasEmotionGuilty => 'Schuldig';

  @override
  String get panasEmotionHostile => 'Vijandelijk';

  @override
  String get panasEmotionInspired => 'Geïnspireerd';

  @override
  String get panasEmotionInterested => 'Geïnteresseerd';

  @override
  String get panasEmotionIrritable => 'Irriteerbaar';

  @override
  String get panasEmotionJittery => 'Jittery';

  @override
  String get panasEmotionNervous => 'Zenuwachtig';

  @override
  String get panasEmotionProud => 'Trots';

  @override
  String get panasEmotionScared => 'Bang';

  @override
  String get panasEmotionStrong => 'Sterk';

  @override
  String get panasEmotionUpset => 'Overstuur';

  @override
  String get panasInstructionFootnote =>
      'Watson, D., Clark, L.A., & Tellegen, A. (1988). Ontwikkeling en validatie van korte maatregelen van positieve en negatieve invloed: De Panaceeënschalen. Journal of Personality and Social Psychology, 54(6), 1063';

  @override
  String get panasInstructionText =>
      'Geef aan in welke mate je je nu zo voelt, dat wil zeggen, op het huidige moment. 1 .Zeer licht of helemaal niet, 2 .Een beetje, 3 . Moderately, 4 .';

  @override
  String get panasInstructionTitle =>
      'Het schema van positieve en negatieve effecten (PANAS; Watson et al., 1988)';

  @override
  String get panasScaleALittle => 'Een beetje.';

  @override
  String get panasScaleExtremely => 'Extreem';

  @override
  String get panasScaleModerately => 'Matig';

  @override
  String get panasScaleQuiteABit => 'Nogal een beetje.';

  @override
  String get panasScaleVerySlightlyOrNotAtAll => 'Zeer licht of helemaal niet';

  @override
  String get privateLabel => 'Privé';

  @override
  String get privateSwitchDescription =>
      'Alleen zichtbaar wanneer privé-items getoond worden';

  @override
  String get projectAgentNotProvisioned =>
      'Er is nog geen projectmanager voor dit project voorzien.';

  @override
  String get projectAgentSectionTitle => 'Agent';

  @override
  String projectCountSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count projecten',
      one: '$count project',
    );
    return '$_temp0';
  }

  @override
  String get projectCreateButton => 'Nieuw project';

  @override
  String get projectCreateTitle => 'Project aanmaken';

  @override
  String get projectDetailTitle => 'Projectdetails';

  @override
  String get projectErrorCreateFailed => 'Fout bij het aanmaken van project.';

  @override
  String get projectErrorLoadFailed => 'Kon projectgegevens niet laden.';

  @override
  String get projectErrorLoadProjects => 'Fout bij laden van projecten';

  @override
  String get projectErrorUpdateFailed =>
      'Bijwerken van project is mislukt. Probeer het opnieuw.';

  @override
  String get projectFilterLabel => 'Project';

  @override
  String get projectHealthBandAtRisk => 'Risico';

  @override
  String get projectHealthBandBlocked => 'Geblokkeerd';

  @override
  String get projectHealthBandOnTrack => 'Op spoor';

  @override
  String get projectHealthBandSurviving => 'Overleven';

  @override
  String get projectHealthBandWatch => 'Kijk';

  @override
  String get projectHealthSectionTitle => 'Gezondheid van projecten';

  @override
  String projectHealthSummary(int projectCount, int taskCount) {
    String _temp0 = intl.Intl.pluralLogic(
      projectCount,
      locale: localeName,
      other: '$projectCount projecten',
      one: '$projectCount project',
    );
    String _temp1 = intl.Intl.pluralLogic(
      taskCount,
      locale: localeName,
      other: '$taskCount taken',
      one: '$taskCount taak',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get projectHealthTitle => 'Projecten';

  @override
  String projectLinkedTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count verbonden taken',
      one: '$count verbonden taak',
    );
    return '$_temp0';
  }

  @override
  String get projectLinkedTasks => 'Gekoppelde taken';

  @override
  String get projectManageTooltip => 'Projecten beheren';

  @override
  String get projectNoLinkedTasks => 'Nog geen taken verbonden';

  @override
  String get projectNoProjects => 'Nog geen projecten';

  @override
  String get projectNotFound => 'Project niet gevonden';

  @override
  String get projectPickerLabel => 'Project';

  @override
  String get projectPickerUnassigned => 'Geen project';

  @override
  String get projectRecommendationDismissTooltip => 'Ingerukt';

  @override
  String get projectRecommendationResolveTooltip => 'Markering is opgelost';

  @override
  String get projectRecommendationsTitle => 'Aanbevolen volgende stappen';

  @override
  String get projectRecommendationUpdateError =>
      'Ik kon de aanbeveling niet bijwerken.';

  @override
  String get projectsFilterStatusLabel => 'Status:';

  @override
  String get projectsFilterTooltip => 'Projecten filteren';

  @override
  String get projectShowcaseAiReportTitle => 'AI-verslag';

  @override
  String projectShowcaseBlockedLegend(int count) {
    return '$count Geblokkeerd';
  }

  @override
  String projectShowcaseBlockedTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count taken geblokkeerd',
      one: '$count taak geblokkeerd',
    );
    return '$_temp0';
  }

  @override
  String projectShowcaseCompletedLegend(int count) {
    return '$count Voltooid';
  }

  @override
  String get projectShowcaseDescriptionTitle => 'Omschrijving';

  @override
  String projectShowcaseDueDate(String date) {
    return 'Verloopdatum $date';
  }

  @override
  String get projectShowcaseHealthScoreDescription =>
      'Deze score is gebaseerd op taaksnelheid, blokkers en de tijd die nog rest tot de deadline.';

  @override
  String get projectShowcaseHealthScoreTitle => 'Gezondheidsscore';

  @override
  String get projectShowcaseNoResults =>
      'Geen projecten gevonden die overeenkomen met uw zoekopdracht.';

  @override
  String get projectShowcaseOneOnOneReviewsTab => 'One-on-one Reviews';

  @override
  String get projectShowcaseOngoing => 'Lopende';

  @override
  String get projectShowcaseProjectTasksTab => 'Projecttaken';

  @override
  String get projectShowcaseSearchHint => 'Zoeken in projecten';

  @override
  String projectShowcaseSessionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessies',
      one: '$count zitting',
    );
    return '$_temp0';
  }

  @override
  String projectShowcaseTasksCompleted(int completed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$completed\'$total voltooide taken',
      one: '$completed\'$total taak voltooid',
    );
    return '$_temp0';
  }

  @override
  String projectShowcaseUpdatedHoursAgo(int hours) {
    return 'Bijgewerkt ${hours}h geleden';
  }

  @override
  String projectShowcaseUpdatedMinutesAgo(int minutes) {
    return 'Bijgewerkt ${minutes}m geleden';
  }

  @override
  String get projectShowcaseUsefulness => 'Nuttige';

  @override
  String get projectShowcaseViewBlocker => 'Beeldblokker';

  @override
  String get projectStatusActive => 'Actief';

  @override
  String get projectStatusArchived => 'Gearchiveerd';

  @override
  String get projectStatusChangeTitle => 'Status wijzigen';

  @override
  String get projectStatusCompleted => 'Voltooid';

  @override
  String get projectStatusMonitoring => 'Toezicht';

  @override
  String get projectStatusOnHold => 'In wacht';

  @override
  String get projectStatusOpen => 'Openen';

  @override
  String get projectSummaryOutdated => 'Samenvatting verouderd.';

  @override
  String projectSummaryOutdatedScheduled(String date, String time) {
    return 'Samenvatting verouderd. Volgende update $date op $time.';
  }

  @override
  String get projectTargetDateLabel => 'Streefdatum';

  @override
  String get projectTitleLabel => 'Projecttitel';

  @override
  String get projectTitleRequired => 'Projecttitel kan niet leeg zijn';

  @override
  String get promptDefaultModelBadge => 'Standaard';

  @override
  String get promptGenerationCardTitle => 'AI Coding Prompt';

  @override
  String get promptGenerationCopiedSnackbar => 'Naar klembord gekopieerd';

  @override
  String get promptGenerationCopyButton => 'Waarschuwing kopiëren';

  @override
  String get promptGenerationCopyTooltip => 'Prompt naar klembord kopiëren';

  @override
  String get promptGenerationExpandTooltip => 'Volledige prompt tonen';

  @override
  String get promptGenerationFullPromptLabel => 'Volledige vraag:';

  @override
  String get promptSelectionModalTitle =>
      'Voorgeconfigureerde prompt selecteren';

  @override
  String get provisionedSyncBundleImported => 'Invoercode';

  @override
  String get provisionedSyncConfigureButton => 'Instellen';

  @override
  String get provisionedSyncCopiedToClipboard => 'Naar klembord gekopieerd';

  @override
  String get provisionedSyncDisconnect => 'Verbinding verbreken';

  @override
  String get provisionedSyncDone => 'Synchronisatie succesvol ingesteld';

  @override
  String get provisionedSyncError => 'Configuratie mislukt';

  @override
  String get provisionedSyncErrorConfigurationFailed =>
      'Er is een fout opgetreden tijdens de configuratie. Probeer het opnieuw.';

  @override
  String get provisionedSyncErrorLoginFailed =>
      'Aanmelden mislukt. Controleer uw referenties en probeer het opnieuw.';

  @override
  String get provisionedSyncImportButton => 'Importeren';

  @override
  String get provisionedSyncImportHint => 'Plakken van de code hier';

  @override
  String get provisionedSyncImportTitle => 'Instellingen synchroniseren';

  @override
  String get provisionedSyncInvalidBundle => 'Ongeldige voorzieningscode';

  @override
  String get provisionedSyncJoiningRoom =>
      'Synchronisatieruimte wordt binnengehaald...';

  @override
  String get provisionedSyncLoggingIn => 'Inloggen...';

  @override
  String get provisionedSyncPasteClipboard => 'Plakken vanaf klembord';

  @override
  String get provisionedSyncReady => 'Scan deze QR-code op uw mobiele apparaat';

  @override
  String get provisionedSyncRetry => 'Opnieuw proberen';

  @override
  String get provisionedSyncRotatingPassword => 'Account beveiligen...';

  @override
  String get provisionedSyncScanButton => 'Scan QR-code';

  @override
  String get provisionedSyncShowQr => 'Voorziening QR tonen';

  @override
  String get provisionedSyncSubtitle =>
      'Synchronisatie instellen uit een voorzieningbundel';

  @override
  String get provisionedSyncSummaryHomeserver => 'Homeserver';

  @override
  String get provisionedSyncSummaryRoom => 'Kamer';

  @override
  String get provisionedSyncSummaryUser => 'Gebruiker';

  @override
  String get provisionedSyncTitle => 'Voorzien van een synchronisatie';

  @override
  String get provisionedSyncVerifyDevicesTitle => 'Apparaatverificatie';

  @override
  String get queueCatchUpNowButton => 'Inhalen nu';

  @override
  String get queueCatchUpNowDone => 'De inhaalslag is aan het draineren.';

  @override
  String queueCatchUpNowError(String reason) {
    return 'Inhaalactie mislukt: $reason';
  }

  @override
  String get queueDepthCardEmpty => 'Wachtrij leeg .. werknemer is ingehaald.';

  @override
  String get queueDepthCardLoading => 'Lezen van wachtrijdiepte...';

  @override
  String get queueDepthCardTitle => 'Inkomende wachtrij';

  @override
  String get queueFetchAllHistoryCancel => 'Annuleren';

  @override
  String queueFetchAllHistoryCancelled(int events) {
    String _temp0 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: '$events gebeurtenissen',
      one: '1 gebeurtenis',
      zero: 'geen gebeurtenissen',
    );
    return 'Geannuleerd $_temp0 Tot nu toe gehaald.';
  }

  @override
  String get queueFetchAllHistoryClose => 'Sluiten';

  @override
  String get queueFetchAllHistoryDescription =>
      'Loopt de hele zichtbare geschiedenis van de kamer in de wachtrij. Veilig te annuleren; een latere run hervat van waar de paginatie gestopt is.';

  @override
  String queueFetchAllHistoryDone(int events, int pages) {
    String _temp0 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages pagina\'s',
      one: '1 pagina',
    );
    String _temp1 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages pagina\'s',
      one: '1 pagina',
    );
    String _temp2 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: '$events gebeurtenissen opgehaald in $_temp0.',
      one: '1 gebeurtenis opgehaald in $_temp1.',
      zero: 'Geen gebeurtenissen opgehaald.',
    );
    return '$_temp2';
  }

  @override
  String queueFetchAllHistoryError(String reason) {
    return 'Ophalen gestopt: $reason';
  }

  @override
  String get queueFetchAllHistoryErrorUnknown =>
      'De ophaalhaling stopte onverwacht.';

  @override
  String queueFetchAllHistoryProgress(int events, int pages) {
    String _temp0 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: 'Pagina $pages · $events gebeurtenissen opgehaald',
      one: 'Pagina $pages · 1 gebeurtenis opgehaald',
    );
    return '$_temp0';
  }

  @override
  String get queueFetchAllHistoryTitle => 'Geschiedenis ophalen';

  @override
  String queueSkippedBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count overgeslagen',
      one: '1 overgeslagen',
    );
    return '$_temp0';
  }

  @override
  String queueSkippedCardBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Synchroniseer gebeurtenissen die de wachtrij heeft opgegeven. Tik op opnieuw proberen om opnieuw te starten.',
      one:
          '1 synchronisatie-gebeurtenis waarmee de wachtrij is gestopt. Tik op opnieuw proberen om opnieuw te vervoegen.',
    );
    return '$_temp0';
  }

  @override
  String get queueSkippedCardTitle => 'Overgeslagen gebeurtenissen';

  @override
  String get queueSkippedRetryAll =>
      'Overgeslagen gebeurtenissen opnieuw proberen';

  @override
  String queueSkippedRetryAllDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gebeurtenissen in de wachtrij voor opnieuw proberen.',
      one: '1 gebeurtenis in de wachtrij voor opnieuw proberen.',
      zero: 'Geen overgeslagen gebeurtenissen om opnieuw te proberen.',
    );
    return '$_temp0';
  }

  @override
  String queueSkippedRetryAllError(String reason) {
    return 'Opnieuw proberen mislukt: $reason';
  }

  @override
  String get referenceImageContinue => 'Doorgaan';

  @override
  String referenceImageContinueWithCount(int count) {
    return 'Doorgaan ($count)';
  }

  @override
  String get referenceImageLoadError =>
      'Kon afbeeldingen niet laden. Probeer het opnieuw.';

  @override
  String get referenceImageSelectionSubtitle =>
      'Kies maximaal 5 afbeeldingen om de visuele stijl van de AI te begeleiden';

  @override
  String get referenceImageSelectionTitle => 'Selecteer referentieafbeeldingen';

  @override
  String get referenceImageSkip => 'Overslaan';

  @override
  String get saveButton => 'Opslaan';

  @override
  String get saveButtonLabel => 'Opslaan';

  @override
  String get saveLabel => 'Opslaan';

  @override
  String get saveShortcutTooltip => 'Opslaan';

  @override
  String get saveSuccessful => 'Opgeslagen met succes';

  @override
  String get searchHint => 'Zoeken...';

  @override
  String get searchModeFullText => 'Volledige tekst';

  @override
  String get searchModeVector => 'Vector';

  @override
  String get searchTasksHint => 'Zoeken taken...';

  @override
  String get selectButton => 'Selecteren';

  @override
  String get selectColor => 'Een kleur selecteren';

  @override
  String get selectLanguage => 'Taal selecteren';

  @override
  String get sessionRatingCardLabel => 'Sessie-klasse';

  @override
  String get sessionRatingChallengeJustRight => 'Precies goed.';

  @override
  String get sessionRatingChallengeTooEasy => 'Te makkelijk.';

  @override
  String get sessionRatingChallengeTooHard => 'Te uitdagend';

  @override
  String get sessionRatingDifficultyLabel => 'Dit werk voelde...';

  @override
  String get sessionRatingEditButton => 'Waardering bewerken';

  @override
  String get sessionRatingEnergyQuestion => 'Hoe energiek voelde je je?';

  @override
  String get sessionRatingFocusQuestion => 'Hoe geconcentreerd was je?';

  @override
  String get sessionRatingNoteHint => 'Snelnote (facultatief)';

  @override
  String get sessionRatingProductivityQuestion =>
      'Hoe productief was deze sessie?';

  @override
  String get sessionRatingRateAction => 'Sessie beoordelen';

  @override
  String get sessionRatingSaveButton => 'Opslaan';

  @override
  String get sessionRatingSaveError =>
      'Opslaan van rating is mislukt. Probeer het opnieuw.';

  @override
  String get sessionRatingSkipButton => 'Overslaan';

  @override
  String get sessionRatingTitle => 'Deze sessie beoordelen';

  @override
  String get sessionRatingViewAction => 'Waardering weergeven';

  @override
  String get settingsAboutAppInformation => 'App-informatie';

  @override
  String get settingsAboutAppTagline => 'Uw persoonlijke dagboek';

  @override
  String get settingsAboutBuildType => 'Bouwtype';

  @override
  String get settingsAboutDailyOsPersonalizationTitle =>
      'Dagelijkse OS-personalisatie';

  @override
  String get settingsAboutDailyOsUserNameHelper =>
      'Gebruikt voor de dagelijkse OS begroeting en gesynchroniseerd op uw apparaten.';

  @override
  String get settingsAboutDailyOsUserNameLabel => 'Uw naam';

  @override
  String get settingsAboutJournalEntries => 'Journal Inzendingen';

  @override
  String get settingsAboutPlatform => 'Platform';

  @override
  String get settingsAboutTitle => 'Over Lotti';

  @override
  String get settingsAboutVersion => 'Versie';

  @override
  String get settingsAboutYourData => 'Uw gegevens';

  @override
  String get settingsAdvancedAboutSubtitle =>
      'Meer informatie over de Lotti-toepassing';

  @override
  String get settingsAdvancedHealthImportSubtitle =>
      'Invoer van gezondheidsgerelateerde gegevens uit externe bronnen';

  @override
  String get settingsAdvancedMaintenanceSubtitle =>
      'Onderhoudstaken uitvoeren om de prestaties van de toepassing te optimaliseren';

  @override
  String get settingsAdvancedManualLanguageSubtitle =>
      'Kies welke taal u de Lotti handleiding in opent';

  @override
  String get settingsAdvancedOutboxSubtitle => 'Synchronisatie-items beheren';

  @override
  String get settingsAdvancedSubtitle =>
      'Geavanceerde instellingen en onderhoud';

  @override
  String get settingsAdvancedTitle => 'Geavanceerde instellingen';

  @override
  String get settingsAgentsInstancesSubtitle => 'Werktuig';

  @override
  String get settingsAgentsPendingWakesSubtitle => 'Geplande wektimers';

  @override
  String get settingsAgentsSoulsSubtitle =>
      'Lange-levende agent persoonlijkheden';

  @override
  String get settingsAgentsStatsSubtitle =>
      'Gebruik en activiteit van de token';

  @override
  String get settingsAgentsTemplatesSubtitle => 'Gedeelde agent blauwdrukken';

  @override
  String get settingsAiModelsSubtitle =>
      'Per provider model rijen en mogelijkheden';

  @override
  String get settingsAiModelsTitle => 'Modellen';

  @override
  String get settingsAiProfilesSubtitle => 'Aanbieders en modellen';

  @override
  String get settingsAiProfilesTitle => 'Inferentieprofielen';

  @override
  String get settingsAiProvidersSubtitle =>
      'Aangesloten AI-providers en sleutels';

  @override
  String get settingsAiProvidersTitle => 'Aanbieders';

  @override
  String get settingsAiSubtitle =>
      'AI providers, modellen en prompts configureren';

  @override
  String get settingsAiTitle => 'AI-instellingen';

  @override
  String get settingsAiUsageSubtitle =>
      'Kosten, energie en CO2e van AI-oproepen';

  @override
  String get settingsAiUsageTitle => 'Gebruik & impact';

  @override
  String get settingsBeamPageEditModelTitle => 'Model bewerken';

  @override
  String get settingsBeamPageEditProfileTitle => 'Profiel bewerken';

  @override
  String get settingsCategoriesCreateTitle => 'Categorie aanmaken';

  @override
  String get settingsCategoriesDetailsLabel => 'Categorie bewerken';

  @override
  String get settingsCategoriesEmptyState => 'Nog geen categorieën';

  @override
  String get settingsCategoriesEmptyStateHint =>
      'Maak een categorie om uw items te organiseren';

  @override
  String get settingsCategoriesErrorLoading => 'Fout bij laden categorieën';

  @override
  String get settingsCategoriesNameLabel => 'Categorienaam';

  @override
  String settingsCategoriesNoMatchQuery(String query) {
    return 'Geen categorieën overeenkomen \"$query\"';
  }

  @override
  String get settingsCategoriesSearchHint => 'Zoeken in categorieën...';

  @override
  String get settingsCategoriesSubtitle => 'Categorieën met AI-instellingen';

  @override
  String settingsCategoriesTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count taken',
      one: '$count taak',
    );
    return '$_temp0';
  }

  @override
  String get settingsCategoriesTitle => 'Categorieën';

  @override
  String get settingsCelebrationsChecklistDescription =>
      'Een pop en vonken wanneer u een item uit controleren';

  @override
  String get settingsCelebrationsChecklistTitle => 'Checklist-items';

  @override
  String get settingsCelebrationsCustomizeTitle => 'Aanpassen';

  @override
  String get settingsCelebrationsCustomizeTooltip => 'Deze stijl aanpassen';

  @override
  String get settingsCelebrationsEnabledDescription =>
      'Meester schakelaar voor voltooiing bloeit. Af verbergt elke animatie; haptici houden hun eigen schakelaar.';

  @override
  String get settingsCelebrationsEnabledTitle => 'Viering animaties';

  @override
  String get settingsCelebrationsGroupLook => 'Kijk.';

  @override
  String get settingsCelebrationsGroupMotion => 'Beweging';

  @override
  String get settingsCelebrationsGroupShape => 'Vorm';

  @override
  String get settingsCelebrationsHabitsDescription =>
      'Gloeien en vonken wanneer je een gewoonte voltooit';

  @override
  String get settingsCelebrationsHabitsTitle => 'Gewoontes';

  @override
  String get settingsCelebrationsHapticsDescription =>
      'Een korte buzz als je iets afmaakt .. onafhankelijk van de animatie.';

  @override
  String get settingsCelebrationsHapticsTitle => 'Afronding haptiek';

  @override
  String get settingsCelebrationsKnobClearCenter => 'Middenspleet';

  @override
  String get settingsCelebrationsKnobCount => 'Deeltjes';

  @override
  String get settingsCelebrationsKnobDescClearCenter =>
      'Lege ruimte in het midden';

  @override
  String get settingsCelebrationsKnobDescCount =>
      'Hoeveel deeltjes vliegen er uit?';

  @override
  String get settingsCelebrationsKnobDescFallout =>
      'Hoe ver vonken naar beneden drijven';

  @override
  String get settingsCelebrationsKnobDescFanSpread =>
      'Breedte van de ventilator';

  @override
  String get settingsCelebrationsKnobDescGlow => 'Sterkte van de gloed';

  @override
  String get settingsCelebrationsKnobDescGravity => 'Hoe snel deeltjes vallen';

  @override
  String get settingsCelebrationsKnobDescHalo => 'Sterkte van de halo';

  @override
  String get settingsCelebrationsKnobDescInnerRing =>
      'Grootte van de binnenring';

  @override
  String get settingsCelebrationsKnobDescLaunch => 'Vertraging voor de barst';

  @override
  String get settingsCelebrationsKnobDescPop => 'Als ze opduiken.';

  @override
  String get settingsCelebrationsKnobDescReach => 'Hoe ver deeltjes reizen';

  @override
  String get settingsCelebrationsKnobDescRise => 'Hoe hoog de deeltjes stijgen';

  @override
  String get settingsCelebrationsKnobDescSize => 'Hoe groot elk deeltje is';

  @override
  String get settingsCelebrationsKnobDescSpeedSpread =>
      'Variatie in deeltjessnelheid';

  @override
  String get settingsCelebrationsKnobDescSpin => 'Hoe snel stukken draaien';

  @override
  String get settingsCelebrationsKnobDescSpread => 'Breedte van de spray';

  @override
  String get settingsCelebrationsKnobDescSway => 'Hoeveel stukken swingen?';

  @override
  String get settingsCelebrationsKnobDescSwell => 'Hoeveel ze groeien.';

  @override
  String get settingsCelebrationsKnobDescTrail => 'Lengte van elk spoor';

  @override
  String get settingsCelebrationsKnobDescTwinkle =>
      'Hoeveel deeltjes flikkeren er?';

  @override
  String get settingsCelebrationsKnobDescUpward => 'Hoe sterk ze stijgen';

  @override
  String get settingsCelebrationsKnobDescWobble =>
      'Hoeveel stukjes wiebelen er?';

  @override
  String get settingsCelebrationsKnobFallout => 'Fallout';

  @override
  String get settingsCelebrationsKnobFanSpread => 'Ventilatorspreiding';

  @override
  String get settingsCelebrationsKnobGlow => 'Gloeien';

  @override
  String get settingsCelebrationsKnobGravity => 'Zwaartekracht';

  @override
  String get settingsCelebrationsKnobHalo => 'Halo';

  @override
  String get settingsCelebrationsKnobInnerRing => 'Binnenring';

  @override
  String get settingsCelebrationsKnobLaunch => 'Starttijd';

  @override
  String get settingsCelebrationsKnobPop => 'Pop-punt';

  @override
  String get settingsCelebrationsKnobReach => 'Bereiken';

  @override
  String get settingsCelebrationsKnobRise => 'Hoogte van de rijhoogte';

  @override
  String get settingsCelebrationsKnobSize => 'Grootte';

  @override
  String get settingsCelebrationsKnobSpeedSpread => 'Snelheidsvariatie';

  @override
  String get settingsCelebrationsKnobSpin => 'Draaien';

  @override
  String get settingsCelebrationsKnobSpread => 'Spread boog';

  @override
  String get settingsCelebrationsKnobSway => 'Sway';

  @override
  String get settingsCelebrationsKnobSwell => 'Geweldig.';

  @override
  String get settingsCelebrationsKnobTrail => 'Lengte van het spoor';

  @override
  String get settingsCelebrationsKnobTwinkle => 'Twinkelen';

  @override
  String get settingsCelebrationsKnobUpward => 'Stijgen';

  @override
  String get settingsCelebrationsKnobWobble => 'Wobble';

  @override
  String get settingsCelebrationsPlaygroundHint =>
      'Tik op de gemarkeerde rij om een voorbeeld te geven';

  @override
  String get settingsCelebrationsPlaygroundLiveNote =>
      'Wijzigingen overal direct opslaan en toepassen';

  @override
  String get settingsCelebrationsPreviewChecklistItem => 'Controleer me.';

  @override
  String get settingsCelebrationsPreviewDescription =>
      'Tik op een knop om de gekozen stijl af te spelen.';

  @override
  String get settingsCelebrationsPreviewDone => 'Klaar';

  @override
  String get settingsCelebrationsPreviewHabit => 'Gewoonte';

  @override
  String get settingsCelebrationsPreviewSample1 => 'Goedemorgen wandeling.';

  @override
  String get settingsCelebrationsPreviewSample2 => 'Het verslag afronden';

  @override
  String get settingsCelebrationsPreviewSample3 => 'Water de planten';

  @override
  String get settingsCelebrationsPreviewTitle => 'Probeer het.';

  @override
  String get settingsCelebrationsReplay => 'Herspelen';

  @override
  String get settingsCelebrationsResetToast => 'Standaard stijl terugzetten';

  @override
  String get settingsCelebrationsResetToDefault => 'Standaard terugzetten';

  @override
  String get settingsCelebrationsResetUndo => 'Ongedaan maken';

  @override
  String get settingsCelebrationsSectionDescription =>
      'Speel een bloeiende wanneer je iets af te maken. Schakel een uit houdt de voltooiing en de haptische . . het slaat gewoon de animatie.';

  @override
  String get settingsCelebrationsSectionTitle => 'Afrondingsfeesten';

  @override
  String get settingsCelebrationsStyleDescription =>
      'Tik op een kaart om een preview van een feestelijke stijl en maak het van jou.';

  @override
  String get settingsCelebrationsStyleTitle => 'Stijl';

  @override
  String get settingsCelebrationsSubtitle => 'Afrondingsfeesten';

  @override
  String get settingsCelebrationsTasksDescription =>
      'Gloeien en vonken wanneer u een taak naar gedaan verplaatsen';

  @override
  String get settingsCelebrationsTasksTitle => 'Taken';

  @override
  String get settingsCelebrationsTitle => 'Animaties';

  @override
  String get settingsCelebrationsVariantBubbles => 'Bubbels';

  @override
  String get settingsCelebrationsVariantCombine => 'Combineer twee';

  @override
  String get settingsCelebrationsVariantCombineDescription =>
      'Twee willekeurige stijlen, gelaagd, elke keer';

  @override
  String get settingsCelebrationsVariantConfetti => 'ConfettiCity in Italy';

  @override
  String get settingsCelebrationsVariantEmbers =>
      'EmbersCity in Ontario Canada';

  @override
  String get settingsCelebrationsVariantFireworks => 'Vuurwerk';

  @override
  String get settingsCelebrationsVariantRandom => 'Willekeurig';

  @override
  String get settingsCelebrationsVariantRandomDescription =>
      'Een frisse stijl bij elke voltooiing';

  @override
  String get settingsCelebrationsVariantSparks => 'Vonken';

  @override
  String get settingsConflictsTitle => 'Conflicten synchroniseren';

  @override
  String get settingsDashboardDetailsLabel => 'Dashboard bewerken';

  @override
  String get settingsDashboardSaveLabel => 'Opslaan';

  @override
  String get settingsDashboardsCreateTitle => 'Dashboard aanmaken';

  @override
  String get settingsDashboardsEmptyState => 'Nog geen dashboards';

  @override
  String get settingsDashboardsEmptyStateHint =>
      'Tik op de + knop om uw eerste dashboard te maken.';

  @override
  String get settingsDashboardsErrorLoading => 'Fout bij laden dashboards';

  @override
  String settingsDashboardsNoMatchQuery(String query) {
    return 'Geen dashboards komen overeen met \"$query\"';
  }

  @override
  String get settingsDashboardsSearchHint => 'Zoek dashboards...';

  @override
  String get settingsDashboardsSubtitle => 'Pas uw dashboardweergaven aan';

  @override
  String get settingsDashboardsTitle => 'Dashboards';

  @override
  String get settingsDefinitionsSubtitle =>
      'Gewoontes, categorieën, etiketten, dashboards en meetbare gegevens';

  @override
  String get settingsDefinitionsTitle => 'Definities';

  @override
  String get settingsFlagsEmptySearch =>
      'Geen vlaggen gevonden voor uw zoekopdracht';

  @override
  String get settingsFlagsSearchHint => 'Zoekvlaggen';

  @override
  String get settingsFlagsSubtitle => 'Functievlaggen en -opties configureren';

  @override
  String get settingsFlagsTitle => 'Vlaggen instellen';

  @override
  String get settingsHabitsCreateTitle => 'Gebruiking maken';

  @override
  String get settingsHabitsDeleteTooltip => 'Gewoonte verwijderen';

  @override
  String get settingsHabitsDescriptionLabel => 'Beschrijving (facultatief)';

  @override
  String get settingsHabitsDetailsLabel => 'Bewerken';

  @override
  String get settingsHabitsEmptyState => 'Nog geen gewoontes';

  @override
  String get settingsHabitsEmptyStateHint =>
      'Tik op de + knop om uw eerste gewoonte te maken.';

  @override
  String get settingsHabitsErrorLoading => 'Fout bij laden';

  @override
  String get settingsHabitsNameLabel => 'Naam van de habitat';

  @override
  String settingsHabitsNoMatchQuery(String query) {
    return 'Geen gewoontes komen overeen met \"$query\"';
  }

  @override
  String get settingsHabitsPrivateLabel => 'Privé: ';

  @override
  String get settingsHabitsSaveLabel => 'Opslaan';

  @override
  String get settingsHabitsSearchHint => 'Zoekgewoonten...';

  @override
  String get settingsHabitsSubtitle => 'Beheer uw gewoonten en routines';

  @override
  String get settingsHabitsTitle => 'Gewoontes';

  @override
  String get settingsHealthImportActivity =>
      'Gegevens over de invoeractiviteit';

  @override
  String get settingsHealthImportBloodPressure =>
      'Bloeddrukgegevens importeren';

  @override
  String get settingsHealthImportBodyMeasurement =>
      'Gegevens over de import van lichaamsmetingen';

  @override
  String get settingsHealthImportFromDate => 'Begin';

  @override
  String get settingsHealthImportHeartRate => 'Hartslaggegevens importeren';

  @override
  String get settingsHealthImportSleep => 'Slaapgegevens importeren';

  @override
  String get settingsHealthImportTitle => 'Gezondheidsimport';

  @override
  String get settingsHealthImportToDate => 'Einde';

  @override
  String get settingsHealthImportWorkout => 'Gegevens importeren';

  @override
  String get settingsKeyboardShortcutsSubtitle =>
      'De toetsenbordcombinaties leren voor snellere desktopnavigatie en bewerken';

  @override
  String get settingsKeyboardShortcutsTitle => 'Sneltoetsen';

  @override
  String get settingsLabelsCategoriesAdd => 'Categorie toevoegen';

  @override
  String get settingsLabelsCategoriesHeading => 'Toepasselijke categorieën';

  @override
  String get settingsLabelsCategoriesNone => 'Geldt voor alle categorieën';

  @override
  String get settingsLabelsCategoriesRemoveTooltip => 'Verwijderen';

  @override
  String get settingsLabelsColorHeading => 'Kleur';

  @override
  String get settingsLabelsColorSubheading => 'Snelle voorinstellingen';

  @override
  String get settingsLabelsCreateTitle => 'Label aanmaken';

  @override
  String get settingsLabelsDeleteConfirmAction => 'Verwijderen';

  @override
  String settingsLabelsDeleteConfirmMessage(Object labelName) {
    return 'Weet u zeker dat u wilt verwijderen \"$labelName\"? Taken met dit label zullen de opdracht verliezen.';
  }

  @override
  String get settingsLabelsDeleteConfirmTitle => 'Label verwijderen';

  @override
  String settingsLabelsDeleteSuccess(Object labelName) {
    return 'Label \"$labelName\" geschrapt';
  }

  @override
  String get settingsLabelsDescriptionHint =>
      'Leg uit wanneer dit label moet worden toegepast';

  @override
  String get settingsLabelsDescriptionLabel => 'Beschrijving (facultatief)';

  @override
  String get settingsLabelsEditTitle => 'Label bewerken';

  @override
  String get settingsLabelsEmptyState => 'Nog geen labels';

  @override
  String get settingsLabelsEmptyStateHint =>
      'Tik op de + knop om uw eerste label aan te maken.';

  @override
  String get settingsLabelsErrorLoading => 'Kon labels niet laden';

  @override
  String get settingsLabelsNameHint =>
      'Bug, laat de blokker los, synchroniseer...';

  @override
  String get settingsLabelsNameLabel => 'Labelnaam';

  @override
  String settingsLabelsNoMatchCreate(String query) {
    return 'Creëer \"$query\" label';
  }

  @override
  String settingsLabelsNoMatchQuery(String query) {
    return 'Geen labels die overeenkomen met \"$query\"';
  }

  @override
  String get settingsLabelsPrivateDescription =>
      'Alleen zichtbaar wanneer privé-items getoond worden';

  @override
  String get settingsLabelsPrivateTitle => 'Privé';

  @override
  String get settingsLabelsSearchHint => 'Zoeken naar labels...';

  @override
  String get settingsLabelsSubtitle => 'Taken met gekleurde labels organiseren';

  @override
  String get settingsLabelsTitle => 'Etiketten';

  @override
  String settingsLabelsUsageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count taken',
      one: '1 taak',
    );
    return '$_temp0';
  }

  @override
  String get settingsLoggingDomainsSubtitle =>
      'Bepaal welke domeinen naar het logboek schrijven';

  @override
  String get settingsLoggingDomainsTitle => 'Loggen van domeinnamen';

  @override
  String get settingsLoggingGlobalToggle => 'Loggen inschakelen';

  @override
  String get settingsLoggingGlobalToggleSubtitle =>
      'Hoofdschakelaar voor alle logging';

  @override
  String get settingsLoggingSlowQueries => 'Langzame database-vragen';

  @override
  String get settingsLoggingSlowQueriesSubtitle =>
      'Schrijft trage vragen naar slow_queries-JJJJ-MM-DD.log';

  @override
  String get settingsMaintenanceOnboardingAnimationGallerySubtitle =>
      'Vergelijk welkomst animaties + verbinding pagina live (debug)';

  @override
  String get settingsMaintenanceOnboardingAnimationGalleryTitle =>
      'Animatiegalerij aan boord';

  @override
  String get settingsMaintenanceOnboardingWelcomeSubtitle =>
      'Bekijk de FTUE welkomst + providertegels (debug)';

  @override
  String get settingsMaintenanceOnboardingWelcomeTitle =>
      'Ontvangst aan boord tonen';

  @override
  String get settingsMaintenanceTitle => 'Onderhoud';

  @override
  String get settingsManualLanguageCzechTitle => 'Tsjechisch';

  @override
  String get settingsManualLanguageDanishTitle => 'Deens';

  @override
  String get settingsManualLanguageDutchTitle => 'Nederlands';

  @override
  String get settingsManualLanguageEnglishTitle => 'Engels';

  @override
  String get settingsManualLanguageFollowSystemSubtitle =>
      'Gebruik de taal van je apparaat als die beschikbaar is.';

  @override
  String get settingsManualLanguageFollowSystemTitle => 'Systeem volgen';

  @override
  String get settingsManualLanguageFrenchTitle => 'Frans';

  @override
  String get settingsManualLanguageGermanTitle => 'Duits';

  @override
  String get settingsManualLanguageItalianTitle => 'Italiaans';

  @override
  String get settingsManualLanguagePortugueseTitle => 'Portugees';

  @override
  String get settingsManualLanguageRomanianTitle => 'Roemeens';

  @override
  String get settingsManualLanguageSpanishTitle => 'Spaans';

  @override
  String get settingsManualLanguageSwedishTitle => 'Zweeds';

  @override
  String get settingsManualLanguageTitle => 'Taal';

  @override
  String get settingsMatrixAccept => 'Accepteren';

  @override
  String get settingsMatrixAcceptVerificationLabel =>
      'Andere apparaat toont emojis, ga door';

  @override
  String get settingsMatrixCancel => 'Annuleren';

  @override
  String get settingsMatrixContinueVerificationLabel =>
      'Accepteer op een ander apparaat om door te gaan';

  @override
  String get settingsMatrixDiagnosticCopied =>
      'Diagnostische informatie gekopieerd naar klembord';

  @override
  String get settingsMatrixDiagnosticCopyButton => 'Kopiëren naar klembord';

  @override
  String get settingsMatrixDiagnosticDialogTitle =>
      'Diagnostische informatie synchroniseren';

  @override
  String get settingsMatrixDiagnosticShowButton =>
      'Diagnostische informatie tonen';

  @override
  String get settingsMatrixDone => 'Klaar';

  @override
  String get settingsMatrixLastUpdated => 'Laatst bijgewerkt:';

  @override
  String get settingsMatrixListUnverifiedLabel => 'Niet-verifieerde apparaten';

  @override
  String get settingsMatrixMaintenanceSubtitle =>
      'Start de onderhoudstaken en hersteltools van Matrix';

  @override
  String get settingsMatrixMaintenanceTitle => 'Onderhoud';

  @override
  String get settingsMatrixMetrics => 'Synchroniseren metrics';

  @override
  String get settingsMatrixNextPage => 'Volgende pagina';

  @override
  String get settingsMatrixNoUnverifiedLabel =>
      'Geen niet-geverifieerde apparaten';

  @override
  String get settingsMatrixPreviousPage => 'Vorige pagina';

  @override
  String settingsMatrixRoomInviteMessage(String roomId, String senderId) {
    return 'Uitnodigen naar kamer $roomId van ${senderId}Accepteren?';
  }

  @override
  String get settingsMatrixRoomInviteTitle => 'Kameruitnodiging';

  @override
  String get settingsMatrixSentMessagesLabel => 'Verzonden berichten:';

  @override
  String settingsMatrixSentMessageType(String eventType) {
    return 'Verzonden ($eventType)';
  }

  @override
  String get settingsMatrixStartVerificationLabel => 'Begincontrole';

  @override
  String get settingsMatrixStatsTitle => 'Matrix Stats';

  @override
  String get settingsMatrixTitle => 'Instellingen synchroniseren';

  @override
  String get settingsMatrixUnverifiedDevicesPage =>
      'Niet-verifieerde apparaten';

  @override
  String get settingsMatrixVerificationCancelledLabel =>
      'Geannuleerd op een ander apparaat...';

  @override
  String get settingsMatrixVerificationSuccessConfirm => 'Begrepen.';

  @override
  String settingsMatrixVerificationSuccessLabel(
    String deviceName,
    String deviceID,
  ) {
    return 'U heeft het succesvol geverifieerd $deviceName ($deviceID)';
  }

  @override
  String get settingsMatrixVerifyConfirm =>
      'Bevestig op een ander apparaat dat de emojis hieronder op beide apparaten worden weergegeven, in dezelfde volgorde:';

  @override
  String get settingsMatrixVerifyIncomingConfirm =>
      'Bevestig dat de emoji\'s hieronder op beide apparaten worden weergegeven, in dezelfde volgorde:';

  @override
  String get settingsMatrixVerifyLabel => 'Verifiëren';

  @override
  String get settingsMeasurableAggregationHelper =>
      'Hoe een dag inzendingen combineren op grafieken';

  @override
  String get settingsMeasurableAggregationLabel => 'Standaard aggregatietype';

  @override
  String get settingsMeasurableDeleteTooltip => 'Meetbaar type verwijderen';

  @override
  String get settingsMeasurableDescriptionLabel => 'Beschrijving (facultatief)';

  @override
  String get settingsMeasurableDetailsLabel => 'Meetbaar bewerken';

  @override
  String get settingsMeasurableNameLabel => 'Naam';

  @override
  String get settingsMeasurablePrivateLabel => 'Privé: ';

  @override
  String get settingsMeasurableSaveLabel => 'Opslaan';

  @override
  String get settingsMeasurablesCreateTitle => 'Meetbaar maken';

  @override
  String get settingsMeasurablesEmptyState => 'Nog geen meetbare waarden';

  @override
  String get settingsMeasurablesEmptyStateHint =>
      'Measurables zijn nummers die je volgt in de tijd .. gewicht, water, stappen.';

  @override
  String get settingsMeasurablesErrorLoading =>
      'Fout bij laden van meetbare gegevens';

  @override
  String settingsMeasurablesNoMatchQuery(String query) {
    return 'Geen meetbare overeenkomst \"$query\"';
  }

  @override
  String get settingsMeasurablesSearchHint => 'Meetbare zoekresultaten...';

  @override
  String get settingsMeasurablesSubtitle =>
      'Meetbare gegevenstypen configureren';

  @override
  String get settingsMeasurablesTitle => 'Meetbare';

  @override
  String get settingsMeasurableUnitLabel => 'Eenheidsafkorting (facultatief)';

  @override
  String get settingsOnboardingActionSubtitle =>
      'Open de welkomststroom . . Sluit uw AI-hersenen en maak een taak';

  @override
  String get settingsOnboardingMetricsSubtitle => 'FTUE trechter';

  @override
  String get settingsOnboardingMetricsTitle => 'Metrics aan boord';

  @override
  String get settingsOnboardingReplayTitle => 'Aan boord spelen';

  @override
  String get settingsOnboardingStartTitle => 'Beginnen met aan boord gaan';

  @override
  String get settingsOnboardingStatusActivated =>
      'Je hebt je eerste AI taak gemaakt.';

  @override
  String get settingsOnboardingStatusLoading => 'Laden...';

  @override
  String get settingsOnboardingStatusNotActivated => 'Nog niet gestart';

  @override
  String get settingsOnboardingStatusTitle => 'Status';

  @override
  String get settingsOnboardingSubtitle =>
      'De welkome flow op elk moment opnieuw afspelen';

  @override
  String get settingsOnboardingTestResetConfirm => 'Terugzetten';

  @override
  String get settingsOnboardingTestResetConfirmQuestion =>
      'Ontruim de prompt geschiedenis en metrics van het boordsysteem? Bestaande dagelijkse OS plannen blijven bestaan, dus gebruik een schoon profiel om de volledige eerste-run Daily OS doorlooptest te doen.';

  @override
  String get settingsOnboardingTestResetSubtitle =>
      'Wis de promptgeschiedenis en -gegevens; de bestaande dagelijkse OS-plannen blijven bestaan (debug)';

  @override
  String get settingsOnboardingTestResetTitle =>
      'Aan boord van de test herstellen';

  @override
  String get settingsOnboardingTitle => 'Aan boord';

  @override
  String get settingsOptionsTitle => 'Opties';

  @override
  String get settingsRecordingStyleExplanation =>
      'Kies hoe de microfoon eruit ziet terwijl je aan het opnemen bent.';

  @override
  String get settingsRecordingStyleSubtitle =>
      'VU meter of energiebol tijdens het opnemen';

  @override
  String get settingsRecordingStyleTitle => 'Opnamestijl';

  @override
  String get settingsResetGeminiConfirm => 'Terugzetten';

  @override
  String get settingsResetGeminiConfirmQuestion =>
      'Dit zal het Tweelingen instellingendialoogvenster weer tonen. Ga verder?';

  @override
  String get settingsResetGeminiSubtitle =>
      'Het Gemini AI-instellingenvenster opnieuw tonen';

  @override
  String get settingsResetGeminiTitle =>
      'Gemini instellen dialoogvenster resetten';

  @override
  String get settingsResetHintsConfirm => 'Bevestigen';

  @override
  String get settingsResetHintsConfirmQuestion =>
      'In-app-hints in de app resetten?';

  @override
  String settingsResetHintsResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Terugzetten $count hints',
      one: 'Een hint resetten',
      zero: 'Geen hints terugzetten',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetHintsSubtitle =>
      'Eenmalige tips en hints aan boord wissen';

  @override
  String get settingsResetHintsTitle => 'In-app hints resetten';

  @override
  String get settingsSpeechSubtitle => 'Stem en hardop lezen';

  @override
  String get settingsSpeechTitle => 'Toespraak';

  @override
  String get settingsSyncConflictsSubtitle =>
      'Synchronisatieconflicten oplossen om de consistentie van gegevens te waarborgen';

  @override
  String get settingsSyncNodeProfileCapabilitiesEmpty =>
      'Geen enkele gedetecteerde .. auto-trigger van gesynchroniseerde audio-inferentie zal niet gericht op dit apparaat.';

  @override
  String get settingsSyncNodeProfileCapabilitiesLabel =>
      'Gedetecteerde AI-mogelijkheden';

  @override
  String get settingsSyncNodeProfileCapabilityMlxAudio => 'MLX-audio (lokaal)';

  @override
  String get settingsSyncNodeProfileCapabilityOllamaLlm => 'Ollama LLM';

  @override
  String get settingsSyncNodeProfileCapabilityOmlxLlm => 'oMLX LLM';

  @override
  String get settingsSyncNodeProfileCapabilityVoxtral => 'Voxtral (lokaal)';

  @override
  String get settingsSyncNodeProfileCapabilityWhisper => 'Fluisteren (lokaal)';

  @override
  String get settingsSyncNodeProfileDisplayNameHelper =>
      'Zichtbaar voor uw andere apparaten bij het kiezen van welke een om een profiel vast te pin.';

  @override
  String get settingsSyncNodeProfileDisplayNameLabel =>
      'Naam van apparaatweergave';

  @override
  String get settingsSyncNodeProfileKnownNodesEmpty =>
      'Nog geen andere apparaten hebben een profiel gepubliceerd.';

  @override
  String get settingsSyncNodeProfileKnownNodesTitle =>
      'Bekende synchronisatieapparaten';

  @override
  String get settingsSyncNodeProfileSaveButton => 'Opslaan';

  @override
  String get settingsSyncNodeProfileSubtitle =>
      'Noem dit apparaat en bekijk de mogelijkheden zichtbaar voor uw andere apparaten.';

  @override
  String get settingsSyncNodeProfileTitle => 'Dit apparaat';

  @override
  String get settingsSyncOutboxTitle => 'Synchronisatie-uitbox';

  @override
  String get settingsSyncStatsSubtitle =>
      'Synchronisatiepijplijngegevens inspecteren';

  @override
  String get settingsSyncSubtitle =>
      'Synchronisatie- en weergavestatistieken instellen';

  @override
  String get settingsThemingAutomatic => 'Automatisch';

  @override
  String get settingsThemingDark => 'Donker uiterlijk';

  @override
  String get settingsThemingLight => 'Lichtschijn';

  @override
  String get settingsThemingSubtitle => 'Pas app uiterlijk en thema\'s';

  @override
  String get settingsThemingTitle => 'Thema';

  @override
  String get settingsV2CategoryEmptyBody =>
      'Kies een subset aan de linkerkant.';

  @override
  String get settingsV2DetailRootCrumb => 'Instellingen';

  @override
  String get settingsV2EmptyStateBody =>
      'Kies een sectie links om te beginnen.';

  @override
  String get settingsV2ResizeHandleLabel =>
      'Grootte-instellingen-boom wijzigen';

  @override
  String get settingsV2UnimplementedTitle => 'Panel nog niet geïmplementeerd';

  @override
  String get settingsWhatsNewSubtitle => 'Zie de laatste updates en functies';

  @override
  String get settingsWhatsNewTitle => 'Wat is er nieuw?';

  @override
  String get settingThemingDark => 'Donker thema';

  @override
  String get settingThemingLight => 'Lichtthema';

  @override
  String get sidebarActiveSectionTitle => 'Activiteit';

  @override
  String get sidebarActivityCollapseTooltip => 'Inklappen';

  @override
  String get sidebarActivityExpandTooltip => 'Activiteiten uitbreiden';

  @override
  String get sidebarAudioRecordingStatusLabel => 'Opname';

  @override
  String get sidebarRunningTimerLabel => 'Tijdklok draaien';

  @override
  String get sidebarRunningTimerStopTooltip => 'Stop timer';

  @override
  String get sidebarTimerStatusLabel => 'Timer';

  @override
  String get sidebarToggleCollapseLabel => 'Zijbalk invouwen';

  @override
  String get sidebarToggleExpandLabel => 'Zijbalk uitvouwen';

  @override
  String sidebarWakesActiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count actief',
      one: '1 actief',
    );
    return '$_temp0';
  }

  @override
  String get sidebarWakesCancelTooltip => 'Agent annuleren';

  @override
  String get sidebarWakesHeader => 'Middelen';

  @override
  String get sidebarWakesNow => 'nu';

  @override
  String get sidebarWakesOpenList => 'Lijst openen';

  @override
  String get sidebarWakesOpenTask => 'Open taak';

  @override
  String sidebarWakesQueuedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wachtrij',
      one: '1 wachtrij',
    );
    return '$_temp0';
  }

  @override
  String get sidebarWakesQueuedLabel => 'In wachtrij';

  @override
  String get sidebarWakesWorkingLabel => 'Werken';

  @override
  String get skillsSectionTitle => 'Vaardigheden';

  @override
  String get speechDictionaryHelper =>
      'Semicolon-gescheiden termen (max 50 tekens) voor betere spraakherkenning';

  @override
  String get speechDictionaryHint => 'macOS; Kirkjubæjarklaustur; Claude Code';

  @override
  String get speechDictionaryLabel => 'Woordenboek';

  @override
  String get speechDictionarySectionDescription =>
      'Voeg termen toe die vaak verkeerd worden gespeld door spraakherkenning (namen, plaatsen, technische termen)';

  @override
  String get speechDictionarySectionTitle => 'Spraakherkenning';

  @override
  String speechDictionaryWarning(Object count) {
    return 'Groot woordenboek ($count voorwaarden) kan de API kosten verhogen';
  }

  @override
  String get speechModalSelectLanguage => 'Taal selecteren';

  @override
  String get speechModalTitle => 'Erkenning van spraak';

  @override
  String get speechSettingsModelDescription => 'Speechmodel voor het apparaat';

  @override
  String get speechSettingsModelDownloadsOnce => 'Eenmaal downloaden';

  @override
  String get speechSettingsModelLabel => 'Model';

  @override
  String get speechSettingsRecommendedBadge => 'Aanbevolen';

  @override
  String get speechSettingsSpeedDescription =>
      'Hoe snel samenvattingen worden gelezen';

  @override
  String get speechSettingsSpeedLabel => 'Leessnelheid';

  @override
  String get speechSettingsVoiceDescription =>
      'Kies de stem die samenvattingen voorleest';

  @override
  String get speechSettingsVoiceLabel => 'Stem';

  @override
  String get speechVoiceGenderFemale => 'Vrouwen';

  @override
  String get speechVoiceGenderMale => 'Man';

  @override
  String get speechVoicePreviewTooltip => 'Voorbeeld van spraak';

  @override
  String get surveyBackButton => 'Terug';

  @override
  String get surveyCancelConfirmation => 'De enquête annuleren?';

  @override
  String get surveyChooseOneOption => 'Kies één optie';

  @override
  String get surveyChooseOneOrMoreOptions => 'Kies een of meer opties';

  @override
  String get surveyDiscardConfirmation => 'Resultaten verwerpen en stoppen?';

  @override
  String get surveyInputNumberValidation => 'Voer een nummer in';

  @override
  String get surveyNextButton => 'Volgende';

  @override
  String get surveyNoButton => 'Nee';

  @override
  String get surveyProgressOf => 'van';

  @override
  String get surveyTapToAnswer => 'Tik op om te antwoorden';

  @override
  String get surveyValueAnd => 'en';

  @override
  String get surveyValueBetween => 'Moet tussen';

  @override
  String get surveyYesButton => 'Ja.';

  @override
  String get syncActivityIdle => 'stationair';

  @override
  String get syncActivityInboxLabel => 'Postvak IN';

  @override
  String syncActivityIndicatorSemantics(int outbox, int inbox) {
    return 'Synchronisatie activiteit. Postvak UIT: ${outbox}Inbox: ${inbox}Open synchronisatie-outbox.';
  }

  @override
  String get syncActivityOutboxLabel => 'Postvak UIT';

  @override
  String get syncActivitySyncingTitle => 'Synchroniseren';

  @override
  String get syncActivityTitle => 'Synchroniseren';

  @override
  String get syncDeleteConfigConfirm => 'Ja, ik ben zeker.';

  @override
  String get syncDeleteConfigQuestion =>
      'Wilt u de synchronisatie-configuratie verwijderen?';

  @override
  String get syncEntitiesConfirm => 'START SYNC';

  @override
  String get syncEntitiesMessage =>
      'Kies de entiteiten die u wilt synchroniseren.';

  @override
  String get syncEntitiesSuccessDescription => 'Alles is up-to-date.';

  @override
  String get syncEntitiesSuccessTitle => 'Compleet synchroniseren';

  @override
  String syncListCountSummary(String label, int itemCount) {
    String _temp0 = intl.Intl.pluralLogic(
      itemCount,
      locale: localeName,
      other: '$itemCount items',
      one: '1 item',
      zero: '0 items',
    );
    return '$label · $_temp0';
  }

  @override
  String get syncListPayloadKindLabel => 'Betaling';

  @override
  String get syncListUnknownPayload => 'Onbekende lading';

  @override
  String get syncNotLoggedInToast => 'Synchronisatie is niet aangemeld';

  @override
  String get syncPayloadAgentBundle => 'Agent bundel';

  @override
  String get syncPayloadAgentEntity => 'Agent-entiteit';

  @override
  String get syncPayloadAgentLink => 'Agentlink';

  @override
  String get syncPayloadAiConfig => 'AI configuratie';

  @override
  String get syncPayloadAiConfigDelete => 'AI configuratie verwijderen';

  @override
  String get syncPayloadBackfillRequest => 'Terugvullen verzoek';

  @override
  String get syncPayloadBackfillResponse => 'Terugvulrespons';

  @override
  String get syncPayloadConfigFlag => 'Configuratievlag';

  @override
  String get syncPayloadConsumptionEvent => 'AI-verbruik';

  @override
  String get syncPayloadDailyOsUserName =>
      'Dagelijkse naam van het besturingssysteem';

  @override
  String get syncPayloadEntityDefinition => 'De definitie van entiteit';

  @override
  String get syncPayloadEntryLink => 'Verwijzing naar invoer';

  @override
  String get syncPayloadJournalEntity => 'Journal';

  @override
  String get syncPayloadNotification => 'Kennisgeving';

  @override
  String get syncPayloadNotificationStateUpdate =>
      'Actualisering van de status van kennisgeving';

  @override
  String get syncPayloadOutboxBundle => 'Outbox bundel';

  @override
  String get syncPayloadSavedTaskFilter => 'Opgeslagen taakfilter';

  @override
  String get syncPayloadSavedTaskFilterDelete =>
      'Opgeslagen taakfilter verwijderen';

  @override
  String get syncPayloadSyncNodeProfile => 'Knoopprofiel synchroniseren';

  @override
  String get syncPayloadThemingSelection => 'Themaselectie';

  @override
  String get syncStepAgentEntities => 'Agententiteiten';

  @override
  String get syncStepAgentLinks => 'Agent links';

  @override
  String get syncStepAiSettings => 'AI-instellingen';

  @override
  String get syncStepBackfillAgentEntityClocks =>
      'Klokken met een eenheid van vulmiddel';

  @override
  String get syncStepBackfillAgentLinkClocks =>
      'Klokken met een koppeling tussen backfillmiddel en klokken';

  @override
  String get syncStepCategories => 'Categorieën';

  @override
  String get syncStepComplete => 'Voltooid';

  @override
  String get syncStepDashboards => 'Dashboards';

  @override
  String get syncStepHabits => 'Gewoontes';

  @override
  String get syncStepLabels => 'Etiketten';

  @override
  String get syncStepMeasurables => 'Meetbare';

  @override
  String get syncStepSavedTaskFilters => 'Opgeslagen taakfilters';

  @override
  String get taskActionBarAudioRecordingActive => 'Audio-opname in uitvoering';

  @override
  String get taskActionBarMoreActions => 'Meer acties';

  @override
  String get taskActionBarOpenRunningTimer => 'Openen van de lopende timer';

  @override
  String get taskActionBarStopTracking => 'Stop tijd volgen';

  @override
  String get taskActionBarTrackTime => 'Tracktijd';

  @override
  String get taskAgentAttributionUnavailable =>
      'Naamsvermelding niet beschikbaar';

  @override
  String get taskAgentAutomaticUpdatesLabel => 'Automatische updates';

  @override
  String get taskAgentAutomaticUpdatesNeedsSetup =>
      'Kies een AI-configuratie voordat u automatisch updates aan zet.';

  @override
  String get taskAgentCancelTimerTooltip =>
      'Annuleren in afwachting van automatische update';

  @override
  String get taskAgentChooseModel => 'Kies een denkmodel';

  @override
  String get taskAgentChooseProfile => 'Kies een inferentieprofiel';

  @override
  String taskAgentCountdownTooltip(String countdown) {
    return 'Volgende auto-run in $countdown';
  }

  @override
  String get taskAgentCreateChipLabel => 'Agent toewijzen';

  @override
  String taskAgentCreateError(String error) {
    return 'Aanmaken van agent mislukt: $error';
  }

  @override
  String get taskAgentCurrentSetupHeader => 'Huidige setup';

  @override
  String get taskAgentCurrentSetupLabel => 'Huidige setup';

  @override
  String get taskAgentDirectModelOverride => 'Direct model override';

  @override
  String get taskAgentDisableConfirmAction => 'Uitzetten';

  @override
  String get taskAgentDisableConfirmBody =>
      'Het huidige rapport blijft zichtbaar, maar deze agent kan niet draaien totdat u een setup hebt gekozen.';

  @override
  String get taskAgentDisableConfirmTitle => 'Al uitschakelen voor deze agent?';

  @override
  String get taskAgentInferenceProfileLabel => 'Inferentieprofiel';

  @override
  String get taskAgentModelPickerTitle => 'Kies denkmodel';

  @override
  String taskAgentNextUpdateIn(String countdown) {
    return 'Volgende update in $countdown';
  }

  @override
  String get taskAgentNoAiSetup => 'Geen AI-opstelling';

  @override
  String get taskAgentNoAiSetupDescription =>
      'Pauzeert agent gevolgtrekking totdat u een profiel of model kiest.';

  @override
  String get taskAgentNoModelsAvailable =>
      'Geen compatibele denkmodellen beschikbaar';

  @override
  String get taskAgentNoProfilesAvailable =>
      'Geen profielen beschikbaar op dit apparaat';

  @override
  String get taskAgentNoProfileSelected => 'Geen AI-opstelling';

  @override
  String get taskAgentNoProfileSelectedDescription =>
      'Kies een opgeslagen setup of denkmodel voordat dit middel kan draaien.';

  @override
  String taskAgentProfileChangedToast(String profile) {
    return 'Gebruik $profile voor elke toekomstige agent update totdat je het verandert.';
  }

  @override
  String get taskAgentProfileDefaultBadge => 'Profielstandaard';

  @override
  String get taskAgentReportOutdatedTitle => 'Deze samenvatting is verouderd';

  @override
  String get taskAgentReportUpToDate => 'Samenvatting is bijgewerkt';

  @override
  String get taskAgentRouteVia => 'via';

  @override
  String get taskAgentRunNowTooltip => 'Rennen.';

  @override
  String get taskAgentSavingSetup =>
      'Instellingen voor opslaan van het bestand';

  @override
  String taskAgentSetupAndReportSemantics(String identity) {
    return 'Dit rapport en huidige installatiegebruik $identity. Activeer om de setup te wijzigen.';
  }

  @override
  String get taskAgentSetupBroken =>
      'Geselecteerde AI-instellingen zijn niet beschikbaar';

  @override
  String taskAgentSetupChangedToast(String model) {
    return 'Gebruik $model voor elke toekomstige agent update totdat je het verandert.';
  }

  @override
  String get taskAgentSetupChoiceHelp =>
      'Kies een profiel voor zijn standaards, of overschrijf alleen het denkmodel.';

  @override
  String get taskAgentSetupOriginCategory =>
      'Gekopiëerd van de categorie standaard wanneer dit programma is aangemaakt';

  @override
  String get taskAgentSetupOriginDisabled => 'Uitgeschakeld';

  @override
  String get taskAgentSetupOriginLegacy => 'Legacy setup';

  @override
  String get taskAgentSetupOriginTemplate => 'Gekopiëerd van het sjabloon';

  @override
  String get taskAgentSetupOriginUser => 'Je koos dit voor deze agent.';

  @override
  String get taskAgentSetupPersistenceDescription =>
      'Wijzigingen zijn van toepassing op elke toekomstige update totdat u ze wijzigt.';

  @override
  String taskAgentSetupSemantics(String identity) {
    return 'Huidige instellingen: $identity. Activeer om de setup te wijzigen.';
  }

  @override
  String get taskAgentSetupTitle => 'Agent setup';

  @override
  String get taskAgentThinkingModelLabel => 'Denkmodel';

  @override
  String get taskAgentThisReportHeader => 'Dit verslag';

  @override
  String get taskAgentTurnOffSetup => 'Zet AI uit voor deze agent.';

  @override
  String get taskAgentUseCategoryDefault => 'Standaard categorie kopiëren';

  @override
  String get taskAgentUseCategoryDefaultDescription =>
      'Kopieert de categorie . Huidige setup. Latere categorie wijzigingen zal dit agent niet beïnvloeden.';

  @override
  String get taskAgentUseProfileDefault => 'Standaardprofiel gebruiken';

  @override
  String get taskAgentWakeAgent => 'Wake agent';

  @override
  String get taskCategoryAllLabel => 'alle';

  @override
  String get taskCategoryLabel => 'Categorie:';

  @override
  String get taskCategoryUnassignedLabel => 'niet toegewezen';

  @override
  String get taskDueDateLabel => 'Verloopdatum';

  @override
  String taskDueDateWithDate(String date) {
    return 'Verloopdatum: $date';
  }

  @override
  String taskDueInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dagen',
      one: '1 dag',
    );
    return 'Vervallen $_temp0';
  }

  @override
  String get taskDueToday => 'Vandaag op de vervaldag';

  @override
  String get taskDueTomorrow => 'Morgen';

  @override
  String get taskDueYesterday => 'Gisteren op de vervaldag';

  @override
  String get taskEditTitleLabel => 'Taaktitel bewerken';

  @override
  String get taskEstimateLabel => 'Raming:';

  @override
  String get taskEstimateModalTitle => 'Raming';

  @override
  String taskEstimateProgressLabel(String tracked, String estimate) {
    return '$tracked van $estimate';
  }

  @override
  String taskEstimateTooltip(String tracked, String estimate) {
    return 'Gespoorde tijd: $tracked van $estimate geraamd';
  }

  @override
  String taskLabelsMoreCount(int count) {
    return '+$count';
  }

  @override
  String get taskLabelsShowFewer => 'Minder tonen';

  @override
  String get taskLanguageArabic => 'Arabisch';

  @override
  String get taskLanguageBengali => 'Bengaals';

  @override
  String get taskLanguageBulgarian => 'Bulgaars';

  @override
  String get taskLanguageChinese => 'Chinees';

  @override
  String get taskLanguageCroatian => 'Kroatisch';

  @override
  String get taskLanguageCzech => 'Tsjechisch';

  @override
  String get taskLanguageDanish => 'Deens';

  @override
  String get taskLanguageDutch => 'Nederlands';

  @override
  String get taskLanguageEnglish => 'Engels';

  @override
  String get taskLanguageEstonian => 'Ests';

  @override
  String get taskLanguageFinnish => 'Fins';

  @override
  String get taskLanguageFrench => 'Frans';

  @override
  String get taskLanguageGerman => 'Duits';

  @override
  String get taskLanguageGreek => 'Grieks';

  @override
  String get taskLanguageHebrew => 'Hebreeuws';

  @override
  String get taskLanguageHindi => 'Hindi';

  @override
  String get taskLanguageHungarian => 'Hongaars';

  @override
  String get taskLanguageIgbo => 'Igbo';

  @override
  String get taskLanguageIndonesian => 'Indonesisch';

  @override
  String get taskLanguageItalian => 'Italiaans';

  @override
  String get taskLanguageJapanese => 'Japans';

  @override
  String get taskLanguageKorean => 'Koreaans';

  @override
  String get taskLanguageLabel => 'Taal';

  @override
  String get taskLanguageLatvian => 'Lets';

  @override
  String get taskLanguageLithuanian => 'Litouws';

  @override
  String get taskLanguageNigerianPidgin => 'Nigeriaanse Pidgin';

  @override
  String get taskLanguageNorwegian => 'Noors';

  @override
  String get taskLanguagePolish => 'Pools';

  @override
  String get taskLanguagePortuguese => 'Portugees';

  @override
  String get taskLanguageRomanian => 'Roemeens';

  @override
  String get taskLanguageRussian => 'Russisch';

  @override
  String get taskLanguageSelectedLabel => 'Geselecteerd';

  @override
  String get taskLanguageSerbian => 'Servisch';

  @override
  String get taskLanguageSetAction => 'Taal instellen';

  @override
  String get taskLanguageSlovak => 'Slowaaks';

  @override
  String get taskLanguageSlovenian => 'Sloveens';

  @override
  String get taskLanguageSpanish => 'Spaans';

  @override
  String get taskLanguageSwahili => 'Swahili';

  @override
  String get taskLanguageSwedish => 'Zweeds';

  @override
  String get taskLanguageThai => 'Thais';

  @override
  String get taskLanguageTurkish => 'Turks';

  @override
  String get taskLanguageTwi => 'Twi';

  @override
  String get taskLanguageUkrainian => 'Oekraïens';

  @override
  String get taskLanguageVietnamese => 'Vietnamees';

  @override
  String get taskLanguageYoruba => 'YorubaCity in Italy';

  @override
  String get taskNoDueDateLabel => 'Geen vervaldatum';

  @override
  String get taskNoEstimateLabel => 'Geen schatting';

  @override
  String taskOverdueByDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dagen te laat',
      one: '1 dag te laat',
    );
    return '$_temp0';
  }

  @override
  String get taskPriorityHigh => 'Hoog';

  @override
  String get taskPriorityLow => 'Laag';

  @override
  String get taskPriorityMedium => 'Middel';

  @override
  String get taskPriorityUrgent => 'Dringend';

  @override
  String get tasksAddLabelButton => 'Label toevoegen';

  @override
  String get tasksAgentFilterAll => 'Alles';

  @override
  String get tasksAgentFilterHasAgent => 'Heeft agent';

  @override
  String get tasksAgentFilterNoAgent => 'Geen agent.';

  @override
  String get tasksAgentFilterTitle => 'Agent';

  @override
  String get tasksFilterApplyTitle => 'Filter toepassen';

  @override
  String get tasksFilterClearAll => 'Alles wissen';

  @override
  String get tasksFilterTitle => 'Filtertaken';

  @override
  String get taskShowcaseAudio => 'Audio';

  @override
  String taskShowcaseCompletedCount(int completed, int total) {
    return '$completed \' $total klaar';
  }

  @override
  String taskShowcaseDueDate(String date) {
    return 'Verloopdatum: $date';
  }

  @override
  String get taskShowcaseJumpToSection => 'Naar sectie springen';

  @override
  String get taskShowcaseLinked => 'Gekoppeld';

  @override
  String get taskShowcaseNoResults =>
      'Geen taken die overeenkomen met uw zoekopdracht.';

  @override
  String get taskShowcaseReadMore => 'Lees meer';

  @override
  String taskShowcaseRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count opnames',
      one: '1 opname',
    );
    return '$_temp0';
  }

  @override
  String taskShowcaseTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count taken',
      one: '1 taak',
    );
    return '$_temp0';
  }

  @override
  String get taskShowcaseTaskDescription => 'Taakbeschrijving';

  @override
  String get taskShowcaseTimeTracker => 'Tijdvolger';

  @override
  String get taskShowcaseTodo => 'Taken';

  @override
  String get taskShowcaseTodos => 'Taken';

  @override
  String get tasksLabelFilterAll => 'Alles';

  @override
  String get tasksLabelFilterTitle => 'Label';

  @override
  String get tasksLabelFilterUnlabeled => 'Niet-gelabeld';

  @override
  String get tasksLabelsDialogClose => 'Sluiten';

  @override
  String get tasksLabelsSheetApply => 'Toepassen';

  @override
  String get tasksLabelsSheetSearchHint => 'Zoeken naar labels...';

  @override
  String get tasksLabelsUpdateFailed => 'Bijwerken van labels is mislukt';

  @override
  String get tasksPriorityFilterAll => 'Alles';

  @override
  String get tasksPriorityFilterTitle => 'Prioriteit';

  @override
  String get tasksPriorityP0 => 'Dringend';

  @override
  String get tasksPriorityP0Description => 'Dringend (ASAP)';

  @override
  String get tasksPriorityP1 => 'Hoog';

  @override
  String get tasksPriorityP1Description => 'Hoog (binnenkort)';

  @override
  String get tasksPriorityP2 => 'Middel';

  @override
  String get tasksPriorityP2Description => 'Middel (Standaard)';

  @override
  String get tasksPriorityP3 => 'Laag';

  @override
  String get tasksPriorityP3Description => 'Laag (wanneer)';

  @override
  String get tasksPriorityPickerTitle => 'Selecteer prioriteit';

  @override
  String get tasksQuickFilterUnassignedLabel => 'Niet toegewezen';

  @override
  String get tasksSavedFilterDeleteConfirmTooltip =>
      'Tik opnieuw om te verwijderen';

  @override
  String get tasksSavedFilterDeleteTooltip => 'Opgeslagen filter verwijderen';

  @override
  String get tasksSavedFilterDragHandleSemantics => 'Sleep naar herschikken';

  @override
  String get tasksSavedFilterRenameSemantics => 'Opgeslagen filter hernoemen';

  @override
  String get tasksSavedFiltersAllShort => 'Alles';

  @override
  String get tasksSavedFiltersAllTasks => 'Alle taken';

  @override
  String get tasksSavedFiltersCustom => 'Aangepast';

  @override
  String get tasksSavedFiltersDeleteConfirmAction => 'Verwijderen';

  @override
  String tasksSavedFiltersDeleteConfirmMessage(String name) {
    return 'Het opgeslagen filter verwijderen${name}Dit kan niet ongedaan worden gemaakt.';
  }

  @override
  String tasksSavedFiltersDeleteConfirmNamed(String name) {
    return 'Verwijderen bevestigen $name';
  }

  @override
  String tasksSavedFiltersDeleteNamed(String name) {
    return 'Verwijderen $name';
  }

  @override
  String get tasksSavedFiltersDone => 'Klaar';

  @override
  String get tasksSavedFiltersEdit => 'Bewerken';

  @override
  String get tasksSavedFiltersFilterNameLabel => 'Filternaam';

  @override
  String get tasksSavedFiltersGroupSemantics => 'Taakfilters';

  @override
  String get tasksSavedFiltersManageTooltip => 'Taakfilters beheren';

  @override
  String get tasksSavedFiltersRailButton => 'Filters';

  @override
  String tasksSavedFiltersRenameNamed(String name) {
    return 'Hernoemen $name';
  }

  @override
  String get tasksSavedFiltersReorderHelper =>
      'Sleep om de volgorde in te stellen. De eerste vijf filters verschijnen in de zijbalk.';

  @override
  String get tasksSavedFiltersSaveAsNewButtonLabel => 'Opslaan als nieuw...';

  @override
  String get tasksSavedFiltersSaveAsNewDescription =>
      'Houd het bestaande filter ongewijzigd en maak een aparte filter aan.';

  @override
  String get tasksSavedFiltersSaveAsNewTitle => 'Opslaan als nieuw filter';

  @override
  String get tasksSavedFiltersSaveButtonLabel => 'Filter opslaan...';

  @override
  String get tasksSavedFiltersSaveChoiceIntro =>
      'Kies of het opgeslagen filter moet worden bijgewerkt of een aparte filter moet worden aangemaakt.';

  @override
  String get tasksSavedFiltersSaveChoiceTitle => 'Filter opslaan';

  @override
  String get tasksSavedFiltersSaveCurrentAs => 'Huidige filter opslaan...';

  @override
  String get tasksSavedFiltersSaveError =>
      'Kon dit filter niet opslaan. Probeer het opnieuw.';

  @override
  String get tasksSavedFiltersSavePageHelper =>
      'Geef dit filter een korte naam. U kunt het later herschikken in taakfilters.';

  @override
  String get tasksSavedFiltersSavePopupCancel => 'Annuleren';

  @override
  String get tasksSavedFiltersSavePopupHint =>
      'b.v. geblokkeerd of in de wachtstand';

  @override
  String get tasksSavedFiltersSavePopupSave => 'Opslaan';

  @override
  String get tasksSavedFiltersSavePopupTitle => 'Dit filter noemen';

  @override
  String get tasksSavedFiltersSheetTitle => 'Taakfilters';

  @override
  String get tasksSavedFiltersShowLess => 'Minder tonen';

  @override
  String tasksSavedFiltersShowMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count meer opgeslagen filters',
      one: '1 meer opgeslagen filter',
    );
    return '$_temp0';
  }

  @override
  String tasksSavedFiltersTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count taken',
      one: '1 taak',
    );
    return '$_temp0';
  }

  @override
  String get tasksSavedFiltersUpdateButtonLabel => 'Filter bijwerken';

  @override
  String get tasksSavedFiltersUpdateExistingDescription =>
      'Vervang de opgeslagen criteria door de huidige filterconfiguratie.';

  @override
  String get tasksSavedFiltersUpdateExistingTitle =>
      'Bestaande filter bijwerken';

  @override
  String get tasksSavedFilterToastDeleted => 'Filter verwijderd';

  @override
  String tasksSavedFilterToastSaved(String name) {
    return 'Opgeslagen \'$name\'';
  }

  @override
  String tasksSavedFilterToastUpdated(String name) {
    return 'Bijgewerkt \'$name\'';
  }

  @override
  String get tasksSearchModeLabel => 'Zoeken';

  @override
  String get tasksShowCreationDate => 'Aanmaakdatum op kaarten tonen';

  @override
  String get tasksShowDueDate => 'Vervallen datum op kaarten tonen';

  @override
  String get tasksSortByCreationDate => 'Aangemaakt';

  @override
  String get tasksSortByDueDate => 'Verloopdatum';

  @override
  String get tasksSortByLabel => 'Sorteren op';

  @override
  String get tasksSortByPriority => 'Prioriteit';

  @override
  String get taskStatusAll => 'Alles';

  @override
  String get taskStatusBlocked => 'Geblokkeerd';

  @override
  String get taskStatusDone => 'Klaar';

  @override
  String get taskStatusGroomed => 'Verfijnd';

  @override
  String get taskStatusInProgress => 'In behandeling';

  @override
  String get taskStatusLabel => 'Status:';

  @override
  String get taskStatusOnHold => 'In wacht';

  @override
  String get taskStatusOpen => 'Openen';

  @override
  String get taskStatusRejected => 'Afgewezen';

  @override
  String get taskTitleEmpty => 'Geen titel';

  @override
  String get taskUntitled => '(zonder titel)';

  @override
  String get thinkingDisclosureCopied => 'Redeneren gekopieerd';

  @override
  String get thinkingDisclosureCopy => 'Beredenering kopiëren';

  @override
  String get thinkingDisclosureHide => 'Beredenering verbergen';

  @override
  String get thinkingDisclosureShow => 'Rationationeren tonen';

  @override
  String get thinkingDisclosureStateCollapsed => 'ingestort';

  @override
  String get thinkingDisclosureStateExpanded => 'uitgebreid';

  @override
  String get timeEntryItemEnd => 'Einde';

  @override
  String get timeEntryItemRunning => 'Uitvoeren';

  @override
  String get timeEntryItemStart => 'Begin';

  @override
  String get unlinkButton => 'Verbinding verbreken';

  @override
  String get unlinkTaskConfirm => 'Weet u zeker dat u deze taak wilt losmaken?';

  @override
  String get unlinkTaskTitle => 'Taak loskoppelen';

  @override
  String vectorSearchTiming(int elapsed, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${elapsed}ms. $count resultaten',
      one: '${elapsed}ms. $count resultaat',
    );
    return '$_temp0';
  }

  @override
  String get viewMenuTitle => 'Beeld';

  @override
  String get viewMenuZoomIn => 'Inzoomen';

  @override
  String get viewMenuZoomOut => 'Uitzoomen';

  @override
  String get viewMenuZoomReset => 'Werkelijke grootte';

  @override
  String get whatsNewBadgeNew => 'NIEUW';

  @override
  String get whatsNewDoneButton => 'Klaar';

  @override
  String get whatsNewSkipButton => 'Overslaan';
}

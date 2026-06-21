// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get activeLabel => 'Actif';

  @override
  String get addActionAddAudioRecording => 'Commencer l\'enregistrement audio';

  @override
  String get addActionAddChecklist => 'Liste de contrôle';

  @override
  String get addActionAddEvent => 'Événement';

  @override
  String get addActionAddImageFromClipboard => 'Coller l\'image';

  @override
  String get addActionAddScreenshot => 'Ajouter une capture d\'écran';

  @override
  String get addActionAddTask => 'Ajouter une tâche';

  @override
  String get addActionAddText => 'Ajouter du texte';

  @override
  String get addActionAddTimer => 'Minuteur';

  @override
  String get addActionAddTimeRecording =>
      'Commencer l\'enregistrement du temps';

  @override
  String get addActionImportImage => 'Importer une image';

  @override
  String get addHabitCommentLabel => 'Commentaire';

  @override
  String get addHabitDateLabel => 'Terminé à';

  @override
  String get addMeasurementCommentLabel => 'Commentaire';

  @override
  String get addMeasurementDateLabel => 'Observé à';

  @override
  String get addMeasurementSaveButton => 'Enregistrer';

  @override
  String get addToDictionary => 'Ajouter au dictionnaire';

  @override
  String get addToDictionaryDuplicate =>
      'Le terme existe déjà dans le dictionnaire';

  @override
  String get addToDictionaryNoCategory =>
      'Impossible d\'ajouter au dictionnaire : la tâche n\'a pas de catégorie';

  @override
  String get addToDictionarySaveFailed =>
      'Échec de l\'enregistrement du dictionnaire';

  @override
  String get addToDictionarySuccess => 'Terme ajouté au dictionnaire';

  @override
  String get addToDictionaryTooLong => 'Terme trop long (max 50 caractères)';

  @override
  String agentABComparisonChoose(String option) {
    return 'Choisir $option';
  }

  @override
  String agentABComparisonOption(String option) {
    return 'Option $option';
  }

  @override
  String agentABComparisonPrefer(String option) {
    return 'Je préfère l\'Option $option';
  }

  @override
  String get agentBinaryChoiceNo => 'Non';

  @override
  String get agentBinaryChoiceYes => 'Oui';

  @override
  String get agentCategoryRatingsScaleMax => 'Corriger d\'abord';

  @override
  String get agentCategoryRatingsScaleMin => 'Laisser';

  @override
  String agentCategoryRatingsStarLabel(int starIndex, int totalStars) {
    return '$starIndex sur $totalStars étoiles';
  }

  @override
  String get agentCategoryRatingsSubmit => 'Utiliser ces priorités';

  @override
  String get agentCategoryRatingsSubtitle =>
      'À quel point c\'est important que je corrige chacun de ces points ? 1 = laisse comme ça, 5 = corrige ça en premier.';

  @override
  String get agentCategoryRatingsTitle => 'Aide-moi à prioriser';

  @override
  String agentControlsActionError(String error) {
    return 'L\'action a échoué : $error';
  }

  @override
  String get agentControlsDeleteButton => 'Supprimer définitivement';

  @override
  String get agentControlsDeleteDialogContent =>
      'Toutes les données de cet agent seront définitivement supprimées, y compris son historique, ses rapports et ses observations. Cette action est irréversible.';

  @override
  String get agentControlsDeleteDialogTitle => 'Supprimer l\'agent ?';

  @override
  String get agentControlsDestroyButton => 'Détruire';

  @override
  String get agentControlsDestroyDialogContent =>
      'Cela désactivera définitivement l\'agent. Son historique sera conservé pour audit.';

  @override
  String get agentControlsDestroyDialogTitle => 'Détruire l\'agent ?';

  @override
  String get agentControlsDestroyedMessage => 'Cet agent a été détruit.';

  @override
  String get agentControlsPauseButton => 'Pause';

  @override
  String get agentControlsReanalyzeButton => 'Réanalyser';

  @override
  String get agentControlsResumeButton => 'Reprendre';

  @override
  String get agentConversationEmpty => 'Pas encore de conversations.';

  @override
  String agentConversationThreadSummary(
    int messageCount,
    int toolCallCount,
    String shortId,
  ) {
    return '$messageCount messages, $toolCallCount appels d\'outils · $shortId';
  }

  @override
  String agentConversationTokenCount(String tokenCount) {
    return '$tokenCount jetons';
  }

  @override
  String get agentDefaultProfileLabel => 'Profil d\'inférence par défaut';

  @override
  String agentDetailErrorLoading(String error) {
    return 'Erreur lors du chargement de l\'agent : $error';
  }

  @override
  String get agentDetailNotFound => 'Agent introuvable.';

  @override
  String get agentDetailUnexpectedType => 'Type d\'entité inattendu.';

  @override
  String get agentEvolutionApprovalRate => 'Taux d\'approbation';

  @override
  String get agentEvolutionChartMttrTrend => 'Tendance MTTR';

  @override
  String get agentEvolutionChartSuccessRateTrend => 'Taux de réussite';

  @override
  String get agentEvolutionChartVersionPerformance => 'Par version';

  @override
  String get agentEvolutionChartWakeHistory => 'Historique des wakes';

  @override
  String get agentEvolutionChatPlaceholder =>
      'Partage tes retours ou demande des infos sur les performances...';

  @override
  String get agentEvolutionCurrentDirectives => 'Directives actuelles';

  @override
  String get agentEvolutionDashboardTitle => 'Performance';

  @override
  String get agentEvolutionHistoryTitle => 'Historique d\'évolution';

  @override
  String get agentEvolutionMetricActive => 'Actifs';

  @override
  String get agentEvolutionMetricAvgDuration => 'Durée moy.';

  @override
  String get agentEvolutionMetricFailures => 'Échecs';

  @override
  String get agentEvolutionMetricSuccess => 'Succès';

  @override
  String get agentEvolutionMetricWakes => 'Réveils';

  @override
  String get agentEvolutionNoSessions =>
      'Aucune session d\'évolution pour l\'instant';

  @override
  String get agentEvolutionNoteRecorded => 'Note enregistrée';

  @override
  String get agentEvolutionProposalApprovalFailed =>
      'Échec de l\'approbation — réessaie';

  @override
  String get agentEvolutionProposalRationale => 'Justification';

  @override
  String get agentEvolutionProposalRejected =>
      'Proposition rejetée — continue la conversation';

  @override
  String get agentEvolutionProposalTitle => 'Modifications proposées';

  @override
  String get agentEvolutionProposedDirectives => 'Directives proposées';

  @override
  String get agentEvolutionSessionAbandoned =>
      'Session terminée sans modifications';

  @override
  String agentEvolutionSessionCompleted(int version) {
    return 'Session terminée — version $version créée';
  }

  @override
  String get agentEvolutionSessionCount => 'Sessions';

  @override
  String get agentEvolutionSessionError =>
      'Impossible de démarrer la session d\'évolution';

  @override
  String agentEvolutionSessionProgress(int sessionNumber, int totalSessions) {
    return 'Session $sessionNumber sur $totalSessions';
  }

  @override
  String get agentEvolutionSessionStarting =>
      'Démarrage de la session d\'évolution...';

  @override
  String agentEvolutionSessionTitle(int sessionNumber) {
    return 'Évolution #$sessionNumber';
  }

  @override
  String agentEvolutionSoulCurrentField(String field) {
    return 'Actuel — $field';
  }

  @override
  String agentEvolutionSoulProposedField(String field) {
    return 'Proposé — $field';
  }

  @override
  String get agentEvolutionStatusAbandoned => 'Abandonné';

  @override
  String get agentEvolutionStatusActive => 'Actif';

  @override
  String get agentEvolutionStatusCompleted => 'Terminé';

  @override
  String get agentEvolutionTimelineFeedbackLabel => 'Retours';

  @override
  String get agentEvolutionVersionProposed => 'Version proposée';

  @override
  String get agentFeedbackCategoryAccuracy => 'Précision';

  @override
  String get agentFeedbackCategoryBreakdownTitle => 'Répartition par catégorie';

  @override
  String get agentFeedbackCategoryCommunication => 'Communication';

  @override
  String get agentFeedbackCategoryGeneral => 'Général';

  @override
  String get agentFeedbackCategoryPrioritization => 'Priorisation';

  @override
  String get agentFeedbackCategoryTimeliness => 'Ponctualité';

  @override
  String get agentFeedbackCategoryTooling => 'Outils';

  @override
  String get agentFeedbackClassificationTitle => 'Classification des retours';

  @override
  String get agentFeedbackExcellenceTitle => 'Notes d\'excellence';

  @override
  String get agentFeedbackGrievancesTitle => 'Griefs';

  @override
  String get agentFeedbackHighPriorityTitle => 'Retours hautement prioritaires';

  @override
  String agentFeedbackItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments',
      one: '1 élément',
    );
    return '$_temp0';
  }

  @override
  String get agentFeedbackSourceDecision => 'Décision';

  @override
  String get agentFeedbackSourceMetric => 'Métrique';

  @override
  String get agentFeedbackSourceObservation => 'Observation';

  @override
  String get agentFeedbackSourceRating => 'Évaluation';

  @override
  String get agentInstancesEmptyFiltered =>
      'Aucune instance ne correspond à tes filtres.';

  @override
  String get agentInstancesFilterClearAll => 'Tout effacer';

  @override
  String get agentInstancesFilterClearSection => 'Effacer';

  @override
  String get agentInstancesFilterSectionSoul => 'Âme';

  @override
  String get agentInstancesFilterSectionStatus => 'Statut';

  @override
  String get agentInstancesFilterSectionType => 'Type';

  @override
  String agentInstancesGroupActiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count actifs',
      one: '1 actif',
    );
    return '$_temp0';
  }

  @override
  String get agentInstancesGroupBySoul => 'Âme';

  @override
  String get agentInstancesGroupByStatus => 'Statut';

  @override
  String get agentInstancesGroupByType => 'Type';

  @override
  String get agentInstancesKindEvolution => 'Évolution';

  @override
  String get agentInstancesKindTaskAgent => 'Agent de tâches';

  @override
  String get agentInstancesPageTitle => 'Instances d\'agents';

  @override
  String agentInstancesResultCountAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count instances',
      one: '1 instance',
    );
    return '$_temp0';
  }

  @override
  String agentInstancesResultCountFiltered(int filtered, int total) {
    return '$filtered sur $total';
  }

  @override
  String get agentInstancesSearchClear => 'Effacer la recherche';

  @override
  String get agentInstancesSearchPlaceholder => 'Rechercher des instances…';

  @override
  String get agentInstancesSortName => 'Nom';

  @override
  String get agentInstancesSortOldest => 'Plus anciennes';

  @override
  String get agentInstancesSortRecent => 'Récentes';

  @override
  String get agentInstancesTitle => 'Instances';

  @override
  String get agentInstancesToolbarFilters => 'Filtres';

  @override
  String get agentInstancesToolbarGroupBy => 'Grouper par';

  @override
  String get agentInstancesUnassignedSoul => 'Non attribué';

  @override
  String get agentLifecycleActive => 'Actif';

  @override
  String get agentLifecycleCreated => 'Créé';

  @override
  String get agentLifecycleDestroyed => 'Détruit';

  @override
  String get agentLifecycleDormant => 'En sommeil';

  @override
  String get agentMessageKindAction => 'Action';

  @override
  String get agentMessageKindMilestone => 'Jalon';

  @override
  String get agentMessageKindObservation => 'Observation';

  @override
  String get agentMessageKindRetraction => 'Rétractation';

  @override
  String get agentMessageKindSummary => 'Résumé';

  @override
  String get agentMessageKindSystem => 'Système';

  @override
  String get agentMessageKindSystemPrompt => 'Prompt système';

  @override
  String get agentMessageKindThought => 'Pensée';

  @override
  String get agentMessageKindToolResult => 'Résultat d\'outil';

  @override
  String get agentMessageKindUser => 'Utilisateur';

  @override
  String get agentMessagePayloadEmpty => '(aucun contenu)';

  @override
  String get agentMessagesEmpty => 'Aucun message pour l\'instant.';

  @override
  String agentMessagesErrorLoading(String error) {
    return 'Échec du chargement des messages : $error';
  }

  @override
  String get agentObservationsEmpty =>
      'Aucune observation enregistrée pour le moment.';

  @override
  String agentPendingWakesActivityHourDetail(
    String hour,
    int count,
    String reasons,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count réveils',
      one: '1 réveil',
    );
    return '$hour : $_temp0 ($reasons)';
  }

  @override
  String get agentPendingWakesActivityTitle => 'Activité de réveil (24h)';

  @override
  String agentPendingWakesActivityTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count réveils au total',
      one: '1 réveil au total',
    );
    return '$_temp0';
  }

  @override
  String get agentPendingWakesDeleteTooltip => 'Supprimer le réveil';

  @override
  String get agentPendingWakesEmptyFiltered =>
      'Aucun réveil ne correspond à tes filtres.';

  @override
  String get agentPendingWakesFilterSectionType => 'Type';

  @override
  String get agentPendingWakesGroupByType => 'Type';

  @override
  String get agentPendingWakesPendingLabel => 'En attente';

  @override
  String agentPendingWakesRunningHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'En cours ($count)',
      one: 'En cours',
    );
    return '$_temp0';
  }

  @override
  String get agentPendingWakesScheduledLabel => 'Planifié';

  @override
  String get agentPendingWakesSearchPlaceholder => 'Rechercher des réveils…';

  @override
  String get agentPendingWakesSortDueLatest => 'Prévu en dernier';

  @override
  String get agentPendingWakesSortDueSoonest => 'Prévu en premier';

  @override
  String get agentPendingWakesTitle => 'Cycles de réveil';

  @override
  String get agentReportHistoryBadge => 'Rapport';

  @override
  String get agentReportHistoryEmpty => 'Pas encore d\'instantanés de rapport.';

  @override
  String get agentReportHistoryError =>
      'Une erreur est survenue lors du chargement de l\'historique des rapports.';

  @override
  String get agentReportNone => 'Aucun rapport disponible pour l\'instant.';

  @override
  String get agentRitualReviewAction => 'Démarrer la conversation';

  @override
  String get agentRitualReviewNegativeSignals => 'Négatif';

  @override
  String get agentRitualReviewNeutralSignals => 'Neutre';

  @override
  String get agentRitualReviewNoFeedback =>
      'Aucun signal de retour dans cette fenêtre';

  @override
  String get agentRitualReviewNoNegativeSignals =>
      'Aucun signal de retour négatif dans cet onglet';

  @override
  String get agentRitualReviewNoNeutralSignals =>
      'Aucun signal de retour neutre dans cet onglet';

  @override
  String get agentRitualReviewNoPositiveSignals =>
      'Aucun signal de retour positif dans cet onglet';

  @override
  String get agentRitualReviewPositiveSignals => 'Positif';

  @override
  String get agentRitualReviewProposalSection => 'Proposition actuelle';

  @override
  String get agentRitualReviewSessionHistory => 'Historique des sessions';

  @override
  String get agentRitualReviewTitle => '1-on-1';

  @override
  String get agentRitualSummaryApprovedChangesHeading =>
      'Modifications validées';

  @override
  String get agentRitualSummaryConversationHeading => 'Conversation';

  @override
  String get agentRitualSummaryRecapHeading => 'Résumé de la session';

  @override
  String get agentRitualSummaryRoleAssistant => 'Agent';

  @override
  String get agentRitualSummaryRoleUser => 'Toi';

  @override
  String get agentRitualSummaryStartHint =>
      'Lance un 1-on-1 pour passer en revue ce qui a dérangé l’utilisateur, ce qui a bien marché et ce qui doit changer ensuite.';

  @override
  String get agentRitualSummarySubtitle =>
      'Tes derniers 1-on-1, l’activité réelle des wakes et les changements validés.';

  @override
  String get agentRitualSummaryTokensSinceLast =>
      'Tokens depuis le dernier 1-on-1';

  @override
  String get agentRitualSummaryWakeHistory30Days =>
      'Activité des wakes (30 derniers jours)';

  @override
  String get agentRitualSummaryWakesSinceLast =>
      'Wakes depuis le dernier 1-on-1';

  @override
  String get agentRunningIndicator => 'En cours';

  @override
  String get agentSessionProgressTitle => 'Progression de session';

  @override
  String get agentSettingsSubtitle => 'Modèles, instances et surveillance';

  @override
  String get agentSettingsTitle => 'Agents';

  @override
  String get agentSoulAntiSycophancyLabel => 'Politique anti-flagornerie';

  @override
  String get agentSoulAssignedTemplatesTitle => 'Modèles assignés';

  @override
  String get agentSoulAssignmentLabel => 'Âme';

  @override
  String get agentSoulCoachingStyleLabel => 'Style de coaching';

  @override
  String get agentSoulCreatedSuccess => 'Âme créée';

  @override
  String get agentSoulCreateTitle => 'Créer une âme';

  @override
  String get agentSoulDeleteConfirmBody =>
      'Cela supprimera l\'âme et toutes ses versions.';

  @override
  String get agentSoulDeleteConfirmTitle => 'Supprimer l\'âme';

  @override
  String get agentSoulDetailTitle => 'Détail de l\'âme';

  @override
  String get agentSoulDisplayNameLabel => 'Nom';

  @override
  String get agentSoulEvolutionHistoryTitle =>
      'Historique d\'évolution de l\'âme';

  @override
  String get agentSoulEvolutionNoSessions =>
      'Pas encore de sessions d\'évolution de l\'âme';

  @override
  String get agentSoulFieldAntiSycophancy => 'Anti-flagornerie';

  @override
  String get agentSoulFieldCoachingStyle => 'Style de coaching';

  @override
  String get agentSoulFieldToneBounds => 'Limites de ton';

  @override
  String get agentSoulFieldVoice => 'Voix';

  @override
  String get agentSoulInfoTab => 'Info';

  @override
  String get agentSoulNoneAssigned => 'Aucune âme assignée';

  @override
  String get agentSoulNotFound => 'Âme introuvable';

  @override
  String get agentSoulProposalSubtitle =>
      'Changements de personnalité proposés';

  @override
  String get agentSoulProposalTitle => 'Proposition de personnalité de l\'âme';

  @override
  String get agentSoulReviewHeroSubtitle =>
      'Affine la personnalité dans tous les modèles partageant cette âme. L\'agent d\'évolution voit les retours de chaque modèle qui utilise cette personnalité.';

  @override
  String get agentSoulReviewStartAction => 'Lancer la revue de personnalité';

  @override
  String get agentSoulReviewStartHint =>
      'Lance une session axée sur la personnalité pour examiner les retours et faire évoluer la voix, le ton, le style de coaching et la franchise.';

  @override
  String agentSoulReviewTemplateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modèles partagent cette âme',
      one: '1 modèle partage cette âme',
    );
    return '$_temp0';
  }

  @override
  String get agentSoulReviewTitle => 'Âme 1-on-1';

  @override
  String get agentSoulRollbackAction => 'Revenir à cette version';

  @override
  String agentSoulRollbackConfirm(int version) {
    return 'Revenir à la version $version ? Tous les modèles utilisant cette âme seront affectés.';
  }

  @override
  String get agentSoulSelectTitle => 'Sélectionner une âme';

  @override
  String get agentSoulsEmptyFiltered =>
      'Aucune âme ne correspond à tes filtres.';

  @override
  String get agentSoulSettingsTab => 'Paramètres';

  @override
  String get agentSoulsSearchPlaceholder => 'Rechercher des âmes…';

  @override
  String get agentSoulsTitle => 'Âmes';

  @override
  String get agentSoulToneBoundsLabel => 'Limites de ton';

  @override
  String get agentSoulVersionHistoryTitle => 'Historique des versions';

  @override
  String agentSoulVersionLabel(int version) {
    return 'Version $version';
  }

  @override
  String get agentSoulVersionSaved => 'Nouvelle version d\'âme enregistrée';

  @override
  String get agentSoulVoiceDirectiveLabel => 'Directive vocale';

  @override
  String get agentStateConsecutiveFailures => 'Échecs consécutifs';

  @override
  String agentStateErrorLoading(String error) {
    return 'Échec du chargement de l\'état : $error';
  }

  @override
  String get agentStateHeading => 'Informations d\'état';

  @override
  String get agentStateLastWake => 'Dernier réveil';

  @override
  String get agentStateNextWake => 'Prochain réveil';

  @override
  String get agentStateRevision => 'Révision';

  @override
  String get agentStateSleepingUntil => 'En sommeil jusqu\'à';

  @override
  String get agentStateWakeCount => 'Nombre de réveils';

  @override
  String get agentStatsAllDayLegend => 'Toute la journée';

  @override
  String get agentStatsAverageLabel => 'Moyenne';

  @override
  String agentStatsByTimeLegend(String time) {
    return 'Quotidien jusqu\'à $time';
  }

  @override
  String get agentStatsCacheRateLabel => 'Taux de cache';

  @override
  String get agentStatsDailyUsageHeading => 'Utilisation quotidienne';

  @override
  String get agentStatsInputLabel => 'Entrée';

  @override
  String get agentStatsNoUsage =>
      'Aucune utilisation de tokens enregistrée au cours des 7 derniers jours.';

  @override
  String get agentStatsOutputLabel => 'Sortie';

  @override
  String agentStatsSourceActiveFor(String duration) {
    return 'Actif depuis $duration';
  }

  @override
  String get agentStatsSourceActivityHeading => 'Activité des agents';

  @override
  String agentStatsSourceWakes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count réveils',
      one: '1 réveil',
    );
    return '$_temp0';
  }

  @override
  String get agentStatsTabTitle => 'Statistiques';

  @override
  String get agentStatsThoughtsLabel => 'Réflexions';

  @override
  String get agentStatsTodayLabel => 'Aujourd\'hui';

  @override
  String get agentStatsTokensPerWakeLabel => 'Tokens / réveil';

  @override
  String get agentStatsTokensUnit => 'tokens';

  @override
  String agentStatsUsageAboveAverage(String time) {
    return 'Tu utilises plus de tokens aujourd\'hui que d\'habitude à $time.';
  }

  @override
  String agentStatsUsageBelowAverage(String time) {
    return 'Tu utilises moins de tokens aujourd\'hui que d\'habitude à $time.';
  }

  @override
  String get agentStatsWakesLabel => 'Réveils';

  @override
  String get agentSuggestionTimeEntryUpdateCurrent => 'Actuel';

  @override
  String get agentSuggestionTimeEntryUpdateNoChange => '(inchangé)';

  @override
  String get agentSuggestionTimeEntryUpdateProposed => 'Proposé';

  @override
  String get agentSuggestionTimeEntryUpdateUnavailable =>
      'Entrée d\'origine indisponible';

  @override
  String get agentTabActivity => 'Activité';

  @override
  String get agentTabConversations => 'Conversations';

  @override
  String get agentTabObservations => 'Observations';

  @override
  String get agentTabReports => 'Rapports';

  @override
  String get agentTabStats => 'Stats';

  @override
  String get agentTemplateAggregateTokenUsageHeading =>
      'Utilisation totale de tokens';

  @override
  String get agentTemplateAssignedLabel => 'Modèle d\'agent';

  @override
  String get agentTemplateCreatedSuccess => 'Modèle créé';

  @override
  String get agentTemplateCreateTitle => 'Créer un modèle';

  @override
  String get agentTemplateDeleteConfirm =>
      'Supprimer ce modèle ? Cette action est irréversible.';

  @override
  String get agentTemplateDeleteHasInstances =>
      'Impossible de supprimer : des agents actifs utilisent ce modèle.';

  @override
  String get agentTemplateDisplayNameLabel => 'Nom';

  @override
  String get agentTemplateEditTitle => 'Modifier le modèle';

  @override
  String get agentTemplateEvolveApprove => 'Approuver et enregistrer';

  @override
  String get agentTemplateEvolveReject => 'Rejeter';

  @override
  String get agentTemplateGeneralDirectiveHint =>
      'Définis la personnalité, les outils, les objectifs et le style d\'interaction de l\'agent...';

  @override
  String get agentTemplateGeneralDirectiveLabel => 'Directive générale';

  @override
  String get agentTemplateInstanceBreakdownHeading => 'Détail par instance';

  @override
  String get agentTemplateKindDayAgent => 'Agent de journée';

  @override
  String get agentTemplateKindImprover => 'Améliorateur de modèle';

  @override
  String get agentTemplateKindProjectAgent => 'Agent de projet';

  @override
  String get agentTemplateKindTaskAgent => 'Agent de tâches';

  @override
  String get agentTemplateMetricsTotalWakes => 'Activations totales';

  @override
  String get agentTemplateNoneAssigned => 'Aucun modèle assigné';

  @override
  String get agentTemplateNoTemplates =>
      'Aucun modèle disponible. Crée-en un dans les Paramètres d\'abord.';

  @override
  String get agentTemplateNotFound => 'Modèle introuvable';

  @override
  String get agentTemplateNoVersions => 'Aucune version';

  @override
  String get agentTemplateReportDirectiveHint =>
      'Définis la structure du rapport, les sections requises et les règles de formatage...';

  @override
  String get agentTemplateReportDirectiveLabel => 'Directive de rapport';

  @override
  String get agentTemplateReportsEmpty => 'Pas encore de rapports.';

  @override
  String get agentTemplateReportsTab => 'Rapports';

  @override
  String get agentTemplateRollbackAction => 'Revenir à cette version';

  @override
  String agentTemplateRollbackConfirm(int version) {
    return 'Revenir à la version $version ? L\'agent utilisera cette version lors de son prochain réveil.';
  }

  @override
  String get agentTemplateSaveNewVersion => 'Enregistrer';

  @override
  String get agentTemplateSelectTitle => 'Sélectionner un modèle';

  @override
  String get agentTemplatesEmptyFiltered =>
      'Aucun modèle ne correspond à tes filtres.';

  @override
  String get agentTemplateSettingsTab => 'Paramètres';

  @override
  String get agentTemplatesFilterSectionKind => 'Type';

  @override
  String get agentTemplatesGroupByKind => 'Type';

  @override
  String get agentTemplatesGroupNone => 'Tous';

  @override
  String get agentTemplatesSearchPlaceholder => 'Rechercher des modèles…';

  @override
  String get agentTemplateStatsTab => 'Statistiques';

  @override
  String get agentTemplateStatusActive => 'Actif';

  @override
  String get agentTemplateStatusArchived => 'Archivé';

  @override
  String get agentTemplatesTitle => 'Modèles d\'agents';

  @override
  String get agentTemplateSwitchHint =>
      'Pour utiliser un autre modèle, détruis cet agent et crée-en un nouveau.';

  @override
  String get agentTemplateVersionHistoryTitle => 'Historique des versions';

  @override
  String agentTemplateVersionLabel(int version) {
    return 'Version $version';
  }

  @override
  String get agentTemplateVersionSaved => 'Nouvelle version enregistrée';

  @override
  String get agentThreadReportLabel => 'Rapport produit pendant ce cycle';

  @override
  String get agentTokenUsageCachedTokens => 'En cache';

  @override
  String get agentTokenUsageEmpty =>
      'Aucune utilisation de tokens enregistrée.';

  @override
  String agentTokenUsageErrorLoading(String error) {
    return 'Échec du chargement de l\'utilisation des tokens : $error';
  }

  @override
  String get agentTokenUsageHeading => 'Utilisation des tokens';

  @override
  String get agentTokenUsageInputTokens => 'Entrée';

  @override
  String get agentTokenUsageModel => 'Modèle';

  @override
  String get agentTokenUsageOutputTokens => 'Sortie';

  @override
  String get agentTokenUsageThoughtsTokens => 'Pensées';

  @override
  String get agentTokenUsageTotalTokens => 'Total';

  @override
  String get agentTokenUsageWakeCount => 'Réveils';

  @override
  String get aggregationDailyAvg => 'Moyenne quotidienne';

  @override
  String get aggregationDailyMax => 'Maximum quotidien';

  @override
  String get aggregationDailySum => 'Somme quotidienne';

  @override
  String get aggregationHourlySum => 'Somme horaire';

  @override
  String get aggregationNone => 'Aucune';

  @override
  String get aiAssistantTitle => 'Générer…';

  @override
  String get aiBatchToggleTooltip => 'Passer à l\'enregistrement standard';

  @override
  String get aiCapabilityChipImageGeneration => 'Génération d\'images';

  @override
  String get aiCapabilityChipImageRecognition => 'Reconnaissance d\'images';

  @override
  String get aiCapabilityChipThinking => 'Réflexion';

  @override
  String get aiCapabilityChipTranscription => 'Transcription';

  @override
  String get aiCardEmptyProposals =>
      'Aucune proposition ouverte · l\'agent affichera ici les nouvelles modifications';

  @override
  String aiCardHistoryToggle(int count) {
    return 'Historique · $count';
  }

  @override
  String get aiCardMenuActionDelete => 'Supprimer';

  @override
  String get aiCardMenuActionEdit => 'Modifier';

  @override
  String get aiCardOpenAgentInternals =>
      'Ouvrir les détails internes de l\'agent';

  @override
  String get aiCardProposalConfirmed => 'Confirmée';

  @override
  String get aiCardProposalDismissed => 'Rejetée';

  @override
  String get aiCardProposalKindAdd => 'Ajouter';

  @override
  String get aiCardProposalKindDue => 'Échéance';

  @override
  String get aiCardProposalKindEstimate => 'Estimation';

  @override
  String get aiCardProposalKindLabel => 'Étiquette';

  @override
  String get aiCardProposalKindPriority => 'Priorité';

  @override
  String get aiCardProposalKindRemove => 'Retirer';

  @override
  String get aiCardProposalKindStatus => 'Statut';

  @override
  String get aiCardProposalKindUpdate => 'Mettre à jour';

  @override
  String get aiCardReadMore => 'Lire plus';

  @override
  String get aiCardShowLess => 'Afficher moins';

  @override
  String get aiCardTitle => 'Résumé IA';

  @override
  String get aiChatMessageCopied => 'Copié dans le presse-papiers';

  @override
  String get aiConfigFailedToLoadModelsGeneric =>
      'Échec du chargement des modèles. Réessaie s\'il te plaît.';

  @override
  String get aiConfigNoModelsAvailable =>
      'Aucun modèle AI n\'est encore configuré. Ajoutes-en un dans les paramètres.';

  @override
  String get aiConfigNoSuitableModelsAvailable =>
      'Aucun modèle ne répond aux exigences de ce prompt. Configure des modèles avec les capacités requises.';

  @override
  String get aiConfigSelectProviderModalTitle =>
      'Sélectionner un fournisseur d\'inférence';

  @override
  String get aiConfigSelectProviderTypeModalTitle =>
      'Sélectionner le type de fournisseur';

  @override
  String get aiConfigUseReasoningFieldLabel => 'Utiliser le raisonnement';

  @override
  String aiDeleteToastCascadeDescription(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modèles aussi supprimés : $names',
      one: '1 modèle aussi supprimé : $names',
    );
    return '$_temp0';
  }

  @override
  String aiDeleteToastErrorTitle(String name) {
    return 'Impossible de supprimer $name';
  }

  @override
  String get aiDeleteToastModelTitle => 'Modèle supprimé';

  @override
  String get aiDeleteToastProfileTitle => 'Profil supprimé';

  @override
  String get aiDeleteToastPromptTitle => 'Prompt supprimé';

  @override
  String get aiDeleteToastProviderTitle => 'Fournisseur supprimé';

  @override
  String get aiDeleteToastSkillTitle => 'Compétence supprimée';

  @override
  String get aiDeleteToastUndoAction => 'Annuler';

  @override
  String get aiFormCancel => 'Annuler';

  @override
  String get aiFormFixErrors => 'Corrige les erreurs avant d\'enregistrer';

  @override
  String get aiFormNoChanges => 'Aucune modification non enregistrée';

  @override
  String get aiImageAnalysisPickerDefaultBadge => 'Par défaut';

  @override
  String get aiImageAnalysisPickerTitle =>
      'Choisis un modèle d\'analyse d\'image';

  @override
  String get aiInferenceErrorAuthenticationTitle =>
      'Échec de l\'authentification';

  @override
  String get aiInferenceErrorConnectionFailedTitle => 'Échec de la connexion';

  @override
  String get aiInferenceErrorInvalidRequestTitle => 'Requête invalide';

  @override
  String get aiInferenceErrorRateLimitTitle => 'Limite de requêtes dépassée';

  @override
  String get aiInferenceErrorRetryButton => 'Réessayer';

  @override
  String get aiInferenceErrorServerTitle => 'Erreur serveur';

  @override
  String get aiInferenceErrorSuggestionsTitle => 'Suggestions :';

  @override
  String get aiInferenceErrorTimeoutTitle => 'Délai d\'attente dépassé';

  @override
  String get aiInferenceErrorUnknownTitle => 'Erreur';

  @override
  String get aiInternalsTitle => 'Détails internes de l\'agent';

  @override
  String get aiModelDownloadCloseButton => 'Fermer';

  @override
  String aiModelDownloadDialogDescription(String modelName) {
    return 'Lotti télécharge $modelName dans le cache MLX Audio et l’utilise pour le traitement vocal local.';
  }

  @override
  String aiModelDownloadDialogTitle(String modelName) {
    return 'Installer $modelName';
  }

  @override
  String get aiModelDownloadInstallTooltip => 'Installer le modèle';

  @override
  String get aiModelDownloadOpenProgressTooltip =>
      'Afficher la progression du téléchargement';

  @override
  String get aiModelDownloadStatusChecking =>
      'Vérification de l’état du modèle';

  @override
  String aiModelDownloadStatusDownloading(int percent) {
    return 'Téléchargement $percent %';
  }

  @override
  String get aiModelDownloadStatusDownloadingIndeterminate => 'Téléchargement';

  @override
  String get aiModelDownloadStatusFailed => 'Téléchargement échoué';

  @override
  String get aiModelDownloadStatusInstalled => 'Installé';

  @override
  String get aiModelDownloadStatusNotInstalled => 'Non installé';

  @override
  String get aiModelDownloadStatusUnsupported => 'Apple Silicon requis';

  @override
  String get aiModelInstallChoiceCancelButton => 'Annuler';

  @override
  String get aiModelInstallChoiceDescription =>
      'Choisis d’abord le modèle de transcription locale à télécharger. Tu pourras installer les autres plus tard depuis la liste des modèles.';

  @override
  String get aiModelInstallChoiceInstallButton => 'Installer le modèle';

  @override
  String get aiModelInstallChoiceRecommended => 'Recommandé';

  @override
  String get aiModelInstallChoiceTitle => 'Choisir le modèle MLX Audio';

  @override
  String aiOllamaModelInstalledSuccessfully(String modelName) {
    return 'Modèle « $modelName » installé avec succès !';
  }

  @override
  String get aiPickProviderBadgeDesktopOnly => 'BUREAU UNIQUEMENT';

  @override
  String get aiPickProviderBadgeNew => 'NOUVEAU';

  @override
  String get aiPickProviderBadgeRecommended => 'RECOMMANDÉ';

  @override
  String get aiPickProviderContinueButton => 'Continuer';

  @override
  String get aiPickProviderDontShowAgainButton => 'Ne plus afficher';

  @override
  String get aiPickProviderFooterHint =>
      'Tu peux ajouter d\'autres fournisseurs plus tard dans Paramètres → IA. Ta clé API est stockée localement.';

  @override
  String get aiPickProviderModalTitle => 'Configure les fonctionnalités IA';

  @override
  String get aiPickProviderSubtitle =>
      'Choisis un fournisseur pour commencer. Nous configurerons automatiquement les modèles et un profil de départ.';

  @override
  String get aiProfileCardActiveBadge => 'Actif';

  @override
  String get aiProfileModelPickerSearchHint => 'Rechercher des modèles…';

  @override
  String get aiProfileSlotModelMissing => 'manquant';

  @override
  String get aiPromptGenerationPickerTitle =>
      'Choisis un modèle de génération de prompts';

  @override
  String get aiProviderAlibabaDescription =>
      'La famille de modèles Qwen d\'Alibaba Cloud via l\'API DashScope';

  @override
  String get aiProviderAlibabaName => 'Alibaba Cloud (Qwen)';

  @override
  String get aiProviderAnthropicDescription =>
      'La famille d\'assistants AI Claude d\'Anthropic';

  @override
  String get aiProviderAnthropicName => 'Anthropic Claude';

  @override
  String get aiProviderCardDraftBadge => 'BROUILLON';

  @override
  String get aiProviderCardFixButton => 'Corriger';

  @override
  String get aiProviderCardMenuTooltip => 'Plus d\'actions';

  @override
  String aiProviderCardModelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modèles',
      one: '1 modèle',
    );
    return '$_temp0';
  }

  @override
  String aiProviderCardModelCountWithLastUsed(int count, String lastUsed) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modèles · utilisés pour la dernière fois $lastUsed',
      one: '1 modèle · utilisé pour la dernière fois $lastUsed',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderCardOllamaHint =>
      'Vérifie qu\'Ollama est en cours d\'exécution';

  @override
  String aiProviderCardStatusConnected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Connecté · $count modèles',
      one: 'Connecté · 1 modèle',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderCardStatusConnectedShort => 'Connecté';

  @override
  String get aiProviderCardStatusInvalidKey => 'Clé invalide';

  @override
  String get aiProviderCardStatusOffline =>
      'Hors ligne · Vérifie qu\'Ollama est en cours d\'exécution';

  @override
  String get aiProviderCardStatusOfflineShort => 'Hors ligne';

  @override
  String get aiProviderConnectBackToProviders => 'Retour aux fournisseurs';

  @override
  String get aiProviderConnectBreadcrumbAdd => 'Ajouter un fournisseur';

  @override
  String get aiProviderConnectFieldBaseUrlHint =>
      'Laisse vide pour utiliser le point de terminaison officiel';

  @override
  String get aiProviderConnectFieldBaseUrlLabelOptional =>
      'URL de base (optionnel)';

  @override
  String get aiProviderConnectFieldBaseUrlPlaceholder =>
      'https://api.example.com';

  @override
  String get aiProviderConnectFieldDisplayNameHint =>
      'Affiché dans ta liste de fournisseurs';

  @override
  String get aiProviderConnectionCheckingLabel =>
      'Vérification de la clé, liste des modèles disponibles…';

  @override
  String aiProviderConnectionFailedBadResponseDetail(String type) {
    return 'Forme de réponse inattendue : $type';
  }

  @override
  String aiProviderConnectionFailedHttpDetail(int status, String message) {
    return 'HTTP $status · $message';
  }

  @override
  String get aiProviderConnectionFailedInvalidBaseUrlDetail =>
      'L\'URL de base doit inclure un schéma http(s) et un hôte (par ex. https://api.example.com)';

  @override
  String aiProviderConnectionFailedNetworkDetail(String message) {
    return '$message';
  }

  @override
  String get aiProviderConnectionFailedTimeoutDetail => 'La requête a expiré';

  @override
  String aiProviderConnectionFailedTitle(String providerName) {
    return 'Impossible de joindre $providerName. Vérifie la clé ou ton réseau.';
  }

  @override
  String get aiProviderConnectionRetestButton => 'Retester';

  @override
  String get aiProviderConnectionRetryButton => 'Réessayer';

  @override
  String aiProviderConnectionVerifiedSubtitle(int count, int ms) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modèles disponibles sur ton compte · réponse en $ms ms',
      one: '1 modèle disponible sur ton compte · réponse en $ms ms',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderConnectionVerifiedTitle => 'Connexion vérifiée';

  @override
  String aiProviderConnectKeyHelperLink(String url) {
    return 'Obtiens une clé sur $url';
  }

  @override
  String get aiProviderConnectKeyHiddenLabel => 'Masquée';

  @override
  String get aiProviderConnectKeyPrivacyHint =>
      'Ta clé API ne quitte jamais ton appareil.';

  @override
  String aiProviderConnectPageTitle(String providerName) {
    return 'Connecter $providerName';
  }

  @override
  String get aiProviderConnectSaveAndContinue => 'Enregistrer et continuer';

  @override
  String get aiProviderConnectSaveAsDraft => 'Enregistrer comme brouillon';

  @override
  String get aiProviderConnectSavedAsDraftToast => 'Enregistré comme brouillon';

  @override
  String get aiProviderConnectStepChoose => 'Choisir le fournisseur';

  @override
  String get aiProviderConnectStepConnect => 'Connecter';

  @override
  String get aiProviderConnectStepReview => 'Vérifier';

  @override
  String get aiProviderDetailActiveProfileTitle => 'Profil actif';

  @override
  String get aiProviderDetailAddModelButton => 'Ajouter un modèle';

  @override
  String get aiProviderDetailApiKeyLabel => 'Clé API';

  @override
  String get aiProviderDetailBackTooltip => 'Retour';

  @override
  String get aiProviderDetailBaseUrlLabel => 'URL de base';

  @override
  String get aiProviderDetailConnectionTitle => 'Connexion';

  @override
  String get aiProviderDetailDangerZoneTitle => 'Zone dangereuse';

  @override
  String get aiProviderDetailDisplayNameLabel => 'Nom d\'affichage';

  @override
  String get aiProviderDetailEditButton => 'Modifier';

  @override
  String get aiProviderDetailEditTooltip => 'Modifier le fournisseur';

  @override
  String get aiProviderDetailLoadError =>
      'Impossible de charger ce fournisseur. Réessaye depuis la liste des réglages IA.';

  @override
  String get aiProviderDetailMissingMessage =>
      'Ce fournisseur n\'est plus disponible.';

  @override
  String aiProviderDetailModelsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Modèles · $count',
      one: 'Modèles · 1',
      zero: 'Modèles',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderDetailNoModelsMessage =>
      'Aucun modèle pour l\'instant. Ajoutes-en un pour utiliser ce fournisseur.';

  @override
  String get aiProviderDetailPageTitle => 'Détails du fournisseur';

  @override
  String get aiProviderDetailRemoveButton => 'Supprimer le fournisseur';

  @override
  String get aiProviderDetailRemoveDescription =>
      'Supprime le fournisseur et tous les modèles qui en dépendent. Action irréversible.';

  @override
  String get aiProviderDetailRemoveTitle => 'Supprimer ce fournisseur';

  @override
  String get aiProviderDetailValueUnset => 'Non défini';

  @override
  String get aiProviderEmbeddedRuntimeHint =>
      'S’exécute intégré au processus de l’app Apple. Aucun serveur local ni URL de base n’est nécessaire.';

  @override
  String get aiProviderGeminiDescription => 'Modèles AI Gemini de Google';

  @override
  String get aiProviderGeminiName => 'Google Gemini';

  @override
  String get aiProviderGenericOpenAiDescription =>
      'API compatible avec le format OpenAI';

  @override
  String get aiProviderGenericOpenAiName => 'Compatible OpenAI';

  @override
  String get aiProviderMistralDescription =>
      'API cloud de Mistral AI avec transcription audio native';

  @override
  String get aiProviderMistralName => 'Mistral';

  @override
  String get aiProviderMlxAudioDescription =>
      'Modèles MLX Audio intégrés pour STT et TTS locaux sur Apple Silicon';

  @override
  String get aiProviderMlxAudioName => 'MLX Audio (local)';

  @override
  String get aiProviderNebiusAiStudioDescription =>
      'Modèles de Nebius AI Studio';

  @override
  String get aiProviderNebiusAiStudioName => 'Nebius AI Studio';

  @override
  String get aiProviderOllamaDescription =>
      'Exécuter l\'inférence localement avec Ollama';

  @override
  String get aiProviderOllamaName => 'Ollama';

  @override
  String get aiProviderOmlxDescription =>
      'Inférence oMLX locale compatible OpenAI pour les modèles MLX';

  @override
  String get aiProviderOmlxName => 'oMLX (local)';

  @override
  String get aiProviderOpenAiDescription => 'Modèles GPT d\'OpenAI';

  @override
  String get aiProviderOpenAiName => 'OpenAI';

  @override
  String get aiProviderOpenRouterDescription => 'Modèles d\'OpenRouter';

  @override
  String get aiProviderOpenRouterName => 'OpenRouter';

  @override
  String get aiProviderSelectContinue => 'Continuer';

  @override
  String get aiProviderSelectDontShowAgain => 'Ne plus afficher';

  @override
  String get aiProviderSetupOptionGeminiDescription =>
      'Modèles multimodaux avec transcription audio. Nécessite une clé API.';

  @override
  String get aiProviderSetupOptionMistralDescription =>
      'IA européenne avec raisonnement (Magistral) et audio (Voxtral).';

  @override
  String get aiProviderSetupOptionOpenAiDescription =>
      'Modèles GPT pour chat et raisonnement. Nécessite une clé API avec crédits.';

  @override
  String get aiProviderTaglineAlibaba =>
      'Modèles Qwen · multimodal · contexte long';

  @override
  String get aiProviderTaglineAnthropic => 'Famille Claude · contexte long';

  @override
  String get aiProviderTaglineGemini => 'Multimodal · transcription audio';

  @override
  String get aiProviderTaglineMlxAudio =>
      'Intégré · Apple Silicon · audio local';

  @override
  String get aiProviderTaglineOllama =>
      'S\'exécute en local · aucun appel cloud';

  @override
  String get aiProviderTaglineOmlx =>
      'Inférence MLX locale · compatible OpenAI';

  @override
  String get aiProviderTaglineOpenAi => 'Famille GPT · vision + raisonnement';

  @override
  String get aiProviderUnknownName => 'Fournisseur d\'IA';

  @override
  String get aiProviderVoxtralDescription =>
      'Transcription Voxtral locale (jusqu\'à 30 min d\'audio, 13 langues)';

  @override
  String get aiProviderVoxtralName => 'Voxtral (local)';

  @override
  String get aiProviderWhisperDescription =>
      'Transcription Whisper locale avec API compatible OpenAI';

  @override
  String get aiProviderWhisperName => 'Whisper (local)';

  @override
  String get aiRealtimeToggleTooltip => 'Passer à la transcription en direct';

  @override
  String get aiResponseDeleteCancel => 'Annuler';

  @override
  String get aiResponseDeleteConfirm => 'Supprimer';

  @override
  String get aiResponseDeleteError =>
      'Échec de la suppression de la réponse AI. Réessaie s\'il te plaît.';

  @override
  String get aiResponseDeleteTitle => 'Supprimer la réponse AI';

  @override
  String get aiResponseDeleteWarning =>
      'Es-tu sûr de vouloir supprimer cette réponse AI ? Cette action est irréversible.';

  @override
  String get aiResponseTypeAudioTranscription => 'Transcription audio';

  @override
  String get aiResponseTypeChecklistUpdates =>
      'Mises à jour de la liste de contrôle';

  @override
  String get aiResponseTypeImageAnalysis => 'Analyse d\'image';

  @override
  String get aiResponseTypeImagePromptGeneration => 'Prompt Image';

  @override
  String get aiResponseTypePromptGeneration => 'Prompt généré';

  @override
  String get aiResponseTypeTaskSummary => 'Résumé de tâche';

  @override
  String get aiRunningActivityOpenProgress =>
      'Afficher la progression de l\'IA';

  @override
  String get aiSettingsAddedLabel => 'Ajouté';

  @override
  String get aiSettingsAddModelButton => 'Ajouter un modèle';

  @override
  String get aiSettingsAddModelTooltip => 'Ajouter ce modèle à ton fournisseur';

  @override
  String get aiSettingsAddProfileButton => 'Ajouter un profil';

  @override
  String get aiSettingsAddProviderButton => 'Ajouter un fournisseur';

  @override
  String get aiSettingsClearAllFiltersTooltip => 'Effacer tous les filtres';

  @override
  String get aiSettingsClearFiltersButton => 'Effacer';

  @override
  String get aiSettingsCounterModels => 'Modèles';

  @override
  String get aiSettingsCounterProfiles => 'Profils';

  @override
  String get aiSettingsCounterProviders => 'Fournisseurs';

  @override
  String get aiSettingsEmptyDescription =>
      'Ajoutes-en un pour activer la transcription, la reconnaissance d\'images, la génération d\'images et la recherche sémantique.';

  @override
  String get aiSettingsEmptyTitle => 'Aucun fournisseur pour le moment';

  @override
  String aiSettingsFilterByCapabilityTooltip(String capability) {
    return 'Filtrer par capacité $capability';
  }

  @override
  String aiSettingsFilterByProviderTooltip(String provider) {
    return 'Filtrer par $provider';
  }

  @override
  String get aiSettingsFilterByReasoningTooltip =>
      'Filtrer par capacité de raisonnement';

  @override
  String get aiSettingsFtueBannerDescription =>
      'Cela prend environ une minute. Lotti configure des modèles et un profil de départ pour toi.';

  @override
  String get aiSettingsFtueBannerStartButton => 'Commencer la configuration';

  @override
  String get aiSettingsFtueBannerTitle =>
      'Ajoute ton premier fournisseur d\'IA';

  @override
  String get aiSettingsModalityAudio => 'Audio';

  @override
  String get aiSettingsModalityText => 'Texte';

  @override
  String get aiSettingsModalityVision => 'Vision';

  @override
  String get aiSettingsNoModelsConfigured => 'Aucun modèle AI configuré';

  @override
  String get aiSettingsNoProvidersConfigured =>
      'Aucun fournisseur AI configuré';

  @override
  String get aiSettingsPageLead =>
      'Configure les fournisseurs d\'IA, les modèles que Lotti peut appeler et les profils d\'inférence qui décident quel modèle gère chaque tâche.';

  @override
  String get aiSettingsPageTitle => 'Paramètres AI';

  @override
  String get aiSettingsReasoningLabel => 'Raisonnement';

  @override
  String get aiSettingsSearchHint => 'Rechercher des configurations AI...';

  @override
  String get aiSettingsSearchHintShort => 'Rechercher';

  @override
  String get aiSettingsTabModels => 'Modèles';

  @override
  String get aiSettingsTabProfiles => 'Profils';

  @override
  String get aiSettingsTabProviders => 'Fournisseurs';

  @override
  String get aiSetupPreviewAcceptButton => 'Accepter et terminer';

  @override
  String get aiSetupPreviewAlreadyAddedSectionLabel => 'Déjà ajoutés';

  @override
  String aiSetupPreviewCategoryFooter(String categoryName) {
    return 'Configure la catégorie de test $categoryName pour l\'essayer.';
  }

  @override
  String aiSetupPreviewConnectedHeader(String providerName) {
    return '$providerName connecté';
  }

  @override
  String get aiSetupPreviewCustomizeButton => 'Personnaliser';

  @override
  String get aiSetupPreviewLead =>
      'Vérifie ce que Lotti va ajouter. Décoche ce que tu ne veux pas ; tu pourras toujours le configurer manuellement plus tard.';

  @override
  String get aiSetupPreviewLiveBadge => 'En direct';

  @override
  String aiSetupPreviewModalTitle(String providerName) {
    return 'Configuration $providerName';
  }

  @override
  String get aiSetupPreviewModelsSectionLabel => 'Modèles';

  @override
  String get aiSetupPreviewProfileSectionLabel => 'Profil d\'inférence';

  @override
  String get aiSetupPreviewProfileSetActiveBadge => 'Activer';

  @override
  String aiSetupResultBulletCategoryCreated(String categoryName) {
    return 'Catégorie de test $categoryName configurée pour l\'essayer';
  }

  @override
  String aiSetupResultBulletCategoryReused(String categoryName) {
    return 'Catégorie de test existante $categoryName réutilisée';
  }

  @override
  String aiSetupResultBulletModels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modèles configurés',
      one: '1 modèle configuré',
    );
    return '$_temp0';
  }

  @override
  String aiSetupResultBulletProfile(String profileName) {
    return 'Profil d\'inférence $profileName créé';
  }

  @override
  String aiSetupResultErrorsHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count problèmes',
      one: '1 problème',
    );
    return '$_temp0 lors de la configuration';
  }

  @override
  String aiSetupResultHeader(String providerName) {
    return '$providerName est connecté';
  }

  @override
  String aiSetupResultKnownModelsMissing(String providerName) {
    return 'Impossible de trouver les configurations de modèle requises pour $providerName';
  }

  @override
  String get aiSetupResultLead =>
      'Nous avons tout configuré pour toi. Les fonctionnalités IA sont prêtes dans ton journal.';

  @override
  String aiSetupResultModalTitle(String providerName) {
    return '$providerName prêt';
  }

  @override
  String get aiSetupResultStartUsingButton => 'Commencer à utiliser l\'IA';

  @override
  String get aiSetupWizardCreatesOptimized =>
      'Crée des modèles, prompts et une catégorie de test optimisés';

  @override
  String aiSetupWizardDescription(String providerName) {
    return 'Configurer ou mettre à jour les modèles, prompts et la catégorie de test pour $providerName';
  }

  @override
  String get aiSetupWizardRunButton => 'Lancer la configuration';

  @override
  String get aiSetupWizardRunLabel => 'Lancer l\'assistant de configuration';

  @override
  String get aiSetupWizardRunningButton => 'En cours...';

  @override
  String get aiSetupWizardSafeToRunMultiple =>
      'Peut être exécuté plusieurs fois - les éléments existants seront conservés';

  @override
  String get aiSetupWizardTitle => 'Assistant de configuration AI';

  @override
  String get aiSummaryPlayTooltip => 'Lire le résumé';

  @override
  String get aiSummaryPreparingTooltip => 'Préparation de l\'audio';

  @override
  String get aiSummarySpeakTooltip => 'Lire le résumé localement à voix haute';

  @override
  String get aiSummaryStopTooltip => 'Arrêter';

  @override
  String get aiSummaryThinkingLabel => 'Réflexion…';

  @override
  String get aiSummaryTtsUnavailable =>
      'La synthèse vocale n\'est pas disponible';

  @override
  String get aiTaskSummaryTitle => 'Résumé de la tâche IA';

  @override
  String get aiTranscriptionPickerDefaultBadge => 'Par défaut';

  @override
  String get aiTranscriptionPickerTitle => 'Choisis un modèle de transcription';

  @override
  String get apiKeyAddPageTitle => 'Ajouter un fournisseur';

  @override
  String get apiKeyAuthenticationDescription =>
      'Sécurise ta connexion à l\'API';

  @override
  String get apiKeyAuthenticationTitle => 'Authentification';

  @override
  String get apiKeyAvailableModelsDescription =>
      'Ajoute rapidement des modèles préconfigurés pour ce fournisseur';

  @override
  String get apiKeyAvailableModelsTitle => 'Modèles disponibles';

  @override
  String get apiKeyBaseUrlLabel => 'URL de base';

  @override
  String get apiKeyDisplayNameHint => 'Saisis un nom convivial';

  @override
  String get apiKeyDisplayNameLabel => 'Nom d\'affichage';

  @override
  String get apiKeyEditGoBackButton => 'Retour';

  @override
  String get apiKeyEditLoadError =>
      'Échec du chargement de la configuration de la clé API';

  @override
  String get apiKeyEditLoadErrorRetry => 'Réessaie ou contacte le support';

  @override
  String get apiKeyEditPageTitle => 'Modifier le fournisseur';

  @override
  String get apiKeyHideTooltip => 'Masquer la clé API';

  @override
  String get apiKeyInputHint => 'Saisis ta clé API';

  @override
  String get apiKeyInputLabel => 'Clé API';

  @override
  String apiKeyKnownModelInputLabel(String modalities) {
    return 'Entrée : $modalities';
  }

  @override
  String apiKeyKnownModelOutputLabel(String modalities) {
    return 'Sortie : $modalities';
  }

  @override
  String get apiKeyProviderConfigDescription =>
      'Configure les paramètres de ton fournisseur d\'inférence IA';

  @override
  String get apiKeyProviderConfigTitle => 'Configuration du fournisseur';

  @override
  String get apiKeyProviderTypeHint => 'Sélectionne un type de fournisseur';

  @override
  String get apiKeyProviderTypeLabel => 'Type de fournisseur';

  @override
  String get apiKeyShowTooltip => 'Afficher la clé API';

  @override
  String get audioRecordingCancel => 'ANNULER';

  @override
  String get audioRecordingListening => 'Écoute en cours...';

  @override
  String get audioRecordingRealtime => 'Transcription en direct';

  @override
  String get audioRecordings => 'Enregistrements audio';

  @override
  String get audioRecordingStandard => 'Standard';

  @override
  String get audioRecordingStop => 'ARRÊTER';

  @override
  String backfillAdvancedRecoveryActions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count actions',
      one: '1 action',
    );
    return '$_temp0';
  }

  @override
  String get backfillAdvancedRecoveryTitle => 'Récupération avancée';

  @override
  String get backfillAskPeersConfirmAccept => 'Demander aux pairs';

  @override
  String backfillAskPeersConfirmContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Bascule les $count entrées du journal de séquence irrésolubles vers manquantes pour que le rattrapage normal redemande aux pairs. Les pairs qui ont encore les données répondront ; les entrées vraiment irrécupérables seront retirées à nouveau après la fenêtre d\'amnistie de 7 jours.',
      one:
          'Bascule 1 entrée du journal de séquence irrésoluble vers manquante pour que le rattrapage normal redemande aux pairs. Les pairs qui ont encore les données répondront ; les entrées vraiment irrécupérables seront retirées à nouveau après la fenêtre d\'amnistie de 7 jours.',
    );
    return '$_temp0';
  }

  @override
  String get backfillAskPeersConfirmTitle =>
      'Redemander aux pairs les entrées irrésolubles ?';

  @override
  String get backfillAskPeersDescription =>
      'Bascule chaque entrée irrésoluble vers manquante et laisse le rattrapage normal redemander aux pairs.';

  @override
  String get backfillAskPeersProcessing => 'Réouverture…';

  @override
  String get backfillAskPeersTitle => 'Demander aux pairs les irrésolubles';

  @override
  String backfillAskPeersTrigger(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Demander aux pairs $count entrées',
      one: 'Demander aux pairs 1 entrée',
    );
    return '$_temp0';
  }

  @override
  String get backfillCatchUpDescription =>
      'Récupère maintenant les entrées manquantes récentes depuis tes pairs.';

  @override
  String backfillDevicesMeta(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count IDs d\'appareil',
      one: '1 ID d\'appareil',
    );
    return '$_temp0';
  }

  @override
  String get backfillManualDescription =>
      'Demander toutes les entrées manquantes quel que soit leur âge. Utilisez cette option pour récupérer les écarts de synchronisation anciens.';

  @override
  String get backfillManualProcessing => 'Traitement...';

  @override
  String get backfillManualTitle => 'Rattrapage manuel';

  @override
  String get backfillManualTrigger => 'Demander les entrées manquantes';

  @override
  String get backfillReRequestDescription =>
      'Redemander les entrées qui ont été demandées mais jamais reçues. Utilisez cette option lorsque les réponses sont bloquées.';

  @override
  String get backfillReRequestProcessing => 'Nouvelle demande...';

  @override
  String get backfillReRequestTitle => 'Redemander les en attente';

  @override
  String get backfillReRequestTrigger => 'Redemander les entrées en attente';

  @override
  String get backfillResetUnresolvableDescription =>
      'Réinitialise les entrées marquées comme irrésolubles à l\'état manquant pour qu\'elles puissent être redemandées. Utilisez cette option après la repopulation du journal de séquence.';

  @override
  String get backfillResetUnresolvableProcessing => 'Réinitialisation...';

  @override
  String get backfillResetUnresolvableTitle =>
      'Réinitialiser les entrées irrésolubles';

  @override
  String get backfillResetUnresolvableTrigger =>
      'Réinitialiser les entrées irrésolubles';

  @override
  String get backfillRetireStuckConfirmAccept => 'Retirer maintenant';

  @override
  String backfillRetireStuckConfirmContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Marque les $count entrées de journal de séquence actuellement ouvertes (manquantes ou demandées) comme irrésolubles. Utilisez ceci pour débloquer le watermark quand des entrées sont bloquées depuis un moment sans que la fenêtre d\'amnistie de 7 jours soit écoulée. Les entrées peuvent toujours être ressuscitées si leurs données arrivent plus tard sur le disque avec une horloge vectorielle valide.',
      one:
          'Marque 1 entrée de journal de séquence actuellement ouverte (manquante ou demandée) comme irrésoluble. Utilisez ceci pour débloquer le watermark quand des entrées sont bloquées depuis un moment sans que la fenêtre d\'amnistie de 7 jours soit écoulée. Les entrées peuvent toujours être ressuscitées si leurs données arrivent plus tard sur le disque avec une horloge vectorielle valide.',
    );
    return '$_temp0';
  }

  @override
  String get backfillRetireStuckConfirmTitle =>
      'Retirer maintenant les entrées bloquées ?';

  @override
  String get backfillRetireStuckDescription =>
      'Force chaque entrée de journal de séquence manquante ou demandée actuellement ouverte à devenir irrésoluble. Ignore l\'amnistie de 7 jours — à utiliser uniquement pour les lignes bloquées qui bloquent le watermark.';

  @override
  String get backfillRetireStuckProcessing => 'Retrait…';

  @override
  String get backfillRetireStuckTitle => 'Retirer les entrées bloquées';

  @override
  String backfillRetireStuckTrigger(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Retirer $count entrées bloquées',
      one: 'Retirer 1 entrée bloquée',
    );
    return '$_temp0';
  }

  @override
  String get backfillSettingsSubtitle =>
      'Gérer la récupération des écarts de synchronisation';

  @override
  String get backfillSettingsTitle => 'Rattrapage de synchronisation';

  @override
  String get backfillStatsBackfilled => 'Rattrapé';

  @override
  String get backfillStatsBurned => 'Annulé';

  @override
  String get backfillStatsDeleted => 'Supprimé';

  @override
  String get backfillStatsMissing => 'Manquant';

  @override
  String get backfillStatsNoData =>
      'Aucune donnée de synchronisation disponible';

  @override
  String get backfillStatsReceived => 'Reçu';

  @override
  String get backfillStatsRefresh => 'Actualiser les statistiques';

  @override
  String get backfillStatsRequested => 'Demandé';

  @override
  String get backfillStatsTitle => 'Statistiques de synchronisation';

  @override
  String get backfillStatsTotalEntries => 'Total des entrées';

  @override
  String get backfillStatsUnresolvable => 'Non résoluble';

  @override
  String get backfillStatusInboundQueue => 'File entrante';

  @override
  String get backfillStatusMissing => 'Manquant';

  @override
  String get backfillStatusSkipped => 'Ignoré';

  @override
  String get backfillToggleDescription =>
      'Demande les entrées manquantes des dernières 24 heures.';

  @override
  String get backfillToggleTitle => 'Rattrapage automatique';

  @override
  String get basicSettings => 'Paramètres de base';

  @override
  String get cancelButton => 'Annuler';

  @override
  String get categoryActiveDescription =>
      'Les catégories inactives n\'apparaîtront pas dans les listes de sélection';

  @override
  String get categoryActiveSwitchDescription =>
      'Sélectionnable pour les nouvelles entrées';

  @override
  String get categoryAiDefaultsDescription =>
      'Définir le profil IA et le modèle d\'agent par défaut pour les nouvelles tâches de cette catégorie';

  @override
  String get categoryAiDefaultsTitle => 'Paramètres IA par défaut';

  @override
  String get categoryCreationError =>
      'Impossible de créer la catégorie. Réessaie s\'il te plaît.';

  @override
  String get categoryDayPlanDescription =>
      'Rendre cette catégorie disponible à la sélection dans le plan de ta journée';

  @override
  String get categoryDayPlanLabel => 'Planification du jour';

  @override
  String get categoryDefaultLanguageDescription =>
      'Définir une langue par défaut pour les tâches de cette catégorie';

  @override
  String get categoryDefaultProfileHint => 'Sélectionner un profil…';

  @override
  String get categoryDefaultTemplateHint => 'Sélectionner un modèle…';

  @override
  String get categoryDefaultTemplateLabel => 'Modèle d\'agent par défaut';

  @override
  String get categoryDeleteConfirm => 'OUI, SUPPRIMER CETTE CATÉGORIE';

  @override
  String get categoryDeleteConfirmation =>
      'Cette action est irréversible. Toutes les entrées de cette catégorie seront conservées mais ne seront plus catégorisées.';

  @override
  String get categoryDeleteTitle => 'Supprimer la catégorie ?';

  @override
  String get categoryFavoriteBadgeLabel => 'Favori';

  @override
  String get categoryFavoriteDescription =>
      'Marquer cette catégorie comme favorite';

  @override
  String get categoryIconChooseHint => 'Choisir une icône';

  @override
  String get categoryIconCreateHint => 'Choisir une icône';

  @override
  String get categoryIconEditHint => 'Choisir une autre icône';

  @override
  String get categoryIconLabel => 'Icône';

  @override
  String get categoryIconPickerTitle => 'Choisir une icône';

  @override
  String get categoryNameRequired => 'Le nom de la catégorie est obligatoire';

  @override
  String get categoryNotFound => 'Catégorie introuvable';

  @override
  String get categoryPrivateBadgeLabel => 'Privée';

  @override
  String get categoryPrivateDescription =>
      'Visible uniquement lorsque les entrées privées sont affichées';

  @override
  String get categorySearchPlaceholder => 'Rechercher des catégories...';

  @override
  String get changeSetCardTitle => 'Modifications proposées';

  @override
  String get changeSetConfirmAll => 'Tout confirmer';

  @override
  String changeSetConfirmAllPartialIssues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments ont rencontré des problèmes partiels',
      one: '1 élément a rencontré des problèmes partiels',
    );
    return '$_temp0';
  }

  @override
  String get changeSetConfirmError => 'Impossible d\'appliquer la modification';

  @override
  String get changeSetItemConfirmed => 'Modification appliquée';

  @override
  String changeSetItemConfirmedWithWarning(String warning) {
    return 'Appliquée avec avertissement : $warning';
  }

  @override
  String get changeSetItemRejected => 'Modification rejetée';

  @override
  String changeSetPendingCount(int count) {
    return '$count en attente';
  }

  @override
  String get changeSetSwipeConfirm => 'Confirmer';

  @override
  String get changeSetSwipeReject => 'Rejeter';

  @override
  String get chatInputCancelRealtime => 'Annuler (Échap)';

  @override
  String get chatInputCancelRecording => 'Annuler l\'enregistrement (Échap)';

  @override
  String get chatInputConfigureModel => 'Configurer le modèle';

  @override
  String get chatInputHintDefault =>
      'Posez des questions sur vos tâches et votre productivité...';

  @override
  String get chatInputHintSelectModel =>
      'Sélectionnez un modèle pour commencer à discuter';

  @override
  String get chatInputListening => 'Écoute en cours...';

  @override
  String get chatInputPleaseWait => 'Veuillez patienter...';

  @override
  String get chatInputProcessing => 'Traitement...';

  @override
  String get chatInputRecordVoice => 'Enregistrer un message vocal';

  @override
  String get chatInputSendTooltip => 'Envoyer le message';

  @override
  String get chatInputStartRealtime => 'Démarrer la transcription en direct';

  @override
  String get chatInputStopRealtime => 'Arrêter la transcription en direct';

  @override
  String get chatInputStopTranscribe => 'Arrêter et transcrire';

  @override
  String get checklistAddItem => 'Ajouter un nouvel élément';

  @override
  String checklistAiConfidenceLabel(String level) {
    return 'Confiance : $level';
  }

  @override
  String get checklistAiMarkComplete => 'Marquer comme terminé';

  @override
  String get checklistAiSuggestionBody => 'Cet élément semble être terminé :';

  @override
  String get checklistAiSuggestionTitle => 'Suggestion IA';

  @override
  String get checklistAllDone => 'Tous les éléments sont terminés !';

  @override
  String get checklistCollapseTooltip => 'Réduire';

  @override
  String checklistCompletedShort(int completed, int total) {
    return '$completed/$total terminés';
  }

  @override
  String get checklistDelete => 'Supprimer la liste de contrôle ?';

  @override
  String get checklistExpandTooltip => 'Développer';

  @override
  String get checklistExportAsMarkdown =>
      'Exporter la liste de contrôle en Markdown';

  @override
  String get checklistExportFailed => 'Échec de l\'exportation';

  @override
  String get checklistItemArchived => 'Élément archivé';

  @override
  String get checklistItemArchiveUndo => 'Annuler';

  @override
  String get checklistItemDeleteCancel => 'Annuler';

  @override
  String get checklistItemDeleteConfirm => 'Confirmer';

  @override
  String get checklistItemDeleted => 'Élément supprimé';

  @override
  String get checklistItemDeleteWarning =>
      'Cette action ne peut pas être annulée.';

  @override
  String get checklistMarkdownCopied => 'Liste de contrôle copiée en Markdown';

  @override
  String get checklistMoreTooltip => 'Plus';

  @override
  String get checklistNoneDone => 'Aucun élément terminé pour le moment.';

  @override
  String get checklistNothingToExport => 'Aucun élément à exporter';

  @override
  String get checklistProgressSemantics =>
      'Progression de la liste de contrôle';

  @override
  String get checklistShare => 'Partager';

  @override
  String get checklistShareHint => 'Appui long pour partager';

  @override
  String get checklistsReorder => 'Réorganiser';

  @override
  String get clearButton => 'Effacer';

  @override
  String get colorCustomLabel => 'Personnalisée';

  @override
  String get colorLabel => 'Couleur';

  @override
  String get commonError => 'Erreur';

  @override
  String get commonLoading => 'Chargement...';

  @override
  String get commonUnknown => 'Inconnu';

  @override
  String get completeHabitFailButton => 'Manqué';

  @override
  String get completeHabitSkipButton => 'Ignoré';

  @override
  String get completeHabitSuccessButton => 'Réussi';

  @override
  String get configFlagAttemptEmbeddingDescription =>
      'Lorsque cette option est activée, l\'application tentera de générer des embeddings pour tes entrées afin d\'améliorer la recherche et les suggestions de contenu associées.';

  @override
  String get configFlagDailyOsNextEnabled =>
      'Activer le nouveau DailyOS agentique';

  @override
  String get configFlagDailyOsNextEnabledDescription =>
      'Remplace l\'interface DailyOS actuelle par le nouveau flux de capture et de réconciliation piloté par l\'agent vocal. Aperçu précoce — la logique back-end est simulée.';

  @override
  String get configFlagEnableAiStreaming =>
      'Activer le streaming IA pour les actions liées aux tâches';

  @override
  String get configFlagEnableAiStreamingDescription =>
      'Diffuser les réponses IA pour les actions liées aux tâches. Désactivez pour mettre les réponses en mémoire tampon et conserver une interface plus fluide.';

  @override
  String get configFlagEnableAiSummaryTts => 'Lecture des résumés IA';

  @override
  String get configFlagEnableAiSummaryTtsDescription =>
      'Affiche le bouton local de synthèse vocale dans les résumés IA des tâches. Nécessite un modèle TTS MLX Audio installé.';

  @override
  String get configFlagEnableDailyOs => 'Activer DailyOS';

  @override
  String get configFlagEnableDailyOsDescription =>
      'Afficher DailyOS dans la navigation principale.';

  @override
  String get configFlagEnableDashboardsPage =>
      'Activer la page Tableaux de bord';

  @override
  String get configFlagEnableDashboardsPageDescription =>
      'Afficher la page Tableaux de bord dans la navigation principale. Affiche tes données et tes informations dans des tableaux de bord personnalisables.';

  @override
  String get configFlagEnableEmbeddings => 'Générer des embeddings';

  @override
  String get configFlagEnableEvents => 'Activer les événements';

  @override
  String get configFlagEnableEventsDescription =>
      'Afficher la fonctionnalité Événements pour créer, suivre et gérer des événements dans ton journal.';

  @override
  String get configFlagEnableForkHealing =>
      'Réparation des bifurcations d’agent';

  @override
  String get configFlagEnableForkHealingDescription =>
      'Fusionne les historiques d’agent divergents issus du multi-appareil au prochain réveil.';

  @override
  String get configFlagEnableHabitsPage => 'Activer la page Habitudes';

  @override
  String get configFlagEnableHabitsPageDescription =>
      'Afficher la page Habitudes dans la navigation principale. Suis et gère tes habitudes quotidiennes ici.';

  @override
  String get configFlagEnableKnowledgeGraph => 'Graphe de connaissances';

  @override
  String get configFlagEnableKnowledgeGraphDescription =>
      'Affiche l\'explorateur expérimental de graphe de connaissances sur les tâches — une carte visuelle des liens entre tâches, entrées et projets.';

  @override
  String get configFlagEnableLogging => 'Activer la journalisation';

  @override
  String get configFlagEnableLoggingDescription =>
      'Activer la journalisation détaillée à des fins de débogage. Cela peut avoir un impact sur les performances.';

  @override
  String get configFlagEnableMatrix => 'Activer la synchronisation Matrix';

  @override
  String get configFlagEnableMatrixDescription =>
      'Activer l\'intégration Matrix pour synchroniser tes entrées sur plusieurs appareils et avec d\'autres utilisateurs Matrix.';

  @override
  String get configFlagEnableNotifications => 'Activer les notifications ?';

  @override
  String get configFlagEnableNotificationsDescription =>
      'Recevoir des notifications pour les rappels, les mises à jour et les événements importants.';

  @override
  String get configFlagEnableProjects => 'Activer les projets';

  @override
  String get configFlagEnableProjectsDescription =>
      'Afficher les fonctions de gestion de projets pour organiser les tâches en projets.';

  @override
  String get configFlagEnableSessionRatings =>
      'Activer les évaluations de session';

  @override
  String get configFlagEnableSessionRatingsDescription =>
      'Proposer une évaluation rapide de session à l\'arrêt d\'un minuteur.';

  @override
  String get configFlagEnableSyncedAlerts => 'Alertes synchronisées';

  @override
  String get configFlagEnableSyncedAlertsDescription =>
      'Synchronise les alertes d\'IA et de tâches entre tes appareils et autorise-les à programmer des notifications système locales.';

  @override
  String get configFlagEnableTooltip => 'Activer les info-bulles';

  @override
  String get configFlagEnableTooltipDescription =>
      'Afficher des info-bulles utiles dans toute l\'application pour te guider à travers les fonctionnalités.';

  @override
  String get configFlagEnableVectorSearch => 'Recherche vectorielle';

  @override
  String get configFlagEnableVectorSearchDescription =>
      'Active la recherche vectorielle dans les filtres des tâches. Nécessite les embeddings activés et Ollama en cours d\'exécution.';

  @override
  String get configFlagEnableWhatsNew => 'Afficher « Nouveautés »';

  @override
  String get configFlagEnableWhatsNewDescription =>
      'Met en évidence les nouvelles fonctionnalités et modifications dans l\'arborescence des Réglages.';

  @override
  String get configFlagPrivate => 'Afficher les entrées privées ?';

  @override
  String get configFlagPrivateDescription =>
      'Active cette option pour rendre tes entrées privées par défaut. Les entrées privées ne sont visibles que par toi.';

  @override
  String get configFlagRecordLocation => 'Enregistrer la localisation';

  @override
  String get configFlagRecordLocationDescription =>
      'Enregistrer automatiquement ta position avec les nouvelles entrées. Cela facilite l\'organisation et la recherche basées sur la localisation.';

  @override
  String get configFlagResendAttachments => 'Renvoyer les pièces jointes';

  @override
  String get configFlagResendAttachmentsDescription =>
      'Active cette option pour renvoyer automatiquement les téléchargements de pièces jointes ayant échoué lorsque la connexion est rétablie.';

  @override
  String get configFlagShowSidebarWakeQueue =>
      'Afficher la file des réveils dans la barre latérale';

  @override
  String get configFlagShowSidebarWakeQueueDescription =>
      'Affiche la file des réveils au-dessus des Réglages — l\'en-tête, les deux prochains réveils avec compte à rebours, et un lien vers la liste complète.';

  @override
  String get configFlagShowSyncActivityIndicator =>
      'Afficher l\'indicateur d\'activité de synchronisation';

  @override
  String get configFlagShowSyncActivityIndicatorDescription =>
      'Affiche l\'activité de synchronisation en direct dans la barre latérale — une bande LED tx/rx avec la profondeur des files d\'entrée et de sortie.';

  @override
  String get conflictApplyButton => 'Appliquer';

  @override
  String get conflictApplyFailedTitle =>
      'Impossible d\'appliquer la résolution';

  @override
  String conflictBannerAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count jours',
      one: 'il y a 1 jour',
    );
    return '$_temp0';
  }

  @override
  String conflictBannerAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count h',
      one: 'il y a 1 h',
    );
    return '$_temp0';
  }

  @override
  String get conflictBannerAgoJustNow => 'à l\'instant';

  @override
  String conflictBannerAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count min',
      one: 'il y a 1 min',
    );
    return '$_temp0';
  }

  @override
  String conflictBannerDivergedAgo(String entity, String ago) {
    return '$entity · divergé $ago';
  }

  @override
  String conflictBannerFieldsDifferList(String fields) {
    return 'Différences : $fields';
  }

  @override
  String get conflictCombineApply => 'Appliquer la combinaison';

  @override
  String get conflictCombineStartFrom => 'Partir de';

  @override
  String get conflictConfirmDeletion => 'Confirmer la suppression';

  @override
  String get conflictDeleteVsEditDescription =>
      'Cette entrée a été modifiée sur un appareil et supprimée sur un autre. Rien n\'est supprimé tant que tu n\'as pas choisi.';

  @override
  String get conflictDeleteVsEditTitle => 'Supprimé sur un appareil';

  @override
  String get conflictDetailEntryNotFoundTitle => 'Entrée introuvable';

  @override
  String get conflictDetailLoadErrorTitle => 'Impossible de charger le conflit';

  @override
  String get conflictDetailNotFoundTitle => 'Conflit introuvable';

  @override
  String get conflictDiffRecommended => 'Recommandé';

  @override
  String conflictDiffUnchanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count champs inchangés',
      one: '1 champ inchangé',
    );
    return '$_temp0';
  }

  @override
  String get conflictFieldBody => 'Corps';

  @override
  String get conflictFieldCategory => 'catégorie';

  @override
  String get conflictFieldDuration => 'durée';

  @override
  String get conflictFieldEnd => 'Fin';

  @override
  String get conflictFieldFlag => 'Marqueur';

  @override
  String get conflictFieldOther => 'Autres détails';

  @override
  String get conflictFieldOtherDescription =>
      'Ces versions diffèrent par des détails non affichés individuellement ici.';

  @override
  String get conflictFieldPrivate => 'Privé';

  @override
  String get conflictFieldStarred => 'Favori';

  @override
  String get conflictFieldStart => 'Début';

  @override
  String get conflictFieldTitle => 'Titre';

  @override
  String get conflictFieldWordCount => 'nombre de mots';

  @override
  String get conflictFlagFollowUp => 'Suivi nécessaire';

  @override
  String get conflictFlagImport => 'Importé';

  @override
  String get conflictFlagNone => 'Aucun';

  @override
  String get conflictFooterHelperLocalSelected =>
      'Conserve ta modification locale et écarte la version synchronisée.';

  @override
  String get conflictFooterHelperPickASide => 'Choisis un côté à appliquer.';

  @override
  String get conflictFooterHelperRemoteSelected =>
      'Accepte la version synchronisée et écarte ta modification locale.';

  @override
  String conflictHeaderPillEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entrées',
      one: '1 entrée',
    );
    return '$_temp0';
  }

  @override
  String conflictHeaderPillFieldsDiffer(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count champs diffèrent',
      one: '1 champ diffère',
    );
    return '$_temp0';
  }

  @override
  String get conflictKeepEdited => 'Garder la version modifiée';

  @override
  String conflictListItemSemanticsLabel(
    String status,
    String timestamp,
    String entityType,
    String id,
  ) {
    return '$status, $timestamp, $entityType, conflit $id';
  }

  @override
  String conflictListItemTooltipFullId(String id) {
    return 'ID du conflit : $id';
  }

  @override
  String get conflictMetaLocalEdit => 'modif. locale';

  @override
  String get conflictMetaVecPrefix => 'vec';

  @override
  String get conflictMetaViaSync => 'via la sync';

  @override
  String conflictNotificationBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entrées ont été modifiées sur deux appareils',
      one: '1 entrée a été modifiée sur deux appareils',
    );
    return '$_temp0';
  }

  @override
  String get conflictNotificationTitle => 'La synchro a besoin de toi';

  @override
  String get conflictPageLeadDesktop =>
      'Différences mises en évidence en ligne. Clique sur un côté pour utiliser cette version, ou ouvre Modifier et fusionner pour les combiner.';

  @override
  String get conflictPageLeadMobile =>
      'Différences mises en évidence en ligne. Touche un côté pour utiliser cette version.';

  @override
  String get conflictPageTitle => 'Conflit de sync';

  @override
  String get conflictPickerCombine => 'Combiner…';

  @override
  String get conflictPickerEditMerge => 'Modifier et fusionner…';

  @override
  String get conflictPickerUseFromSync => 'Utiliser la sync';

  @override
  String get conflictPickerUseThisDevice => 'Utiliser cet appareil';

  @override
  String get conflictResolvedToast => 'Conflit résolu';

  @override
  String get conflictsEmptyDescription =>
      'Tout est synchronisé. Les éléments résolus restent disponibles dans l\'autre filtre.';

  @override
  String get conflictsEmptyTitle => 'Aucun conflit détecté';

  @override
  String get conflictSideFromSync => 'DEPUIS LA SYNC';

  @override
  String get conflictSideThisDevice => 'CET APPAREIL';

  @override
  String get conflictsResolved => 'résolu';

  @override
  String get conflictsUnresolved => 'non résolu';

  @override
  String get conflictValueAbsent => 'Non défini';

  @override
  String get conflictValueNo => 'Non';

  @override
  String get conflictValueYes => 'Oui';

  @override
  String conflictWordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mots',
      one: '$count mot',
    );
    return '$_temp0';
  }

  @override
  String get copyAsMarkdown => 'Copier en Markdown';

  @override
  String get copyAsText => 'Copier en texte';

  @override
  String get correctionExampleCancel => 'ANNULER';

  @override
  String correctionExamplePending(int seconds) {
    return 'Enregistrement de la correction dans ${seconds}s...';
  }

  @override
  String get correctionExamplesEmpty =>
      'Aucune correction capturée pour l\'instant. Modifie un élément de liste pour ajouter ton premier exemple.';

  @override
  String get correctionExamplesSectionDescription =>
      'Lorsque tu corriges manuellement des éléments de liste, ces corrections sont enregistrées ici et utilisées pour améliorer les suggestions de l\'IA.';

  @override
  String get correctionExamplesSectionTitle =>
      'Exemples de Correction de Liste';

  @override
  String correctionExamplesWarning(int count, int max) {
    return 'Tu as $count corrections. Seules les $max plus récentes seront utilisées dans les prompts IA. Pense à supprimer les exemples anciens ou redondants.';
  }

  @override
  String get coverArtChipActive => 'Couverture';

  @override
  String get coverArtChipSet => 'Définir couverture';

  @override
  String get coverArtGenerationComplete => 'Couverture prête !';

  @override
  String get coverArtGenerationDismissHint =>
      'Tu peux fermer ceci — la génération continue en arrière-plan';

  @override
  String get createButton => 'Créer';

  @override
  String get createCategoryTitle => 'Créer une catégorie';

  @override
  String get createEntryLabel => 'Créer une nouvelle entrée';

  @override
  String get createEntryTitle => 'Ajouter';

  @override
  String get createNewLinkedTask => 'Créer une nouvelle tâche liée...';

  @override
  String get customColor => 'Couleur personnalisée';

  @override
  String get dailyOsActual => 'Réel';

  @override
  String get dailyOsAddBlock => 'Ajouter un bloc';

  @override
  String get dailyOsAddBudget => 'Ajouter un budget';

  @override
  String get dailyOsAddNote => 'Ajouter une note...';

  @override
  String get dailyOsAgreeToPlan => 'Accepter le plan';

  @override
  String get dailyOsCancel => 'Annuler';

  @override
  String get dailyOsCategory => 'Catégorie';

  @override
  String get dailyOsChooseCategory => 'Choisir une catégorie...';

  @override
  String get dailyOsDayPlan => 'Plan du jour';

  @override
  String get dailyOsDaySummary => 'Résumé du jour';

  @override
  String get dailyOsDelete => 'Supprimer';

  @override
  String get dailyOsDeletePlannedBlock => 'Supprimer le bloc ?';

  @override
  String get dailyOsDeletePlannedBlockConfirm =>
      'Cela supprimera le bloc planifié de ta chronologie.';

  @override
  String get dailyOsDraftMessage =>
      'Le plan est un brouillon. Accepte pour le verrouiller.';

  @override
  String get dailyOsDueToday => 'Dû aujourd\'hui';

  @override
  String get dailyOsDueTodayShort => 'Dû';

  @override
  String dailyOsDurationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count heures',
      one: '1 heure',
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
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsEditPlannedBlock => 'Modifier le bloc planifié';

  @override
  String get dailyOsEndTime => 'Fin';

  @override
  String get dailyOsExpandToMove =>
      'Développer la chronologie pour déplacer ce bloc';

  @override
  String get dailyOsExpandToMoveMore =>
      'Développer la chronologie pour déplacer plus loin';

  @override
  String get dailyOsFailedToLoadBudgets => 'Échec du chargement des budgets';

  @override
  String get dailyOsFailedToLoadTimeline =>
      'Échec du chargement de la chronologie';

  @override
  String get dailyOsFold => 'Réduire';

  @override
  String get dailyOsInvalidTimeRange => 'Plage horaire invalide';

  @override
  String get dailyOsNearLimit => 'Proche de la limite';

  @override
  String get dailyOsNextAgendaCapacityComfortable => 'Confortable';

  @override
  String get dailyOsNextAgendaCapacityNearFull => 'Presque plein';

  @override
  String get dailyOsNextAgendaCapacityNoPlan => 'Pas encore de plan';

  @override
  String dailyOsNextAgendaCapacityOf(String capacity) {
    return 'sur $capacity';
  }

  @override
  String get dailyOsNextAgendaCapacityOver => 'Surcharge';

  @override
  String get dailyOsNextAgendaDonutLeft => 'libre';

  @override
  String get dailyOsNextAgendaDonutOver => 'en trop';

  @override
  String dailyOsNextAgendaHeadlineLeft(String duration) {
    return '$duration restant';
  }

  @override
  String dailyOsNextAgendaHeadlineOver(String duration) {
    return '$duration de trop';
  }

  @override
  String get dailyOsNextAgendaNoPlanBody =>
      'Ton temps suivi est là quoi qu\'il arrive — dicte un check-in et je construis ta journée autour.';

  @override
  String dailyOsNextAgendaNoPlanSummary(String duration) {
    return '$duration suivi pour l\'instant. Dicte un check-in et je construis ta journée autour.';
  }

  @override
  String get dailyOsNextAgendaNoPlanTitle =>
      'Pas encore de plan pour aujourd\'hui.';

  @override
  String get dailyOsNextAgendaStateDone => 'Fait';

  @override
  String get dailyOsNextAgendaStateInProgress => 'En cours';

  @override
  String get dailyOsNextAgendaStateOpen => 'Ouvert';

  @override
  String get dailyOsNextAgendaStateOverdue => 'En retard';

  @override
  String dailyOsNextAgendaSummary(String scheduled, String capacity) {
    return '$scheduled sur $capacity engagés';
  }

  @override
  String dailyOsNextAgendaTrackedLegend(String duration, int completedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      completedCount,
      locale: localeName,
      other: '$completedCount terminées',
      one: '1 terminée',
    );
    return 'Suivi · $duration · $_temp0';
  }

  @override
  String get dailyOsNextCaptureCaptured => 'C\'est noté.';

  @override
  String get dailyOsNextCaptureDoneCta => 'Terminer';

  @override
  String get dailyOsNextCaptureErrorMicrophonePermissionDenied =>
      'L’autorisation du micro a été refusée.';

  @override
  String get dailyOsNextCaptureErrorNoActiveRealtimeSession =>
      'Aucune session en temps réel active.';

  @override
  String get dailyOsNextCaptureErrorNoAudioRecorded =>
      'Aucun audio n’a été enregistré.';

  @override
  String get dailyOsNextCaptureErrorRealtimeTranscriptionFailed =>
      'La transcription en temps réel a échoué.';

  @override
  String get dailyOsNextCaptureErrorRealtimeTranscriptionStartFailed =>
      'La transcription en temps réel n’a pas pu démarrer.';

  @override
  String get dailyOsNextCaptureErrorRecordingStartFailed =>
      'L’enregistrement n’a pas pu démarrer.';

  @override
  String get dailyOsNextCaptureErrorTranscriptionFailed =>
      'La transcription a échoué.';

  @override
  String get dailyOsNextCaptureHeadlineCaptured => 'C\'est bien ça ?';

  @override
  String get dailyOsNextCaptureHeadlineLead => 'Qu\'as-tu en tête';

  @override
  String get dailyOsNextCaptureHeadlineListening => 'Je t\'écoute.';

  @override
  String get dailyOsNextCaptureHeadlineTail => 'pour aujourd\'hui ?';

  @override
  String dailyOsNextCaptureHeadlineTailForDate(String date) {
    return 'pour $date ?';
  }

  @override
  String get dailyOsNextCaptureHeadlineTailTomorrow => 'pour demain ?';

  @override
  String get dailyOsNextCaptureHeadlineTailYesterday => 'pour hier ?';

  @override
  String get dailyOsNextCaptureHeadlineTranscribing => 'Je note…';

  @override
  String get dailyOsNextCaptureIdleClick => 'Clique pour parler';

  @override
  String get dailyOsNextCaptureIdleExample =>
      '« Travail de fond ce matin, une balade après le déjeuner, les mails avant 17 h. »';

  @override
  String get dailyOsNextCaptureIdleHint => 'Tape pour parler · écris plutôt';

  @override
  String get dailyOsNextCaptureIdleTalk => 'Tape pour parler';

  @override
  String get dailyOsNextCaptureListeningStatus => 'À l’écoute…';

  @override
  String dailyOsNextCapturePastPrompt(String date) {
    return 'Tu veux encore suivre quelque chose du $date ?';
  }

  @override
  String get dailyOsNextCaptureReconcileCta => 'Vérifier';

  @override
  String get dailyOsNextCapturesPanelTitle => 'Captures';

  @override
  String get dailyOsNextCaptureTranscribing => 'Transcription en cours…';

  @override
  String get dailyOsNextCaptureTranscriptHint =>
      'Corrige ce que la transcription a mal compris avant de planifier.';

  @override
  String get dailyOsNextCaptureTranscriptLabel => 'Relis la transcription';

  @override
  String get dailyOsNextCaptureTypeInstead => 'Écrire plutôt';

  @override
  String get dailyOsNextCaptureVoiceButtonReset => 'Recommencer';

  @override
  String get dailyOsNextCaptureVoiceButtonStart => 'Démarrer l\'écoute';

  @override
  String get dailyOsNextCaptureVoiceButtonStop => 'Arrêter l\'écoute';

  @override
  String get dailyOsNextCategoryFilterAll => 'Toutes les catégories';

  @override
  String get dailyOsNextCategoryFilterDescription =>
      'Seules les catégories activées pour la planification du jour sont utilisées pour le traitement automatique de Daily OS.';

  @override
  String get dailyOsNextCategoryFilterEmpty =>
      'Aucune catégorie activée pour la planification du jour.';

  @override
  String get dailyOsNextCategoryFilterIncludeAll => 'Tout inclure';

  @override
  String get dailyOsNextCategoryFilterTitle => 'Catégories traitées';

  @override
  String get dailyOsNextCategoryFilterTooltip =>
      'Choisir les catégories traitées par Daily OS';

  @override
  String dailyOsNextCommitCapacityNote(String scheduled, String capacity) {
    return '$scheduled sur $capacity engagés. Marge confortable — tu peux absorber une surprise.';
  }

  @override
  String get dailyOsNextCommitDraftOverline => 'TA JOURNÉE, EN BROUILLON';

  @override
  String get dailyOsNextCommitExplainer =>
      'Valide pour faire passer la journée de brouillon à engagée.';

  @override
  String get dailyOsNextCommitFinalStepEyebrow => 'DERNIÈRE ÉTAPE';

  @override
  String get dailyOsNextCommitHeadline => 'Rends-la tienne.';

  @override
  String get dailyOsNextCommitHoldHelper =>
      'Maintiens une seconde pour valider';

  @override
  String get dailyOsNextCommitHoldWordDone => 'Engagée';

  @override
  String get dailyOsNextCommitHoldWordHolding => 'Continue';

  @override
  String get dailyOsNextCommitHoldWordIdle => 'Maintiens';

  @override
  String get dailyOsNextCommitLockingIn => 'Verrouillage…';

  @override
  String get dailyOsNextCommitShepherdSubline =>
      'Je guide — toi tu fais le travail.';

  @override
  String get dailyOsNextCommitSubCaption =>
      'Tu peux encore me parler ensuite — mais l\'ossature ne bouge plus.';

  @override
  String get dailyOsNextCommitTitle => 'Verrouiller';

  @override
  String get dailyOsNextCommitTodayIsYours => 'La journée est à toi.';

  @override
  String get dailyOsNextDayBack => 'Retour';

  @override
  String get dailyOsNextDayCheckInCta => 'Dicter un check-in';

  @override
  String get dailyOsNextDayDeleteDialogBody =>
      'Les blocs préparés pour cette journée seront supprimés. Tes captures et leurs enregistrements audio restent dans ton journal.';

  @override
  String get dailyOsNextDayDeleteDialogCancel => 'Annuler';

  @override
  String get dailyOsNextDayDeleteDialogConfirm => 'Supprimer';

  @override
  String get dailyOsNextDayDeleteDialogTitle => 'Supprimer ce plan ?';

  @override
  String get dailyOsNextDayLockInCta => 'Verrouiller';

  @override
  String get dailyOsNextDayMenuDeletePlan => 'Supprimer le plan';

  @override
  String get dailyOsNextDayMenuInspectAgent => 'Inspecter l\'agent';

  @override
  String get dailyOsNextDayMoreTooltip => 'Plus';

  @override
  String get dailyOsNextDayRefineCta => 'Ajuster';

  @override
  String get dailyOsNextDayRefineFooterHint =>
      'Parle pour réorganiser le plan — tu verras chaque changement avant qu\'il soit enregistré.';

  @override
  String get dailyOsNextDayTitle => 'Ta journée';

  @override
  String get dailyOsNextDayWhyChipLabel => 'POURQUOI';

  @override
  String get dailyOsNextDayWrapUpCta => 'Clore';

  @override
  String get dailyOsNextDraftingHeader => 'Préparation de ta journée…';

  @override
  String get dailyOsNextDraftingNudgeAccept => 'Oui, protège les matinées';

  @override
  String get dailyOsNextDraftingNudgeDecline => 'Pas aujourd\'hui';

  @override
  String get dailyOsNextDraftingReasoningOverline => '✦ RAISONNEMENT';

  @override
  String get dailyOsNextDraftingStatusAfternoon => 'J\'organise l\'après-midi…';

  @override
  String get dailyOsNextDraftingStatusAlmost => 'Presque fini…';

  @override
  String get dailyOsNextDraftingStatusBreathing =>
      'Je laisse de l\'air dans le planning…';

  @override
  String get dailyOsNextDraftingStatusDeepWork =>
      'Je place le travail de fond en premier…';

  @override
  String get dailyOsNextDraftingStatusMatching =>
      'J\'associe les tâches à ta journée…';

  @override
  String get dailyOsNextDraftingStatusReading => 'Je lis ton point du jour…';

  @override
  String get dailyOsNextDraftingStatusTimings => 'Je vérifie les horaires…';

  @override
  String get dailyOsNextDraftingStatusYesterday =>
      'Je regarde le rythme d\'hier…';

  @override
  String get dailyOsNextEditTitleHint => 'Modifier le titre';

  @override
  String get dailyOsNextGenericError =>
      'Une erreur est survenue. Réessaie dans un instant.';

  @override
  String get dailyOsNextGreetingAfternoon => 'Bon après-midi.';

  @override
  String get dailyOsNextGreetingEvening => 'Bonsoir.';

  @override
  String dailyOsNextGreetingHiName(String name) {
    return 'Salut $name 👋';
  }

  @override
  String get dailyOsNextGreetingMorning => 'Bonjour.';

  @override
  String get dailyOsNextKnowledgeConfirm => 'Confirmer';

  @override
  String get dailyOsNextKnowledgeConfirmedHeader => 'Confirmé';

  @override
  String get dailyOsNextKnowledgeEdit => 'Modifier';

  @override
  String get dailyOsNextKnowledgeEditCancel => 'Annuler';

  @override
  String get dailyOsNextKnowledgeEditHookHint => 'Résumé en une ligne';

  @override
  String get dailyOsNextKnowledgeEditSave => 'Enregistrer';

  @override
  String get dailyOsNextKnowledgeEditStatementHint => 'Que dois-je retenir ?';

  @override
  String get dailyOsNextKnowledgeEmpty =>
      'Rien pour l\'instant — je retiendrai ce que tu me dis.';

  @override
  String dailyOsNextKnowledgeNudge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count observations — à valider',
      one: '1 observation — à valider',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextKnowledgeProposedHeader =>
      'En attente de ta confirmation';

  @override
  String get dailyOsNextKnowledgeRetract => 'Oublier';

  @override
  String get dailyOsNextKnowledgeStale => 'Toujours vrai ?';

  @override
  String get dailyOsNextKnowledgeTitle => 'Ce que j\'ai appris';

  @override
  String get dailyOsNextParsedCardBreakLinkTooltip => 'Dissocier';

  @override
  String get dailyOsNextPlanViewAgenda => 'Agenda';

  @override
  String get dailyOsNextPlanViewDay => 'Journée';

  @override
  String get dailyOsNextReconcileBadgeMatched => 'LIÉ';

  @override
  String get dailyOsNextReconcileBadgeNew => 'NOUVEAU';

  @override
  String get dailyOsNextReconcileBadgeUpdate => 'MAJ';

  @override
  String get dailyOsNextReconcileBuildDayCta => 'Construire ma journée';

  @override
  String get dailyOsNextReconcileDecideOverline => 'À DÉCIDER';

  @override
  String get dailyOsNextReconcileDefaultBehaviorHint =>
      'Tes décisions ici alimentent le plan — ne rien décider signifie « laisse comme c\'est ».';

  @override
  String dailyOsNextReconcileError(String detail) {
    return 'Une erreur est survenue : $detail';
  }

  @override
  String get dailyOsNextReconcileHeadline => 'Voici ce que j’ai entendu.';

  @override
  String get dailyOsNextReconcileHeardEmpty =>
      'Les cartes de capture apparaîtront ici une fois l\'analyse terminée.';

  @override
  String get dailyOsNextReconcileHeardOverline => 'ENTENDU';

  @override
  String get dailyOsNextReconcileLowConfidence => 'confiance faible';

  @override
  String get dailyOsNextReconcileReRecord => 'Réenregistrer';

  @override
  String get dailyOsNextReconcileVoiceHint =>
      'Vérifie les décisions avant de construire ta journée';

  @override
  String get dailyOsNextRefineAccept => 'Accepter';

  @override
  String get dailyOsNextRefineCurrentPlan => 'PLAN ACTUEL';

  @override
  String get dailyOsNextRefineDiffAdded => 'AJOUTÉ';

  @override
  String get dailyOsNextRefineDiffDropped => 'RETIRÉ';

  @override
  String get dailyOsNextRefineDiffMoved => 'DÉPLACÉ';

  @override
  String get dailyOsNextRefineHeadlineDiffReady =>
      'Voilà ce que je changerais.';

  @override
  String get dailyOsNextRefineHeadlineIdle => 'Qu’est-ce qu’on change ?';

  @override
  String get dailyOsNextRefineHeadlineThinking => 'Je retravaille ton plan…';

  @override
  String get dailyOsNextRefineKeepTalking => 'Continuer à parler';

  @override
  String get dailyOsNextRefineLooksGood => 'C’est bon';

  @override
  String get dailyOsNextRefineNoChanges =>
      'Aucun changement de plan n\'est revenu. Reformule et réessaie.';

  @override
  String get dailyOsNextRefineOverline => '🎤 AFFINEMENT';

  @override
  String get dailyOsNextRefineRevert => 'Annuler';

  @override
  String get dailyOsNextRefineStatusAccepted => 'Verrouillé.';

  @override
  String get dailyOsNextRefineStatusDiffReady => 'Voilà ce qui a changé.';

  @override
  String get dailyOsNextRefineStatusIdle => 'Tape pour parler.';

  @override
  String get dailyOsNextRefineStatusListening => 'À l\'écoute…';

  @override
  String get dailyOsNextRefineStatusThinking => '✦ Réorganisation en cours…';

  @override
  String get dailyOsNextRefineTitle => 'Affiner le plan';

  @override
  String get dailyOsNextRenameFailed => 'Impossible de renommer — réessaie.';

  @override
  String get dailyOsNextShutdownCarryoverDrop => 'Abandonner';

  @override
  String get dailyOsNextShutdownCarryoverDropped => 'Abandonné';

  @override
  String get dailyOsNextShutdownCarryoverOverline => 'REPORTÉ';

  @override
  String get dailyOsNextShutdownCarryoverPickDate => 'Choisir une date';

  @override
  String get dailyOsNextShutdownCarryoverScheduled => 'Programmé';

  @override
  String get dailyOsNextShutdownCloseDay => 'Clore la journée';

  @override
  String get dailyOsNextShutdownCompletedOverline => 'CE QUE TU AS FAIT';

  @override
  String get dailyOsNextShutdownMetricEnergy => 'ÉNERGIE';

  @override
  String dailyOsNextShutdownMetricEnergyDelta(String delta) {
    return '$delta vs. semaine';
  }

  @override
  String get dailyOsNextShutdownMetricFlow => 'SESSIONS DE FLOW';

  @override
  String get dailyOsNextShutdownMetricFocus => 'TEMPS DE FOCUS';

  @override
  String get dailyOsNextShutdownMetricSwitches => 'CHANGEMENTS DE CONTEXTE';

  @override
  String dailyOsNextShutdownMetricSwitchesAvg(String avg) {
    return 'moy. $avg cette semaine';
  }

  @override
  String get dailyOsNextShutdownReflectionOverline =>
      '💬 RÉFLEXION EN UNE LIGNE';

  @override
  String get dailyOsNextShutdownReflectionPlaceholder =>
      'ex. : matin net, après-midi traînant après un café trop long avec Sarah.';

  @override
  String get dailyOsNextShutdownReflectionPrompt =>
      'Comment s\'est passée la journée ? (Cela alimente le brouillon de demain.)';

  @override
  String get dailyOsNextShutdownReflectionSpeak => 'Le dire';

  @override
  String get dailyOsNextShutdownReflectionSubmit => 'Passer';

  @override
  String get dailyOsNextShutdownReflectionThanks =>
      'Noté — ça alimente demain.';

  @override
  String get dailyOsNextShutdownSaveAndClose => 'Enregistrer et fermer';

  @override
  String get dailyOsNextShutdownTitle => 'Clore la journée';

  @override
  String get dailyOsNextShutdownTomorrowOverline => '✦ POUR DEMAIN';

  @override
  String dailyOsNextStateDueOnDate(String date) {
    return 'À rendre le $date';
  }

  @override
  String get dailyOsNextStateDueToday => 'Pour aujourd\'hui';

  @override
  String dailyOsNextStateInProgress(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'En cours · $count sessions',
      one: 'En cours · 1 session',
      zero: 'En cours',
    );
    return '$_temp0';
  }

  @override
  String dailyOsNextStateOverdue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'En retard · $days jours',
      one: 'En retard · 1 jour',
      zero: 'En retard',
    );
    return '$_temp0';
  }

  @override
  String dailyOsNextStateOverdueOnDate(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'En retard de $days jours le $date',
      one: 'En retard de 1 jour le $date',
      zero: 'En retard le $date',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextStateRecurringMissed => 'Récurrent · manqué';

  @override
  String get dailyOsNextTimelineActual => 'Réel';

  @override
  String get dailyOsNextTimelineBoth => 'Plan et réel';

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
    return 'Session $index sur $total';
  }

  @override
  String get dailyOsNextTimelineShowBoth => 'Afficher plan et réel ensemble';

  @override
  String get dailyOsNextTimelineShowPaged =>
      'Afficher plan et réel en balayage';

  @override
  String get dailyOsNextTimelineSwipeHint =>
      'Balaye vers le réel · pince verticalement pour zoomer';

  @override
  String get dailyOsNextTimelineTracked => 'suivi';

  @override
  String dailyOsNextTimeSpentEarlierSessions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions précédentes',
      one: '1 session précédente',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextTimeSpentShowLess => 'Afficher moins';

  @override
  String dailyOsNextTimeSpentSummary(String duration, int completedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      completedCount,
      locale: localeName,
      other: '$completedCount terminées',
      one: '1 terminée',
    );
    return '$duration · $_temp0';
  }

  @override
  String get dailyOsNextTimeSpentTitle => 'AUJOURD\'HUI';

  @override
  String get dailyOsNextTimeSpentTitlePast => 'TEMPS SUIVI';

  @override
  String get dailyOsNextTriageConfirmDefer => 'Reporté';

  @override
  String get dailyOsNextTriageConfirmDone => 'Marqué comme fait';

  @override
  String get dailyOsNextTriageConfirmDoNow => 'Fait tout de suite';

  @override
  String get dailyOsNextTriageConfirmDrop => 'Abandonné';

  @override
  String get dailyOsNextTriageConfirmToday => 'Ajouté à aujourd\'hui';

  @override
  String get dailyOsNextTriageDefer => 'Reporter';

  @override
  String get dailyOsNextTriageDone => 'Fait';

  @override
  String get dailyOsNextTriageDoNow => 'Faire maintenant';

  @override
  String get dailyOsNextTriageDrop => 'Abandonner';

  @override
  String get dailyOsNextTriageToday => 'Aujourd\'hui';

  @override
  String get dailyOsNoBudgets => 'Aucun budget de temps';

  @override
  String get dailyOsNoBudgetsHint =>
      'Ajoute des budgets pour suivre la répartition de ton temps entre les catégories.';

  @override
  String get dailyOsNoBudgetWarning => 'Pas de temps prévu';

  @override
  String get dailyOsNote => 'Note';

  @override
  String get dailyOsNoTimeline => 'Aucune entrée de chronologie';

  @override
  String get dailyOsNoTimelineHint =>
      'Démarre un minuteur ou ajoute des blocs planifiés pour voir ta journée.';

  @override
  String get dailyOsOnTrack => 'En bonne voie';

  @override
  String get dailyOsOver => 'Dépassé';

  @override
  String get dailyOsOverallProgress => 'Progression globale';

  @override
  String get dailyOsOverBudget => 'Budget dépassé';

  @override
  String get dailyOsOverdue => 'En retard';

  @override
  String get dailyOsOverdueShort => 'Retard';

  @override
  String get dailyOsPlan => 'Plan';

  @override
  String get dailyOsPlanCreated => 'Plan créé avec succès';

  @override
  String get dailyOsPlanCreatedDescription =>
      'Tes blocs de temps ont été enregistrés. Tu peux commencer à suivre tes tâches.';

  @override
  String get dailyOsPlanned => 'Planifié';

  @override
  String get dailyOsPlanWithoutVoice => 'Planifier sans la voix';

  @override
  String get dailyOsQuickCreateTask => 'Créer une tâche pour ce budget';

  @override
  String get dailyOsReAgree => 'Accepter à nouveau';

  @override
  String get dailyOsRecorded => 'Enregistré';

  @override
  String get dailyOsRemaining => 'Restant';

  @override
  String get dailyOsReviewMessage =>
      'Modifications détectées. Révise ton plan.';

  @override
  String get dailyOsSave => 'Enregistrer';

  @override
  String get dailyOsSaveError => 'Impossible d\'enregistrer le plan';

  @override
  String get dailyOsSaveErrorDescription =>
      'Quelque chose s\'est mal passé. Réessaie s\'il te plaît.';

  @override
  String get dailyOsSavePlan => 'Enregistrer le plan';

  @override
  String get dailyOsSelectCategory => 'Sélectionner une catégorie';

  @override
  String get dailyOsSetTimeBlocks => 'Définir les blocs de temps';

  @override
  String get dailyOsSetTimeBlocksAddNew => 'Ajouter un nouveau bloc de temps';

  @override
  String get dailyOsSetTimeBlocksFavourites => 'Favoris';

  @override
  String get dailyOsSetTimeBlocksOther => 'Autres catégories';

  @override
  String get dailyOsSetTimeBlocksTapHint =>
      'Appuie pour ajouter un bloc de temps';

  @override
  String get dailyOsStartTime => 'Début';

  @override
  String get dailyOsTasks => 'Tâches';

  @override
  String get dailyOsTimeBudgets => 'Budgets de temps';

  @override
  String dailyOsTimeLeft(String time) {
    return '$time restant';
  }

  @override
  String get dailyOsTimeline => 'Chronologie';

  @override
  String dailyOsTimeOver(String time) {
    return '+$time dépassé';
  }

  @override
  String get dailyOsTimeRange => 'Plage horaire';

  @override
  String get dailyOsTimesUp => 'Temps écoulé';

  @override
  String get dailyOsTodayButton => 'Aujourd\'hui';

  @override
  String get dailyOsUncategorized => 'Non catégorisé';

  @override
  String get dashboardActiveLabel => 'Actif';

  @override
  String get dashboardActiveSwitchDescription =>
      'Affiché dans la liste des tableaux de bord';

  @override
  String get dashboardAddChartsTitle => 'Graphiques';

  @override
  String get dashboardAddHabitButton => 'Tableaux des habitudes';

  @override
  String get dashboardAddHabitTitle => 'Tableaux des habitudes';

  @override
  String get dashboardAddHealthButton => 'Graphiques de santé';

  @override
  String get dashboardAddHealthTitle => 'Graphiques de santé';

  @override
  String get dashboardAddMeasurementButton => 'Graphiques de mesures';

  @override
  String get dashboardAddMeasurementTitle => 'Graphiques de mesures';

  @override
  String get dashboardAddMeasurementTooltip => 'Ajouter une mesure';

  @override
  String get dashboardAddSurveyButton => 'Graphiques des questionnaires';

  @override
  String get dashboardAddSurveyTitle => 'Graphiques des questionnaires';

  @override
  String get dashboardAddWorkoutButton => 'Graphiques d\'entraînement';

  @override
  String get dashboardAddWorkoutTitle => 'Graphiques d\'entraînement';

  @override
  String get dashboardAggregationDailyAverage => 'Moyenne quotidienne';

  @override
  String get dashboardAggregationDailyMax => 'Maximum quotidien';

  @override
  String get dashboardAggregationDailyTotal => 'Total quotidien';

  @override
  String get dashboardAggregationHourlyTotal => 'Total horaire';

  @override
  String get dashboardAggregationLabel => 'Type d\'agrégation :';

  @override
  String get dashboardCategoryLabel => 'Catégorie';

  @override
  String get dashboardChartNoData => 'Aucune donnée sur cette période';

  @override
  String get dashboardCopyHint =>
      'Enregistrer et copier la configuration du tableau de bord';

  @override
  String get dashboardCopyLabel => 'Enregistrer et copier la configuration';

  @override
  String get dashboardDeleteConfirm => 'OUI, SUPPRIMER CE TABLEAU DE BORD';

  @override
  String get dashboardDeleteHint => 'Supprimer tableau de bord';

  @override
  String get dashboardDeleteQuestion =>
      'Veux-tu vraiment supprimer ce tableau de bord ?';

  @override
  String get dashboardDescriptionLabel => 'Description';

  @override
  String get dashboardHealthBloodPressure => 'Tension artérielle';

  @override
  String get dashboardHealthDiastolic => 'Diastolique';

  @override
  String get dashboardHealthSystolic => 'Systolique';

  @override
  String get dashboardNameLabel => 'Nom du tableau de bord';

  @override
  String get dashboardNotFound => 'Tableau de bord non trouvé';

  @override
  String get dashboardPrivateLabel => 'Privé';

  @override
  String get dashboardTakeSurveyTooltip => 'Répondre au questionnaire';

  @override
  String get defaultLanguage => 'Langue par défaut';

  @override
  String get deleteButton => 'Supprimer';

  @override
  String get deleteDeviceLabel => 'Supprimer l\'appareil';

  @override
  String get designSystemActionVariantTitle => 'Avec action';

  @override
  String get designSystemActivatedLabel => 'Actif';

  @override
  String get designSystemAvatarAwayLabel => 'Absent';

  @override
  String get designSystemAvatarBusyLabel => 'Occupé';

  @override
  String get designSystemAvatarConnectedLabel => 'Connecté';

  @override
  String get designSystemAvatarEnabledLabel => 'Activé';

  @override
  String get designSystemAvatarSizeMatrixTitle => 'Matrice des tailles';

  @override
  String get designSystemAvatarStatusMatrixTitle => 'Matrice des statuts';

  @override
  String get designSystemBackLabel => 'Retour';

  @override
  String get designSystemBreadcrumbCurrentLabel => 'Fil d\'Ariane';

  @override
  String get designSystemBreadcrumbDesignSystemLabel => 'Design System';

  @override
  String get designSystemBreadcrumbHomeLabel => 'Accueil';

  @override
  String get designSystemBreadcrumbMobileLabel => 'Mobile';

  @override
  String get designSystemBreadcrumbProjectsLabel => 'Projets';

  @override
  String get designSystemBreadcrumbSampleLabel => 'Fil d\'Ariane';

  @override
  String get designSystemBreadcrumbTrailTitle => 'Chemin du fil d\'Ariane';

  @override
  String get designSystemCalendarPickerLabel => 'Sélecteur de calendrier';

  @override
  String get designSystemCalendarViewsTitle => 'Vues du calendrier';

  @override
  String get designSystemCaptionDescriptionSample =>
      'La suppression de tous les utilisateurs a dépublié ce projet. Ajoute des utilisateurs pour republier.';

  @override
  String get designSystemCaptionIconLeftLabel => 'Icône à gauche';

  @override
  String get designSystemCaptionIconTopLabel => 'Icône en haut';

  @override
  String get designSystemCaptionNoIconLabel => 'Sans icône';

  @override
  String get designSystemCaptionTitleSample => 'Titre';

  @override
  String get designSystemCaptionVariantsTitle => 'Variantes de caption';

  @override
  String get designSystemCaptionWithActionsLabel => 'Avec actions';

  @override
  String get designSystemCaptionWithoutActionsLabel => 'Sans actions';

  @override
  String get designSystemCheckboxLabel => 'Case à cocher';

  @override
  String get designSystemContextMenuDeleteLabel => 'Supprimer';

  @override
  String get designSystemContextMenuVariantsTitle =>
      'Variantes de menu contextuel';

  @override
  String get designSystemCountdownVariantTitle => 'Avec compte à rebours';

  @override
  String get designSystemDateCardsTitle => 'Cartes de date';

  @override
  String get designSystemDefaultLabel => 'Par défaut';

  @override
  String get designSystemDisabledLabel => 'Désactivé';

  @override
  String get designSystemDividerLabelText => 'Libellé du séparateur';

  @override
  String get designSystemDropdownComboboxTitle => 'Combobox';

  @override
  String get designSystemDropdownFieldLabel => 'Libellé';

  @override
  String get designSystemDropdownInputLabel => 'Saisie';

  @override
  String get designSystemDropdownListTitle => 'Liste déroulante';

  @override
  String get designSystemDropdownMultiselectInputLabel => 'Choisis des équipes';

  @override
  String get designSystemDropdownMultiselectTitle => 'Sélection multiple';

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
  String get designSystemErrorLabel => 'Erreur';

  @override
  String get designSystemFileUploadClickLabel => 'Cliquer pour téléverser';

  @override
  String get designSystemFileUploadCompleteLabel => 'Terminé';

  @override
  String get designSystemFileUploadDefaultLabel => 'Par défaut';

  @override
  String get designSystemFileUploadDragLabel => 'ou glisser-déposer';

  @override
  String get designSystemFileUploadDropZoneSectionTitle => 'Zone de dépôt';

  @override
  String get designSystemFileUploadErrorLabel => 'Erreur';

  @override
  String get designSystemFileUploadFailedText => 'Échec du téléversement';

  @override
  String get designSystemFileUploadHintText =>
      'SVG, PNG, JPG ou GIF (max. 800×400px)';

  @override
  String get designSystemFileUploadHoverLabel => 'Survol';

  @override
  String get designSystemFileUploadItemSectionTitle => 'Éléments de fichier';

  @override
  String get designSystemFileUploadRetryLabel => 'Réessayer';

  @override
  String get designSystemFileUploadUploadingLabel => 'Téléversement';

  @override
  String get designSystemFilledLabel => 'Rempli';

  @override
  String get designSystemHeaderApiDocumentationLabel => 'Documentation API';

  @override
  String get designSystemHeaderBackActionLabel => 'Retour';

  @override
  String get designSystemHeaderDesktopSectionTitle => 'Desktop';

  @override
  String get designSystemHeaderHelpActionLabel => 'Aide';

  @override
  String get designSystemHeaderMobileSectionTitle => 'Mobile';

  @override
  String get designSystemHeaderNotificationsActionLabel => 'Notifications';

  @override
  String get designSystemHeaderSearchActionLabel => 'Recherche';

  @override
  String get designSystemHorizontalLabel => 'Horizontal';

  @override
  String get designSystemHoverLabel => 'Survol';

  @override
  String get designSystemInfoLabel => 'Info';

  @override
  String get designSystemInputErrorSample => 'Ce champ est obligatoire';

  @override
  String get designSystemInputHelperSample => 'Saisis ton nom';

  @override
  String get designSystemInputHintSample => 'Espace réservé...';

  @override
  String get designSystemInputLabelSample => 'Libellé';

  @override
  String get designSystemInputVariantsTitle => 'Variantes de champ de saisie';

  @override
  String get designSystemInputWithErrorLabel => 'Avec erreur';

  @override
  String get designSystemInputWithHelperLabel => 'Avec texte d\'aide';

  @override
  String get designSystemInputWithIconsLabel => 'Avec icônes';

  @override
  String get designSystemListItemActivatedLabel => 'Activé';

  @override
  String get designSystemListItemOneLineLabel => 'Une ligne';

  @override
  String get designSystemListItemSubtitleSample => 'Sous-titre';

  @override
  String get designSystemListItemTitleSample => 'Titre';

  @override
  String get designSystemListItemTwoLinesLabel => 'Deux lignes';

  @override
  String get designSystemListItemVariantsTitle =>
      'Variantes d\'élément de liste';

  @override
  String get designSystemListItemWithDividerLabel => 'Avec séparateur';

  @override
  String get designSystemMediumLabel => 'Moyen';

  @override
  String designSystemMyDailyDurationHoursMinutesCompact(
    int hours,
    int minutes,
  ) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get designSystemMyDailyEditPlanLabel => 'Modifier le plan';

  @override
  String get designSystemMyDailyGreetingMorning => 'Bonjour.';

  @override
  String designSystemMyDailyGreetingWithName(String name) {
    return 'Salut, $name';
  }

  @override
  String get designSystemMyDailyHikeWithDanielaTitle =>
      'Randonnée avec Daniela';

  @override
  String get designSystemMyDailyLunchBreakTitle => 'Pause déjeuner';

  @override
  String get designSystemMyDailyMeetingsLabel => 'Réunions';

  @override
  String get designSystemMyDailyMeetingWithDannyTitle => 'Réunion avec Danny';

  @override
  String get designSystemMyDailyProfileActionLabel => 'Profil';

  @override
  String get designSystemMyDailySkiWithMattTitle => 'Aller skier avec Matt';

  @override
  String get designSystemMyDailyTapToExpandLabel => 'Appuie pour développer';

  @override
  String get designSystemNavigationCollapsedLabel => 'Replié';

  @override
  String get designSystemNavigationDailyFilterSectionTitle =>
      'Filtre quotidien';

  @override
  String get designSystemNavigationExpandedLabel => 'Déployé';

  @override
  String get designSystemNavigationFilterByBlockLabel => 'Filtrer par bloc';

  @override
  String get designSystemNavigationHikingLabel => 'Randonnée';

  @override
  String get designSystemNavigationHolidayLabel => 'Vacances';

  @override
  String get designSystemNavigationInsightsLabel => 'Aperçus';

  @override
  String get designSystemNavigationLottiTasksLabel => 'Tâches Lotti';

  @override
  String get designSystemNavigationMyDailyLabel => 'Mon quotidien';

  @override
  String get designSystemNavigationNewLabel => 'Nouveau';

  @override
  String get designSystemNavigationPlaceholderLabel => 'Espace réservé';

  @override
  String get designSystemNavigationSidebarSectionTitle =>
      'Variantes de barre latérale';

  @override
  String get designSystemNavigationSubComponentsSectionTitle =>
      'Sous-composants';

  @override
  String get designSystemNavigationTabBarSectionTitle =>
      'Variantes de barre d’onglets';

  @override
  String get designSystemPressedLabel => 'Appuyé';

  @override
  String get designSystemProgressBarChunkyLabel => 'Segmenté';

  @override
  String get designSystemProgressBarLabelAndPercentageLabel =>
      'Libellé + pourcentage';

  @override
  String get designSystemProgressBarLabelOnlyLabel => 'Libellé seul';

  @override
  String get designSystemProgressBarOffLabel => 'Désactivé';

  @override
  String get designSystemProgressBarPercentageOnlyLabel => 'Pourcentage';

  @override
  String get designSystemProgressBarQuestBarLabel => 'Barre de quête';

  @override
  String get designSystemProgressBarQuestLabel => 'Libellé de méga lot';

  @override
  String get designSystemProgressBarSampleLabel =>
      'Libellé de barre de progression';

  @override
  String get designSystemRadioButtonLabel => 'Bouton radio';

  @override
  String get designSystemScrollbarSizesTitle =>
      'Tailles de barre de défilement';

  @override
  String get designSystemSearchFilledText => 'Recherche Lotti';

  @override
  String get designSystemSearchHintLabel => 'Tape un utilisateur';

  @override
  String get designSystemSelectedLabel => 'Sélectionné';

  @override
  String get designSystemSizeScaleTitle => 'Échelle des tailles';

  @override
  String get designSystemSmallLabel => 'Petit';

  @override
  String get designSystemSpinnerPlainLabel => 'Simple';

  @override
  String get designSystemSpinnerSkeletonPulseLabel => 'Pulsation';

  @override
  String get designSystemSpinnerSkeletonsTitle => 'Squelettes';

  @override
  String get designSystemSpinnerSkeletonWaveLabel => 'Vague';

  @override
  String get designSystemSpinnerSpinnersTitle => 'Spinners';

  @override
  String get designSystemSpinnerTrackLabel => 'Avec piste';

  @override
  String designSystemSplitButtonDropdownSemantics(String label) {
    return 'Ouvrir les options de $label';
  }

  @override
  String get designSystemStateMatrixTitle => 'Matrice d\'états';

  @override
  String get designSystemSuccessLabel => 'Succès';

  @override
  String get designSystemTabBarTitle => 'Barre d\'onglets';

  @override
  String get designSystemTabPendingLabel => 'En attente';

  @override
  String get designSystemTaskListBlockedLabel => 'Bloqué';

  @override
  String get designSystemTaskListDefaultLabel => 'Par défaut';

  @override
  String get designSystemTaskListHoverLabel => 'Survol';

  @override
  String get designSystemTaskListItemSectionTitle =>
      'Variantes d\'élément de liste de tâches';

  @override
  String get designSystemTaskListOnHoldLabel => 'En attente';

  @override
  String get designSystemTaskListOpenLabel => 'Ouvert';

  @override
  String get designSystemTaskListPressedLabel => 'Appuyé';

  @override
  String get designSystemTaskListSampleTime => '8:00-9:30';

  @override
  String get designSystemTaskListSampleTitle => 'Tests utilisateurs';

  @override
  String get designSystemTaskListWithDividerLabel => 'Avec séparateur';

  @override
  String get designSystemTextareaErrorSample => 'Ce champ est obligatoire';

  @override
  String get designSystemTextareaHelperSample => 'Saisis ton message ici';

  @override
  String get designSystemTextareaHintSample => 'Écris quelque chose...';

  @override
  String get designSystemTextareaLabelSample => 'Libellé';

  @override
  String get designSystemTextareaVariantsTitle => 'Variantes de textarea';

  @override
  String get designSystemTextareaWithCounterLabel => 'Avec compteur';

  @override
  String get designSystemTextareaWithErrorLabel => 'Avec erreur';

  @override
  String get designSystemTextareaWithHelperLabel => 'Avec texte d\'aide';

  @override
  String get designSystemTimePickerFormatsTitle => 'Formats d\'heure';

  @override
  String get designSystemTimePickerTwelveHourLabel => '12 heures';

  @override
  String get designSystemTimePickerTwentyFourHourLabel => '24 heures';

  @override
  String get designSystemTitleOnlyVariantTitle => 'Variante titre seul';

  @override
  String get designSystemToastDetailsLabel => 'Détails de la notification';

  @override
  String get designSystemToggleLabel => 'Libellé du toggle';

  @override
  String get designSystemTooltipIconMessageSample =>
      'Informations utiles sur ce champ';

  @override
  String get designSystemTooltipIconVariantsTitle => 'Icône d\'info-bulle';

  @override
  String get designSystemUndoLabel => 'Annuler';

  @override
  String get designSystemVariantMatrixTitle => 'Matrice des variantes';

  @override
  String get designSystemVerticalLabel => 'Vertical';

  @override
  String get designSystemWarningLabel => 'Avertissement';

  @override
  String get designSystemWeeklyCalendarLabel => 'Calendrier hebdomadaire';

  @override
  String get designSystemWithLabelLabel => 'Avec libellé';

  @override
  String get desktopEmptyStateSelectDashboard =>
      'Sélectionne un tableau de bord pour voir les détails';

  @override
  String get desktopEmptyStateSelectProject =>
      'Sélectionne un projet pour voir les détails';

  @override
  String get desktopEmptyStateSelectTask =>
      'Sélectionne une tâche pour voir les détails';

  @override
  String deviceDeletedSuccess(String deviceName) {
    return 'Appareil $deviceName supprimé avec succès';
  }

  @override
  String deviceDeleteFailed(String error) {
    return 'Échec de suppression de l\'appareil : $error';
  }

  @override
  String get doneButton => 'Terminé';

  @override
  String get editMenuTitle => 'Modifier';

  @override
  String get editorInsertDivider => 'Insérer un séparateur';

  @override
  String get editorPlaceholder => 'Saisir des notes...';

  @override
  String get embeddingSelectAll => 'Tout sélectionner';

  @override
  String get embeddingUnselectAll => 'Tout désélectionner';

  @override
  String get enhancedPromptFormPreconfiguredPromptDescription =>
      'Choisir parmi des modèles de prompt prédéfinis';

  @override
  String get enterCategoryName => 'Saisir le nom de la catégorie';

  @override
  String get entryActions => 'Actions';

  @override
  String get entryLabelsActionSubtitle =>
      'Assigner des étiquettes pour organiser cette entrée';

  @override
  String get entryLabelsActionTitle => 'Étiquettes';

  @override
  String get entryLabelsEditTooltip => 'Modifier les étiquettes';

  @override
  String get entryLabelsHeaderTitle => 'Étiquettes';

  @override
  String get entryLabelsNoLabels => 'Aucune étiquette assignée';

  @override
  String get entryTypeLabelAiResponse => 'Réponse AI';

  @override
  String get entryTypeLabelChecklist => 'Liste de contrôle';

  @override
  String get entryTypeLabelChecklistItem => 'Élément de liste';

  @override
  String get entryTypeLabelHabitCompletionEntry => 'Habitude';

  @override
  String get entryTypeLabelJournalAudio => 'Audio';

  @override
  String get entryTypeLabelJournalEntry => 'Texte';

  @override
  String get entryTypeLabelJournalEvent => 'Événement';

  @override
  String get entryTypeLabelJournalImage => 'Photo';

  @override
  String get entryTypeLabelMeasurementEntry => 'Mesure';

  @override
  String get entryTypeLabelQuantitativeEntry => 'Santé';

  @override
  String get entryTypeLabelSurveyEntry => 'Sondage';

  @override
  String get entryTypeLabelTask => 'Tâche';

  @override
  String get entryTypeLabelWorkoutEntry => 'Entraînement';

  @override
  String get eventNameLabel => 'Événement :';

  @override
  String get favoriteLabel => 'Favori';

  @override
  String get fileMenuNewEllipsis => 'Nouveau...';

  @override
  String get fileMenuNewEntry => 'Nouvelle entrée';

  @override
  String get fileMenuNewScreenshot => 'Capture d\'écran';

  @override
  String get fileMenuNewTask => 'Tâche';

  @override
  String get fileMenuTitle => 'Fichier';

  @override
  String get filterSelectionNoMatches => 'Aucun résultat';

  @override
  String get geminiThinkingModeHighDescription =>
      'Raisonnement le plus poussé ; peut augmenter la latence et le coût.';

  @override
  String get geminiThinkingModeHighLabel => 'Élevé';

  @override
  String get geminiThinkingModeLowDescription =>
      'Raisonnement faible pour des prompts quotidiens rapides.';

  @override
  String get geminiThinkingModeLowLabel => 'Faible';

  @override
  String get geminiThinkingModeMediumDescription =>
      'Raisonnement équilibré pour des réponses plus soignées.';

  @override
  String get geminiThinkingModeMediumLabel => 'Moyen';

  @override
  String get geminiThinkingModeMinimalDescription =>
      'Réglage le plus rapide ; Gemini peut quand même réfléchir brièvement sur les prompts complexes.';

  @override
  String get geminiThinkingModeMinimalLabel => 'Minimal';

  @override
  String get generateCoverArt => 'Générer une couverture';

  @override
  String get generateCoverArtSubtitle =>
      'Créer une image à partir de la description vocale';

  @override
  String get habitActiveFromLabel => 'Date de début';

  @override
  String get habitActiveSwitchDescription => 'Affichée sur la page Habitudes';

  @override
  String get habitArchivedLabel => 'Archivé';

  @override
  String get habitCategoryHint => 'Choisir une catégorie';

  @override
  String get habitCategoryLabel => 'Catégorie';

  @override
  String get habitCloseCompletionLabel => 'Fermer la saisie d\'habitude';

  @override
  String habitCompleteSemanticLabel(String habit) {
    return 'Enregistrer $habit';
  }

  @override
  String get habitCompletionStatusCompleted => 'Terminé';

  @override
  String get habitCompletionStatusFailed => 'Échoué';

  @override
  String get habitCompletionStatusOpen => 'Ouvert';

  @override
  String get habitCompletionStatusSkipped => 'Ignoré';

  @override
  String get habitDashboardHint => 'Choisir un tableau de bord';

  @override
  String get habitDashboardLabel => 'Tableau de bord (facultatif)';

  @override
  String habitDayStatusSemantic(String habit, String status) {
    return '$habit, $status';
  }

  @override
  String get habitDeleteConfirm => 'OUI, SUPPRIMER CETTE HABITUDE';

  @override
  String get habitDeleteQuestion => 'Veux-tu supprimer cette habitude ?';

  @override
  String habitHeatmapDaySemantic(String date, int done, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total faits',
      one: '1 fait',
    );
    return '$date, $done sur $_temp0';
  }

  @override
  String get habitLogOtherDayHint =>
      'Maintiens appuyé pour enregistrer un autre jour';

  @override
  String get habitNotRecordedLabel => 'Non enregistré';

  @override
  String get habitPriorityLabel => 'Priorité';

  @override
  String get habitsAboveGoal => 'Dans les clous';

  @override
  String habitsActiveHabitsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count habitudes actives',
      one: '1 habitude active',
    );
    return '$_temp0';
  }

  @override
  String get habitsAllDoneToday => 'Tout est fait aujourd\'hui';

  @override
  String get habitsCompletedHeader => 'Terminées';

  @override
  String get habitsCompletionRateTitle => 'Taux de réussite';

  @override
  String get habitsConsistencyTitle => 'Régularité';

  @override
  String habitsDayFailedPercent(int percent) {
    return '$percent% marqués manqués';
  }

  @override
  String habitsDaySkippedPercent(int percent) {
    return '$percent% ignorés';
  }

  @override
  String habitsDaySuccessfulPercent(int percent) {
    return '$percent% réussis';
  }

  @override
  String get habitsDoneTodayLabel => 'Fait aujourd\'hui';

  @override
  String get habitSectionOptionsTitle => 'Options';

  @override
  String get habitSectionScheduleTitle => 'Planification';

  @override
  String get habitsFilterAll => 'toutes';

  @override
  String get habitsFilterCompleted => 'terminées';

  @override
  String get habitsFilterOpenNow => 'dues';

  @override
  String get habitsFilterPendingLater => 'plus tard';

  @override
  String get habitsGoalLineLabel => 'Objectif';

  @override
  String get habitsHeatmapEmpty =>
      'Ajoute une habitude pour commencer à suivre ta régularité';

  @override
  String get habitsHeatmapLess => 'Moins';

  @override
  String get habitsHeatmapMore => 'Plus';

  @override
  String get habitShowAlertAtLabel => 'Afficher l\'alerte à';

  @override
  String get habitShowFromLabel => 'Afficher à partir de';

  @override
  String habitsLaggardHint(String habit, int kept, int active) {
    return '$habit — $kept sur $active réussis';
  }

  @override
  String get habitsOpenHeader => 'Dues maintenant';

  @override
  String get habitsPendingLaterHeader => 'Plus tard dans la journée';

  @override
  String habitsPointsToGoal(int points) {
    String _temp0 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: '$points pts avant l\'\'objectif',
      one: '1 pt avant l\'\'objectif',
    );
    return '$_temp0';
  }

  @override
  String get habitsRecordButton => 'Enregistrer';

  @override
  String get habitsRollingAverageLabel => 'moyenne sur 7 jours';

  @override
  String get habitsStartStreakToday => 'Commence une série aujourd\'hui';

  @override
  String habitsStreakLongCount(int count) {
    return '$count sur une série de 7 jours';
  }

  @override
  String habitsStreakShortCount(int count) {
    return '$count sur une série de 3 jours';
  }

  @override
  String get habitsTapForBreakdown => 'Touche un jour pour le détail';

  @override
  String habitsToGoCount(int count) {
    return 'encore $count';
  }

  @override
  String habitStreakDaysSemantic(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours d\'\'affilée',
      one: '1 jour d\'\'affilée',
    );
    return '$_temp0';
  }

  @override
  String get habitsVsPreviousWeek => 'vs semaine précédente';

  @override
  String get imageGenerationError => 'Échec de la génération d\'image';

  @override
  String get imageGenerationGenerating => 'Génération de l\'image...';

  @override
  String get imageGenerationProviderRejectedTitle =>
      'Le fournisseur d\'images a refusé cette demande';

  @override
  String imageGenerationWithReferences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Avec $count images de référence',
      one: 'Avec 1 image de référence',
      zero: 'Aucune image de référence',
    );
    return '$_temp0';
  }

  @override
  String get imagePromptGenerationCardTitle => 'Prompt Image IA';

  @override
  String get imagePromptGenerationCopiedSnackbar =>
      'Prompt d\'image copié dans le presse-papiers';

  @override
  String get imagePromptGenerationCopyButton => 'Copier Prompt';

  @override
  String get imagePromptGenerationCopyTooltip =>
      'Copier le prompt d\'image dans le presse-papiers';

  @override
  String get imagePromptGenerationExpandTooltip => 'Afficher le prompt complet';

  @override
  String get imagePromptGenerationFullPromptLabel => 'Prompt image complet :';

  @override
  String get images => 'Images';

  @override
  String get inactiveLabel => 'Inactif';

  @override
  String get inactiveSwitchDescription =>
      'Peut être choisi pour de nouvelles entrées si actif';

  @override
  String get inferenceProfileCreateTitle => 'Créer un profil';

  @override
  String get inferenceProfileDescriptionLabel => 'Description';

  @override
  String get inferenceProfileDesktopOnly => 'Bureau uniquement';

  @override
  String get inferenceProfileDesktopOnlyDescription =>
      'Disponible uniquement sur les plateformes de bureau (ex. pour les modèles locaux)';

  @override
  String inferenceProfileDetailLoadError(String error) {
    return 'Impossible de charger le profil : $error';
  }

  @override
  String get inferenceProfileDetailNotFound => 'Profil introuvable';

  @override
  String get inferenceProfileEditTitle => 'Modifier le profil';

  @override
  String get inferenceProfileImageGeneration => 'Génération d\'images';

  @override
  String get inferenceProfileImageRecognition => 'Reconnaissance d\'images';

  @override
  String get inferenceProfileNameLabel => 'Nom du profil';

  @override
  String get inferenceProfileNameRequired => 'Un nom de profil est requis';

  @override
  String get inferenceProfilePinnedHostHelper =>
      'Lorsque défini, seul cet appareil exécute automatiquement l\'inférence pour les entrées audio synchronisées qui utilisent ce profil.';

  @override
  String get inferenceProfilePinnedHostLabel => 'Appareil épinglé';

  @override
  String get inferenceProfilePinnedHostNoEligibleNodes =>
      'Aucun appareil connu n\'annonce les fournisseurs que ce profil utilise. Ouvre les paramètres des nœuds de synchronisation sur l\'appareil cible.';

  @override
  String get inferenceProfilePinnedHostNoneHelper =>
      'Les entrées audio synchronisées ne sont pas transcrites automatiquement quand aucun appareil n\'est épinglé.';

  @override
  String get inferenceProfilePinnedHostNoneLabel =>
      'Non épinglé (pas de déclenchement auto)';

  @override
  String get inferenceProfilePinnedHostThisDeviceSuffix => ' (cet appareil)';

  @override
  String get inferenceProfileSaveButton => 'Enregistrer';

  @override
  String get inferenceProfileSelectModel => 'Sélectionner un modèle…';

  @override
  String get inferenceProfileSelectProfile => 'Sélectionner un profil…';

  @override
  String get inferenceProfilesEmpty => 'Aucun profil d\'inférence';

  @override
  String inferenceProfileSkillModelRequired(String slotName) {
    return 'Nécessite le modèle $slotName';
  }

  @override
  String get inferenceProfileSkillsSection => 'Compétences automatisées';

  @override
  String inferenceProfileSkillUsesModel(String slotName) {
    return 'Utilise le modèle $slotName';
  }

  @override
  String get inferenceProfilesTitle => 'Profils d\'inférence';

  @override
  String get inferenceProfileThinking => 'Réflexion';

  @override
  String get inferenceProfileThinkingHighEnd => 'Réflexion (haut de gamme)';

  @override
  String get inferenceProfileThinkingRequired =>
      'Un modèle de réflexion est requis';

  @override
  String get inferenceProfileTranscription => 'Transcription';

  @override
  String get inputDataTypeAudioFilesDescription =>
      'Utiliser des fichiers audio comme entrée';

  @override
  String get inputDataTypeAudioFilesName => 'Fichiers audio';

  @override
  String get inputDataTypeImagesDescription =>
      'Utiliser des images comme entrée';

  @override
  String get inputDataTypeImagesName => 'Images';

  @override
  String get inputDataTypeTaskDescription =>
      'Utiliser la tâche actuelle comme entrée';

  @override
  String get inputDataTypeTaskName => 'Tâche';

  @override
  String get inputDataTypeTasksListDescription =>
      'Utiliser une liste de tâches comme entrée';

  @override
  String get inputDataTypeTasksListName => 'Liste de tâches';

  @override
  String get insightsChartCompareCaption => 'Cette période vs la précédente';

  @override
  String get insightsChartCompareCaptionPartial =>
      'Cette période jusqu\'ici vs la précédente';

  @override
  String get insightsChartCompareHint =>
      'Comparaison affichée dans le tableau ci-dessous';

  @override
  String get insightsChartCumulativeCaption => 'Total cumulé sur la période';

  @override
  String get insightsChartCumulativeShort =>
      'Pas encore assez de jours pour un total cumulé';

  @override
  String get insightsChartDailyCaption => 'Temps par jour';

  @override
  String get insightsChartHourlyCaption => 'Temps par heure';

  @override
  String get insightsChartPerDay => 'Par jour';

  @override
  String get insightsChartPerHour => 'Par heure';

  @override
  String get insightsChartPerWeek => 'Par semaine';

  @override
  String get insightsChartRunningTotal => 'Total cumulé';

  @override
  String get insightsChartTitle => 'Temps par catégorie';

  @override
  String get insightsChartWeeklyCaption => 'Temps par semaine';

  @override
  String get insightsChooseFocusCategories => 'Choisir les catégories focus';

  @override
  String get insightsCompare => 'Comparer';

  @override
  String get insightsCompareFullPeriod => 'période entière';

  @override
  String get insightsComparePrevious => 'Précédent';

  @override
  String get insightsCompareSameDays => 'mêmes jours';

  @override
  String get insightsCompareTooltip => 'Comparer avec la période précédente';

  @override
  String get insightsCompareVs => 'vs';

  @override
  String get insightsDeletedCategory => 'Catégorie supprimée';

  @override
  String get insightsDeltaNew => 'nouveau';

  @override
  String get insightsEmptyBody =>
      'Le temps que tu suis sur tes notes et tâches apparaîtra ici.';

  @override
  String get insightsEmptyChart => 'Aucune donnée sur cette période';

  @override
  String get insightsEmptyPreviousPeriod => 'Voir la période précédente';

  @override
  String get insightsEmptyShowYear => 'Voir cette année';

  @override
  String get insightsEmptyTitle => 'Aucun temps suivi sur cette période';

  @override
  String get insightsFocusCategoriesEmpty =>
      'Aucune catégorie active pour le moment.';

  @override
  String get insightsFocusCategoriesTitle => 'Catégories focus';

  @override
  String get insightsKpiFocus => 'FOCUS';

  @override
  String get insightsKpiFocusHelp => 'Catégories que tu suis';

  @override
  String get insightsKpiOther => 'AUTRE';

  @override
  String get insightsKpiOtherHelp => 'Tout le reste';

  @override
  String insightsKpiTopCategory(String category, String share) {
    return 'Surtout sur $category · $share';
  }

  @override
  String get insightsKpiTotal => 'TOTAL';

  @override
  String get insightsLoadError => 'Impossible de charger les données de temps';

  @override
  String get insightsOtherCategories => 'Autre';

  @override
  String get insightsPartialWeek => 'semaine partielle';

  @override
  String get insightsPeriodDay => 'Jour';

  @override
  String get insightsPeriodJump => 'Aller à une date';

  @override
  String get insightsPeriodMonth => 'Mois';

  @override
  String get insightsPeriodNext => 'Période suivante';

  @override
  String get insightsPeriodPrevious => 'Période précédente';

  @override
  String get insightsPeriodQuarter => 'Trimestre';

  @override
  String get insightsPeriodToDateSuffix => 'jusqu\'ici';

  @override
  String get insightsPeriodWeek => 'Semaine';

  @override
  String get insightsPeriodYear => 'Année';

  @override
  String get insightsRangeMonthToDate => 'Ce mois-ci jusqu\'ici';

  @override
  String get insightsRangeMtd => 'Ce mois-ci';

  @override
  String get insightsRangeYearToDate => 'Cette année jusqu\'ici';

  @override
  String get insightsRangeYtd => 'Cette année';

  @override
  String get insightsRefreshError =>
      'Échec de l\'actualisation — affichage des dernières données chargées';

  @override
  String get insightsTableAvgPerDay => 'MOY./JOUR';

  @override
  String get insightsTableCategory => 'CATÉGORIE';

  @override
  String get insightsTableCompareNote =>
      'Évolution par rapport à la période précédente';

  @override
  String get insightsTableCurrent => 'ACTUEL';

  @override
  String get insightsTableDelta => 'Évolution';

  @override
  String get insightsTablePrevious => 'PRÉCÉDENT';

  @override
  String get insightsTableShare => 'PART';

  @override
  String get insightsTableTotal => 'TOTAL';

  @override
  String get insightsTimeAnalysisTitle => 'Analyse du temps';

  @override
  String get insightsUncategorized => 'Sans catégorie';

  @override
  String get journalCopyImageLabel => 'Copier l\'image';

  @override
  String get journalDateFromLabel => 'Date de début :';

  @override
  String get journalDateInvalid => 'Plage de dates invalide';

  @override
  String get journalDateLabel => 'Date';

  @override
  String get journalDateNowButton => 'maintenant';

  @override
  String get journalDateSaveButton => 'ENREGISTRER';

  @override
  String get journalDateTimeRangeTitle => 'Date et heure';

  @override
  String get journalDateToLabel => 'Date de fin :';

  @override
  String get journalDeleteConfirm => 'OUI, SUPPRIMER CETTE ENTRÉE';

  @override
  String get journalDeleteHint => 'Supprimer l\'entrée';

  @override
  String get journalDeleteQuestion =>
      'Veux-tu vraiment supprimer cette entrée ?';

  @override
  String get journalDurationLabel => 'Durée';

  @override
  String get journalEndDateLabel => 'Date de fin';

  @override
  String get journalEndsAnotherDayHint => 'Choisis une date de fin distincte';

  @override
  String get journalEndsAnotherDayLabel => 'Se termine un autre jour';

  @override
  String get journalEndTimeLabel => 'Heure de fin';

  @override
  String get journalFavoriteTooltip => 'Préféré';

  @override
  String get journalFilterEntryTypesTitle => 'Types d\'entrée';

  @override
  String get journalFilterFlagged => 'Suivis';

  @override
  String get journalFilterPrivate => 'Privés';

  @override
  String get journalFilterShowTitle => 'Afficher';

  @override
  String get journalFilterStarred => 'Favoris';

  @override
  String get journalFlaggedTooltip => 'Suivi';

  @override
  String get journalHideLinkHint => 'Masquer le lien';

  @override
  String get journalHideMapHint => 'Masquer la carte';

  @override
  String get journalLinkedEntriesActivityFilterAudio => 'Audio';

  @override
  String get journalLinkedEntriesActivityFilterCode => 'Code';

  @override
  String get journalLinkedEntriesActivityFilterImages => 'Images';

  @override
  String get journalLinkedEntriesActivityFilterTimer => 'Minuteur';

  @override
  String get journalLinkedEntriesFilterModalTitle => 'Filtrer et trier';

  @override
  String get journalLinkedEntriesShowFlaggedOnly =>
      'Afficher uniquement les entrées suivies';

  @override
  String get journalLinkedEntriesShowHidden => 'Afficher les entrées masquées';

  @override
  String get journalLinkedEntriesSortLabel => 'Trier par';

  @override
  String get journalLinkedEntriesSortNewestFirst => 'Plus récent d\'abord';

  @override
  String get journalLinkedEntriesSortOldestFirst => 'Plus ancien d\'abord';

  @override
  String get journalLinkedFromLabel => 'Lié depuis :';

  @override
  String get journalLinkFromHint => 'Lié depuis';

  @override
  String get journalLinkToHint => 'Lié à';

  @override
  String journalOvernightNextDay(String date) {
    return 'Fin $date (jour suivant)';
  }

  @override
  String get journalPrivateTooltip => 'Privé';

  @override
  String get journalSearchHint => 'Rechercher journal...';

  @override
  String get journalShareHint => 'Partager';

  @override
  String get journalShowLinkHint => 'Afficher le lien';

  @override
  String get journalShowMapHint => 'Afficher la carte';

  @override
  String get journalStartDateLabel => 'Date de début';

  @override
  String get journalStartTimeLabel => 'Heure de début';

  @override
  String get journalTodayButton => 'Aujourd\'hui';

  @override
  String get journalToggleFlaggedTitle => 'Signalé';

  @override
  String get journalTogglePrivateTitle => 'Privé';

  @override
  String get journalToggleStarredTitle => 'Favori';

  @override
  String get journalUnlinkConfirm => 'OUI, DISSOCIER L\'ENTRÉE';

  @override
  String get journalUnlinkHint => 'Dissocier';

  @override
  String get journalUnlinkQuestion =>
      'Es-tu sûr de vouloir dissocier cette entrée ?';

  @override
  String get knowledgeGraphEmpty => 'Aucun lien à explorer pour le moment';

  @override
  String get knowledgeGraphError =>
      'Impossible de charger le graphe de connaissances';

  @override
  String get knowledgeGraphTitle => 'Graphe de connaissances';

  @override
  String get knowledgeGraphTooltip => 'Explorer les liens';

  @override
  String get linkedFromCaption => 'depuis';

  @override
  String get linkedTaskImageBadge => 'De la tâche liée';

  @override
  String get linkedTasksMenuTooltip => 'Options des tâches liées';

  @override
  String get linkedTasksTitle => 'Tâches liées';

  @override
  String get linkedToCaption => 'vers';

  @override
  String get linkExistingTask => 'Lier une tâche existante...';

  @override
  String get loggingDomainAgentRuntime => 'Exécution des agents';

  @override
  String get loggingDomainAgentWorkflow => 'Flux des agents';

  @override
  String get loggingDomainAi => 'IA';

  @override
  String get loggingDomainCalendar => 'Calendrier et temps';

  @override
  String get loggingDomainChat => 'Chat';

  @override
  String get loggingDomainDailyOs => 'Daily OS';

  @override
  String get loggingDomainDatabase => 'Base de données';

  @override
  String get loggingDomainGeneral => 'Général';

  @override
  String get loggingDomainHabits => 'Habitudes';

  @override
  String get loggingDomainHealth => 'Santé';

  @override
  String get loggingDomainLabels => 'Étiquettes';

  @override
  String get loggingDomainLocation => 'Localisation';

  @override
  String get loggingDomainNavigation => 'Navigation';

  @override
  String get loggingDomainNotifications => 'Notifications';

  @override
  String get loggingDomainPersistence => 'Persistance';

  @override
  String get loggingDomainRatings => 'Évaluations';

  @override
  String get loggingDomainScreenshots => 'Captures d\'écran';

  @override
  String get loggingDomainSettings => 'Paramètres';

  @override
  String get loggingDomainSpeech => 'Voix et audio';

  @override
  String get loggingDomainSync => 'Synchronisation';

  @override
  String get loggingDomainTasks => 'Tâches et listes';

  @override
  String get loggingDomainTheming => 'Thèmes';

  @override
  String get loggingDomainWhatsNew => 'Nouveautés';

  @override
  String get maintenanceDeleteAgentDb =>
      'Supprimer la base de données des agents';

  @override
  String get maintenanceDeleteAgentDbDescription =>
      'Supprimer la base de données des agents et redémarrer l\'app';

  @override
  String get maintenanceDeleteDatabaseConfirm =>
      'OUI, SUPPRIMER LA BASE DE DONNÉES';

  @override
  String maintenanceDeleteDatabaseQuestion(String databaseName) {
    return 'Es-tu sûr de vouloir supprimer la base de données $databaseName ?';
  }

  @override
  String get maintenanceDeleteEditorDb =>
      'Supprimer la base de données des brouillons';

  @override
  String get maintenanceDeleteEditorDbDescription =>
      'Supprimer la base de données des brouillons de l\'éditeur';

  @override
  String get maintenanceDeleteSyncDb =>
      'Supprimer la base de données de synchronisation';

  @override
  String get maintenanceDeleteSyncDbDescription =>
      'Supprimer la base de données de synchronisation';

  @override
  String get maintenanceGenerateEmbeddings => 'Générer les embeddings';

  @override
  String get maintenanceGenerateEmbeddingsConfirm => 'OUI, GÉNÉRER';

  @override
  String get maintenanceGenerateEmbeddingsDescription =>
      'Générer les embeddings pour les entrées des catégories sélectionnées';

  @override
  String get maintenanceGenerateEmbeddingsMessage =>
      'Sélectionne les catégories pour générer les embeddings.';

  @override
  String maintenanceGenerateEmbeddingsProgress(
    int processed,
    int total,
    int embedded,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      embedded,
      locale: localeName,
      other: '$embedded embeddings générés',
      one: '1 embedding généré',
    );
    String _temp1 = intl.Intl.pluralLogic(
      embedded,
      locale: localeName,
      other: '$embedded embeddings générés',
      one: '1 embedding généré',
    );
    String _temp2 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$processed / $total entrées ($_temp0)',
      one: '$processed / $total entrée ($_temp1)',
    );
    return '$_temp2';
  }

  @override
  String get maintenancePopulatePhaseAgentEntities =>
      'Traitement des entités d\'agents...';

  @override
  String get maintenancePopulatePhaseAgentLinks =>
      'Traitement des liens d\'agents...';

  @override
  String get maintenancePopulatePhaseJournal =>
      'Traitement des entrées du journal...';

  @override
  String get maintenancePopulatePhaseLinks =>
      'Traitement des liens d\'entrées...';

  @override
  String get maintenancePopulateSequenceLog =>
      'Remplir le journal de séquence de synchronisation';

  @override
  String maintenancePopulateSequenceLogComplete(int count) {
    return '$count entrées indexées';
  }

  @override
  String get maintenancePopulateSequenceLogConfirm => 'OUI, REMPLIR';

  @override
  String get maintenancePopulateSequenceLogDescription =>
      'Indexer les entrées existantes pour le support de rattrapage';

  @override
  String get maintenancePopulateSequenceLogMessage =>
      'Cela analysera toutes les entrées du journal et les ajoutera au journal de séquence de synchronisation. Cela permet les réponses de rattrapage pour les entrées créées avant l\'ajout de cette fonctionnalité.';

  @override
  String get maintenancePurgeDeleted => 'Purger les éléments supprimés';

  @override
  String get maintenancePurgeDeletedConfirm => 'Purger';

  @override
  String get maintenancePurgeDeletedDescription =>
      'Purger définitivement tous les éléments supprimés';

  @override
  String get maintenancePurgeDeletedMessage =>
      'Es-tu sûr de vouloir purger tous les éléments supprimés ? Cette action est irréversible.';

  @override
  String get maintenancePurgeSentOutbox =>
      'Purger les anciens éléments envoyés de l\'outbox';

  @override
  String get maintenancePurgeSentOutboxConfirm => 'OUI, PURGER';

  @override
  String get maintenancePurgeSentOutboxDescription =>
      'Supprimer les lignes de l\'outbox envoyées il y a plus de 7 jours et récupérer l\'espace disque';

  @override
  String get maintenancePurgeSentOutboxQuestion =>
      'Purger les éléments de l\'outbox envoyés il y a plus de 7 jours ? Cela supprime les lignes déjà envoyées par lots et exécute VACUUM pour récupérer l\'espace disque. Les éléments en attente et en erreur sont conservés.';

  @override
  String get maintenanceRecreateFts5 => 'Recréer l\'index de texte intégral';

  @override
  String get maintenanceRecreateFts5Confirm => 'OUI, RECRÉER L\'INDEX';

  @override
  String get maintenanceRecreateFts5Description =>
      'Recréer l\'index de recherche en texte intégral';

  @override
  String get maintenanceRecreateFts5Message =>
      'Es-tu sûr de vouloir recréer l\'index de recherche en texte intégral ? Cela peut prendre un certain temps.';

  @override
  String get maintenanceReSync => 'Resynchroniser les messages';

  @override
  String get maintenanceReSyncAgentEntities => 'Entités d\'agent';

  @override
  String get maintenanceReSyncDescription =>
      'Resynchroniser les messages depuis le serveur';

  @override
  String get maintenanceReSyncEntityTypes => 'Types d\'entités';

  @override
  String get maintenanceReSyncJournalEntities => 'Entrées du journal';

  @override
  String get maintenanceReSyncSelectAtLeastOne =>
      'Sélectionne au moins un type d\'entité';

  @override
  String get maintenanceReSyncStart => 'Démarrer';

  @override
  String get maintenanceSyncDefinitions =>
      'Synchroniser les mesurables, tableaux de bord, habitudes, catégories, paramètres AI';

  @override
  String get maintenanceSyncDefinitionsDescription =>
      'Synchroniser les mesurables, tableaux de bord, habitudes, catégories et paramètres AI';

  @override
  String get manageLinks => 'Gérer les liens...';

  @override
  String get measurableDeleteConfirm => 'OUI, SUPPRIMER CET ÉLÉMENT MESURABLE';

  @override
  String get measurableDeleteQuestion =>
      'Veux-tu supprimer ce type de données mesurables ?';

  @override
  String get measurableNotFound => 'Élément mesurable introuvable';

  @override
  String get measurementCommentHint => 'Ajoute une note (facultatif)';

  @override
  String get measurementQuickAddLabel => 'Ajout rapide';

  @override
  String get mediaShowInFileExplorerAction =>
      'Afficher dans l\'Explorateur de fichiers';

  @override
  String get mediaShowInFilesAction => 'Afficher dans Fichiers';

  @override
  String get mediaShowInFinderAction => 'Afficher dans le Finder';

  @override
  String get modalityAudioDescription => 'Capacités de traitement audio';

  @override
  String get modalityAudioName => 'Audio';

  @override
  String get modalityImageDescription => 'Capacités de traitement d\'image';

  @override
  String get modalityImageName => 'Image';

  @override
  String get modalityTextDescription =>
      'Contenu et traitement basés sur le texte';

  @override
  String get modalityTextName => 'Texte';

  @override
  String get modelAddPageTitle => 'Ajouter un modèle';

  @override
  String get modelEditBackTooltip => 'Retour';

  @override
  String get modelEditDescriptionHint => 'Décris ce modèle';

  @override
  String get modelEditDescriptionLabel => 'Description';

  @override
  String get modelEditDisplayNameHint => 'Un nom familier pour ce modèle';

  @override
  String get modelEditDisplayNameLabel => 'Nom d\'affichage';

  @override
  String get modelEditFunctionCallingDescription =>
      'Ce modèle prend en charge l\'appel de fonctions et d\'outils.';

  @override
  String get modelEditFunctionCallingLabel => 'Appel de fonctions';

  @override
  String get modelEditGeminiThinkingModeLabel => 'Mode de réflexion Gemini';

  @override
  String get modelEditInputModalitiesHint => 'Sélectionner les types d\'entrée';

  @override
  String get modelEditInputModalitiesLabel => 'Modalités d\'entrée';

  @override
  String get modelEditLoadError =>
      'Échec du chargement de la configuration du modèle';

  @override
  String get modelEditMaxTokensHint => 'Optionnel — laisser vide pour illimité';

  @override
  String get modelEditMaxTokensLabel => 'Tokens de complétion max';

  @override
  String get modelEditModalityNoneSelected => 'Aucun sélectionné';

  @override
  String get modelEditOutputModalitiesHint =>
      'Sélectionner les types de sortie';

  @override
  String get modelEditOutputModalitiesLabel => 'Modalités de sortie';

  @override
  String get modelEditPageTitle => 'Modifier le modèle';

  @override
  String get modelEditProviderHint => 'Sélectionner un fournisseur';

  @override
  String get modelEditProviderLabel => 'Fournisseur';

  @override
  String get modelEditProviderModelIdHint => 'ex. gpt-4-turbo';

  @override
  String get modelEditProviderModelIdLabel => 'ID modèle du fournisseur';

  @override
  String get modelEditReasoningDescription =>
      'Ce modèle utilise une réflexion étendue / chaîne de pensée.';

  @override
  String get modelEditReasoningLabel => 'Modèle de raisonnement';

  @override
  String get modelEditSaveButton => 'Enregistrer';

  @override
  String get modelEditSectionCapabilities => 'Capacités';

  @override
  String get modelEditSectionIdentity => 'Identité';

  @override
  String modelManagementSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count modèle$_temp0 sélectionné$_temp1';
  }

  @override
  String get multiSelectAddButton => 'Ajouter';

  @override
  String multiSelectAddButtonWithCount(int count) {
    return 'Ajouter ($count)';
  }

  @override
  String get multiSelectNoItemsFound => 'Aucun élément trouvé';

  @override
  String navTabMoreSemanticsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Plus, $count sections supplémentaires',
      one: 'Plus, 1 section supplémentaire',
    );
    return '$_temp0';
  }

  @override
  String get navTabTitleCalendar => 'DailyOS';

  @override
  String get navTabTitleHabits => 'Habitudes';

  @override
  String get navTabTitleInsights => 'Tableaux de bord';

  @override
  String get navTabTitleJournal => 'Journal';

  @override
  String get navTabTitleMore => 'Plus';

  @override
  String get navTabTitleProjects => 'Projets';

  @override
  String get navTabTitleSettings => 'Paramètres';

  @override
  String get navTabTitleTasks => 'Tâches';

  @override
  String nestedAiResponsesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count réponse$_temp0 AI';
  }

  @override
  String get noDefaultLanguage => 'Aucune langue par défaut';

  @override
  String get noTasksFound => 'Aucune tâche trouvée';

  @override
  String get noTasksToLink => 'Aucune tâche disponible à lier';

  @override
  String get notificationBellEmptySemantics =>
      'Notifications, aucune alerte non lue';

  @override
  String get notificationBellTooltip => 'Notifications';

  @override
  String notificationBellUnseenSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'alertes non lues',
      one: 'alerte non lue',
    );
    return 'Notifications, $count $_temp0';
  }

  @override
  String get notificationInboxDismiss => 'Ignorer la notification';

  @override
  String get notificationInboxEmpty => 'Tu es à jour.';

  @override
  String get notificationInboxError =>
      'Impossible de charger les notifications.';

  @override
  String get notificationInboxTitle => 'Notifications';

  @override
  String get notificationSuggestionAttentionBodyFallback =>
      'Ouvre la tâche pour la passer en revue.';

  @override
  String notificationSuggestionAttentionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count suggestions ont besoin de ton attention',
      one: '1 suggestion a besoin de ton attention',
    );
    return '$_temp0';
  }

  @override
  String get optionalCategoryLabel => 'Catégorie (facultatif)';

  @override
  String get outboxActionRemove => 'Retirer';

  @override
  String get outboxActionRetry => 'Réessayer';

  @override
  String get outboxFailedReassurance =>
      'Toujours enregistré sur cet appareil — la synchro reprendra une fois le problème résolu.';

  @override
  String get outboxFilterFailed => 'Échec';

  @override
  String get outboxFilterWaiting => 'En attente';

  @override
  String get outboxMonitorAttachmentLabel => 'Pièce jointe';

  @override
  String get outboxMonitorDelete => 'supprimer';

  @override
  String get outboxMonitorDeleteConfirmLabel => 'Supprimer';

  @override
  String get outboxMonitorDeleteConfirmMessage =>
      'Es-tu sûr de vouloir supprimer cet élément de synchronisation ? Cette action est irréversible.';

  @override
  String get outboxMonitorDeleteFailed =>
      'Échec de la suppression. Réessaie s\'il te plaît.';

  @override
  String get outboxMonitorDeleteSuccess => 'Élément supprimé';

  @override
  String get outboxMonitorEmptyDescription =>
      'Il n\'y a aucun élément de synchronisation dans cette vue.';

  @override
  String get outboxMonitorEmptyTitle => 'La boîte d\'envoi est vide';

  @override
  String get outboxMonitorFetchFailed =>
      'Impossible de charger la boîte d\'envoi. Tire vers le bas pour actualiser et réessaie.';

  @override
  String get outboxMonitorLabelError => 'erreur';

  @override
  String get outboxMonitorLabelPending => 'en attente';

  @override
  String get outboxMonitorLabelSent => 'envoyé';

  @override
  String get outboxMonitorLabelSuccess => 'succès';

  @override
  String get outboxMonitorNoAttachment => 'pas de pièce jointe';

  @override
  String get outboxMonitorPayloadSizeLabel => 'Taille';

  @override
  String get outboxMonitorRetries => 'retries';

  @override
  String get outboxMonitorRetriesLabel => 'Tentatives';

  @override
  String get outboxMonitorRetry => 'réessayer';

  @override
  String get outboxMonitorRetryConfirmLabel => 'Réessayer maintenant';

  @override
  String get outboxMonitorRetryConfirmMessage =>
      'Réessayer cet élément de synchronisation maintenant ?';

  @override
  String get outboxMonitorRetryFailed =>
      'Échec de la nouvelle tentative. Réessaie s\'il te plaît.';

  @override
  String get outboxMonitorRetryQueued => 'Nouvelle tentative programmée';

  @override
  String get outboxMonitorSubjectLabel => 'Sujet';

  @override
  String get outboxMonitorVolumeChartTitle =>
      'Volume de synchronisation quotidien';

  @override
  String get outboxRemoveConfirmMessage =>
      'Cette modification n\'est pas encore synchronisée. La retirer ici l\'empêchera d\'atteindre tes autres appareils. Elle reste sur cet appareil.';

  @override
  String get outboxRemoveConfirmTitle => 'Retirer de la file ?';

  @override
  String get outboxRetryAll => 'Tout réessayer';

  @override
  String get outboxShowDetails => 'Afficher les détails techniques';

  @override
  String get outboxStatusFailed => 'Échec de l\'envoi';

  @override
  String get outboxStatusSending => 'Envoi en cours';

  @override
  String get outboxStatusSent => 'Envoyé';

  @override
  String get outboxStatusWaiting => 'En attente d\'envoi';

  @override
  String outboxSummaryFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments n\'ont pas pu être envoyés',
      one: '1 élément n\'a pas pu être envoyé',
    );
    return '$_temp0';
  }

  @override
  String outboxSummaryOffline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments seront envoyés une fois reconnecté',
      one: '1 élément sera envoyé une fois reconnecté',
    );
    return '$_temp0';
  }

  @override
  String outboxSummarySending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Envoi de $count éléments…',
      one: 'Envoi d\'1 élément…',
    );
    return '$_temp0';
  }

  @override
  String get outboxSummarySynced => 'Tout est synchronisé';

  @override
  String outboxSummaryWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments en attente d\'envoi',
      one: '1 élément en attente d\'envoi',
    );
    return '$_temp0';
  }

  @override
  String outboxTriedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Essayé $count fois',
      one: 'Essayé une fois',
    );
    return '$_temp0';
  }

  @override
  String get privateLabel => 'Privé';

  @override
  String get privateSwitchDescription =>
      'Visible uniquement lorsque les entrées privées sont affichées';

  @override
  String get projectAgentNotProvisioned =>
      'Aucun agent de projet n\'a encore été configuré pour ce projet.';

  @override
  String get projectAgentSectionTitle => 'Agent';

  @override
  String projectCountSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count projets',
      one: '$count projet',
    );
    return '$_temp0';
  }

  @override
  String get projectCreateButton => 'Créer un projet';

  @override
  String get projectCreateTitle => 'Créer un projet';

  @override
  String get projectDetailTitle => 'Détails du projet';

  @override
  String get projectErrorCreateFailed =>
      'Erreur lors de la création du projet.';

  @override
  String get projectErrorLoadFailed =>
      'Impossible de charger les données du projet.';

  @override
  String get projectErrorLoadProjects =>
      'Erreur lors du chargement des projets';

  @override
  String get projectErrorUpdateFailed =>
      'Impossible de mettre à jour le projet. Réessaie.';

  @override
  String get projectFilterLabel => 'Projet';

  @override
  String get projectHealthBandAtRisk => 'À risque';

  @override
  String get projectHealthBandBlocked => 'Bloqué';

  @override
  String get projectHealthBandOnTrack => 'Sur la bonne voie';

  @override
  String get projectHealthBandSurviving => 'Ça tient';

  @override
  String get projectHealthBandWatch => 'À surveiller';

  @override
  String get projectHealthSectionTitle => 'Santé du projet';

  @override
  String projectHealthSummary(int projectCount, int taskCount) {
    String _temp0 = intl.Intl.pluralLogic(
      projectCount,
      locale: localeName,
      other: '$projectCount projets',
      one: '$projectCount projet',
    );
    String _temp1 = intl.Intl.pluralLogic(
      taskCount,
      locale: localeName,
      other: '$taskCount tâches',
      one: '$taskCount tâche',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get projectHealthTitle => 'Projets';

  @override
  String projectLinkedTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tâches liées',
      one: '$count tâche liée',
    );
    return '$_temp0';
  }

  @override
  String get projectLinkedTasks => 'Tâches liées';

  @override
  String get projectManageTooltip => 'Gérer les projets';

  @override
  String get projectNoLinkedTasks => 'Aucune tâche liée pour le moment';

  @override
  String get projectNoProjects => 'Pas encore de projets';

  @override
  String get projectNotFound => 'Projet introuvable';

  @override
  String get projectPickerLabel => 'Projet';

  @override
  String get projectPickerUnassigned => 'Aucun projet';

  @override
  String get projectRecommendationDismissTooltip => 'Ignorer';

  @override
  String get projectRecommendationResolveTooltip => 'Marquer comme résolue';

  @override
  String get projectRecommendationsTitle => 'Prochaines étapes recommandées';

  @override
  String get projectRecommendationUpdateError =>
      'Impossible de mettre à jour la recommandation. Réessaie.';

  @override
  String get projectsFilterStatusLabel => 'Statut :';

  @override
  String get projectsFilterTooltip => 'Filtrer les projets';

  @override
  String get projectShowcaseAiReportTitle => 'Rapport IA';

  @override
  String projectShowcaseBlockedLegend(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bloquées',
      one: '$count bloquée',
    );
    return '$_temp0';
  }

  @override
  String projectShowcaseBlockedTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tâches bloquées',
      one: '$count tâche bloquée',
    );
    return '$_temp0';
  }

  @override
  String projectShowcaseCompletedLegend(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count terminées',
      one: '$count terminée',
    );
    return '$_temp0';
  }

  @override
  String get projectShowcaseDescriptionTitle => 'Description';

  @override
  String projectShowcaseDueDate(String date) {
    return 'Échéance $date';
  }

  @override
  String get projectShowcaseHealthScoreDescription =>
      'Ce score se base sur le rythme des tâches, les blocages et le temps restant avant l\'échéance.';

  @override
  String get projectShowcaseHealthScoreTitle => 'Score de santé';

  @override
  String get projectShowcaseNoResults =>
      'Aucun projet ne correspond à ta recherche.';

  @override
  String get projectShowcaseOneOnOneReviewsTab => 'Revues 1:1';

  @override
  String get projectShowcaseOngoing => 'En cours';

  @override
  String get projectShowcaseProjectTasksTab => 'Tâches du projet';

  @override
  String get projectShowcaseSearchHint => 'Rechercher des projets';

  @override
  String projectShowcaseSessionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '$count session',
    );
    return '$_temp0';
  }

  @override
  String projectShowcaseTasksCompleted(int completed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$completed/$total tâches terminées',
      one: '$completed/$total tâche terminée',
    );
    return '$_temp0';
  }

  @override
  String projectShowcaseUpdatedHoursAgo(int hours) {
    return 'Mis à jour il y a $hours h ↻';
  }

  @override
  String projectShowcaseUpdatedMinutesAgo(int minutes) {
    return 'Mis à jour il y a $minutes min ↻';
  }

  @override
  String get projectShowcaseUsefulness => 'Utilité';

  @override
  String get projectShowcaseViewBlocker => 'Voir le blocage';

  @override
  String get projectStatusActive => 'Actif';

  @override
  String get projectStatusArchived => 'Archivé';

  @override
  String get projectStatusChangeTitle => 'Changer le statut';

  @override
  String get projectStatusCompleted => 'Terminé';

  @override
  String get projectStatusMonitoring => 'Surveillance';

  @override
  String get projectStatusOnHold => 'En pause';

  @override
  String get projectStatusOpen => 'Ouvert';

  @override
  String get projectSummaryOutdated => 'Le résumé est obsolète.';

  @override
  String projectSummaryOutdatedScheduled(String date, String time) {
    return 'Le résumé est obsolète. Prochaine mise à jour le $date à $time.';
  }

  @override
  String get projectTargetDateLabel => 'Date cible';

  @override
  String get projectTitleLabel => 'Titre du projet';

  @override
  String get projectTitleRequired => 'Le titre du projet ne peut pas être vide';

  @override
  String get promptDefaultModelBadge => 'Par défaut';

  @override
  String get promptGenerationCardTitle => 'Prompt de codage AI';

  @override
  String get promptGenerationCopiedSnackbar =>
      'Prompt copié dans le presse-papiers';

  @override
  String get promptGenerationCopyButton => 'Copier le prompt';

  @override
  String get promptGenerationCopyTooltip =>
      'Copier le prompt dans le presse-papiers';

  @override
  String get promptGenerationExpandTooltip => 'Afficher le prompt complet';

  @override
  String get promptGenerationFullPromptLabel => 'Prompt complet :';

  @override
  String get promptSelectionModalTitle => 'Sélectionner un prompt préconfiguré';

  @override
  String get provisionedSyncBundleImported => 'Code de provisionnement importé';

  @override
  String get provisionedSyncConfigureButton => 'Configurer';

  @override
  String get provisionedSyncCopiedToClipboard => 'Copié dans le presse-papiers';

  @override
  String get provisionedSyncDisconnect => 'Déconnecter';

  @override
  String get provisionedSyncDone => 'Synchronisation configurée avec succès';

  @override
  String get provisionedSyncError => 'Échec de la configuration';

  @override
  String get provisionedSyncErrorConfigurationFailed =>
      'Une erreur est survenue lors de la configuration. Réessaie.';

  @override
  String get provisionedSyncErrorLoginFailed =>
      'Échec de la connexion. Vérifie tes identifiants et réessaie.';

  @override
  String get provisionedSyncImportButton => 'Importer';

  @override
  String get provisionedSyncImportHint =>
      'Colle le code de provisionnement ici';

  @override
  String get provisionedSyncImportTitle => 'Configurer la synchronisation';

  @override
  String get provisionedSyncInvalidBundle => 'Code de provisionnement invalide';

  @override
  String get provisionedSyncJoiningRoom =>
      'Rejoindre la salle de synchronisation...';

  @override
  String get provisionedSyncLoggingIn => 'Connexion en cours...';

  @override
  String get provisionedSyncPasteClipboard => 'Coller depuis le presse-papiers';

  @override
  String get provisionedSyncReady =>
      'Scanne ce code QR sur ton appareil mobile';

  @override
  String get provisionedSyncRetry => 'Réessayer';

  @override
  String get provisionedSyncRotatingPassword => 'Sécurisation du compte...';

  @override
  String get provisionedSyncScanButton => 'Scanner le code QR';

  @override
  String get provisionedSyncShowQr => 'Afficher le QR de provisionnement';

  @override
  String get provisionedSyncSubtitle =>
      'Configurer la synchronisation à partir d\'un paquet de provisionnement';

  @override
  String get provisionedSyncSummaryHomeserver => 'Serveur';

  @override
  String get provisionedSyncSummaryRoom => 'Salle';

  @override
  String get provisionedSyncSummaryUser => 'Utilisateur';

  @override
  String get provisionedSyncTitle => 'Synchronisation provisionnée';

  @override
  String get provisionedSyncVerifyDevicesTitle => 'Vérification des appareils';

  @override
  String get queueCatchUpNowButton => 'Rattraper maintenant';

  @override
  String get queueCatchUpNowDone => 'Rattrapage lancé — la file se vide.';

  @override
  String queueCatchUpNowError(String reason) {
    return 'Rattrapage échoué : $reason';
  }

  @override
  String get queueDepthCardEmpty => 'File vide — le worker est à jour.';

  @override
  String get queueDepthCardLoading => 'Lecture de la profondeur de la file…';

  @override
  String get queueDepthCardTitle => 'File d\'entrée';

  @override
  String get queueFetchAllHistoryCancel => 'Annuler';

  @override
  String queueFetchAllHistoryCancelled(int events) {
    String _temp0 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: '$events événements',
      one: '1 événement',
      zero: 'aucun événement',
    );
    return 'Annulé — $_temp0 récupéré(s) jusqu\'ici.';
  }

  @override
  String get queueFetchAllHistoryClose => 'Fermer';

  @override
  String get queueFetchAllHistoryDescription =>
      'Parcourt tout l\'historique visible de la salle dans la file. Tu peux annuler à tout moment ; une nouvelle exécution reprend là où la pagination s\'est arrêtée.';

  @override
  String queueFetchAllHistoryDone(int events, int pages) {
    String _temp0 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages pages',
      one: '1 page',
    );
    String _temp1 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages pages',
      one: '1 page',
    );
    String _temp2 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: '$events événements récupérés sur $_temp0.',
      one: '1 événement récupéré sur $_temp1.',
      zero: 'Aucun événement récupéré.',
    );
    return '$_temp2';
  }

  @override
  String queueFetchAllHistoryError(String reason) {
    return 'Récupération arrêtée : $reason';
  }

  @override
  String get queueFetchAllHistoryErrorUnknown =>
      'Récupération arrêtée de manière inattendue.';

  @override
  String queueFetchAllHistoryProgress(int events, int pages) {
    String _temp0 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: 'Page $pages  ·  $events événements récupérés',
      one: 'Page $pages  ·  1 événement récupéré',
    );
    return '$_temp0';
  }

  @override
  String get queueFetchAllHistoryTitle => 'Récupération de l\'historique';

  @override
  String queueSkippedBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ignorés',
      one: '1 ignoré',
    );
    return '$_temp0';
  }

  @override
  String queueSkippedCardBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count événements de synchronisation que la file a abandonnés. Appuie sur réessayer pour les retenter.',
      one:
          '1 événement de synchronisation que la file a abandonné. Appuie sur réessayer pour le retenter.',
    );
    return '$_temp0';
  }

  @override
  String get queueSkippedCardTitle => 'Événements ignorés';

  @override
  String get queueSkippedRetryAll => 'Réessayer les événements ignorés';

  @override
  String queueSkippedRetryAllDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count événements remis en file pour réessai.',
      one: '1 événement remis en file pour réessai.',
      zero: 'Aucun événement ignoré.',
    );
    return '$_temp0';
  }

  @override
  String queueSkippedRetryAllError(String reason) {
    return 'Réessai échoué : $reason';
  }

  @override
  String get referenceImageContinue => 'Continuer';

  @override
  String referenceImageContinueWithCount(int count) {
    return 'Continuer ($count)';
  }

  @override
  String get referenceImageLoadError =>
      'Échec du chargement des images. Réessaie s\'il te plaît.';

  @override
  String get referenceImageSelectionSubtitle =>
      'Choisis jusqu\'à 5 images pour guider le style visuel de l\'IA';

  @override
  String get referenceImageSelectionTitle =>
      'Sélectionner des images de référence';

  @override
  String get referenceImageSkip => 'Passer';

  @override
  String get saveButton => 'Enregistrer';

  @override
  String get saveButtonLabel => 'Enregistrer';

  @override
  String get saveLabel => 'Enregistrer';

  @override
  String get saveShortcutTooltip => 'Enregistrer — Ctrl+S (⌘S sur Mac)';

  @override
  String get saveSuccessful => 'Enregistré avec succès';

  @override
  String get searchHint => 'Rechercher...';

  @override
  String get searchModeFullText => 'Texte intégral';

  @override
  String get searchModeVector => 'Vecteur';

  @override
  String get searchTasksHint => 'Rechercher des tâches...';

  @override
  String get selectButton => 'Sélectionner';

  @override
  String get selectColor => 'Choisir une couleur';

  @override
  String get selectLanguage => 'Sélectionner une langue';

  @override
  String get sessionRatingCardLabel => 'Évaluation de session';

  @override
  String get sessionRatingChallengeJustRight => 'Juste bien';

  @override
  String get sessionRatingChallengeTooEasy => 'Trop facile';

  @override
  String get sessionRatingChallengeTooHard => 'Trop difficile';

  @override
  String get sessionRatingDifficultyLabel => 'Ce travail semblait...';

  @override
  String get sessionRatingEditButton => 'Modifier l\'évaluation';

  @override
  String get sessionRatingEnergyQuestion =>
      'Quel était ton niveau d\'énergie ?';

  @override
  String get sessionRatingFocusQuestion =>
      'Quel était ton niveau de concentration ?';

  @override
  String get sessionRatingNoteHint => 'Note rapide (optionnelle)';

  @override
  String get sessionRatingProductivityQuestion =>
      'Quelle a été la productivité de cette session ?';

  @override
  String get sessionRatingRateAction => 'Évaluer la session';

  @override
  String get sessionRatingSaveButton => 'Enregistrer';

  @override
  String get sessionRatingSaveError =>
      'Impossible d\'enregistrer l\'évaluation. Réessaie s\'il te plaît.';

  @override
  String get sessionRatingSkipButton => 'Passer';

  @override
  String get sessionRatingTitle => 'Évaluer cette session';

  @override
  String get sessionRatingViewAction => 'Voir l\'évaluation';

  @override
  String get settingsAboutAppInformation => 'Informations sur l\'application';

  @override
  String get settingsAboutAppTagline => 'Ton journal personnel';

  @override
  String get settingsAboutBuildType => 'Type de build';

  @override
  String get settingsAboutDailyOsPersonalizationTitle =>
      'Personnalisation Daily OS';

  @override
  String get settingsAboutDailyOsUserNameHelper =>
      'Utilisé seulement pour la salutation Daily OS sur cet appareil.';

  @override
  String get settingsAboutDailyOsUserNameLabel => 'Ton nom';

  @override
  String get settingsAboutJournalEntries => 'Entrées de journal';

  @override
  String get settingsAboutPlatform => 'Plateforme';

  @override
  String get settingsAboutTitle => 'À propos de Lotti';

  @override
  String get settingsAboutVersion => 'Version';

  @override
  String get settingsAboutYourData => 'Tes données';

  @override
  String get settingsAdvancedAboutSubtitle =>
      'En savoir plus sur l\'application Lotti';

  @override
  String get settingsAdvancedHealthImportSubtitle =>
      'Importer des données liées à la santé depuis des sources externes';

  @override
  String get settingsAdvancedMaintenanceSubtitle =>
      'Effectuer des tâches de maintenance pour optimiser les performances de l\'application';

  @override
  String get settingsAdvancedOutboxSubtitle =>
      'Afficher et gérer les éléments en attente de synchronisation';

  @override
  String get settingsAdvancedSubtitle => 'Paramètres avancés et maintenance';

  @override
  String get settingsAdvancedTitle => 'Paramètres avancés';

  @override
  String get settingsAgentsInstancesSubtitle => 'Agents en cours d\'exécution';

  @override
  String get settingsAgentsPendingWakesSubtitle =>
      'Minuteries de réveil programmées';

  @override
  String get settingsAgentsSoulsSubtitle => 'Personnalités d\'agents durables';

  @override
  String get settingsAgentsStatsSubtitle =>
      'Utilisation des tokens et activité';

  @override
  String get settingsAgentsTemplatesSubtitle => 'Modèles d\'agents partagés';

  @override
  String get settingsAiModelsSubtitle => 'Modèles et capacités par fournisseur';

  @override
  String get settingsAiModelsTitle => 'Modèles';

  @override
  String get settingsAiProfilesSubtitle => 'Fournisseurs et modèles';

  @override
  String get settingsAiProfilesTitle => 'Profils d\'inférence';

  @override
  String get settingsAiProvidersSubtitle => 'Fournisseurs IA connectés et clés';

  @override
  String get settingsAiProvidersTitle => 'Fournisseurs';

  @override
  String get settingsAiSubtitle =>
      'Configurer les fournisseurs AI, modèles et prompts';

  @override
  String get settingsAiTitle => 'Paramètres AI';

  @override
  String get settingsBeamPageEditModelTitle => 'Modifier le modèle';

  @override
  String get settingsBeamPageEditProfileTitle => 'Modifier le profil';

  @override
  String get settingsCategoriesCreateTitle => 'Créer une catégorie';

  @override
  String get settingsCategoriesDetailsLabel => 'Modifier la catégorie';

  @override
  String get settingsCategoriesEmptyState => 'Aucune catégorie pour le moment';

  @override
  String get settingsCategoriesEmptyStateHint =>
      'Crée une catégorie pour organiser tes entrées';

  @override
  String get settingsCategoriesErrorLoading =>
      'Erreur lors du chargement des catégories';

  @override
  String get settingsCategoriesNameLabel => 'Nom de la catégorie';

  @override
  String settingsCategoriesNoMatchQuery(String query) {
    return 'Aucune catégorie ne correspond à \"$query\"';
  }

  @override
  String get settingsCategoriesSearchHint => 'Rechercher des catégories…';

  @override
  String get settingsCategoriesSubtitle => 'Catégories avec paramètres AI';

  @override
  String settingsCategoriesTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tâches',
      one: '$count tâche',
    );
    return '$_temp0';
  }

  @override
  String get settingsCategoriesTitle => 'Catégories';

  @override
  String get settingsCelebrationsChecklistDescription =>
      'Un pop et des étincelles quand tu coches un élément';

  @override
  String get settingsCelebrationsChecklistTitle => 'Éléments de liste';

  @override
  String get settingsCelebrationsHabitsDescription =>
      'Lueur et étincelles quand tu accomplis une habitude';

  @override
  String get settingsCelebrationsHabitsTitle => 'Habitudes';

  @override
  String get settingsCelebrationsSectionDescription =>
      'Une petite touche festive quand tu termines quelque chose. Si tu en désactives une, l\'achèvement et son retour haptique restent — seule l\'animation est ignorée.';

  @override
  String get settingsCelebrationsSectionTitle => 'Célébrations de fin';

  @override
  String get settingsCelebrationsSubtitle => 'Célébrations de fin';

  @override
  String get settingsCelebrationsTasksDescription =>
      'Lueur et étincelles quand tu passes une tâche à Terminé';

  @override
  String get settingsCelebrationsTasksTitle => 'Tâches';

  @override
  String get settingsCelebrationsTitle => 'Animations';

  @override
  String get settingsConflictsTitle => 'Conflits de synchronisation';

  @override
  String get settingsDashboardDetailsLabel => 'Modifier le tableau de bord';

  @override
  String get settingsDashboardSaveLabel => 'Enregistrer';

  @override
  String get settingsDashboardsCreateTitle => 'Créer un tableau de bord';

  @override
  String get settingsDashboardsEmptyState =>
      'Aucun tableau de bord pour le moment';

  @override
  String get settingsDashboardsEmptyStateHint =>
      'Appuie sur le bouton + pour créer ton premier tableau de bord.';

  @override
  String get settingsDashboardsErrorLoading =>
      'Erreur lors du chargement des tableaux de bord';

  @override
  String settingsDashboardsNoMatchQuery(String query) {
    return 'Aucun tableau de bord ne correspond à \"$query\"';
  }

  @override
  String get settingsDashboardsSearchHint => 'Rechercher des tableaux de bord…';

  @override
  String get settingsDashboardsSubtitle =>
      'Personnaliser tes vues de tableau de bord';

  @override
  String get settingsDashboardsTitle => 'Gestion du tableau de bord';

  @override
  String get settingsDefinitionsSubtitle =>
      'Habitudes, catégories, étiquettes, tableaux de bord et mesures';

  @override
  String get settingsDefinitionsTitle => 'Définitions';

  @override
  String get settingsFlagsEmptySearch =>
      'Aucun indicateur ne correspond à ta recherche';

  @override
  String get settingsFlagsSearchHint => 'Rechercher des indicateurs';

  @override
  String get settingsFlagsSubtitle => 'Configurer les indicateurs et options';

  @override
  String get settingsFlagsTitle => 'Flags';

  @override
  String get settingsHabitsCreateTitle => 'Créer une habitude';

  @override
  String get settingsHabitsDeleteTooltip => 'Supprimer l\'habitude';

  @override
  String get settingsHabitsDescriptionLabel => 'Description (facultatif)';

  @override
  String get settingsHabitsDetailsLabel => 'Modifier l\'habitude';

  @override
  String get settingsHabitsEmptyState => 'Aucune habitude pour le moment';

  @override
  String get settingsHabitsEmptyStateHint =>
      'Appuie sur le bouton + pour créer ta première habitude.';

  @override
  String get settingsHabitsErrorLoading =>
      'Erreur lors du chargement des habitudes';

  @override
  String get settingsHabitsNameLabel => 'Nom de l\'habitude';

  @override
  String settingsHabitsNoMatchQuery(String query) {
    return 'Aucune habitude ne correspond à \"$query\"';
  }

  @override
  String get settingsHabitsPrivateLabel => 'Privé : ';

  @override
  String get settingsHabitsSaveLabel => 'Enregistrer';

  @override
  String get settingsHabitsSearchHint => 'Rechercher des habitudes…';

  @override
  String get settingsHabitsSubtitle => 'Gérer tes habitudes et routines';

  @override
  String get settingsHabitsTitle => 'Habitudes';

  @override
  String get settingsHealthImportActivity => 'Importer les données d\'activité';

  @override
  String get settingsHealthImportBloodPressure =>
      'Importer les données de tension artérielle';

  @override
  String get settingsHealthImportBodyMeasurement => 'Importer les mensurations';

  @override
  String get settingsHealthImportFromDate => 'Début';

  @override
  String get settingsHealthImportHeartRate =>
      'Importer les données de fréquence cardiaque';

  @override
  String get settingsHealthImportSleep => 'Importer les données de sommeil';

  @override
  String get settingsHealthImportTitle => 'Health Import';

  @override
  String get settingsHealthImportToDate => 'Fin';

  @override
  String get settingsHealthImportWorkout =>
      'Importer les données d\'entraînement';

  @override
  String get settingsLabelsCategoriesAdd => 'Ajouter une catégorie';

  @override
  String get settingsLabelsCategoriesHeading => 'Catégories applicables';

  @override
  String get settingsLabelsCategoriesNone =>
      'S\'applique à toutes les catégories';

  @override
  String get settingsLabelsCategoriesRemoveTooltip => 'Supprimer';

  @override
  String get settingsLabelsColorHeading => 'Couleur';

  @override
  String get settingsLabelsColorSubheading => 'Préréglages rapides';

  @override
  String get settingsLabelsCreateTitle => 'Créer une étiquette';

  @override
  String get settingsLabelsDeleteConfirmAction => 'Supprimer';

  @override
  String settingsLabelsDeleteConfirmMessage(Object labelName) {
    return 'Es-tu sûr de vouloir supprimer « $labelName » ? Les tâches portant cette étiquette perdront l\'attribution.';
  }

  @override
  String get settingsLabelsDeleteConfirmTitle => 'Supprimer l\'étiquette';

  @override
  String settingsLabelsDeleteSuccess(Object labelName) {
    return 'Étiquette « $labelName » supprimée';
  }

  @override
  String get settingsLabelsDescriptionHint =>
      'Expliquer quand appliquer cette étiquette';

  @override
  String get settingsLabelsDescriptionLabel => 'Description (optionnel)';

  @override
  String get settingsLabelsEditTitle => 'Modifier l\'étiquette';

  @override
  String get settingsLabelsEmptyState => 'Aucune étiquette pour le moment';

  @override
  String get settingsLabelsEmptyStateHint =>
      'Appuie sur le bouton + pour créer ta première étiquette.';

  @override
  String get settingsLabelsErrorLoading => 'Échec du chargement des étiquettes';

  @override
  String get settingsLabelsNameHint => 'Bug, Bloquant, Synchronisation…';

  @override
  String get settingsLabelsNameLabel => 'Nom de l\'étiquette';

  @override
  String settingsLabelsNoMatchCreate(String query) {
    return 'Créer l\'étiquette \"$query\"';
  }

  @override
  String settingsLabelsNoMatchQuery(String query) {
    return 'Aucune étiquette ne correspond à \"$query\"';
  }

  @override
  String get settingsLabelsPrivateDescription =>
      'Visible uniquement lorsque les entrées privées sont affichées';

  @override
  String get settingsLabelsPrivateTitle => 'Privé';

  @override
  String get settingsLabelsSearchHint => 'Rechercher des étiquettes…';

  @override
  String get settingsLabelsSubtitle =>
      'Organiser les tâches avec des étiquettes colorées';

  @override
  String get settingsLabelsTitle => 'Étiquettes';

  @override
  String settingsLabelsUsageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tâches',
      one: '1 tâche',
    );
    return '$_temp0';
  }

  @override
  String get settingsLoggingDomainsSubtitle =>
      'Contrôle quels domaines écrivent dans le journal';

  @override
  String get settingsLoggingDomainsTitle => 'Domaines de journalisation';

  @override
  String get settingsLoggingGlobalToggle => 'Activer la journalisation';

  @override
  String get settingsLoggingGlobalToggleSubtitle =>
      'Interrupteur principal pour toute la journalisation';

  @override
  String get settingsLoggingSlowQueries => 'Requêtes lentes de la base';

  @override
  String get settingsLoggingSlowQueriesSubtitle =>
      'Les requêtes lentes sont écrites dans slow_queries-YYYY-MM-DD.log';

  @override
  String get settingsMaintenanceTitle => 'Maintenance';

  @override
  String get settingsMatrixAccept => 'Accepter';

  @override
  String get settingsMatrixAcceptVerificationLabel =>
      'L\'autre appareil affiche des emojis, continuer';

  @override
  String get settingsMatrixCancel => 'Annuler';

  @override
  String get settingsMatrixContinueVerificationLabel =>
      'Accepter sur l\'autre appareil pour continuer';

  @override
  String get settingsMatrixDiagnosticCopied =>
      'Informations de diagnostic copiées dans le presse-papiers';

  @override
  String get settingsMatrixDiagnosticCopyButton =>
      'Copier dans le presse-papiers';

  @override
  String get settingsMatrixDiagnosticDialogTitle =>
      'Informations de diagnostic de synchronisation';

  @override
  String get settingsMatrixDiagnosticShowButton =>
      'Afficher les informations de diagnostic';

  @override
  String get settingsMatrixDone => 'Terminé';

  @override
  String get settingsMatrixLastUpdated => 'Dernière mise à jour :';

  @override
  String get settingsMatrixListUnverifiedLabel => 'Appareils non vérifiés';

  @override
  String get settingsMatrixMaintenanceSubtitle =>
      'Exécuter les tâches de maintenance Matrix et les outils de récupération';

  @override
  String get settingsMatrixMaintenanceTitle => 'Maintenance';

  @override
  String get settingsMatrixMetrics => 'Métriques de synchronisation';

  @override
  String get settingsMatrixNextPage => 'Page suivante';

  @override
  String get settingsMatrixNoUnverifiedLabel => 'Aucun appareil non vérifié';

  @override
  String get settingsMatrixPreviousPage => 'Page précédente';

  @override
  String settingsMatrixRoomInviteMessage(String roomId, String senderId) {
    return 'Invitation au salon $roomId de $senderId. Accepter ?';
  }

  @override
  String get settingsMatrixRoomInviteTitle => 'Invitation au salon';

  @override
  String get settingsMatrixSentMessagesLabel => 'Messages envoyés :';

  @override
  String get settingsMatrixStartVerificationLabel => 'Démarrer la vérification';

  @override
  String get settingsMatrixStatsTitle => 'Statistiques Matrix';

  @override
  String get settingsMatrixTitle => 'Paramètres de synchronisation Matrix';

  @override
  String get settingsMatrixUnverifiedDevicesPage => 'Appareils non vérifiés';

  @override
  String get settingsMatrixVerificationCancelledLabel =>
      'Annulé sur un autre appareil…';

  @override
  String get settingsMatrixVerificationSuccessConfirm => 'OK';

  @override
  String settingsMatrixVerificationSuccessLabel(
    String deviceName,
    String deviceID,
  ) {
    return 'Tu as vérifié avec succès $deviceName ($deviceID)';
  }

  @override
  String get settingsMatrixVerifyConfirm =>
      'Confirme sur l\'autre appareil que les émojis ci-dessous sont affichés sur les deux appareils, dans le même ordre :';

  @override
  String get settingsMatrixVerifyIncomingConfirm =>
      'Confirme que les émojis ci-dessous sont affichés sur les deux appareils, dans le même ordre :';

  @override
  String get settingsMatrixVerifyLabel => 'Vérifier';

  @override
  String get settingsMeasurableAggregationHelper =>
      'Comment les entrées d\'une journée sont combinées dans les graphiques';

  @override
  String get settingsMeasurableAggregationLabel => 'Agrégation par défaut';

  @override
  String get settingsMeasurableDeleteTooltip => 'Supprimer type mesurable';

  @override
  String get settingsMeasurableDescriptionLabel => 'Description';

  @override
  String get settingsMeasurableDetailsLabel => 'Modifier l\'élément mesurable';

  @override
  String get settingsMeasurableNameLabel => 'Nom de la mesure';

  @override
  String get settingsMeasurablePrivateLabel => 'Privé :';

  @override
  String get settingsMeasurableSaveLabel => 'Enregistrer';

  @override
  String get settingsMeasurablesCreateTitle => 'Créer un élément mesurable';

  @override
  String get settingsMeasurablesEmptyState =>
      'Aucun élément mesurable pour le moment';

  @override
  String get settingsMeasurablesEmptyStateHint =>
      'Les éléments mesurables sont des chiffres que tu suis dans le temps — poids, eau, pas.';

  @override
  String get settingsMeasurablesErrorLoading =>
      'Erreur lors du chargement des éléments mesurables';

  @override
  String settingsMeasurablesNoMatchQuery(String query) {
    return 'Aucun élément mesurable ne correspond à \"$query\"';
  }

  @override
  String get settingsMeasurablesSearchHint =>
      'Rechercher des éléments mesurables…';

  @override
  String get settingsMeasurablesSubtitle =>
      'Configurer les types de données mesurables';

  @override
  String get settingsMeasurablesTitle => 'Éléments mesurables';

  @override
  String get settingsMeasurableUnitLabel => 'Abréviation d\'unité';

  @override
  String get settingsResetGeminiConfirm => 'Réinitialiser';

  @override
  String get settingsResetGeminiConfirmQuestion =>
      'Cela affichera à nouveau le dialogue de configuration Gemini. Continuer?';

  @override
  String get settingsResetGeminiSubtitle =>
      'Afficher à nouveau le dialogue de configuration Gemini AI';

  @override
  String get settingsResetGeminiTitle =>
      'Réinitialiser le dialogue de configuration Gemini';

  @override
  String get settingsResetHintsConfirm => 'Confirmer';

  @override
  String get settingsResetHintsConfirmQuestion =>
      'Réinitialiser les astuces dans l\'application ?';

  @override
  String settingsResetHintsResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count astuces réinitialisées',
      one: 'Une astuce réinitialisée',
      zero: 'Aucune astuce réinitialisée',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetHintsSubtitle =>
      'Effacer les conseils ponctuels et les astuces d\'introduction';

  @override
  String get settingsResetHintsTitle =>
      'Réinitialiser les astuces de l\'application';

  @override
  String get settingsSpeechSubtitle => 'Voix et lecture à voix haute';

  @override
  String get settingsSpeechTitle => 'Parole';

  @override
  String get settingsSyncConflictsSubtitle =>
      'Résoudre les conflits de synchronisation pour assurer la cohérence des données';

  @override
  String get settingsSyncNodeProfileCapabilitiesEmpty =>
      'Aucune détectée — le déclenchement automatique de l\'inférence audio synchronisée ne ciblera pas cet appareil.';

  @override
  String get settingsSyncNodeProfileCapabilitiesLabel =>
      'Capacités d\'IA détectées';

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
      'Visible par tes autres appareils lorsque tu choisis lequel épingler à un profil.';

  @override
  String get settingsSyncNodeProfileDisplayNameLabel => 'Nom de l\'appareil';

  @override
  String get settingsSyncNodeProfileKnownNodesEmpty =>
      'Aucun autre appareil n\'a encore publié de profil.';

  @override
  String get settingsSyncNodeProfileKnownNodesTitle =>
      'Appareils de synchronisation connus';

  @override
  String get settingsSyncNodeProfileSaveButton => 'Enregistrer';

  @override
  String get settingsSyncNodeProfileSubtitle =>
      'Nomme cet appareil et passe en revue les capacités visibles par tes autres appareils.';

  @override
  String get settingsSyncNodeProfileTitle => 'Cet appareil';

  @override
  String get settingsSyncOutboxTitle => 'Sync Outbox';

  @override
  String get settingsSyncStatsSubtitle =>
      'Inspecter les métriques du pipeline de synchronisation';

  @override
  String get settingsSyncSubtitle =>
      'Configurer la synchronisation et voir les statistiques';

  @override
  String get settingsThemingAutomatic => 'Automatique';

  @override
  String get settingsThemingDark => 'Apparence sombre';

  @override
  String get settingsThemingLight => 'Apparence claire';

  @override
  String get settingsThemingSubtitle =>
      'Personnaliser l\'apparence et les thèmes';

  @override
  String get settingsThemingTitle => 'Thème';

  @override
  String get settingsV2CategoryEmptyBody => 'Choisis un sous-réglage à gauche.';

  @override
  String get settingsV2DetailRootCrumb => 'Paramètres';

  @override
  String get settingsV2EmptyStateBody =>
      'Choisis une rubrique à gauche pour commencer.';

  @override
  String get settingsV2ResizeHandleLabel =>
      'Redimensionner l\'arborescence des paramètres';

  @override
  String get settingsV2UnimplementedTitle => 'Volet non encore disponible';

  @override
  String get settingsWhatsNewSubtitle =>
      'Découvre les dernières mises à jour et fonctionnalités';

  @override
  String get settingsWhatsNewTitle => 'Quoi de neuf';

  @override
  String get settingThemingDark => 'Thème sombre';

  @override
  String get settingThemingLight => 'Thème clair';

  @override
  String get sidebarRunningTimerLabel => 'Minuteur en cours';

  @override
  String get sidebarRunningTimerStopTooltip => 'Arrêter le minuteur';

  @override
  String get sidebarToggleCollapseLabel => 'Réduire la barre latérale';

  @override
  String get sidebarToggleExpandLabel => 'Développer la barre latérale';

  @override
  String get sidebarWakesCancelTooltip => 'Annuler l\'agent';

  @override
  String get sidebarWakesHeader => 'Agents';

  @override
  String get sidebarWakesNow => 'maintenant';

  @override
  String get sidebarWakesOpenList => 'Ouvrir la liste';

  @override
  String get skillsSectionTitle => 'Compétences';

  @override
  String get speechDictionaryHelper =>
      'Termes séparés par des points-virgules (max 50 caractères) pour une meilleure reconnaissance vocale';

  @override
  String get speechDictionaryHint => 'macOS; Kirkjubæjarklaustur; Claude Code';

  @override
  String get speechDictionaryLabel => 'Dictionnaire vocal';

  @override
  String get speechDictionarySectionDescription =>
      'Ajoute des termes souvent mal transcrits par la reconnaissance vocale (noms, lieux, termes techniques)';

  @override
  String get speechDictionarySectionTitle => 'Reconnaissance vocale';

  @override
  String speechDictionaryWarning(Object count) {
    return 'Un grand dictionnaire ($count termes) peut augmenter les coûts API';
  }

  @override
  String get speechModalSelectLanguage => 'Sélectionner la langue';

  @override
  String get speechModalTitle => 'Reconnaissance vocale';

  @override
  String get speechSettingsModelDescription => 'Modèle vocal sur l\'appareil';

  @override
  String get speechSettingsModelDownloadsOnce => 'Téléchargé une fois';

  @override
  String get speechSettingsModelLabel => 'Modèle';

  @override
  String get speechSettingsRecommendedBadge => 'Recommandé';

  @override
  String get speechSettingsSpeedDescription =>
      'À quelle vitesse les résumés sont lus';

  @override
  String get speechSettingsSpeedLabel => 'Vitesse de lecture';

  @override
  String get speechSettingsVoiceDescription =>
      'Choisis la voix qui lit les résumés à voix haute';

  @override
  String get speechSettingsVoiceLabel => 'Voix';

  @override
  String get speechVoiceGenderFemale => 'Féminine';

  @override
  String get speechVoiceGenderMale => 'Masculine';

  @override
  String get speechVoicePreviewTooltip => 'Écouter la voix';

  @override
  String get syncActivityInboxLabel => 'Entrée';

  @override
  String syncActivityIndicatorSemantics(int outbox, int inbox) {
    return 'Activité de synchronisation. Boîte d\'envoi : $outbox. Boîte de réception : $inbox. Ouvrir la boîte d\'envoi de synchronisation.';
  }

  @override
  String get syncActivityOutboxLabel => 'Sortie';

  @override
  String get syncDeleteConfigConfirm => 'OUI, JE SUIS SÛR';

  @override
  String get syncDeleteConfigQuestion =>
      'Veux-tu supprimer la configuration de synchronisation ?';

  @override
  String get syncEntitiesConfirm => 'DÉMARRER LA SYNCHRONISATION';

  @override
  String get syncEntitiesMessage => 'Choisis les données à synchroniser.';

  @override
  String get syncEntitiesSuccessDescription => 'Tout est à jour.';

  @override
  String get syncEntitiesSuccessTitle => 'Synchronisation terminée';

  @override
  String syncListCountSummary(String label, int itemCount) {
    String _temp0 = intl.Intl.pluralLogic(
      itemCount,
      locale: localeName,
      other: '$itemCount éléments',
      one: '1 élément',
      zero: '0 éléments',
    );
    return '$label · $_temp0';
  }

  @override
  String get syncListPayloadKindLabel => 'Contenu';

  @override
  String get syncListUnknownPayload => 'Contenu inconnu';

  @override
  String get syncNotLoggedInToast => 'La synchronisation n\'est pas connectée';

  @override
  String get syncPayloadAgentBundle => 'Lot d\'agent';

  @override
  String get syncPayloadAgentEntity => 'Entité d\'agent';

  @override
  String get syncPayloadAgentLink => 'Lien d\'agent';

  @override
  String get syncPayloadAiConfig => 'Configuration AI';

  @override
  String get syncPayloadAiConfigDelete => 'Suppression de configuration AI';

  @override
  String get syncPayloadBackfillRequest => 'Demande de rattrapage';

  @override
  String get syncPayloadBackfillResponse => 'Réponse de rattrapage';

  @override
  String get syncPayloadConfigFlag => 'Option de configuration';

  @override
  String get syncPayloadEntityDefinition => 'Définition d\'entité';

  @override
  String get syncPayloadEntryLink => 'Lien d\'entrée';

  @override
  String get syncPayloadJournalEntity => 'Entrée de journal';

  @override
  String get syncPayloadNotification => 'Notification';

  @override
  String get syncPayloadNotificationStateUpdate =>
      'Mise à jour d\'état de notification';

  @override
  String get syncPayloadOutboxBundle => 'Lot d\'envoi';

  @override
  String get syncPayloadSyncNodeProfile => 'Profil du nœud de synchronisation';

  @override
  String get syncPayloadThemingSelection => 'Sélection de thème';

  @override
  String get syncStepAgentEntities => 'Entités d\'agent';

  @override
  String get syncStepAgentLinks => 'Liens d\'agent';

  @override
  String get syncStepAiSettings => 'Paramètres IA';

  @override
  String get syncStepBackfillAgentEntityClocks =>
      'Remplir les horloges des entités d\'agent';

  @override
  String get syncStepBackfillAgentLinkClocks =>
      'Remplir les horloges des liens d\'agent';

  @override
  String get syncStepCategories => 'Catégories';

  @override
  String get syncStepComplete => 'Terminé';

  @override
  String get syncStepDashboards => 'Tableaux de bord';

  @override
  String get syncStepHabits => 'Habitudes';

  @override
  String get syncStepLabels => 'Étiquettes';

  @override
  String get syncStepMeasurables => 'Mesurables';

  @override
  String get taskActionBarAudioRecordingActive =>
      'Enregistrement audio en cours';

  @override
  String get taskActionBarMoreActions => 'Plus d\'actions';

  @override
  String get taskActionBarOpenRunningTimer => 'Ouvrir le minuteur en cours';

  @override
  String get taskActionBarStopTracking => 'Arrêter le suivi';

  @override
  String get taskActionBarTrackTime => 'Suivre le temps';

  @override
  String get taskAgentCancelTimerTooltip => 'Annuler';

  @override
  String taskAgentCountdownTooltip(String countdown) {
    return 'Prochaine exécution auto dans $countdown';
  }

  @override
  String get taskAgentCreateChipLabel => 'Assigner un agent';

  @override
  String taskAgentCreateError(String error) {
    return 'Échec de la création de l\'agent : $error';
  }

  @override
  String get taskAgentRunNowTooltip => 'Actualiser';

  @override
  String get taskCategoryAllLabel => 'tout';

  @override
  String get taskCategoryLabel => 'Catégorie :';

  @override
  String get taskCategoryUnassignedLabel => 'non attribué';

  @override
  String get taskDueDateLabel => 'Date d\'échéance';

  @override
  String taskDueDateWithDate(String date) {
    return 'Échéance : $date';
  }

  @override
  String taskDueInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours',
      one: '1 jour',
    );
    return 'Échéance dans $_temp0';
  }

  @override
  String get taskDueToday => 'Échéance aujourd\'hui';

  @override
  String get taskDueTomorrow => 'Échéance demain';

  @override
  String get taskDueYesterday => 'Échéance hier';

  @override
  String get taskEditTitleLabel => 'Modifier le titre de la tâche';

  @override
  String get taskEstimateLabel => 'Temps estimé :';

  @override
  String taskEstimateProgressLabel(String tracked, String estimate) {
    return '$tracked sur $estimate';
  }

  @override
  String taskEstimateTooltip(String tracked, String estimate) {
    return 'Temps suivi : $tracked sur $estimate estimé';
  }

  @override
  String taskLabelsMoreCount(int count) {
    return '+$count';
  }

  @override
  String get taskLabelsShowFewer => 'Afficher moins';

  @override
  String get taskLanguageArabic => 'Arabe';

  @override
  String get taskLanguageBengali => 'Bengali';

  @override
  String get taskLanguageBulgarian => 'Bulgare';

  @override
  String get taskLanguageChinese => 'Chinois';

  @override
  String get taskLanguageCroatian => 'Croate';

  @override
  String get taskLanguageCzech => 'Tchèque';

  @override
  String get taskLanguageDanish => 'Danois';

  @override
  String get taskLanguageDutch => 'Néerlandais';

  @override
  String get taskLanguageEnglish => 'Anglais';

  @override
  String get taskLanguageEstonian => 'Estonien';

  @override
  String get taskLanguageFinnish => 'Finnois';

  @override
  String get taskLanguageFrench => 'Français';

  @override
  String get taskLanguageGerman => 'Allemand';

  @override
  String get taskLanguageGreek => 'Grec';

  @override
  String get taskLanguageHebrew => 'Hébreu';

  @override
  String get taskLanguageHindi => 'Hindi';

  @override
  String get taskLanguageHungarian => 'Hongrois';

  @override
  String get taskLanguageIgbo => 'Igbo';

  @override
  String get taskLanguageIndonesian => 'Indonésien';

  @override
  String get taskLanguageItalian => 'Italien';

  @override
  String get taskLanguageJapanese => 'Japonais';

  @override
  String get taskLanguageKorean => 'Coréen';

  @override
  String get taskLanguageLabel => 'Langue';

  @override
  String get taskLanguageLatvian => 'Letton';

  @override
  String get taskLanguageLithuanian => 'Lituanien';

  @override
  String get taskLanguageNigerianPidgin => 'Pidgin nigérian';

  @override
  String get taskLanguageNorwegian => 'Norvégien';

  @override
  String get taskLanguagePolish => 'Polonais';

  @override
  String get taskLanguagePortuguese => 'Portugais';

  @override
  String get taskLanguageRomanian => 'Roumain';

  @override
  String get taskLanguageRussian => 'Russe';

  @override
  String get taskLanguageSelectedLabel => 'Langue actuelle';

  @override
  String get taskLanguageSerbian => 'Serbe';

  @override
  String get taskLanguageSetAction => 'Définir la langue';

  @override
  String get taskLanguageSlovak => 'Slovaque';

  @override
  String get taskLanguageSlovenian => 'Slovène';

  @override
  String get taskLanguageSpanish => 'Espagnol';

  @override
  String get taskLanguageSwahili => 'Swahili';

  @override
  String get taskLanguageSwedish => 'Suédois';

  @override
  String get taskLanguageThai => 'Thaï';

  @override
  String get taskLanguageTurkish => 'Turc';

  @override
  String get taskLanguageTwi => 'Twi';

  @override
  String get taskLanguageUkrainian => 'Ukrainien';

  @override
  String get taskLanguageVietnamese => 'Vietnamien';

  @override
  String get taskLanguageYoruba => 'Yoruba';

  @override
  String get taskNoDueDateLabel => 'Pas de date d\'échéance';

  @override
  String get taskNoEstimateLabel => 'Sans estimation';

  @override
  String taskOverdueByDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours',
      one: '1 jour',
    );
    return 'En retard de $_temp0';
  }

  @override
  String get taskPriorityHigh => 'Haute';

  @override
  String get taskPriorityLow => 'Basse';

  @override
  String get taskPriorityMedium => 'Moyenne';

  @override
  String get taskPriorityUrgent => 'Urgente';

  @override
  String get tasksAddLabelButton => 'Ajouter une étiquette';

  @override
  String get tasksAgentFilterAll => 'Tous';

  @override
  String get tasksAgentFilterHasAgent => 'A un agent';

  @override
  String get tasksAgentFilterNoAgent => 'Sans agent';

  @override
  String get tasksAgentFilterTitle => 'Agent';

  @override
  String get tasksFilterApplyTitle => 'Appliquer le filtre';

  @override
  String get tasksFilterClearAll => 'Tout effacer';

  @override
  String get tasksFilterTitle => 'Filtre des tâches';

  @override
  String get taskShowcaseAudio => 'Audio';

  @override
  String taskShowcaseCompletedCount(int completed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      completed,
      locale: localeName,
      other: '$completed / $total terminés',
      one: '1 / $total terminé',
    );
    return '$_temp0';
  }

  @override
  String taskShowcaseDueDate(String date) {
    return 'Échéance : $date';
  }

  @override
  String get taskShowcaseJumpToSection => 'Aller à la section';

  @override
  String get taskShowcaseLinked => 'Lié';

  @override
  String get taskShowcaseNoResults =>
      'Aucune tâche ne correspond à ta recherche.';

  @override
  String get taskShowcaseReadMore => 'Lire la suite';

  @override
  String taskShowcaseRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enregistrements',
      one: '1 enregistrement',
    );
    return '$_temp0';
  }

  @override
  String taskShowcaseShowMore(int count) {
    return 'Afficher $count de plus';
  }

  @override
  String taskShowcaseTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tâches',
      one: '1 tâche',
    );
    return '$_temp0';
  }

  @override
  String get taskShowcaseTaskDescription => 'Description de la tâche';

  @override
  String get taskShowcaseTimeTracker => 'Suivi du temps';

  @override
  String get taskShowcaseTodo => 'À faire';

  @override
  String get taskShowcaseTodos => 'À faire';

  @override
  String get tasksLabelFilterAll => 'Toutes';

  @override
  String get tasksLabelFilterTitle => 'Étiquette';

  @override
  String get tasksLabelFilterUnlabeled => 'Sans étiquette';

  @override
  String get tasksLabelsDialogClose => 'Fermer';

  @override
  String get tasksLabelsSheetApply => 'Appliquer';

  @override
  String get tasksLabelsSheetSearchHint => 'Rechercher des étiquettes…';

  @override
  String get tasksLabelsUpdateFailed =>
      'Échec de la mise à jour des étiquettes';

  @override
  String get tasksPriorityFilterAll => 'Toutes';

  @override
  String get tasksPriorityFilterTitle => 'Priorité';

  @override
  String get tasksPriorityP0 => 'Urgente';

  @override
  String get tasksPriorityP0Description => 'Urgente (Dès que possible)';

  @override
  String get tasksPriorityP1 => 'Haute';

  @override
  String get tasksPriorityP1Description => 'Haute (Bientôt)';

  @override
  String get tasksPriorityP2 => 'Moyenne';

  @override
  String get tasksPriorityP2Description => 'Moyenne (Par défaut)';

  @override
  String get tasksPriorityP3 => 'Basse';

  @override
  String get tasksPriorityP3Description => 'Basse (Quand possible)';

  @override
  String get tasksPriorityPickerTitle => 'Sélectionner la priorité';

  @override
  String get tasksQuickFilterClear => 'Effacer';

  @override
  String get tasksQuickFilterLabelsActiveTitle =>
      'Filtres d\'étiquettes actifs';

  @override
  String get tasksQuickFilterUnassignedLabel => 'Non attribué';

  @override
  String get tasksSavedFilterDeleteConfirmTooltip =>
      'Appuie à nouveau pour supprimer';

  @override
  String get tasksSavedFilterDeleteTooltip => 'Supprimer le filtre enregistré';

  @override
  String get tasksSavedFilterDragHandleSemantics =>
      'Fais glisser pour réorganiser';

  @override
  String get tasksSavedFilterRenameSemantics => 'Renommer le filtre enregistré';

  @override
  String get tasksSavedFiltersSaveButtonLabel => 'Enregistrer';

  @override
  String get tasksSavedFiltersSavePopupCancel => 'Annuler';

  @override
  String tasksSavedFiltersSavePopupHelper(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count filtres actifs. Enregistrés dans la barre latérale, sous Tâches.',
      one: '1 filtre actif. Enregistré dans la barre latérale, sous Tâches.',
    );
    return '$_temp0';
  }

  @override
  String get tasksSavedFiltersSavePopupHint => 'ex. : Bloquées ou en pause';

  @override
  String get tasksSavedFiltersSavePopupSave => 'Enregistrer';

  @override
  String get tasksSavedFiltersSavePopupTitle => 'Nomme ce filtre';

  @override
  String get tasksSavedFilterToastDeleted => 'Filtre supprimé';

  @override
  String tasksSavedFilterToastSaved(String name) {
    return '« $name » enregistré';
  }

  @override
  String tasksSavedFilterToastUpdated(String name) {
    return '« $name » mis à jour';
  }

  @override
  String get tasksSearchModeLabel => 'Mode de recherche';

  @override
  String get tasksShowCreationDate =>
      'Afficher la date de création sur les cartes';

  @override
  String get tasksShowDueDate => 'Afficher la date d\'échéance sur les cartes';

  @override
  String get tasksSortByCreationDate => 'Création';

  @override
  String get tasksSortByDueDate => 'Échéance';

  @override
  String get tasksSortByLabel => 'Trier par';

  @override
  String get tasksSortByPriority => 'Priorité';

  @override
  String get taskStatusAll => 'Tout';

  @override
  String get taskStatusBlocked => 'BLOQUÉE';

  @override
  String get taskStatusDone => 'TERMINÉE';

  @override
  String get taskStatusGroomed => 'AFFINÉE';

  @override
  String get taskStatusInProgress => 'EN COURS';

  @override
  String get taskStatusLabel => 'État de la tâche :';

  @override
  String get taskStatusOnHold => 'EN ATTENTE';

  @override
  String get taskStatusOpen => 'OUVERTE';

  @override
  String get taskStatusRejected => 'REJETÉE';

  @override
  String get taskTitleEmpty => 'Sans titre';

  @override
  String taskTrackedTimeTooltip(String duration) {
    return 'Temps suivi : $duration';
  }

  @override
  String get taskUntitled => '(sans titre)';

  @override
  String get thinkingDisclosureCopied => 'Raisonnement copié';

  @override
  String get thinkingDisclosureCopy => 'Copier le raisonnement';

  @override
  String get thinkingDisclosureHide => 'Masquer le raisonnement';

  @override
  String get thinkingDisclosureShow => 'Afficher le raisonnement';

  @override
  String get thinkingDisclosureStateCollapsed => 'replié';

  @override
  String get thinkingDisclosureStateExpanded => 'déplié';

  @override
  String get timeEntryItemEnd => 'Fin';

  @override
  String get timeEntryItemRunning => 'En cours';

  @override
  String get timeEntryItemStart => 'Début';

  @override
  String get unlinkButton => 'Délier';

  @override
  String get unlinkTaskConfirm => 'Es-tu sûr de vouloir délier cette tâche ?';

  @override
  String get unlinkTaskTitle => 'Délier la tâche';

  @override
  String vectorSearchTiming(int elapsed, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${elapsed}ms, $count résultats',
      one: '${elapsed}ms, $count résultat',
    );
    return '$_temp0';
  }

  @override
  String get viewMenuTitle => 'Affichage';

  @override
  String get viewMenuZoomIn => 'Agrandir';

  @override
  String get viewMenuZoomOut => 'Réduire';

  @override
  String get viewMenuZoomReset => 'Taille réelle';

  @override
  String get whatsNewDoneButton => 'Terminé';

  @override
  String get whatsNewSkipButton => 'Ignorer';
}

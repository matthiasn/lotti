// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get activeLabel => 'Active';

  @override
  String get addActionAddAudioRecording => 'Audio Recording';

  @override
  String get addActionAddChecklist => 'Checklist';

  @override
  String get addActionAddEvent => 'Event';

  @override
  String get addActionAddImageFromClipboard => 'Paste Image';

  @override
  String get addActionAddScreenshot => 'Screenshot';

  @override
  String get addActionAddTask => 'Task';

  @override
  String get addActionAddText => 'Text Entry';

  @override
  String get addActionAddTimeRecording => 'Timer Entry';

  @override
  String get addActionAddTimer => 'Timer';

  @override
  String get addActionImportImage => 'Import Image';

  @override
  String get addHabitCommentLabel => 'Comment';

  @override
  String get addHabitDateLabel => 'Completed at';

  @override
  String get addMeasurementCommentLabel => 'Comment';

  @override
  String get addMeasurementDateLabel => 'Observed at';

  @override
  String get addMeasurementSaveButton => 'Save';

  @override
  String get addToDictionary => 'Add to Dictionary';

  @override
  String get addToDictionaryDuplicate => 'Term already exists in dictionary';

  @override
  String get addToDictionaryNoCategory =>
      'Cannot add to dictionary: task has no category';

  @override
  String get addToDictionarySaveFailed => 'Failed to save dictionary';

  @override
  String get addToDictionarySuccess => 'Term added to dictionary';

  @override
  String get addToDictionaryTooLong => 'Term too long (max 50 characters)';

  @override
  String agentABComparisonChoose(String option) {
    return 'Choose $option';
  }

  @override
  String agentABComparisonOption(String option) {
    return 'Option $option';
  }

  @override
  String agentABComparisonPrefer(String option) {
    return 'I prefer Option $option';
  }

  @override
  String get agentBinaryChoiceNo => 'No';

  @override
  String get agentBinaryChoiceYes => 'Yes';

  @override
  String get agentCategoryRatingsScaleMax => 'Fix first';

  @override
  String get agentCategoryRatingsScaleMin => 'Leave it';

  @override
  String agentCategoryRatingsStarLabel(int starIndex, int totalStars) {
    return '$starIndex of $totalStars stars';
  }

  @override
  String get agentCategoryRatingsSubmit => 'Use These Priorities';

  @override
  String get agentCategoryRatingsSubtitle =>
      'How important is it that I fix each of these? 1 means leave it alone, 5 means fix it first.';

  @override
  String get agentCategoryRatingsTitle => 'Help Me Prioritize';

  @override
  String agentControlsActionError(String error) {
    return 'Action failed: $error';
  }

  @override
  String get agentControlsDeleteButton => 'Delete permanently';

  @override
  String get agentControlsDeleteDialogContent =>
      'This will permanently delete all data for this agent, including its history, reports, and observations. This cannot be undone.';

  @override
  String get agentControlsDeleteDialogTitle => 'Delete Agent?';

  @override
  String get agentControlsDestroyButton => 'Destroy';

  @override
  String get agentControlsDestroyDialogContent =>
      'This will permanently deactivate the agent. Its history will be preserved for audit.';

  @override
  String get agentControlsDestroyDialogTitle => 'Destroy Agent?';

  @override
  String get agentControlsDestroyedMessage => 'This agent has been destroyed.';

  @override
  String get agentControlsPauseButton => 'Pause';

  @override
  String get agentControlsReanalyzeButton => 'Re-analyze';

  @override
  String get agentControlsResumeButton => 'Resume';

  @override
  String get agentConversationEmpty => 'No conversations yet.';

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
    return '$tokenCount tokens';
  }

  @override
  String get agentDefaultProfileLabel => 'Default inference profile';

  @override
  String agentDetailErrorLoading(String error) {
    return 'Error loading agent: $error';
  }

  @override
  String get agentDetailNotFound => 'Agent not found.';

  @override
  String get agentDetailUnexpectedType => 'Unexpected entity type.';

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
  String get agentFeedbackCategoryAccuracy => 'Accuracy';

  @override
  String get agentFeedbackCategoryBreakdownTitle => 'Category Breakdown';

  @override
  String get agentFeedbackCategoryCommunication => 'Communication';

  @override
  String get agentFeedbackCategoryGeneral => 'General';

  @override
  String get agentFeedbackCategoryPrioritization => 'Prioritization';

  @override
  String get agentFeedbackCategoryTimeliness => 'Timeliness';

  @override
  String get agentFeedbackCategoryTooling => 'Tooling';

  @override
  String get agentFeedbackClassificationTitle => 'Feedback Classification';

  @override
  String get agentFeedbackExcellenceTitle => 'Notes of Excellence';

  @override
  String get agentFeedbackGrievancesTitle => 'Grievances';

  @override
  String get agentFeedbackHighPriorityTitle => 'High-Priority Feedback';

  @override
  String agentFeedbackItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get agentFeedbackSourceDecision => 'Decision';

  @override
  String get agentFeedbackSourceMetric => 'Metric';

  @override
  String get agentFeedbackSourceObservation => 'Observation';

  @override
  String get agentFeedbackSourceRating => 'Rating';

  @override
  String get agentInstancesEmptyFiltered => 'No instances match your filters.';

  @override
  String get agentInstancesFilterClearAll => 'Clear all';

  @override
  String get agentInstancesFilterClearSection => 'Clear';

  @override
  String get agentInstancesFilterSectionSoul => 'Soul';

  @override
  String get agentInstancesFilterSectionStatus => 'Status';

  @override
  String get agentInstancesFilterSectionType => 'Type';

  @override
  String agentInstancesGroupActiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active',
      one: '1 active',
    );
    return '$_temp0';
  }

  @override
  String get agentInstancesGroupBySoul => 'Soul';

  @override
  String get agentInstancesGroupByStatus => 'Status';

  @override
  String get agentInstancesGroupByType => 'Type';

  @override
  String get agentInstancesKindEvolution => 'Evolution';

  @override
  String get agentInstancesKindTaskAgent => 'Task Agent';

  @override
  String get agentInstancesPageTitle => 'Agent Instances';

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
    return '$filtered of $total';
  }

  @override
  String get agentInstancesSearchClear => 'Clear search';

  @override
  String get agentInstancesSearchPlaceholder => 'Search instances…';

  @override
  String get agentInstancesSortName => 'Name';

  @override
  String get agentInstancesSortOldest => 'Oldest';

  @override
  String get agentInstancesSortRecent => 'Recent';

  @override
  String get agentInstancesTitle => 'Instances';

  @override
  String get agentInstancesToolbarFilters => 'Filters';

  @override
  String get agentInstancesToolbarGroupBy => 'Group by';

  @override
  String get agentInstancesUnassignedSoul => 'Unassigned';

  @override
  String get agentLifecycleActive => 'Active';

  @override
  String get agentLifecycleCreated => 'Created';

  @override
  String get agentLifecycleDestroyed => 'Destroyed';

  @override
  String get agentLifecycleDormant => 'Dormant';

  @override
  String get agentMessageKindAction => 'Action';

  @override
  String get agentMessageKindMilestone => 'Milestone';

  @override
  String get agentMessageKindObservation => 'Observation';

  @override
  String get agentMessageKindRetraction => 'Retraction';

  @override
  String get agentMessageKindSummary => 'Summary';

  @override
  String get agentMessageKindSystem => 'System';

  @override
  String get agentMessageKindSystemPrompt => 'System Prompt';

  @override
  String get agentMessageKindThought => 'Thought';

  @override
  String get agentMessageKindToolResult => 'Tool Result';

  @override
  String get agentMessageKindUser => 'User';

  @override
  String get agentMessagePayloadEmpty => '(no content)';

  @override
  String get agentMessagesEmpty => 'No messages yet.';

  @override
  String agentMessagesErrorLoading(String error) {
    return 'Failed to load messages: $error';
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
      other: '$count wakes',
      one: '1 wake',
    );
    return '$hour: $_temp0 ($reasons)';
  }

  @override
  String get agentPendingWakesActivityTitle => 'Wake Activity (24h)';

  @override
  String agentPendingWakesActivityTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count total wakes',
      one: '1 total wake',
    );
    return '$_temp0';
  }

  @override
  String get agentPendingWakesDeleteTooltip => 'Remove wake';

  @override
  String get agentPendingWakesEmptyFiltered => 'No wakes match your filters.';

  @override
  String get agentPendingWakesFilterSectionType => 'Type';

  @override
  String get agentPendingWakesGroupByType => 'Type';

  @override
  String get agentPendingWakesPendingLabel => 'Pending';

  @override
  String agentPendingWakesRunningHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Running now ($count)',
      one: 'Running now',
    );
    return '$_temp0';
  }

  @override
  String get agentPendingWakesScheduledLabel => 'Scheduled';

  @override
  String get agentPendingWakesSearchPlaceholder => 'Search wakes…';

  @override
  String get agentPendingWakesSortDueLatest => 'Due latest';

  @override
  String get agentPendingWakesSortDueSoonest => 'Due soonest';

  @override
  String get agentPendingWakesTitle => 'Wake Cycles';

  @override
  String get agentReportHistoryBadge => 'Report';

  @override
  String get agentReportHistoryEmpty => 'No report snapshots yet.';

  @override
  String get agentReportHistoryError =>
      'An error occurred while loading the report history.';

  @override
  String get agentReportNone => 'No report available yet.';

  @override
  String get agentRitualReviewAction => 'Start Conversation';

  @override
  String get agentRitualReviewNegativeSignals => 'Negative';

  @override
  String get agentRitualReviewNeutralSignals => 'Neutral';

  @override
  String get agentRitualReviewNoFeedback =>
      'No feedback signals in this window';

  @override
  String get agentRitualReviewNoNegativeSignals =>
      'No negative feedback signals in this tab';

  @override
  String get agentRitualReviewNoNeutralSignals =>
      'No neutral feedback signals in this tab';

  @override
  String get agentRitualReviewNoPositiveSignals =>
      'No positive feedback signals in this tab';

  @override
  String get agentRitualReviewPositiveSignals => 'Positive';

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
  String get agentSoulAntiSycophancyLabel => 'Anti-Sycophancy Policy';

  @override
  String get agentSoulAssignedTemplatesTitle => 'Assigned Templates';

  @override
  String get agentSoulAssignmentLabel => 'Soul';

  @override
  String get agentSoulCoachingStyleLabel => 'Coaching Style';

  @override
  String get agentSoulCreateTitle => 'Create Soul';

  @override
  String get agentSoulCreatedSuccess => 'Soul created';

  @override
  String get agentSoulDeleteConfirmBody =>
      'This will remove the soul and all its versions.';

  @override
  String get agentSoulDeleteConfirmTitle => 'Delete Soul';

  @override
  String get agentSoulDetailTitle => 'Soul Detail';

  @override
  String get agentSoulDisplayNameLabel => 'Name';

  @override
  String get agentSoulEvolutionHistoryTitle => 'Soul Evolution History';

  @override
  String get agentSoulEvolutionNoSessions => 'No soul evolution sessions yet';

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
  String get agentSoulNoneAssigned => 'No soul assigned';

  @override
  String get agentSoulNotFound => 'Soul not found';

  @override
  String get agentSoulProposalSubtitle => 'Proposed personality changes';

  @override
  String get agentSoulProposalTitle => 'Soul Personality Proposal';

  @override
  String get agentSoulReviewHeroSubtitle =>
      'Refine personality across all templates sharing this soul. The evolution agent sees feedback from every template that uses this personality.';

  @override
  String get agentSoulReviewStartAction => 'Start Personality Review';

  @override
  String get agentSoulReviewStartHint =>
      'Start a personality-focused session to review feedback and evolve voice, tone, coaching style, and directness.';

  @override
  String agentSoulReviewTemplateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count templates sharing this soul',
      one: '1 template sharing this soul',
    );
    return '$_temp0';
  }

  @override
  String get agentSoulReviewTitle => 'Soul 1-on-1';

  @override
  String get agentSoulRollbackAction => 'Roll Back to This Version';

  @override
  String agentSoulRollbackConfirm(int version) {
    return 'Roll back to version $version? All templates using this soul will pick up the change.';
  }

  @override
  String get agentSoulSelectTitle => 'Select Soul';

  @override
  String get agentSoulSettingsTab => 'Settings';

  @override
  String get agentSoulToneBoundsLabel => 'Tone Bounds';

  @override
  String get agentSoulVersionHistoryTitle => 'Version History';

  @override
  String agentSoulVersionLabel(int version) {
    return 'Version $version';
  }

  @override
  String get agentSoulVersionSaved => 'New soul version saved';

  @override
  String get agentSoulVoiceDirectiveLabel => 'Voice Directive';

  @override
  String get agentSoulsEmptyFiltered => 'No souls match your filters.';

  @override
  String get agentSoulsSearchPlaceholder => 'Search souls…';

  @override
  String get agentSoulsTitle => 'Souls';

  @override
  String get agentStateConsecutiveFailures => 'Consecutive failures';

  @override
  String agentStateErrorLoading(String error) {
    return 'Failed to load state: $error';
  }

  @override
  String get agentStateHeading => 'State Info';

  @override
  String get agentStateLastWake => 'Last wake';

  @override
  String get agentStateNextWake => 'Next wake';

  @override
  String get agentStateRevision => 'Revision';

  @override
  String get agentStateSleepingUntil => 'Sleeping until';

  @override
  String get agentStateWakeCount => 'Wake count';

  @override
  String get agentStatsAllDayLegend => 'All Day';

  @override
  String get agentStatsAverageLabel => 'Average';

  @override
  String agentStatsByTimeLegend(String time) {
    return 'Daily by $time';
  }

  @override
  String get agentStatsCacheRateLabel => 'Cache Rate';

  @override
  String get agentStatsDailyUsageHeading => 'Daily Usage';

  @override
  String get agentStatsInputLabel => 'Input';

  @override
  String get agentStatsNoUsage => 'No token usage recorded in the past 7 days.';

  @override
  String get agentStatsOutputLabel => 'Output';

  @override
  String agentStatsSourceActiveFor(String duration) {
    return 'Active for $duration';
  }

  @override
  String get agentStatsSourceActivityHeading => 'Agent Activity';

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
  String get agentStatsTabTitle => 'Stats';

  @override
  String get agentStatsThoughtsLabel => 'Thoughts';

  @override
  String get agentStatsTodayLabel => 'Today';

  @override
  String get agentStatsTokensPerWakeLabel => 'Tokens / Wake';

  @override
  String get agentStatsTokensUnit => 'tokens';

  @override
  String agentStatsUsageAboveAverage(String time) {
    return 'You\'re using more tokens today than you usually do by $time.';
  }

  @override
  String agentStatsUsageBelowAverage(String time) {
    return 'You\'re using fewer tokens today than you usually do by $time.';
  }

  @override
  String get agentStatsWakesLabel => 'Wakes';

  @override
  String get agentSuggestionTimeEntryUpdateCurrent => 'Current';

  @override
  String get agentSuggestionTimeEntryUpdateNoChange => '(unchanged)';

  @override
  String get agentSuggestionTimeEntryUpdateProposed => 'Proposed';

  @override
  String get agentSuggestionTimeEntryUpdateUnavailable =>
      'Original entry not available';

  @override
  String get agentTabActivity => 'Activity';

  @override
  String get agentTabConversations => 'Conversations';

  @override
  String get agentTabObservations => 'Observations';

  @override
  String get agentTabReports => 'Reports';

  @override
  String get agentTabStats => 'Stats';

  @override
  String get agentTemplateAggregateTokenUsageHeading => 'Aggregate Token Usage';

  @override
  String get agentTemplateAssignedLabel => 'Template';

  @override
  String get agentTemplateCreateTitle => 'Create Template';

  @override
  String get agentTemplateCreatedSuccess => 'Template created';

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
      'Define the agent\'s personality, tools, objectives, and interaction style...';

  @override
  String get agentTemplateGeneralDirectiveLabel => 'General Directive';

  @override
  String get agentTemplateInstanceBreakdownHeading => 'Per-Instance Breakdown';

  @override
  String get agentTemplateKindDayAgent => 'Day Agent';

  @override
  String get agentTemplateKindImprover => 'Template Improver';

  @override
  String get agentTemplateKindProjectAgent => 'Project Agent';

  @override
  String get agentTemplateKindTaskAgent => 'Task Agent';

  @override
  String get agentTemplateMetricsTotalWakes => 'Total Wakes';

  @override
  String get agentTemplateNoTemplates =>
      'No templates available. Create one in Settings first.';

  @override
  String get agentTemplateNoVersions => 'No versions';

  @override
  String get agentTemplateNoneAssigned => 'No template assigned';

  @override
  String get agentTemplateNotFound => 'Template not found';

  @override
  String get agentTemplateReportDirectiveHint =>
      'Define the report structure, required sections, and formatting rules...';

  @override
  String get agentTemplateReportDirectiveLabel => 'Report Directive';

  @override
  String get agentTemplateReportsEmpty => 'No reports yet.';

  @override
  String get agentTemplateReportsTab => 'Reports';

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
  String get agentTemplateSettingsTab => 'Settings';

  @override
  String get agentTemplateStatsTab => 'Stats';

  @override
  String get agentTemplateStatusActive => 'Active';

  @override
  String get agentTemplateStatusArchived => 'Archived';

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
  String get agentTemplatesEmptyFiltered => 'No templates match your filters.';

  @override
  String get agentTemplatesFilterSectionKind => 'Kind';

  @override
  String get agentTemplatesGroupByKind => 'Kind';

  @override
  String get agentTemplatesGroupNone => 'All';

  @override
  String get agentTemplatesSearchPlaceholder => 'Search templates…';

  @override
  String get agentTemplatesTitle => 'Agent Templates';

  @override
  String get agentThreadReportLabel => 'Report produced during this wake';

  @override
  String get agentTokenUsageCachedTokens => 'Cached';

  @override
  String get agentTokenUsageEmpty => 'No token usage recorded yet.';

  @override
  String agentTokenUsageErrorLoading(String error) {
    return 'Failed to load token usage: $error';
  }

  @override
  String get agentTokenUsageHeading => 'Token Usage';

  @override
  String get agentTokenUsageInputTokens => 'Input';

  @override
  String get agentTokenUsageModel => 'Model';

  @override
  String get agentTokenUsageOutputTokens => 'Output';

  @override
  String get agentTokenUsageThoughtsTokens => 'Thoughts';

  @override
  String get agentTokenUsageTotalTokens => 'Total';

  @override
  String get agentTokenUsageWakeCount => 'Wakes';

  @override
  String get aiAssistantTitle => 'Generate…';

  @override
  String get aiBatchToggleTooltip => 'Switch to standard recording';

  @override
  String get aiCapabilityChipImageGeneration => 'Image generation';

  @override
  String get aiCapabilityChipImageRecognition => 'Image recognition';

  @override
  String get aiCapabilityChipThinking => 'Thinking';

  @override
  String get aiCapabilityChipTranscription => 'Transcription';

  @override
  String get aiCardEmptyProposals =>
      'No open proposals · agent will surface new changes here';

  @override
  String aiCardHistoryToggle(int count) {
    return 'History · $count';
  }

  @override
  String get aiCardMenuActionDelete => 'Delete';

  @override
  String get aiCardMenuActionEdit => 'Edit';

  @override
  String get aiCardOpenAgentInternals => 'Open agent internals';

  @override
  String get aiCardProposalConfirmed => 'Confirmed';

  @override
  String get aiCardProposalDismissed => 'Dismissed';

  @override
  String get aiCardProposalKindAdd => 'Add';

  @override
  String get aiCardProposalKindDue => 'Due';

  @override
  String get aiCardProposalKindEstimate => 'Estimate';

  @override
  String get aiCardProposalKindLabel => 'Label';

  @override
  String get aiCardProposalKindPriority => 'Priority';

  @override
  String get aiCardProposalKindRemove => 'Remove';

  @override
  String get aiCardProposalKindStatus => 'Status';

  @override
  String get aiCardProposalKindUpdate => 'Update';

  @override
  String get aiCardReadMore => 'Read more';

  @override
  String get aiCardShowLess => 'Show less';

  @override
  String get aiCardTitle => 'AI summary';

  @override
  String get aiChatMessageCopied => 'Copied to clipboard';

  @override
  String get aiConfigFailedToLoadModelsGeneric =>
      'Failed to load models. Please try again.';

  @override
  String get aiConfigNoModelsAvailable =>
      'No AI models are configured yet. Please add one in settings.';

  @override
  String get aiConfigNoSuitableModelsAvailable =>
      'No models meet the requirements for this prompt. Please configure models that support the required capabilities.';

  @override
  String get aiConfigSelectProviderModalTitle => 'Select Inference Provider';

  @override
  String get aiConfigSelectProviderTypeModalTitle => 'Select Provider Type';

  @override
  String get aiConfigUseReasoningFieldLabel => 'Use Reasoning';

  @override
  String aiDeleteToastCascadeDescription(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Also removed $count models: $names',
      one: 'Also removed 1 model: $names',
    );
    return '$_temp0';
  }

  @override
  String aiDeleteToastErrorTitle(String name) {
    return 'Couldn\'t delete $name';
  }

  @override
  String get aiDeleteToastModelTitle => 'Model deleted';

  @override
  String get aiDeleteToastProfileTitle => 'Profile deleted';

  @override
  String get aiDeleteToastPromptTitle => 'Prompt deleted';

  @override
  String get aiDeleteToastProviderTitle => 'Provider deleted';

  @override
  String get aiDeleteToastSkillTitle => 'Skill deleted';

  @override
  String get aiDeleteToastUndoAction => 'Undo';

  @override
  String get aiFormCancel => 'Cancel';

  @override
  String get aiFormFixErrors => 'Please fix errors before saving';

  @override
  String get aiFormNoChanges => 'No unsaved changes';

  @override
  String get aiImageAnalysisPickerDefaultBadge => 'Default';

  @override
  String get aiImageAnalysisPickerTitle => 'Pick an image analysis model';

  @override
  String get aiInferenceErrorAuthenticationTitle => 'Authentication Failed';

  @override
  String get aiInferenceErrorConnectionFailedTitle => 'Connection Failed';

  @override
  String get aiInferenceErrorInvalidRequestTitle => 'Invalid Request';

  @override
  String get aiInferenceErrorRateLimitTitle => 'Rate Limit Exceeded';

  @override
  String get aiInferenceErrorRetryButton => 'Try Again';

  @override
  String get aiInferenceErrorServerTitle => 'Server Error';

  @override
  String get aiInferenceErrorSuggestionsTitle => 'Suggestions:';

  @override
  String get aiInferenceErrorTimeoutTitle => 'Request Timed Out';

  @override
  String get aiInferenceErrorUnknownTitle => 'Error';

  @override
  String get aiInternalsTitle => 'Agent internals';

  @override
  String get aiModelDownloadCloseButton => 'Close';

  @override
  String aiModelDownloadDialogDescription(String modelName) {
    return 'Lotti will download $modelName into the MLX Audio cache and use it for local speech processing.';
  }

  @override
  String aiModelDownloadDialogTitle(String modelName) {
    return 'Install $modelName';
  }

  @override
  String get aiModelDownloadInstallTooltip => 'Install model';

  @override
  String get aiModelDownloadOpenProgressTooltip => 'Show download progress';

  @override
  String get aiModelDownloadStatusChecking => 'Checking model status';

  @override
  String aiModelDownloadStatusDownloading(int percent) {
    return 'Downloading $percent%';
  }

  @override
  String get aiModelDownloadStatusDownloadingIndeterminate => 'Downloading';

  @override
  String get aiModelDownloadStatusFailed => 'Download failed';

  @override
  String get aiModelDownloadStatusInstalled => 'Installed';

  @override
  String get aiModelDownloadStatusNotInstalled => 'Not installed';

  @override
  String get aiModelDownloadStatusUnsupported => 'Apple Silicon required';

  @override
  String get aiModelInstallChoiceCancelButton => 'Cancel';

  @override
  String get aiModelInstallChoiceDescription =>
      'Pick the local speech-to-text model to download first. You can install the others later from the model list.';

  @override
  String get aiModelInstallChoiceInstallButton => 'Install model';

  @override
  String get aiModelInstallChoiceRecommended => 'Recommended';

  @override
  String get aiModelInstallChoiceTitle => 'Choose MLX Audio model';

  @override
  String aiOllamaModelInstalledSuccessfully(String modelName) {
    return 'Model \"$modelName\" installed successfully!';
  }

  @override
  String get aiPickProviderBadgeDesktopOnly => 'DESKTOP ONLY';

  @override
  String get aiPickProviderBadgeNew => 'NEW';

  @override
  String get aiPickProviderBadgeRecommended => 'RECOMMENDED';

  @override
  String get aiPickProviderContinueButton => 'Continue';

  @override
  String get aiPickProviderDontShowAgainButton => 'Don\'t show again';

  @override
  String get aiPickProviderFooterHint =>
      'You can add more providers later in Settings → AI. Your API key is stored locally.';

  @override
  String get aiPickProviderModalTitle => 'Set up AI features';

  @override
  String get aiPickProviderSubtitle =>
      'Pick a provider to get started. We\'ll set up models and a starting profile automatically.';

  @override
  String get aiProfileCardActiveBadge => 'Active';

  @override
  String get aiProfileModelPickerSearchHint => 'Search models…';

  @override
  String get aiProfileSlotModelMissing => 'missing';

  @override
  String get aiPromptGenerationPickerTitle => 'Pick a prompt generation model';

  @override
  String get aiProviderAlibabaDescription =>
      'Alibaba Cloud\'s Qwen family of models via DashScope API';

  @override
  String get aiProviderAlibabaName => 'Alibaba Cloud (Qwen)';

  @override
  String get aiProviderAnthropicDescription =>
      'Anthropic\'s Claude family of AI assistants';

  @override
  String get aiProviderAnthropicName => 'Anthropic Claude';

  @override
  String get aiProviderCardDraftBadge => 'DRAFT';

  @override
  String get aiProviderCardFixButton => 'Fix';

  @override
  String get aiProviderCardMenuTooltip => 'More actions';

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
      other: '$count models · last used $lastUsed',
      one: '1 model · last used $lastUsed',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderCardOllamaHint => 'Make sure Ollama is running';

  @override
  String aiProviderCardStatusConnected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Connected · $count models',
      one: 'Connected · 1 model',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderCardStatusConnectedShort => 'Connected';

  @override
  String get aiProviderCardStatusInvalidKey => 'Invalid key';

  @override
  String get aiProviderCardStatusOffline =>
      'Offline · Make sure Ollama is running';

  @override
  String get aiProviderCardStatusOfflineShort => 'Offline';

  @override
  String get aiProviderConnectBackToProviders => 'Back to providers';

  @override
  String get aiProviderConnectBreadcrumbAdd => 'Add provider';

  @override
  String get aiProviderConnectFieldBaseUrlHint =>
      'Leave blank to use the official endpoint';

  @override
  String get aiProviderConnectFieldBaseUrlLabelOptional =>
      'Base URL (optional)';

  @override
  String get aiProviderConnectFieldBaseUrlPlaceholder =>
      'https://api.example.com';

  @override
  String get aiProviderConnectFieldDisplayNameHint =>
      'Shown in your provider list';

  @override
  String aiProviderConnectKeyHelperLink(String url) {
    return 'Get a key at $url';
  }

  @override
  String get aiProviderConnectKeyHiddenLabel => 'Hidden';

  @override
  String get aiProviderConnectKeyPrivacyHint =>
      'Your API key never leaves your device.';

  @override
  String aiProviderConnectPageTitle(String providerName) {
    return 'Connect $providerName';
  }

  @override
  String get aiProviderConnectSaveAndContinue => 'Save & continue';

  @override
  String get aiProviderConnectSaveAsDraft => 'Save as draft';

  @override
  String get aiProviderConnectSavedAsDraftToast => 'Saved as draft';

  @override
  String get aiProviderConnectStepChoose => 'Choose provider';

  @override
  String get aiProviderConnectStepConnect => 'Connect';

  @override
  String get aiProviderConnectStepReview => 'Review';

  @override
  String get aiProviderConnectionCheckingLabel =>
      'Checking key, listing available models…';

  @override
  String aiProviderConnectionFailedBadResponseDetail(String type) {
    return 'Unexpected response shape: $type';
  }

  @override
  String aiProviderConnectionFailedHttpDetail(int status, String message) {
    return 'HTTP $status · $message';
  }

  @override
  String get aiProviderConnectionFailedInvalidBaseUrlDetail =>
      'Base URL must include http(s) scheme and host (e.g. https://api.example.com)';

  @override
  String aiProviderConnectionFailedNetworkDetail(String message) {
    return '$message';
  }

  @override
  String get aiProviderConnectionFailedTimeoutDetail => 'Request timed out';

  @override
  String aiProviderConnectionFailedTitle(String providerName) {
    return 'Couldn\'t reach $providerName. Check the key or your network.';
  }

  @override
  String get aiProviderConnectionRetestButton => 'Re-test';

  @override
  String get aiProviderConnectionRetryButton => 'Retry';

  @override
  String aiProviderConnectionVerifiedSubtitle(int count, int ms) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count models available on your account · responded in ${ms}ms',
      one: '1 model available on your account · responded in ${ms}ms',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderConnectionVerifiedTitle => 'Connection verified';

  @override
  String get aiProviderDetailActiveProfileTitle => 'Active profile';

  @override
  String get aiProviderDetailAddModelButton => 'Add model';

  @override
  String get aiProviderDetailApiKeyLabel => 'API key';

  @override
  String get aiProviderDetailBackTooltip => 'Back';

  @override
  String get aiProviderDetailBaseUrlLabel => 'Base URL';

  @override
  String get aiProviderDetailConnectionTitle => 'Connection';

  @override
  String get aiProviderDetailDangerZoneTitle => 'Danger zone';

  @override
  String get aiProviderDetailDisplayNameLabel => 'Display name';

  @override
  String get aiProviderDetailEditButton => 'Edit';

  @override
  String get aiProviderDetailEditTooltip => 'Edit provider';

  @override
  String get aiProviderDetailLoadError =>
      'Could not load this provider. Try again from the AI Settings list.';

  @override
  String get aiProviderDetailMissingMessage =>
      'This provider is no longer available.';

  @override
  String aiProviderDetailModelsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Models · $count',
      one: 'Models · 1',
      zero: 'Models',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderDetailNoModelsMessage =>
      'No models yet. Add one to start using this provider.';

  @override
  String get aiProviderDetailPageTitle => 'Provider details';

  @override
  String get aiProviderDetailRemoveButton => 'Remove provider';

  @override
  String get aiProviderDetailRemoveDescription =>
      'Deletes the provider and every model that depends on it. This cannot be undone.';

  @override
  String get aiProviderDetailRemoveTitle => 'Remove this provider';

  @override
  String get aiProviderDetailValueUnset => 'Not set';

  @override
  String get aiProviderEmbeddedRuntimeHint =>
      'Runs embedded in the Apple app process. No local server or Base URL is required.';

  @override
  String get aiProviderGeminiDescription => 'Google\'s Gemini AI models';

  @override
  String get aiProviderGeminiName => 'Google Gemini';

  @override
  String get aiProviderGenericOpenAiDescription =>
      'API compatible with OpenAI format';

  @override
  String get aiProviderGenericOpenAiName => 'OpenAI Compatible';

  @override
  String get aiProviderMistralDescription =>
      'Mistral AI cloud API with native audio transcription';

  @override
  String get aiProviderMistralName => 'Mistral';

  @override
  String get aiProviderMlxAudioDescription =>
      'Embedded MLX Audio models for local STT and TTS on Apple Silicon';

  @override
  String get aiProviderMlxAudioName => 'MLX Audio (local)';

  @override
  String get aiProviderNebiusAiStudioDescription =>
      'Nebius AI Studio\'s models';

  @override
  String get aiProviderNebiusAiStudioName => 'Nebius AI Studio';

  @override
  String get aiProviderOllamaDescription => 'Run inference locally with Ollama';

  @override
  String get aiProviderOllamaName => 'Ollama';

  @override
  String get aiProviderOpenAiDescription => 'OpenAI\'s GPT models';

  @override
  String get aiProviderOpenAiName => 'OpenAI';

  @override
  String get aiProviderOpenRouterDescription => 'OpenRouter\'s models';

  @override
  String get aiProviderOpenRouterName => 'OpenRouter';

  @override
  String get aiProviderSetupOptionGeminiDescription =>
      'Multimodal models with audio transcription. Requires API key.';

  @override
  String get aiProviderSetupOptionMistralDescription =>
      'European AI with reasoning (Magistral) and audio (Voxtral) models.';

  @override
  String get aiProviderSetupOptionOpenAiDescription =>
      'GPT models for chat and reasoning. Requires API key with credits.';

  @override
  String get aiProviderTaglineAlibaba =>
      'Qwen models · multimodal · long context';

  @override
  String get aiProviderTaglineAnthropic => 'Claude family · long context';

  @override
  String get aiProviderTaglineGemini => 'Multimodal · audio transcription';

  @override
  String get aiProviderTaglineMlxAudio =>
      'Embedded · Apple Silicon · local audio';

  @override
  String get aiProviderTaglineOllama => 'Runs locally · no cloud calls';

  @override
  String get aiProviderTaglineOpenAi => 'GPT family · vision + reasoning';

  @override
  String get aiProviderUnknownName => 'AI provider';

  @override
  String get aiProviderVoxtralDescription =>
      'Local Voxtral transcription (up to 30 min audio, 13 languages)';

  @override
  String get aiProviderVoxtralName => 'Voxtral (local)';

  @override
  String get aiProviderWhisperDescription =>
      'Local Whisper transcription with OpenAI-compatible API';

  @override
  String get aiProviderWhisperName => 'Whisper (local)';

  @override
  String get aiRealtimeToggleTooltip => 'Switch to live transcription';

  @override
  String get aiResponseDeleteCancel => 'Cancel';

  @override
  String get aiResponseDeleteConfirm => 'Delete';

  @override
  String get aiResponseDeleteError =>
      'Failed to delete AI response. Please try again.';

  @override
  String get aiResponseDeleteTitle => 'Delete AI Response';

  @override
  String get aiResponseDeleteWarning =>
      'Are you sure you want to delete this AI response? This cannot be undone.';

  @override
  String get aiResponseTypeAudioTranscription => 'Audio Transcription';

  @override
  String get aiResponseTypeChecklistUpdates => 'Checklist Updates';

  @override
  String get aiResponseTypeImageAnalysis => 'Image Analysis';

  @override
  String get aiResponseTypeImagePromptGeneration => 'Image Prompt';

  @override
  String get aiResponseTypePromptGeneration => 'Generated Prompt';

  @override
  String get aiResponseTypeTaskSummary => 'Task Summary';

  @override
  String get aiRunningActivityOpenProgress => 'Show AI progress';

  @override
  String get aiSettingsAddModelButton => 'Add model';

  @override
  String get aiSettingsAddModelTooltip => 'Add this model to your provider';

  @override
  String get aiSettingsAddProfileButton => 'Add Profile';

  @override
  String get aiSettingsAddProviderButton => 'Add provider';

  @override
  String get aiSettingsAddedLabel => 'Added';

  @override
  String get aiSettingsClearAllFiltersTooltip => 'Clear all filters';

  @override
  String get aiSettingsClearFiltersButton => 'Clear';

  @override
  String get aiSettingsCounterModels => 'Models';

  @override
  String get aiSettingsCounterProfiles => 'Profiles';

  @override
  String get aiSettingsCounterProviders => 'Providers';

  @override
  String get aiSettingsEmptyDescription =>
      'Add one to unlock transcription, image recognition, image generation, and semantic search.';

  @override
  String get aiSettingsEmptyTitle => 'No providers yet';

  @override
  String aiSettingsFilterByCapabilityTooltip(String capability) {
    return 'Filter by $capability capability';
  }

  @override
  String aiSettingsFilterByProviderTooltip(String provider) {
    return 'Filter by $provider';
  }

  @override
  String get aiSettingsFilterByReasoningTooltip =>
      'Filter by reasoning capability';

  @override
  String get aiSettingsFtueBannerDescription =>
      'Takes about a minute. Lotti will set up models and a starting profile for you.';

  @override
  String get aiSettingsFtueBannerStartButton => 'Start setup';

  @override
  String get aiSettingsFtueBannerTitle => 'Add your first AI provider';

  @override
  String get aiSettingsModalityAudio => 'Audio';

  @override
  String get aiSettingsModalityText => 'Text';

  @override
  String get aiSettingsModalityVision => 'Vision';

  @override
  String get aiSettingsNoModelsConfigured => 'No AI models configured';

  @override
  String get aiSettingsNoProvidersConfigured => 'No AI providers configured';

  @override
  String get aiSettingsPageLead =>
      'Configure AI providers, the models Lotti can call, and the inference profiles that decide which model handles which task.';

  @override
  String get aiSettingsPageTitle => 'AI Settings';

  @override
  String get aiSettingsReasoningLabel => 'Reasoning';

  @override
  String get aiSettingsSearchHint => 'Search AI configurations...';

  @override
  String get aiSettingsSearchHintShort => 'Search';

  @override
  String get aiSettingsTabModels => 'Models';

  @override
  String get aiSettingsTabProfiles => 'Profiles';

  @override
  String get aiSettingsTabProviders => 'Providers';

  @override
  String get aiSetupPreviewAcceptButton => 'Accept & finish';

  @override
  String get aiSetupPreviewAlreadyAddedSectionLabel => 'Already added';

  @override
  String aiSetupPreviewCategoryFooter(String categoryName) {
    return 'Set up a test category $categoryName to try it out.';
  }

  @override
  String aiSetupPreviewConnectedHeader(String providerName) {
    return '$providerName connected';
  }

  @override
  String get aiSetupPreviewCustomizeButton => 'Customize';

  @override
  String get aiSetupPreviewLead =>
      'Review what Lotti will add. Uncheck anything you don\'t want; you can always set it up later by hand.';

  @override
  String get aiSetupPreviewLiveBadge => 'Live';

  @override
  String aiSetupPreviewModalTitle(String providerName) {
    return '$providerName setup';
  }

  @override
  String get aiSetupPreviewModelsSectionLabel => 'Models';

  @override
  String get aiSetupPreviewProfileSectionLabel => 'Inference profile';

  @override
  String get aiSetupPreviewProfileSetActiveBadge => 'Set active';

  @override
  String aiSetupResultBulletCategoryCreated(String categoryName) {
    return 'Set up a test category $categoryName to try it out';
  }

  @override
  String aiSetupResultBulletCategoryReused(String categoryName) {
    return 'Reusing existing test category $categoryName';
  }

  @override
  String aiSetupResultBulletModels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Configured $count models',
      one: 'Configured 1 model',
    );
    return '$_temp0';
  }

  @override
  String aiSetupResultBulletProfile(String profileName) {
    return 'Created inference profile $profileName';
  }

  @override
  String aiSetupResultErrorsHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count issues',
      one: '1 issue',
    );
    return '$_temp0 during setup';
  }

  @override
  String aiSetupResultHeader(String providerName) {
    return '$providerName is connected';
  }

  @override
  String aiSetupResultKnownModelsMissing(String providerName) {
    return 'Failed to find required $providerName model configurations';
  }

  @override
  String get aiSetupResultLead =>
      'We set things up for you. AI features are ready to use in your journal.';

  @override
  String aiSetupResultModalTitle(String providerName) {
    return '$providerName ready';
  }

  @override
  String get aiSetupResultStartUsingButton => 'Start using AI';

  @override
  String get aiSetupWizardCreatesOptimized =>
      'Creates optimized models, prompts, and a test category';

  @override
  String aiSetupWizardDescription(String providerName) {
    return 'Set up or refresh models, prompts, and test category for $providerName';
  }

  @override
  String get aiSetupWizardRunButton => 'Run Setup';

  @override
  String get aiSetupWizardRunLabel => 'Run Setup Wizard';

  @override
  String get aiSetupWizardRunningButton => 'Running...';

  @override
  String get aiSetupWizardSafeToRunMultiple =>
      'Safe to run multiple times - existing items will be kept';

  @override
  String get aiSetupWizardTitle => 'AI Setup Wizard';

  @override
  String get aiSummarySpeakTooltip => 'Read summary aloud locally';

  @override
  String get aiTaskSummaryTitle => 'AI Task Summary';

  @override
  String get aiTranscriptionPickerDefaultBadge => 'Default';

  @override
  String get aiTranscriptionPickerTitle => 'Pick a transcription model';

  @override
  String get apiKeyAddPageTitle => 'Add Provider';

  @override
  String get apiKeyAuthenticationDescription => 'Secure your API connection';

  @override
  String get apiKeyAuthenticationTitle => 'Authentication';

  @override
  String get apiKeyAvailableModelsDescription =>
      'Quick-add preconfigured models for this provider';

  @override
  String get apiKeyAvailableModelsTitle => 'Available Models';

  @override
  String get apiKeyBaseUrlLabel => 'Base URL';

  @override
  String get apiKeyDisplayNameHint => 'Enter a friendly name';

  @override
  String get apiKeyDisplayNameLabel => 'Display Name';

  @override
  String get apiKeyEditGoBackButton => 'Go Back';

  @override
  String get apiKeyEditLoadError => 'Failed to load API key configuration';

  @override
  String get apiKeyEditLoadErrorRetry => 'Please try again or contact support';

  @override
  String get apiKeyEditPageTitle => 'Edit Provider';

  @override
  String get apiKeyHideTooltip => 'Hide API Key';

  @override
  String get apiKeyInputHint => 'Enter your API key';

  @override
  String get apiKeyInputLabel => 'API Key';

  @override
  String apiKeyKnownModelInputLabel(String modalities) {
    return 'In: $modalities';
  }

  @override
  String apiKeyKnownModelOutputLabel(String modalities) {
    return 'Out: $modalities';
  }

  @override
  String get apiKeyProviderConfigDescription =>
      'Configure your AI inference provider settings';

  @override
  String get apiKeyProviderConfigTitle => 'Provider Configuration';

  @override
  String get apiKeyProviderTypeHint => 'Select a provider type';

  @override
  String get apiKeyProviderTypeLabel => 'Provider Type';

  @override
  String get apiKeyShowTooltip => 'Show API Key';

  @override
  String get audioRecordingCancel => 'CANCEL';

  @override
  String get audioRecordingListening => 'Listening...';

  @override
  String get audioRecordingRealtime => 'Live Transcription';

  @override
  String get audioRecordingStandard => 'Standard';

  @override
  String get audioRecordingStop => 'STOP';

  @override
  String get audioRecordings => 'Audio Recordings';

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
  String get backfillAdvancedRecoveryTitle => 'Advanced recovery';

  @override
  String get backfillAskPeersConfirmAccept => 'Ask peers';

  @override
  String backfillAskPeersConfirmContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'This flips all $count unresolvable sequence-log entries back to missing so the normal backfill sweep re-asks peers. Peers who still have the payload will respond; truly unrecoverable entries will retire again after the 7-day amnesty window.',
      one:
          'This flips 1 unresolvable sequence-log entry back to missing so the normal backfill sweep re-asks peers. Peers who still have the payload will respond; truly unrecoverable entries will retire again after the 7-day amnesty window.',
    );
    return '$_temp0';
  }

  @override
  String get backfillAskPeersConfirmTitle =>
      'Ask peers again for unresolvable entries?';

  @override
  String get backfillAskPeersDescription =>
      'Flip every unresolvable sequence-log entry back to missing and let the normal backfill sweep re-ask peers.';

  @override
  String get backfillAskPeersProcessing => 'Reopening…';

  @override
  String get backfillAskPeersTitle => 'Ask peers for unresolvable';

  @override
  String backfillAskPeersTrigger(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ask peers for $count entries',
      one: 'Ask peers for 1 entry',
    );
    return '$_temp0';
  }

  @override
  String get backfillCatchUpDescription =>
      'Pull recent missing entries from peers right now.';

  @override
  String backfillDevicesMeta(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count device IDs',
      one: '1 device ID',
    );
    return '$_temp0';
  }

  @override
  String get backfillManualDescription =>
      'Request all missing entries regardless of age. Use this to recover older sync gaps.';

  @override
  String get backfillManualProcessing => 'Processing...';

  @override
  String get backfillManualTitle => 'Manual Backfill';

  @override
  String get backfillManualTrigger => 'Request Missing Entries';

  @override
  String get backfillReRequestDescription =>
      'Re-request entries that were requested but never received. Use this when responses are stuck.';

  @override
  String get backfillReRequestProcessing => 'Re-requesting...';

  @override
  String get backfillReRequestTitle => 'Re-Request Pending';

  @override
  String get backfillReRequestTrigger => 'Re-Request Pending Entries';

  @override
  String get backfillResetUnresolvableDescription =>
      'Reset entries marked as unresolvable back to missing so they can be re-requested. Use after sequence log repopulation.';

  @override
  String get backfillResetUnresolvableProcessing => 'Resetting...';

  @override
  String get backfillResetUnresolvableTitle => 'Reset Unresolvable';

  @override
  String get backfillResetUnresolvableTrigger => 'Reset Unresolvable Entries';

  @override
  String get backfillRetireStuckConfirmAccept => 'Retire now';

  @override
  String backfillRetireStuckConfirmContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'This marks $count currently-open (missing or requested) sequence-log entries as unresolvable. Use this to unblock the watermark when entries have been stuck for a while without the 7-day amnesty window having passed. Entries can still be resurrected if their payload later arrives on disk with a valid vector clock.',
      one:
          'This marks 1 currently-open (missing or requested) sequence-log entry as unresolvable. Use this to unblock the watermark when entries have been stuck for a while without the 7-day amnesty window having passed. Entries can still be resurrected if their payload later arrives on disk with a valid vector clock.',
    );
    return '$_temp0';
  }

  @override
  String get backfillRetireStuckConfirmTitle => 'Retire stuck entries now?';

  @override
  String get backfillRetireStuckDescription =>
      'Force every currently-open missing or requested sequence-log entry to unresolvable. Skips the 7-day amnesty — use only for stuck rows blocking the watermark.';

  @override
  String get backfillRetireStuckProcessing => 'Retiring…';

  @override
  String get backfillRetireStuckTitle => 'Retire stuck entries';

  @override
  String backfillRetireStuckTrigger(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Retire $count stuck entries',
      one: 'Retire 1 stuck entry',
    );
    return '$_temp0';
  }

  @override
  String get backfillSettingsSubtitle => 'Manage sync gap recovery';

  @override
  String get backfillSettingsTitle => 'Backfill sync';

  @override
  String get backfillStatsBackfilled => 'Backfilled';

  @override
  String get backfillStatsBurned => 'Burned';

  @override
  String get backfillStatsDeleted => 'Deleted';

  @override
  String get backfillStatsMissing => 'Missing';

  @override
  String get backfillStatsNoData => 'No sync data available';

  @override
  String get backfillStatsReceived => 'Received';

  @override
  String get backfillStatsRefresh => 'Refresh stats';

  @override
  String get backfillStatsRequested => 'Requested';

  @override
  String get backfillStatsTitle => 'Sync statistics';

  @override
  String get backfillStatsTotalEntries => 'Total entries';

  @override
  String get backfillStatsUnresolvable => 'Unresolvable';

  @override
  String get backfillStatusInboundQueue => 'Inbound queue';

  @override
  String get backfillStatusMissing => 'Missing';

  @override
  String get backfillStatusSkipped => 'Skipped';

  @override
  String get backfillToggleDescription =>
      'Requests missing entries from the last 24 hours.';

  @override
  String get backfillToggleTitle => 'Automatic backfill';

  @override
  String get basicSettings => 'Basic settings';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get categoryActiveDescription =>
      'Inactive categories won\'t appear in selection lists';

  @override
  String get categoryAiDefaultsDescription =>
      'Set default AI profile and agent template for new tasks in this category';

  @override
  String get categoryAiDefaultsTitle => 'AI Defaults';

  @override
  String get categoryCreationError =>
      'Failed to create category. Please try again.';

  @override
  String get categoryDayPlanDescription =>
      'Make this category available for selection in the day plan';

  @override
  String get categoryDayPlanLabel => 'Day planning';

  @override
  String get categoryDefaultLanguageDescription =>
      'Set a default language for tasks in this category';

  @override
  String get categoryDefaultProfileHint => 'Select a profile…';

  @override
  String get categoryDefaultTemplateHint => 'Select a template…';

  @override
  String get categoryDefaultTemplateLabel => 'Default agent template';

  @override
  String get categoryDeleteConfirm => 'YES, DELETE THIS CATEGORY';

  @override
  String get categoryDeleteConfirmation =>
      'This action cannot be undone. All entries in this category will remain but will no longer be categorized.';

  @override
  String get categoryDeleteTitle => 'Delete Category?';

  @override
  String get categoryFavoriteDescription => 'Mark this category as a favorite';

  @override
  String get categoryIconChooseHint => 'Choose an icon';

  @override
  String get categoryIconCreateHint => 'Tap to select an icon';

  @override
  String get categoryIconEditHint => 'Tap to select a different icon';

  @override
  String get categoryIconLabel => 'Icon';

  @override
  String get categoryIconPickerTitle => 'Choose icon';

  @override
  String get categoryNameRequired => 'Category name is required';

  @override
  String get categoryNotFound => 'Category not found';

  @override
  String get categoryPrivateDescription =>
      'Hide this category when private mode is enabled';

  @override
  String get categorySearchPlaceholder => 'Search categories...';

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
  String get chatInputCancelRealtime => 'Cancel (Esc)';

  @override
  String get chatInputCancelRecording => 'Cancel recording (Esc)';

  @override
  String get chatInputConfigureModel => 'Configure model';

  @override
  String get chatInputHintDefault => 'Ask about your tasks and productivity...';

  @override
  String get chatInputHintSelectModel => 'Select a model to start chatting';

  @override
  String get chatInputListening => 'Listening...';

  @override
  String get chatInputPleaseWait => 'Please wait...';

  @override
  String get chatInputProcessing => 'Processing...';

  @override
  String get chatInputRecordVoice => 'Record voice message';

  @override
  String get chatInputSendTooltip => 'Send message';

  @override
  String get chatInputStartRealtime => 'Start live transcription';

  @override
  String get chatInputStopRealtime => 'Stop live transcription';

  @override
  String get chatInputStopTranscribe => 'Stop and transcribe';

  @override
  String get checklistAddItem => 'Add a new item';

  @override
  String checklistAiConfidenceLabel(String level) {
    return 'Confidence: $level';
  }

  @override
  String get checklistAiMarkComplete => 'Mark Complete';

  @override
  String get checklistAiSuggestionBody => 'This item appears to be completed:';

  @override
  String get checklistAiSuggestionTitle => 'AI Suggestion';

  @override
  String get checklistAllDone => 'All items completed!';

  @override
  String get checklistCollapseTooltip => 'Collapse';

  @override
  String checklistCompletedShort(int completed, int total) {
    return '$completed/$total done';
  }

  @override
  String get checklistDelete => 'Delete checklist?';

  @override
  String get checklistExpandTooltip => 'Expand';

  @override
  String get checklistExportAsMarkdown => 'Export checklist as Markdown';

  @override
  String get checklistExportFailed => 'Export failed';

  @override
  String get checklistItemArchiveUndo => 'Undo';

  @override
  String get checklistItemArchived => 'Item archived';

  @override
  String get checklistItemDeleteCancel => 'Cancel';

  @override
  String get checklistItemDeleteConfirm => 'Confirm';

  @override
  String get checklistItemDeleteWarning => 'This action cannot be undone.';

  @override
  String get checklistItemDeleted => 'Item deleted';

  @override
  String get checklistMarkdownCopied => 'Checklist copied as Markdown';

  @override
  String get checklistMoreTooltip => 'More';

  @override
  String get checklistNoneDone => 'No completed items yet.';

  @override
  String get checklistNothingToExport => 'No items to export';

  @override
  String get checklistProgressSemantics => 'Checklist progress';

  @override
  String get checklistShare => 'Share';

  @override
  String get checklistShareHint => 'Long press to share';

  @override
  String get checklistsReorder => 'Reorder';

  @override
  String get clearButton => 'Clear';

  @override
  String get colorLabel => 'Color';

  @override
  String get commonError => 'Error';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get completeHabitFailButton => 'Fail';

  @override
  String get completeHabitSkipButton => 'Skip';

  @override
  String get completeHabitSuccessButton => 'Success';

  @override
  String get configFlagAttemptEmbeddingDescription =>
      'When enabled, the app will attempt to generate embeddings for your entries to improve search and related content suggestions.';

  @override
  String get configFlagDailyOsNextEnabled => 'Use next-gen agentic DailyOS';

  @override
  String get configFlagDailyOsNextEnabledDescription =>
      'Replace the current DailyOS surface with the new voice-first, agent-led capture and reconcile flow. Early preview — backend logic is mocked.';

  @override
  String get configFlagEnableAiStreaming =>
      'Enable AI streaming for task actions';

  @override
  String get configFlagEnableAiStreamingDescription =>
      'Stream AI responses for task-related actions. Turn off to buffer responses and keep the UI smoother.';

  @override
  String get configFlagEnableAiSummaryTts => 'AI summary playback';

  @override
  String get configFlagEnableAiSummaryTtsDescription =>
      'Show the local text-to-speech button on task AI summaries. Requires an installed MLX Audio TTS model.';

  @override
  String get configFlagEnableDailyOs => 'Enable DailyOS';

  @override
  String get configFlagEnableDailyOsDescription =>
      'Show the DailyOS page in the main navigation.';

  @override
  String get configFlagEnableDashboardsPage => 'Enable Dashboards page';

  @override
  String get configFlagEnableDashboardsPageDescription =>
      'Show the Dashboards page in the main navigation. View your data and insights in customizable dashboards.';

  @override
  String get configFlagEnableEmbeddings => 'Generate Embeddings';

  @override
  String get configFlagEnableEvents => 'Enable Events';

  @override
  String get configFlagEnableEventsDescription =>
      'Show the Events feature to create, track, and manage events in your journal.';

  @override
  String get configFlagEnableForkHealing => 'Agent fork healing';

  @override
  String get configFlagEnableForkHealingDescription =>
      'Heal divergent agent histories from multi-device use by merging them at the next wake.';

  @override
  String get configFlagEnableHabitsPage => 'Enable Habits page';

  @override
  String get configFlagEnableHabitsPageDescription =>
      'Show the Habits page in the main navigation. Track and manage your daily habits here.';

  @override
  String get configFlagEnableLogging => 'Enable logging';

  @override
  String get configFlagEnableLoggingDescription =>
      'Enable detailed logging for debugging purposes. This may impact performance.';

  @override
  String get configFlagEnableMatrix => 'Enable Matrix sync';

  @override
  String get configFlagEnableMatrixDescription =>
      'Enable the Matrix integration to sync your entries across devices and with other Matrix users.';

  @override
  String get configFlagEnableNotifications => 'Enable notifications?';

  @override
  String get configFlagEnableNotificationsDescription =>
      'Receive notifications for reminders, updates, and important events.';

  @override
  String get configFlagEnableProjects => 'Enable Projects';

  @override
  String get configFlagEnableProjectsDescription =>
      'Show project management features for organizing tasks into projects.';

  @override
  String get configFlagEnableSessionRatings => 'Enable Session Ratings';

  @override
  String get configFlagEnableSessionRatingsDescription =>
      'Prompt for a quick session rating when you stop a timer.';

  @override
  String get configFlagEnableSyncedAlerts => 'Synced alerts';

  @override
  String get configFlagEnableSyncedAlertsDescription =>
      'Sync AI and task alerts across devices and allow them to schedule local OS notifications.';

  @override
  String get configFlagEnableTooltip => 'Enable tooltips';

  @override
  String get configFlagEnableTooltipDescription =>
      'Show helpful tooltips throughout the app to guide you through features.';

  @override
  String get configFlagEnableVectorSearch => 'Vector Search';

  @override
  String get configFlagEnableVectorSearchDescription =>
      'Enable vector search in task filters. Requires embeddings to be enabled and Ollama running.';

  @override
  String get configFlagEnableWhatsNew => 'Show What\'s New';

  @override
  String get configFlagEnableWhatsNewDescription =>
      'Highlight new features and changes inside the Settings tree.';

  @override
  String get configFlagPrivate => 'Show private entries?';

  @override
  String get configFlagPrivateDescription =>
      'Enable this to make your entries private by default. Private entries are only visible to you.';

  @override
  String get configFlagRecordLocation => 'Record location';

  @override
  String get configFlagRecordLocationDescription =>
      'Automatically record your location with new entries. This helps with location-based organization and search.';

  @override
  String get configFlagResendAttachments => 'Resend attachments';

  @override
  String get configFlagResendAttachmentsDescription =>
      'Enable this to automatically resend failed attachment uploads when the connection is restored.';

  @override
  String get configFlagShowSidebarWakeQueue => 'Show sidebar wake queue';

  @override
  String get configFlagShowSidebarWakeQueueDescription =>
      'Show the inline Wake Queue above Settings — header, the next two pending wakes with countdowns, and a link to the full list.';

  @override
  String get configFlagShowSyncActivityIndicator =>
      'Show sync activity indicator';

  @override
  String get configFlagShowSyncActivityIndicatorDescription =>
      'Show live sync activity in the sidebar — a tx/rx LED strip with outbox and inbox depth.';

  @override
  String get conflictApplyButton => 'Apply';

  @override
  String get conflictApplyFailedTitle => 'Couldn\'t apply resolution';

  @override
  String conflictBannerAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String conflictBannerAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count h ago',
      one: '1 h ago',
    );
    return '$_temp0';
  }

  @override
  String get conflictBannerAgoJustNow => 'just now';

  @override
  String conflictBannerAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min ago',
      one: '1 min ago',
    );
    return '$_temp0';
  }

  @override
  String conflictBannerDivergedAgo(String entity, String ago) {
    return '$entity · diverged $ago';
  }

  @override
  String conflictBannerFieldsDifferList(String fields) {
    return 'Differs in: $fields';
  }

  @override
  String get conflictDetailEntryNotFoundTitle => 'Entry not found';

  @override
  String get conflictDetailLoadErrorTitle => 'Couldn\'t load conflict';

  @override
  String get conflictDetailNotFoundTitle => 'Conflict not found';

  @override
  String get conflictFieldCategory => 'category';

  @override
  String get conflictFieldDuration => 'duration';

  @override
  String get conflictFieldTitle => 'Title';

  @override
  String get conflictFieldWordCount => 'word count';

  @override
  String get conflictFooterHelperLocalSelected =>
      'Will keep your local edit and discard the synced version.';

  @override
  String get conflictFooterHelperPickASide => 'Pick a side to apply.';

  @override
  String get conflictFooterHelperRemoteSelected =>
      'Will accept the synced version and discard your local edit.';

  @override
  String conflictHeaderPillEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
    );
    return '$_temp0';
  }

  @override
  String conflictHeaderPillFieldsDiffer(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fields differ',
      one: '1 field differs',
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
    return 'Conflict ID: $id';
  }

  @override
  String get conflictMetaLocalEdit => 'local edit';

  @override
  String get conflictMetaVecPrefix => 'vec';

  @override
  String get conflictMetaViaSync => 'via sync';

  @override
  String get conflictPageLeadDesktop =>
      'Differences highlighted inline. Click a side to use that version, or open Edit & merge to combine them.';

  @override
  String get conflictPageLeadMobile =>
      'Differences highlighted inline. Tap a side to use that version.';

  @override
  String get conflictPageTitle => 'Sync conflict';

  @override
  String get conflictPickerEditMerge => 'Edit & merge…';

  @override
  String get conflictPickerUseFromSync => 'Use from sync';

  @override
  String get conflictPickerUseThisDevice => 'Use this device';

  @override
  String get conflictSideFromSync => 'FROM SYNC';

  @override
  String get conflictSideThisDevice => 'THIS DEVICE';

  @override
  String conflictWordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words',
      one: '$count word',
    );
    return '$_temp0';
  }

  @override
  String get conflictsEmptyDescription =>
      'Everything is in sync right now. Resolved items stay available in the other filter.';

  @override
  String get conflictsEmptyTitle => 'No conflicts detected';

  @override
  String get conflictsResolved => 'resolved';

  @override
  String get conflictsUnresolved => 'unresolved';

  @override
  String get copyAsMarkdown => 'Copy as Markdown';

  @override
  String get copyAsText => 'Copy as text';

  @override
  String get correctionExampleCancel => 'CANCEL';

  @override
  String correctionExamplePending(int seconds) {
    return 'Saving correction in ${seconds}s...';
  }

  @override
  String get correctionExamplesEmpty =>
      'No corrections captured yet. Edit a checklist item to add your first example.';

  @override
  String get correctionExamplesSectionDescription =>
      'When you manually correct checklist items, those corrections are saved here and used to improve AI suggestions.';

  @override
  String get correctionExamplesSectionTitle => 'Checklist Correction Examples';

  @override
  String correctionExamplesWarning(int count, int max) {
    return 'You have $count corrections. Only the most recent $max will be used in AI prompts. Consider deleting old or redundant examples.';
  }

  @override
  String get coverArtChipActive => 'Cover';

  @override
  String get coverArtChipSet => 'Set cover';

  @override
  String get coverArtGenerationComplete => 'Cover art ready!';

  @override
  String get coverArtGenerationDismissHint =>
      'You can close this — generation continues in the background';

  @override
  String get createButton => 'Create';

  @override
  String get createCategoryTitle => 'Create category';

  @override
  String get createEntryLabel => 'Create new entry';

  @override
  String get createEntryTitle => 'Add';

  @override
  String get createNewLinkedTask => 'Create new linked task...';

  @override
  String get customColor => 'Custom Color';

  @override
  String get dailyOsActual => 'Actual';

  @override
  String get dailyOsAddBlock => 'Add Block';

  @override
  String get dailyOsAddBudget => 'Add Budget';

  @override
  String get dailyOsAddNote => 'Add a note...';

  @override
  String get dailyOsAgreeToPlan => 'Agree to Plan';

  @override
  String get dailyOsCancel => 'Cancel';

  @override
  String get dailyOsCategory => 'Category';

  @override
  String get dailyOsChooseCategory => 'Choose a category...';

  @override
  String get dailyOsDayPlan => 'Day Plan';

  @override
  String get dailyOsDaySummary => 'Day Summary';

  @override
  String get dailyOsDelete => 'Delete';

  @override
  String get dailyOsDeletePlannedBlock => 'Delete Block?';

  @override
  String get dailyOsDeletePlannedBlockConfirm =>
      'This will remove the planned block from your timeline.';

  @override
  String get dailyOsDraftMessage => 'Plan is in draft. Agree to lock it in.';

  @override
  String get dailyOsDueToday => 'Due today';

  @override
  String get dailyOsDueTodayShort => 'Due';

  @override
  String dailyOsDurationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
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
  String get dailyOsEditPlannedBlock => 'Edit Planned Block';

  @override
  String get dailyOsEndTime => 'End';

  @override
  String get dailyOsExpandToMove => 'Expand timeline to drag this block';

  @override
  String get dailyOsExpandToMoveMore => 'Expand timeline to move further';

  @override
  String get dailyOsFailedToLoadBudgets => 'Failed to load budgets';

  @override
  String get dailyOsFailedToLoadTimeline => 'Failed to load timeline';

  @override
  String get dailyOsFold => 'Fold';

  @override
  String get dailyOsInvalidTimeRange => 'Invalid time range';

  @override
  String get dailyOsNearLimit => 'Near limit';

  @override
  String get dailyOsNextAgendaCapacityComfortable => 'Comfortable';

  @override
  String get dailyOsNextAgendaCapacityNearFull => 'Near full';

  @override
  String get dailyOsNextAgendaCapacityNoPlan => 'No plan yet';

  @override
  String dailyOsNextAgendaCapacityOf(String capacity) {
    return 'of $capacity';
  }

  @override
  String get dailyOsNextAgendaCapacityOver => 'Over capacity';

  @override
  String get dailyOsNextAgendaDonutLeft => 'left';

  @override
  String get dailyOsNextAgendaDonutOver => 'over';

  @override
  String dailyOsNextAgendaHeadlineLeft(String duration) {
    return '$duration left';
  }

  @override
  String dailyOsNextAgendaHeadlineOver(String duration) {
    return '$duration over';
  }

  @override
  String get dailyOsNextAgendaNoPlanBody =>
      'Your tracked time is here either way — speak a check-in and I\'ll draft a day around it.';

  @override
  String dailyOsNextAgendaNoPlanSummary(String duration) {
    return '$duration tracked so far. Speak a check-in and I\'ll draft a day around it.';
  }

  @override
  String get dailyOsNextAgendaNoPlanTitle => 'No plan yet for today.';

  @override
  String get dailyOsNextAgendaStateDone => 'Done';

  @override
  String get dailyOsNextAgendaStateInProgress => 'In progress';

  @override
  String get dailyOsNextAgendaStateOpen => 'Open';

  @override
  String get dailyOsNextAgendaStateOverdue => 'Overdue';

  @override
  String dailyOsNextAgendaSummary(String scheduled, String capacity) {
    return '$scheduled of $capacity committed';
  }

  @override
  String dailyOsNextAgendaTrackedLegend(String duration, int completedCount) {
    return 'Tracked · $duration · $completedCount done';
  }

  @override
  String get dailyOsNextCaptureCaptured => 'Got it.';

  @override
  String get dailyOsNextCaptureDoneCta => 'Done';

  @override
  String get dailyOsNextCaptureErrorMicrophonePermissionDenied =>
      'Microphone permission was denied.';

  @override
  String get dailyOsNextCaptureErrorNoActiveRealtimeSession =>
      'No active realtime session.';

  @override
  String get dailyOsNextCaptureErrorNoAudioRecorded => 'No audio was recorded.';

  @override
  String get dailyOsNextCaptureErrorRealtimeTranscriptionFailed =>
      'Realtime transcription failed.';

  @override
  String get dailyOsNextCaptureErrorRealtimeTranscriptionStartFailed =>
      'Realtime transcription could not start.';

  @override
  String get dailyOsNextCaptureErrorRecordingStartFailed =>
      'Recording could not start.';

  @override
  String get dailyOsNextCaptureErrorTranscriptionFailed =>
      'Transcription failed.';

  @override
  String get dailyOsNextCaptureHeadlineCaptured => 'Does this look right?';

  @override
  String get dailyOsNextCaptureHeadlineLead => 'What’s on your mind';

  @override
  String get dailyOsNextCaptureHeadlineListening => 'I’m listening.';

  @override
  String get dailyOsNextCaptureHeadlineTail => 'for today?';

  @override
  String dailyOsNextCaptureHeadlineTailForDate(String date) {
    return 'for $date?';
  }

  @override
  String get dailyOsNextCaptureHeadlineTailTomorrow => 'for tomorrow?';

  @override
  String get dailyOsNextCaptureHeadlineTailYesterday => 'for yesterday?';

  @override
  String get dailyOsNextCaptureHeadlineTranscribing => 'Writing that down…';

  @override
  String get dailyOsNextCaptureIdleClick => 'Click to talk';

  @override
  String get dailyOsNextCaptureIdleExample =>
      '“Deep work this morning, a walk after lunch, emails before five.”';

  @override
  String get dailyOsNextCaptureIdleHint => 'Tap to talk · type instead';

  @override
  String get dailyOsNextCaptureIdleTalk => 'Tap to talk';

  @override
  String get dailyOsNextCaptureListeningStatus => 'Listening…';

  @override
  String dailyOsNextCapturePastPrompt(String date) {
    return 'Anything you still want to track from $date?';
  }

  @override
  String get dailyOsNextCaptureReconcileCta => 'Review';

  @override
  String get dailyOsNextCaptureTranscribing => 'Transcribing…';

  @override
  String get dailyOsNextCaptureTranscriptHint =>
      'Fix anything the transcript got wrong before planning.';

  @override
  String get dailyOsNextCaptureTranscriptLabel => 'Review transcript';

  @override
  String get dailyOsNextCaptureTypeInstead => 'Type instead';

  @override
  String get dailyOsNextCaptureVoiceButtonReset => 'Start over';

  @override
  String get dailyOsNextCaptureVoiceButtonStart => 'Start listening';

  @override
  String get dailyOsNextCaptureVoiceButtonStop => 'Stop listening';

  @override
  String get dailyOsNextCapturesPanelTitle => 'Captures';

  @override
  String get dailyOsNextCategoryFilterAll => 'All categories';

  @override
  String get dailyOsNextCategoryFilterDescription =>
      'Only categories enabled for day planning are surfaced for Daily OS automated processing.';

  @override
  String get dailyOsNextCategoryFilterEmpty =>
      'No categories enabled for day planning yet.';

  @override
  String get dailyOsNextCategoryFilterIncludeAll => 'Include all';

  @override
  String get dailyOsNextCategoryFilterTitle => 'Processing categories';

  @override
  String get dailyOsNextCategoryFilterTooltip =>
      'Choose Daily OS processing categories';

  @override
  String dailyOsNextCommitCapacityNote(String scheduled, String capacity) {
    return '$scheduled of $capacity committed. Comfortable margin — you can absorb one surprise.';
  }

  @override
  String get dailyOsNextCommitDraftOverline => 'YOUR DAY, DRAFTED';

  @override
  String get dailyOsNextCommitExplainer =>
      'Sign off to move today from draft to committed.';

  @override
  String get dailyOsNextCommitFinalStepEyebrow => 'FINAL STEP';

  @override
  String get dailyOsNextCommitHeadline => 'Make it yours.';

  @override
  String get dailyOsNextCommitHoldHelper => 'Hold for a second to sign off';

  @override
  String get dailyOsNextCommitHoldWordDone => 'Committed';

  @override
  String get dailyOsNextCommitHoldWordHolding => 'Keep holding';

  @override
  String get dailyOsNextCommitHoldWordIdle => 'Hold';

  @override
  String get dailyOsNextCommitLockingIn => 'Locking in…';

  @override
  String get dailyOsNextCommitShepherdSubline =>
      'I\'ll shepherd it — you do the work.';

  @override
  String get dailyOsNextCommitSubCaption =>
      'You can still talk to me afterward — but the bones stay put.';

  @override
  String get dailyOsNextCommitTitle => 'Lock it in';

  @override
  String get dailyOsNextCommitTodayIsYours => 'Today is yours.';

  @override
  String get dailyOsNextDayBack => 'Back';

  @override
  String get dailyOsNextDayCheckInCta => 'Speak a check-in';

  @override
  String get dailyOsNextDayDeleteDialogBody =>
      'The drafted blocks for this day will be removed. Captures and their audio recordings stay in your journal.';

  @override
  String get dailyOsNextDayDeleteDialogCancel => 'Cancel';

  @override
  String get dailyOsNextDayDeleteDialogConfirm => 'Delete';

  @override
  String get dailyOsNextDayDeleteDialogTitle => 'Delete this plan?';

  @override
  String get dailyOsNextDayLockInCta => 'Lock in';

  @override
  String get dailyOsNextDayMenuDeletePlan => 'Delete plan';

  @override
  String get dailyOsNextDayMenuInspectAgent => 'Inspect agent';

  @override
  String get dailyOsNextDayMoreTooltip => 'More';

  @override
  String get dailyOsNextDayRefineCta => 'Refine';

  @override
  String get dailyOsNextDayRefineFooterHint =>
      'Talk to reshape the plan — you\'ll see every change before anything is saved.';

  @override
  String get dailyOsNextDayTitle => 'Your day';

  @override
  String get dailyOsNextDayWhyChipLabel => 'WHY';

  @override
  String get dailyOsNextDayWrapUpCta => 'Wrap up';

  @override
  String get dailyOsNextDraftingHeader => 'Drafting your day…';

  @override
  String get dailyOsNextDraftingNudgeAccept => 'Yes, protect mornings';

  @override
  String get dailyOsNextDraftingNudgeDecline => 'Not today';

  @override
  String get dailyOsNextDraftingReasoningOverline => '✦ REASONING';

  @override
  String get dailyOsNextDraftingStatusAfternoon => 'Sequencing the afternoon…';

  @override
  String get dailyOsNextDraftingStatusAlmost => 'Almost there…';

  @override
  String get dailyOsNextDraftingStatusBreathing => 'Leaving room to breathe…';

  @override
  String get dailyOsNextDraftingStatusDeepWork => 'Placing deep work first…';

  @override
  String get dailyOsNextDraftingStatusMatching => 'Matching tasks to your day…';

  @override
  String get dailyOsNextDraftingStatusReading => 'Reading your check-in…';

  @override
  String get dailyOsNextDraftingStatusTimings => 'Double-checking timings…';

  @override
  String get dailyOsNextDraftingStatusYesterday =>
      'Looking at yesterday\'s rhythm…';

  @override
  String get dailyOsNextEditTitleHint => 'Edit title';

  @override
  String get dailyOsNextGenericError =>
      'Something went wrong. Try again in a moment.';

  @override
  String get dailyOsNextGreetingAfternoon => 'Good afternoon.';

  @override
  String get dailyOsNextGreetingEvening => 'Good evening.';

  @override
  String dailyOsNextGreetingHiName(String name) {
    return 'Hi $name 👋';
  }

  @override
  String get dailyOsNextGreetingMorning => 'Good morning.';

  @override
  String get dailyOsNextKnowledgeConfirm => 'Confirm';

  @override
  String get dailyOsNextKnowledgeConfirmedHeader => 'Confirmed';

  @override
  String get dailyOsNextKnowledgeEdit => 'Edit';

  @override
  String get dailyOsNextKnowledgeEditCancel => 'Cancel';

  @override
  String get dailyOsNextKnowledgeEditHookHint => 'One-line summary';

  @override
  String get dailyOsNextKnowledgeEditSave => 'Save';

  @override
  String get dailyOsNextKnowledgeEditStatementHint => 'What should I remember?';

  @override
  String get dailyOsNextKnowledgeEmpty =>
      'Nothing yet — I\'ll remember what you tell me.';

  @override
  String dailyOsNextKnowledgeNudge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count things I noticed — review',
      one: '1 thing I noticed — review',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextKnowledgeProposedHeader => 'Awaiting your confirmation';

  @override
  String get dailyOsNextKnowledgeRetract => 'Forget';

  @override
  String get dailyOsNextKnowledgeStale => 'Still true?';

  @override
  String get dailyOsNextKnowledgeTitle => 'What I\'ve learned';

  @override
  String get dailyOsNextParsedCardBreakLinkTooltip => 'Break link';

  @override
  String get dailyOsNextPlanViewAgenda => 'Agenda';

  @override
  String get dailyOsNextPlanViewDay => 'Day';

  @override
  String get dailyOsNextReconcileBadgeMatched => 'MATCHED';

  @override
  String get dailyOsNextReconcileBadgeNew => 'NEW';

  @override
  String get dailyOsNextReconcileBadgeUpdate => 'UPDATE';

  @override
  String get dailyOsNextReconcileBuildDayCta => 'Build my day';

  @override
  String get dailyOsNextReconcileDecideOverline => 'WORTH DECIDING ON';

  @override
  String get dailyOsNextReconcileDefaultBehaviorHint =>
      'Decisions here feed into the plan — no decision means \"leave it where it is.\"';

  @override
  String dailyOsNextReconcileError(String detail) {
    return 'Something went wrong: $detail';
  }

  @override
  String get dailyOsNextReconcileHeadline => 'Here’s what I heard.';

  @override
  String get dailyOsNextReconcileHeardEmpty =>
      'Capture cards will appear here once parsing finishes.';

  @override
  String get dailyOsNextReconcileHeardOverline => 'HEARD';

  @override
  String get dailyOsNextReconcileLowConfidence => 'low confidence';

  @override
  String get dailyOsNextReconcileReRecord => 'Re-record';

  @override
  String get dailyOsNextReconcileVoiceHint =>
      'Review decisions before building your day';

  @override
  String get dailyOsNextRefineAccept => 'Accept';

  @override
  String get dailyOsNextRefineCurrentPlan => 'CURRENT PLAN';

  @override
  String get dailyOsNextRefineDiffAdded => 'ADDED';

  @override
  String get dailyOsNextRefineDiffDropped => 'DROPPED';

  @override
  String get dailyOsNextRefineDiffMoved => 'MOVED';

  @override
  String get dailyOsNextRefineHeadlineDiffReady => 'Here’s what I’d change.';

  @override
  String get dailyOsNextRefineHeadlineIdle => 'What should change?';

  @override
  String get dailyOsNextRefineHeadlineThinking => 'Reworking your plan…';

  @override
  String get dailyOsNextRefineKeepTalking => 'Keep talking';

  @override
  String get dailyOsNextRefineLooksGood => 'Looks good';

  @override
  String get dailyOsNextRefineNoChanges =>
      'No plan changes came back. Reword it and try again.';

  @override
  String get dailyOsNextRefineOverline => '🎤 REFINEMENT';

  @override
  String get dailyOsNextRefineRevert => 'Revert';

  @override
  String get dailyOsNextRefineStatusAccepted => 'Locked in.';

  @override
  String get dailyOsNextRefineStatusDiffReady => 'Here\'s what changed.';

  @override
  String get dailyOsNextRefineStatusIdle => 'Tap to talk.';

  @override
  String get dailyOsNextRefineStatusListening => 'Listening…';

  @override
  String get dailyOsNextRefineStatusThinking => '✦ Reworking the plan…';

  @override
  String get dailyOsNextRefineTitle => 'Refine the plan';

  @override
  String get dailyOsNextRenameFailed => 'Couldn\'t rename — try again.';

  @override
  String get dailyOsNextShutdownCarryoverDrop => 'Drop';

  @override
  String get dailyOsNextShutdownCarryoverDropped => 'Dropped';

  @override
  String get dailyOsNextShutdownCarryoverOverline => 'CARRIES FORWARD';

  @override
  String get dailyOsNextShutdownCarryoverPickDate => 'Pick a date';

  @override
  String get dailyOsNextShutdownCarryoverScheduled => 'Scheduled';

  @override
  String get dailyOsNextShutdownCloseDay => 'Close the day';

  @override
  String get dailyOsNextShutdownCompletedOverline => 'WHAT YOU DID';

  @override
  String get dailyOsNextShutdownMetricEnergy => 'ENERGY';

  @override
  String dailyOsNextShutdownMetricEnergyDelta(String delta) {
    return '$delta vs. week';
  }

  @override
  String get dailyOsNextShutdownMetricFlow => 'FLOW SESSIONS';

  @override
  String get dailyOsNextShutdownMetricFocus => 'FOCUS TIME';

  @override
  String get dailyOsNextShutdownMetricSwitches => 'CONTEXT SWITCHES';

  @override
  String dailyOsNextShutdownMetricSwitchesAvg(String avg) {
    return 'avg $avg this week';
  }

  @override
  String get dailyOsNextShutdownReflectionOverline => '💬 ONE-LINE REFLECTION';

  @override
  String get dailyOsNextShutdownReflectionPlaceholder =>
      'e.g., morning was sharp, afternoon dragged after coffee with Sarah ran long.';

  @override
  String get dailyOsNextShutdownReflectionPrompt =>
      'How did today land? (This feeds tomorrow\'s draft.)';

  @override
  String get dailyOsNextShutdownReflectionSpeak => 'Speak it';

  @override
  String get dailyOsNextShutdownReflectionSubmit => 'Skip';

  @override
  String get dailyOsNextShutdownReflectionThanks =>
      'Got it — feeding tomorrow.';

  @override
  String get dailyOsNextShutdownSaveAndClose => 'Save & close';

  @override
  String get dailyOsNextShutdownTitle => 'Close out the day';

  @override
  String get dailyOsNextShutdownTomorrowOverline => '✦ FOR TOMORROW';

  @override
  String dailyOsNextStateDueOnDate(String date) {
    return 'Due $date';
  }

  @override
  String get dailyOsNextStateDueToday => 'Due today';

  @override
  String dailyOsNextStateInProgress(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In progress · $count sessions',
      one: 'In progress · 1 session',
      zero: 'In progress',
    );
    return '$_temp0';
  }

  @override
  String dailyOsNextStateOverdue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Overdue · $days days',
      one: 'Overdue · 1 day',
      zero: 'Overdue',
    );
    return '$_temp0';
  }

  @override
  String dailyOsNextStateOverdueOnDate(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Overdue by $days days on $date',
      one: 'Overdue by 1 day on $date',
      zero: 'Overdue on $date',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextStateRecurringMissed => 'Recurring · missed';

  @override
  String dailyOsNextTimeSpentEarlierSessions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count earlier sessions',
      one: '1 earlier session',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextTimeSpentShowLess => 'Show less';

  @override
  String dailyOsNextTimeSpentSummary(String duration, int completedCount) {
    return '$duration · $completedCount done';
  }

  @override
  String get dailyOsNextTimeSpentTitle => 'TODAY SO FAR';

  @override
  String get dailyOsNextTimeSpentTitlePast => 'TIME SPENT';

  @override
  String get dailyOsNextTimelineActual => 'Actual';

  @override
  String get dailyOsNextTimelineBoth => 'Plan and actual';

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
    return 'Session $index of $total';
  }

  @override
  String get dailyOsNextTimelineShowBoth => 'Show plan and actual together';

  @override
  String get dailyOsNextTimelineShowPaged => 'Show swipeable plan and actual';

  @override
  String get dailyOsNextTimelineSwipeHint =>
      'Swipe for actual · pinch vertically to zoom';

  @override
  String get dailyOsNextTimelineTracked => 'tracked';

  @override
  String get dailyOsNextTriageConfirmDefer => 'Deferred';

  @override
  String get dailyOsNextTriageConfirmDoNow => 'Done now';

  @override
  String get dailyOsNextTriageConfirmDone => 'Marked done';

  @override
  String get dailyOsNextTriageConfirmDrop => 'Dropped';

  @override
  String get dailyOsNextTriageConfirmToday => 'Added to today';

  @override
  String get dailyOsNextTriageDefer => 'Defer';

  @override
  String get dailyOsNextTriageDoNow => 'Do now';

  @override
  String get dailyOsNextTriageDone => 'Done';

  @override
  String get dailyOsNextTriageDrop => 'Drop';

  @override
  String get dailyOsNextTriageToday => 'Today';

  @override
  String get dailyOsNoBudgetWarning => 'No time budgeted';

  @override
  String get dailyOsNoBudgets => 'No time budgets';

  @override
  String get dailyOsNoBudgetsHint =>
      'Add budgets to track how you spend your time across categories.';

  @override
  String get dailyOsNoTimeline => 'No timeline entries';

  @override
  String get dailyOsNoTimelineHint =>
      'Start a timer or add planned blocks to see your day.';

  @override
  String get dailyOsNote => 'Note';

  @override
  String get dailyOsOnTrack => 'On track';

  @override
  String get dailyOsOver => 'Over';

  @override
  String get dailyOsOverBudget => 'Over budget';

  @override
  String get dailyOsOverallProgress => 'Overall Progress';

  @override
  String get dailyOsOverdue => 'Overdue';

  @override
  String get dailyOsOverdueShort => 'Late';

  @override
  String get dailyOsPlan => 'Plan';

  @override
  String get dailyOsPlanCreated => 'Plan created successfully';

  @override
  String get dailyOsPlanCreatedDescription =>
      'Your time blocks have been saved. You can start tracking your tasks.';

  @override
  String get dailyOsPlanWithoutVoice => 'Plan without voice';

  @override
  String get dailyOsPlanned => 'Planned';

  @override
  String get dailyOsQuickCreateTask => 'Create task for this budget';

  @override
  String get dailyOsReAgree => 'Re-agree';

  @override
  String get dailyOsRecorded => 'Recorded';

  @override
  String get dailyOsRemaining => 'Remaining';

  @override
  String get dailyOsReviewMessage => 'Changes detected. Review your plan.';

  @override
  String get dailyOsSave => 'Save';

  @override
  String get dailyOsSaveError => 'Could not save plan';

  @override
  String get dailyOsSaveErrorDescription =>
      'Something went wrong. Please try again.';

  @override
  String get dailyOsSavePlan => 'Save plan';

  @override
  String get dailyOsSelectCategory => 'Select Category';

  @override
  String get dailyOsSetTimeBlocks => 'Set time blocks';

  @override
  String get dailyOsSetTimeBlocksAddNew => 'Add new time block';

  @override
  String get dailyOsSetTimeBlocksFavourites => 'Favourites';

  @override
  String get dailyOsSetTimeBlocksOther => 'Other categories';

  @override
  String get dailyOsSetTimeBlocksTapHint => 'Tap to add time block';

  @override
  String get dailyOsStartTime => 'Start';

  @override
  String get dailyOsTasks => 'Tasks';

  @override
  String get dailyOsTimeBudgets => 'Time Budgets';

  @override
  String dailyOsTimeLeft(String time) {
    return '$time left';
  }

  @override
  String dailyOsTimeOver(String time) {
    return '+$time over';
  }

  @override
  String get dailyOsTimeRange => 'Time Range';

  @override
  String get dailyOsTimeline => 'Timeline';

  @override
  String get dailyOsTimesUp => 'Time\'s up';

  @override
  String get dailyOsTodayButton => 'Today';

  @override
  String get dailyOsUncategorized => 'Uncategorized';

  @override
  String get dashboardActiveLabel => 'Active';

  @override
  String get dashboardAddChartsTitle => 'Charts';

  @override
  String get dashboardAddHabitButton => 'Habit Charts';

  @override
  String get dashboardAddHabitTitle => 'Habit Charts';

  @override
  String get dashboardAddHealthButton => 'Health Charts';

  @override
  String get dashboardAddHealthTitle => 'Health Charts';

  @override
  String get dashboardAddMeasurementButton => 'Measurement Charts';

  @override
  String get dashboardAddMeasurementTitle => 'Measurement Charts';

  @override
  String get dashboardAddSurveyButton => 'Survey Charts';

  @override
  String get dashboardAddSurveyTitle => 'Survey Charts';

  @override
  String get dashboardAddWorkoutButton => 'Workout Charts';

  @override
  String get dashboardAddWorkoutTitle => 'Workout Charts';

  @override
  String get dashboardAggregationLabel => 'Aggregation Type:';

  @override
  String get dashboardCategoryLabel => 'Category';

  @override
  String get dashboardCopyHint => 'Save & Copy dashboard config';

  @override
  String get dashboardDeleteConfirm => 'YES, DELETE THIS DASHBOARD';

  @override
  String get dashboardDeleteHint => 'Delete dashboard';

  @override
  String get dashboardDeleteQuestion => 'Do you want to delete this dashboard?';

  @override
  String get dashboardDescriptionLabel => 'Description (optional)';

  @override
  String get dashboardNameLabel => 'Dashboard name';

  @override
  String get dashboardNotFound => 'Dashboard not found';

  @override
  String get dashboardPrivateLabel => 'Private';

  @override
  String get defaultLanguage => 'Default Language';

  @override
  String get deleteButton => 'Delete';

  @override
  String get deleteDeviceLabel => 'Delete device';

  @override
  String get designSystemActionVariantTitle => 'With Action';

  @override
  String get designSystemActivatedLabel => 'Activated';

  @override
  String get designSystemAvatarAwayLabel => 'Away';

  @override
  String get designSystemAvatarBusyLabel => 'Busy';

  @override
  String get designSystemAvatarConnectedLabel => 'Connected';

  @override
  String get designSystemAvatarEnabledLabel => 'Enabled';

  @override
  String get designSystemAvatarSizeMatrixTitle => 'Size Matrix';

  @override
  String get designSystemAvatarStatusMatrixTitle => 'Status Matrix';

  @override
  String get designSystemBackLabel => 'Back';

  @override
  String get designSystemBreadcrumbCurrentLabel => 'Breadcrumbs';

  @override
  String get designSystemBreadcrumbDesignSystemLabel => 'Design System';

  @override
  String get designSystemBreadcrumbHomeLabel => 'Home';

  @override
  String get designSystemBreadcrumbMobileLabel => 'Mobile';

  @override
  String get designSystemBreadcrumbProjectsLabel => 'Projects';

  @override
  String get designSystemBreadcrumbSampleLabel => 'Breadcrumb';

  @override
  String get designSystemBreadcrumbTrailTitle => 'Breadcrumb Trail';

  @override
  String get designSystemCalendarPickerLabel => 'Calendar Picker';

  @override
  String get designSystemCalendarViewsTitle => 'Calendar Views';

  @override
  String get designSystemCaptionDescriptionSample =>
      'Removing all users unpublished this project. Add users to publish it again.';

  @override
  String get designSystemCaptionIconLeftLabel => 'Left icon';

  @override
  String get designSystemCaptionIconTopLabel => 'Top icon';

  @override
  String get designSystemCaptionNoIconLabel => 'No icon';

  @override
  String get designSystemCaptionTitleSample => 'Caption title';

  @override
  String get designSystemCaptionVariantsTitle => 'Caption Variants';

  @override
  String get designSystemCaptionWithActionsLabel => 'With actions';

  @override
  String get designSystemCaptionWithoutActionsLabel => 'Without actions';

  @override
  String get designSystemCheckboxLabel => 'Checkbox';

  @override
  String get designSystemContextMenuDeleteLabel => 'Delete';

  @override
  String get designSystemContextMenuVariantsTitle => 'Context Menu Variants';

  @override
  String get designSystemCountdownVariantTitle => 'With Countdown';

  @override
  String get designSystemDateCardsTitle => 'Date Cards';

  @override
  String get designSystemDefaultLabel => 'Default';

  @override
  String get designSystemDisabledLabel => 'Disabled';

  @override
  String get designSystemDividerLabelText => 'Divider label';

  @override
  String get designSystemDropdownComboboxTitle => 'Combobox';

  @override
  String get designSystemDropdownFieldLabel => 'Label';

  @override
  String get designSystemDropdownInputLabel => 'Input';

  @override
  String get designSystemDropdownListTitle => 'Dropdown list';

  @override
  String get designSystemDropdownMultiselectInputLabel => 'Select teams';

  @override
  String get designSystemDropdownMultiselectTitle => 'Multiselect';

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
  String get designSystemErrorLabel => 'Error';

  @override
  String get designSystemFileUploadClickLabel => 'Click to upload';

  @override
  String get designSystemFileUploadCompleteLabel => 'Complete';

  @override
  String get designSystemFileUploadDefaultLabel => 'Default';

  @override
  String get designSystemFileUploadDragLabel => 'or drag and drop';

  @override
  String get designSystemFileUploadDropZoneSectionTitle => 'Drop Zone';

  @override
  String get designSystemFileUploadErrorLabel => 'Error';

  @override
  String get designSystemFileUploadFailedText => 'Upload failed';

  @override
  String get designSystemFileUploadHintText =>
      'SVG, PNG, JPG or GIF (max. 800×400px)';

  @override
  String get designSystemFileUploadHoverLabel => 'Hover';

  @override
  String get designSystemFileUploadItemSectionTitle => 'File Items';

  @override
  String get designSystemFileUploadRetryLabel => 'Retry';

  @override
  String get designSystemFileUploadUploadingLabel => 'Uploading';

  @override
  String get designSystemFilledLabel => 'Filled';

  @override
  String get designSystemHeaderApiDocumentationLabel => 'API Documentation';

  @override
  String get designSystemHeaderBackActionLabel => 'Back';

  @override
  String get designSystemHeaderDesktopSectionTitle => 'Desktop';

  @override
  String get designSystemHeaderHelpActionLabel => 'Help';

  @override
  String get designSystemHeaderMobileSectionTitle => 'Mobile';

  @override
  String get designSystemHeaderNotificationsActionLabel => 'Notifications';

  @override
  String get designSystemHeaderSearchActionLabel => 'Search';

  @override
  String get designSystemHorizontalLabel => 'Horizontal';

  @override
  String get designSystemHoverLabel => 'Hover';

  @override
  String get designSystemInfoLabel => 'Info';

  @override
  String get designSystemInputErrorSample => 'This field is required';

  @override
  String get designSystemInputHelperSample => 'Enter your name';

  @override
  String get designSystemInputHintSample => 'Placeholder...';

  @override
  String get designSystemInputLabelSample => 'Label';

  @override
  String get designSystemInputVariantsTitle => 'Input Variants';

  @override
  String get designSystemInputWithErrorLabel => 'With error';

  @override
  String get designSystemInputWithHelperLabel => 'With helper text';

  @override
  String get designSystemInputWithIconsLabel => 'With icons';

  @override
  String get designSystemListItemActivatedLabel => 'Activated';

  @override
  String get designSystemListItemOneLineLabel => 'One line';

  @override
  String get designSystemListItemSubtitleSample => 'Subtitle';

  @override
  String get designSystemListItemTitleSample => 'Title';

  @override
  String get designSystemListItemTwoLinesLabel => 'Two lines';

  @override
  String get designSystemListItemVariantsTitle => 'List Item Variants';

  @override
  String get designSystemListItemWithDividerLabel => 'With divider';

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
  String get designSystemMyDailyEditPlanLabel => 'Edit plan';

  @override
  String get designSystemMyDailyGreetingMorning => 'Good morning.';

  @override
  String designSystemMyDailyGreetingWithName(String name) {
    return 'Hi, $name';
  }

  @override
  String get designSystemMyDailyHikeWithDanielaTitle => 'Hiking with Daniela';

  @override
  String get designSystemMyDailyLunchBreakTitle => 'Lunch break';

  @override
  String get designSystemMyDailyMeetingWithDannyTitle => 'Meeting with Danny';

  @override
  String get designSystemMyDailyMeetingsLabel => 'Meetings';

  @override
  String get designSystemMyDailyProfileActionLabel => 'Profile';

  @override
  String get designSystemMyDailySkiWithMattTitle => 'Go skiing with Matt';

  @override
  String get designSystemMyDailyTapToExpandLabel => 'Tap to expand';

  @override
  String get designSystemNavigationCollapsedLabel => 'Collapsed';

  @override
  String get designSystemNavigationDailyFilterSectionTitle => 'Daily Filter';

  @override
  String get designSystemNavigationExpandedLabel => 'Expanded';

  @override
  String get designSystemNavigationFilterByBlockLabel => 'Filter by block';

  @override
  String get designSystemNavigationHikingLabel => 'Hiking';

  @override
  String get designSystemNavigationHolidayLabel => 'Holiday';

  @override
  String get designSystemNavigationInsightsLabel => 'Insights';

  @override
  String get designSystemNavigationLottiTasksLabel => 'Lotti Tasks';

  @override
  String get designSystemNavigationMyDailyLabel => 'My Daily';

  @override
  String get designSystemNavigationNewLabel => 'New';

  @override
  String get designSystemNavigationPlaceholderLabel => 'Placeholder';

  @override
  String get designSystemNavigationSidebarSectionTitle => 'Sidebar Variants';

  @override
  String get designSystemNavigationSubComponentsSectionTitle =>
      'Sub-components';

  @override
  String get designSystemNavigationTabBarSectionTitle => 'Tab Bar Variants';

  @override
  String get designSystemPressedLabel => 'Pressed';

  @override
  String get designSystemProgressBarChunkyLabel => 'Chunky';

  @override
  String get designSystemProgressBarLabelAndPercentageLabel =>
      'Label + Percentage';

  @override
  String get designSystemProgressBarLabelOnlyLabel => 'Label only';

  @override
  String get designSystemProgressBarOffLabel => 'Off';

  @override
  String get designSystemProgressBarPercentageOnlyLabel => 'Percentage';

  @override
  String get designSystemProgressBarQuestBarLabel => 'Quest bar';

  @override
  String get designSystemProgressBarQuestLabel => 'Mega prize label';

  @override
  String get designSystemProgressBarSampleLabel => 'Progress bar label';

  @override
  String get designSystemRadioButtonLabel => 'Radio button';

  @override
  String get designSystemScrollbarSizesTitle => 'Scrollbar Sizes';

  @override
  String get designSystemSearchFilledText => 'Lotti search';

  @override
  String get designSystemSearchHintLabel => 'Type user';

  @override
  String get designSystemSelectedLabel => 'Selected';

  @override
  String get designSystemSizeScaleTitle => 'Size Scale';

  @override
  String get designSystemSmallLabel => 'Small';

  @override
  String get designSystemSpinnerPlainLabel => 'Plain';

  @override
  String get designSystemSpinnerSkeletonPulseLabel => 'Pulse';

  @override
  String get designSystemSpinnerSkeletonWaveLabel => 'Wave';

  @override
  String get designSystemSpinnerSkeletonsTitle => 'Skeletons';

  @override
  String get designSystemSpinnerSpinnersTitle => 'Spinners';

  @override
  String get designSystemSpinnerTrackLabel => 'With track';

  @override
  String designSystemSplitButtonDropdownSemantics(String label) {
    return 'Open $label options';
  }

  @override
  String get designSystemStateMatrixTitle => 'State Matrix';

  @override
  String get designSystemSuccessLabel => 'Success';

  @override
  String get designSystemTabBarTitle => 'Tab Bar';

  @override
  String get designSystemTabPendingLabel => 'Pending';

  @override
  String get designSystemTaskListBlockedLabel => 'Blocked';

  @override
  String get designSystemTaskListDefaultLabel => 'Default';

  @override
  String get designSystemTaskListHoverLabel => 'Hover';

  @override
  String get designSystemTaskListItemSectionTitle => 'Task List Item Variants';

  @override
  String get designSystemTaskListOnHoldLabel => 'On Hold';

  @override
  String get designSystemTaskListOpenLabel => 'Open';

  @override
  String get designSystemTaskListPressedLabel => 'Pressed';

  @override
  String get designSystemTaskListSampleTime => '8:00-9:30am';

  @override
  String get designSystemTaskListSampleTitle => 'User Testing';

  @override
  String get designSystemTaskListWithDividerLabel => 'With divider';

  @override
  String get designSystemTextareaErrorSample => 'This field is required';

  @override
  String get designSystemTextareaHelperSample => 'Enter your message here';

  @override
  String get designSystemTextareaHintSample => 'Type something...';

  @override
  String get designSystemTextareaLabelSample => 'Label';

  @override
  String get designSystemTextareaVariantsTitle => 'Textarea Variants';

  @override
  String get designSystemTextareaWithCounterLabel => 'With counter';

  @override
  String get designSystemTextareaWithErrorLabel => 'With error';

  @override
  String get designSystemTextareaWithHelperLabel => 'With helper text';

  @override
  String get designSystemTimePickerFormatsTitle => 'Time Formats';

  @override
  String get designSystemTimePickerTwelveHourLabel => '12-hour';

  @override
  String get designSystemTimePickerTwentyFourHourLabel => '24-hour';

  @override
  String get designSystemTitleOnlyVariantTitle => 'Title Only Variant';

  @override
  String get designSystemToastDetailsLabel => 'Notification details';

  @override
  String get designSystemToggleLabel => 'Toggle label';

  @override
  String get designSystemTooltipIconMessageSample =>
      'Helpful information about this field';

  @override
  String get designSystemTooltipIconVariantsTitle => 'Tooltip Icon';

  @override
  String get designSystemUndoLabel => 'Undo';

  @override
  String get designSystemVariantMatrixTitle => 'Variant Matrix';

  @override
  String get designSystemVerticalLabel => 'Vertical';

  @override
  String get designSystemWarningLabel => 'Warning';

  @override
  String get designSystemWeeklyCalendarLabel => 'Weekly Calendar';

  @override
  String get designSystemWithLabelLabel => 'With label';

  @override
  String get desktopEmptyStateSelectDashboard =>
      'Select a dashboard to view details';

  @override
  String get desktopEmptyStateSelectProject =>
      'Select a project to view details';

  @override
  String get desktopEmptyStateSelectTask => 'Select a task to view details';

  @override
  String deviceDeleteFailed(String error) {
    return 'Failed to delete device: $error';
  }

  @override
  String deviceDeletedSuccess(String deviceName) {
    return 'Device $deviceName deleted successfully';
  }

  @override
  String get doneButton => 'Done';

  @override
  String get editMenuTitle => 'Edit';

  @override
  String get editorInsertDivider => 'Insert divider';

  @override
  String get editorPlaceholder => 'Enter notes...';

  @override
  String get embeddingSelectAll => 'Select All';

  @override
  String get embeddingUnselectAll => 'Deselect All';

  @override
  String get enhancedPromptFormPreconfiguredPromptDescription =>
      'Choose from ready-made prompt templates';

  @override
  String get enterCategoryName => 'Enter category name';

  @override
  String get entryActions => 'Actions';

  @override
  String get entryLabelsActionSubtitle =>
      'Assign labels to organize this entry';

  @override
  String get entryLabelsActionTitle => 'Labels';

  @override
  String get entryLabelsEditTooltip => 'Edit labels';

  @override
  String get entryLabelsHeaderTitle => 'Labels';

  @override
  String get entryLabelsNoLabels => 'No labels assigned';

  @override
  String get entryTypeLabelAiResponse => 'AI Response';

  @override
  String get entryTypeLabelChecklist => 'Checklist';

  @override
  String get entryTypeLabelChecklistItem => 'To Do';

  @override
  String get entryTypeLabelHabitCompletionEntry => 'Habit';

  @override
  String get entryTypeLabelJournalAudio => 'Audio';

  @override
  String get entryTypeLabelJournalEntry => 'Text';

  @override
  String get entryTypeLabelJournalEvent => 'Event';

  @override
  String get entryTypeLabelJournalImage => 'Photo';

  @override
  String get entryTypeLabelMeasurementEntry => 'Measured';

  @override
  String get entryTypeLabelQuantitativeEntry => 'Health';

  @override
  String get entryTypeLabelSurveyEntry => 'Survey';

  @override
  String get entryTypeLabelTask => 'Task';

  @override
  String get entryTypeLabelWorkoutEntry => 'Workout';

  @override
  String get eventNameLabel => 'Event:';

  @override
  String get favoriteLabel => 'Favorite';

  @override
  String get fileMenuNewEllipsis => 'New ...';

  @override
  String get fileMenuNewEntry => 'New Entry';

  @override
  String get fileMenuNewScreenshot => 'Screenshot';

  @override
  String get fileMenuNewTask => 'Task';

  @override
  String get fileMenuTitle => 'File';

  @override
  String get filterSelectionNoMatches => 'No matches';

  @override
  String get geminiThinkingModeHighDescription =>
      'Deepest reasoning; can increase latency and cost.';

  @override
  String get geminiThinkingModeHighLabel => 'High';

  @override
  String get geminiThinkingModeLowDescription =>
      'Low reasoning for fast everyday prompts.';

  @override
  String get geminiThinkingModeLowLabel => 'Low';

  @override
  String get geminiThinkingModeMediumDescription =>
      'Balanced reasoning for more careful answers.';

  @override
  String get geminiThinkingModeMediumLabel => 'Medium';

  @override
  String get geminiThinkingModeMinimalDescription =>
      'Fastest setting; Gemini may still think briefly on complex prompts.';

  @override
  String get geminiThinkingModeMinimalLabel => 'Minimal';

  @override
  String get generateCoverArt => 'Generate Cover Art';

  @override
  String get generateCoverArtSubtitle => 'Create image from voice description';

  @override
  String get habitActiveFromLabel => 'Start date';

  @override
  String get habitArchivedLabel => 'Archived';

  @override
  String get habitCategoryHint => 'Select category';

  @override
  String get habitCategoryLabel => 'Category';

  @override
  String get habitDashboardHint => 'Select dashboard';

  @override
  String get habitDashboardLabel => 'Dashboard';

  @override
  String get habitDeleteConfirm => 'YES, DELETE THIS HABIT';

  @override
  String get habitDeleteQuestion => 'Do you want to delete this habit?';

  @override
  String get habitPriorityLabel => 'Priority';

  @override
  String get habitSectionOptionsTitle => 'Options';

  @override
  String get habitSectionScheduleTitle => 'Schedule';

  @override
  String get habitShowAlertAtLabel => 'Show alert at';

  @override
  String get habitShowFromLabel => 'Show from';

  @override
  String get habitsCompletedHeader => 'Completed';

  @override
  String get habitsFilterAll => 'all';

  @override
  String get habitsFilterCompleted => 'done';

  @override
  String get habitsFilterOpenNow => 'due';

  @override
  String get habitsFilterPendingLater => 'later';

  @override
  String get habitsOpenHeader => 'Due now';

  @override
  String get habitsPendingLaterHeader => 'Later today';

  @override
  String get imageGenerationError => 'Failed to generate image';

  @override
  String get imageGenerationGenerating => 'Generating image...';

  @override
  String imageGenerationWithReferences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Using $count reference images',
      one: 'Using 1 reference image',
      zero: 'No reference images',
    );
    return '$_temp0';
  }

  @override
  String get imagePromptGenerationCardTitle => 'AI Image Prompt';

  @override
  String get imagePromptGenerationCopiedSnackbar =>
      'Image prompt copied to clipboard';

  @override
  String get imagePromptGenerationCopyButton => 'Copy Prompt';

  @override
  String get imagePromptGenerationCopyTooltip =>
      'Copy image prompt to clipboard';

  @override
  String get imagePromptGenerationExpandTooltip => 'Show full prompt';

  @override
  String get imagePromptGenerationFullPromptLabel => 'Full Image Prompt:';

  @override
  String get images => 'Images';

  @override
  String get inactiveLabel => 'Inactive';

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
    return 'Could not load profile: $error';
  }

  @override
  String get inferenceProfileDetailNotFound => 'Profile not found';

  @override
  String get inferenceProfileEditTitle => 'Edit Profile';

  @override
  String get inferenceProfileImageGeneration => 'Image Generation';

  @override
  String get inferenceProfileImageRecognition => 'Image Recognition';

  @override
  String get inferenceProfileNameLabel => 'Profile Name';

  @override
  String get inferenceProfileNameRequired => 'A profile name is required';

  @override
  String get inferenceProfilePinnedHostHelper =>
      'When set, only this device auto-runs inference for synced audio entries that use this profile.';

  @override
  String get inferenceProfilePinnedHostLabel => 'Pinned device';

  @override
  String get inferenceProfilePinnedHostNoEligibleNodes =>
      'No known devices advertise the providers this profile uses. Open Sync node settings on the target device.';

  @override
  String get inferenceProfilePinnedHostNoneHelper =>
      'Synced audio entries are not auto-transcribed when no device is pinned.';

  @override
  String get inferenceProfilePinnedHostNoneLabel =>
      'Not pinned (no auto-trigger)';

  @override
  String get inferenceProfilePinnedHostThisDeviceSuffix => ' (this device)';

  @override
  String get inferenceProfileSaveButton => 'Save';

  @override
  String get inferenceProfileSelectModel => 'Select a model…';

  @override
  String get inferenceProfileSelectProfile => 'Select a profile…';

  @override
  String inferenceProfileSkillModelRequired(String slotName) {
    return 'Requires $slotName model to be set';
  }

  @override
  String inferenceProfileSkillUsesModel(String slotName) {
    return 'Uses $slotName model';
  }

  @override
  String get inferenceProfileSkillsSection => 'Automated Skills';

  @override
  String get inferenceProfileThinking => 'Thinking';

  @override
  String get inferenceProfileThinkingHighEnd => 'Thinking (High-End)';

  @override
  String get inferenceProfileThinkingRequired => 'A thinking model is required';

  @override
  String get inferenceProfileTranscription => 'Transcription';

  @override
  String get inferenceProfilesEmpty => 'No inference profiles yet';

  @override
  String get inferenceProfilesTitle => 'Inference Profiles';

  @override
  String get inputDataTypeAudioFilesDescription => 'Use audio files as input';

  @override
  String get inputDataTypeAudioFilesName => 'Audio Files';

  @override
  String get inputDataTypeImagesDescription => 'Use images as input';

  @override
  String get inputDataTypeImagesName => 'Images';

  @override
  String get inputDataTypeTaskDescription => 'Use the current task as input';

  @override
  String get inputDataTypeTaskName => 'Task';

  @override
  String get inputDataTypeTasksListDescription =>
      'Use a list of tasks as input';

  @override
  String get inputDataTypeTasksListName => 'Tasks List';

  @override
  String get insightsChartCumulative => 'Cumulative';

  @override
  String get insightsChartCumulativeCaption => 'Running total over the range';

  @override
  String get insightsChartDaily => 'Daily';

  @override
  String get insightsChartDailyCaption => 'Time per day';

  @override
  String get insightsChartTitle => 'Time by category';

  @override
  String get insightsChooseFocusCategories => 'Choose focus categories';

  @override
  String get insightsDeletedCategory => 'Deleted category';

  @override
  String get insightsEmptyBody =>
      'Time you track on entries and tasks will show up here.';

  @override
  String get insightsEmptyChart => 'No data in this range';

  @override
  String get insightsEmptyShowYtd => 'View year to date';

  @override
  String get insightsEmptyTitle => 'No tracked time in this range';

  @override
  String get insightsFocusCategoriesEmpty => 'No active categories yet.';

  @override
  String get insightsFocusCategoriesTitle => 'Focus categories';

  @override
  String get insightsKpiFocus => 'FOCUS';

  @override
  String get insightsKpiOther => 'OTHER';

  @override
  String get insightsKpiTotal => 'TOTAL';

  @override
  String get insightsLoadError => 'Couldn\'t load time data';

  @override
  String get insightsOtherCategories => 'Other';

  @override
  String get insightsPartialWeek => 'partial week';

  @override
  String get insightsRange1d => '1d';

  @override
  String get insightsRange30d => '30d';

  @override
  String get insightsRange7d => '7d';

  @override
  String get insightsRangeCustom => 'Custom range';

  @override
  String get insightsRangeLastMonth => 'Last month';

  @override
  String get insightsRangeMtd => 'MTD';

  @override
  String get insightsRangeYtd => 'YTD';

  @override
  String get insightsTableAvgPerDay => 'AVG/DAY';

  @override
  String get insightsTableCategory => 'CATEGORY';

  @override
  String get insightsTableShare => 'SHARE';

  @override
  String get insightsTableTotal => 'TOTAL';

  @override
  String get insightsTimeAnalysisTitle => 'Time Analysis';

  @override
  String get insightsUncategorized => 'Uncategorized';

  @override
  String get journalCopyImageLabel => 'Copy image';

  @override
  String get journalDateFromLabel => 'Date from:';

  @override
  String get journalDateInvalid => 'Invalid Date Range';

  @override
  String get journalDateNowButton => 'Now';

  @override
  String get journalDateSaveButton => 'SAVE';

  @override
  String get journalDateToLabel => 'Date to:';

  @override
  String get journalDeleteConfirm => 'YES, DELETE THIS ENTRY';

  @override
  String get journalDeleteHint => 'Delete entry';

  @override
  String get journalDeleteQuestion =>
      'Do you want to delete this journal entry?';

  @override
  String get journalDurationLabel => 'Duration:';

  @override
  String get journalFavoriteTooltip => 'starred only';

  @override
  String get journalFlaggedTooltip => 'flagged only';

  @override
  String get journalHideLinkHint => 'Hide link';

  @override
  String get journalHideMapHint => 'Hide map';

  @override
  String get journalLinkFromHint => 'Link from';

  @override
  String get journalLinkToHint => 'Link to';

  @override
  String get journalLinkedEntriesActivityFilterAudio => 'Audio';

  @override
  String get journalLinkedEntriesActivityFilterImages => 'Images';

  @override
  String get journalLinkedEntriesActivityFilterTimer => 'Timer';

  @override
  String get journalLinkedEntriesFilterModalTitle => 'Filter & Sort';

  @override
  String get journalLinkedEntriesShowFlaggedOnly => 'Show flagged entries only';

  @override
  String get journalLinkedEntriesShowHidden => 'Show hidden entries';

  @override
  String get journalLinkedEntriesSortLabel => 'Sort by';

  @override
  String get journalLinkedEntriesSortNewestFirst => 'Newest first';

  @override
  String get journalLinkedEntriesSortOldestFirst => 'Oldest first';

  @override
  String get journalLinkedFromLabel => 'Linked from:';

  @override
  String get journalPrivateTooltip => 'private only';

  @override
  String get journalSearchHint => 'Search journal...';

  @override
  String get journalShareHint => 'Share';

  @override
  String get journalShowLinkHint => 'Show link';

  @override
  String get journalShowMapHint => 'Show map';

  @override
  String get journalToggleFlaggedTitle => 'Flagged';

  @override
  String get journalTogglePrivateTitle => 'Private';

  @override
  String get journalToggleStarredTitle => 'Favorite';

  @override
  String get journalUnlinkConfirm => 'YES, UNLINK ENTRY';

  @override
  String get journalUnlinkHint => 'Unlink';

  @override
  String get journalUnlinkQuestion =>
      'Are you sure you want to unlink this entry?';

  @override
  String get linkExistingTask => 'Link existing task...';

  @override
  String get linkedFromCaption => 'from';

  @override
  String get linkedTaskImageBadge => 'From linked task';

  @override
  String get linkedTasksMenuTooltip => 'Linked tasks options';

  @override
  String get linkedTasksTitle => 'Linked Tasks';

  @override
  String get linkedToCaption => 'to';

  @override
  String get loggingDomainAgentRuntime => 'Agent runtime';

  @override
  String get loggingDomainAgentWorkflow => 'Agent workflow';

  @override
  String get loggingDomainAi => 'AI';

  @override
  String get loggingDomainCalendar => 'Calendar & time';

  @override
  String get loggingDomainChat => 'Chat';

  @override
  String get loggingDomainDailyOs => 'Daily OS';

  @override
  String get loggingDomainDatabase => 'Database';

  @override
  String get loggingDomainGeneral => 'General';

  @override
  String get loggingDomainHabits => 'Habits';

  @override
  String get loggingDomainHealth => 'Health';

  @override
  String get loggingDomainLabels => 'Labels';

  @override
  String get loggingDomainLocation => 'Location';

  @override
  String get loggingDomainNavigation => 'Navigation';

  @override
  String get loggingDomainNotifications => 'Notifications';

  @override
  String get loggingDomainPersistence => 'Persistence';

  @override
  String get loggingDomainRatings => 'Ratings';

  @override
  String get loggingDomainScreenshots => 'Screenshots';

  @override
  String get loggingDomainSettings => 'Settings';

  @override
  String get loggingDomainSpeech => 'Speech & audio';

  @override
  String get loggingDomainSync => 'Sync';

  @override
  String get loggingDomainTasks => 'Tasks & checklists';

  @override
  String get loggingDomainTheming => 'Theming';

  @override
  String get loggingDomainWhatsNew => 'What\'s new';

  @override
  String get maintenanceDeleteAgentDb => 'Delete Agents Database';

  @override
  String get maintenanceDeleteAgentDbDescription =>
      'Delete agents database and restart app';

  @override
  String get maintenanceDeleteDatabaseConfirm => 'YES, DELETE DATABASE';

  @override
  String maintenanceDeleteDatabaseQuestion(String databaseName) {
    return 'Are you sure you want to delete $databaseName Database?';
  }

  @override
  String get maintenanceDeleteEditorDb => 'Delete Editor Database';

  @override
  String get maintenanceDeleteEditorDbDescription =>
      'Delete editor drafts database';

  @override
  String get maintenanceDeleteSyncDb => 'Delete Sync Database';

  @override
  String get maintenanceDeleteSyncDbDescription => 'Delete sync database';

  @override
  String get maintenanceGenerateEmbeddings => 'Generate Embeddings';

  @override
  String get maintenanceGenerateEmbeddingsConfirm => 'YES, GENERATE';

  @override
  String get maintenanceGenerateEmbeddingsDescription =>
      'Generate embeddings for entries in selected categories';

  @override
  String get maintenanceGenerateEmbeddingsMessage =>
      'Select categories to generate embeddings for.';

  @override
  String maintenanceGenerateEmbeddingsProgress(
    int processed,
    int total,
    int embedded,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$processed / $total entries ($embedded embedded)',
      one: '$processed / $total entry ($embedded embedded)',
    );
    return '$_temp0';
  }

  @override
  String get maintenancePopulatePhaseAgentEntities =>
      'Processing agent entities...';

  @override
  String get maintenancePopulatePhaseAgentLinks => 'Processing agent links...';

  @override
  String get maintenancePopulatePhaseJournal => 'Processing journal entries...';

  @override
  String get maintenancePopulatePhaseLinks => 'Processing entry links...';

  @override
  String get maintenancePopulateSequenceLog => 'Populate sync sequence log';

  @override
  String maintenancePopulateSequenceLogComplete(int count) {
    return '$count entries indexed';
  }

  @override
  String get maintenancePopulateSequenceLogConfirm => 'YES, POPULATE';

  @override
  String get maintenancePopulateSequenceLogDescription =>
      'Index existing entries for backfill support';

  @override
  String get maintenancePopulateSequenceLogMessage =>
      'This will scan all journal entries and add them to the sync sequence log. This enables backfill responses for entries created before this feature was added.';

  @override
  String get maintenancePurgeDeleted => 'Purge deleted items';

  @override
  String get maintenancePurgeDeletedConfirm => 'Yes, purge all';

  @override
  String get maintenancePurgeDeletedDescription =>
      'Purge all deleted items permanently';

  @override
  String get maintenancePurgeDeletedMessage =>
      'Are you sure you want to purge all deleted items? This action cannot be undone.';

  @override
  String get maintenancePurgeSentOutbox => 'Purge old sent outbox items';

  @override
  String get maintenancePurgeSentOutboxConfirm => 'YES, PURGE';

  @override
  String get maintenancePurgeSentOutboxDescription =>
      'Delete sent outbox rows older than 7 days and reclaim disk';

  @override
  String get maintenancePurgeSentOutboxQuestion =>
      'Purge sent outbox items older than 7 days? This deletes already-sent rows in chunks and runs VACUUM to reclaim disk. Pending and error items are kept.';

  @override
  String get maintenanceReSync => 'Re-sync messages';

  @override
  String get maintenanceReSyncAgentEntities => 'Agent entities';

  @override
  String get maintenanceReSyncDescription => 'Re-sync messages from server';

  @override
  String get maintenanceReSyncEntityTypes => 'Entity types';

  @override
  String get maintenanceReSyncJournalEntities => 'Journal entities';

  @override
  String get maintenanceReSyncSelectAtLeastOne =>
      'Select at least one entity type';

  @override
  String get maintenanceRecreateFts5 => 'Recreate full-text index';

  @override
  String get maintenanceRecreateFts5Confirm => 'YES, RECREATE INDEX';

  @override
  String get maintenanceRecreateFts5Description =>
      'Recreate full-text search index';

  @override
  String get maintenanceRecreateFts5Message =>
      'Are you sure you want to recreate the full-text index? This may take some time.';

  @override
  String get maintenanceSyncDefinitions =>
      'Sync measurables, dashboards, habits, categories, AI settings';

  @override
  String get maintenanceSyncDefinitionsDescription =>
      'Sync measurables, dashboards, habits, categories, and AI settings';

  @override
  String get manageLinks => 'Manage links...';

  @override
  String get measurableDeleteConfirm => 'YES, DELETE THIS MEASURABLE';

  @override
  String get measurableDeleteQuestion =>
      'Do you want to delete this measurable data type?';

  @override
  String get measurableNotFound => 'Measurable not found';

  @override
  String get mediaShowInFileExplorerAction => 'Show in File Explorer';

  @override
  String get mediaShowInFilesAction => 'Show in Files';

  @override
  String get mediaShowInFinderAction => 'Show in Finder';

  @override
  String get modalityAudioDescription => 'Audio processing capabilities';

  @override
  String get modalityAudioName => 'Audio';

  @override
  String get modalityImageDescription => 'Image processing capabilities';

  @override
  String get modalityImageName => 'Image';

  @override
  String get modalityTextDescription => 'Text-based content and processing';

  @override
  String get modalityTextName => 'Text';

  @override
  String get modelAddPageTitle => 'Add Model';

  @override
  String get modelEditBackTooltip => 'Back';

  @override
  String get modelEditDescriptionHint => 'Describe this model';

  @override
  String get modelEditDescriptionLabel => 'Description';

  @override
  String get modelEditDisplayNameHint => 'A friendly name for this model';

  @override
  String get modelEditDisplayNameLabel => 'Display name';

  @override
  String get modelEditFunctionCallingDescription =>
      'This model supports function and tool calling.';

  @override
  String get modelEditFunctionCallingLabel => 'Function calling';

  @override
  String get modelEditGeminiThinkingModeLabel => 'Gemini thinking mode';

  @override
  String get modelEditInputModalitiesHint => 'Select input types';

  @override
  String get modelEditInputModalitiesLabel => 'Input modalities';

  @override
  String get modelEditLoadError => 'Failed to load model configuration';

  @override
  String get modelEditMaxTokensHint => 'Optional — leave empty for unlimited';

  @override
  String get modelEditMaxTokensLabel => 'Max completion tokens';

  @override
  String get modelEditModalityNoneSelected => 'None selected';

  @override
  String get modelEditOutputModalitiesHint => 'Select output types';

  @override
  String get modelEditOutputModalitiesLabel => 'Output modalities';

  @override
  String get modelEditPageTitle => 'Edit Model';

  @override
  String get modelEditProviderHint => 'Select a provider';

  @override
  String get modelEditProviderLabel => 'Provider';

  @override
  String get modelEditProviderModelIdHint => 'e.g. gpt-4-turbo';

  @override
  String get modelEditProviderModelIdLabel => 'Provider model ID';

  @override
  String get modelEditReasoningDescription =>
      'This model uses extended thinking / chain-of-thought.';

  @override
  String get modelEditReasoningLabel => 'Reasoning model';

  @override
  String get modelEditSaveButton => 'Save';

  @override
  String get modelEditSectionCapabilities => 'Capabilities';

  @override
  String get modelEditSectionIdentity => 'Identity';

  @override
  String modelManagementSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count model$_temp0 selected';
  }

  @override
  String get multiSelectAddButton => 'Add';

  @override
  String multiSelectAddButtonWithCount(int count) {
    return 'Add ($count)';
  }

  @override
  String get multiSelectNoItemsFound => 'No items found';

  @override
  String navTabMoreSemanticsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'More, $count additional destinations',
      one: 'More, 1 additional destination',
    );
    return '$_temp0';
  }

  @override
  String get navTabTitleCalendar => 'DailyOS';

  @override
  String get navTabTitleHabits => 'Habits';

  @override
  String get navTabTitleInsights => 'Insights';

  @override
  String get navTabTitleJournal => 'Logbook';

  @override
  String get navTabTitleMore => 'More';

  @override
  String get navTabTitleProjects => 'Projects';

  @override
  String get navTabTitleSettings => 'Settings';

  @override
  String get navTabTitleTasks => 'Tasks';

  @override
  String nestedAiResponsesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count AI response$_temp0';
  }

  @override
  String get noDefaultLanguage => 'No default language';

  @override
  String get noTasksFound => 'No tasks found';

  @override
  String get noTasksToLink => 'No tasks available to link';

  @override
  String get notificationBellEmptySemantics =>
      'Notifications, no unread alerts';

  @override
  String get notificationBellTooltip => 'Notifications';

  @override
  String notificationBellUnseenSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'alerts',
      one: 'alert',
    );
    return 'Notifications, $count unread $_temp0';
  }

  @override
  String get notificationInboxDismiss => 'Dismiss notification';

  @override
  String get notificationInboxEmpty => 'You\'re all caught up.';

  @override
  String get notificationInboxError => 'Couldn\'t load notifications.';

  @override
  String get notificationInboxTitle => 'Notifications';

  @override
  String get notificationSuggestionAttentionBodyFallback =>
      'Open the task to review.';

  @override
  String notificationSuggestionAttentionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count suggestions need your attention',
      one: '1 suggestion needs your attention',
    );
    return '$_temp0';
  }

  @override
  String get outboxMonitorAttachmentLabel => 'Attachment';

  @override
  String get outboxMonitorDelete => 'delete';

  @override
  String get outboxMonitorDeleteConfirmLabel => 'Delete';

  @override
  String get outboxMonitorDeleteConfirmMessage =>
      'Are you sure you want to delete this sync item? This action cannot be undone.';

  @override
  String get outboxMonitorDeleteFailed => 'Delete failed. Please try again.';

  @override
  String get outboxMonitorDeleteSuccess => 'Item deleted';

  @override
  String get outboxMonitorEmptyDescription =>
      'There are no sync items in this view.';

  @override
  String get outboxMonitorEmptyTitle => 'Outbox is clear';

  @override
  String get outboxMonitorFetchFailed =>
      'Couldn\'t load the outbox. Pull to refresh and try again.';

  @override
  String get outboxMonitorLabelError => 'error';

  @override
  String get outboxMonitorLabelPending => 'pending';

  @override
  String get outboxMonitorLabelSent => 'sent';

  @override
  String get outboxMonitorLabelSuccess => 'success';

  @override
  String get outboxMonitorNoAttachment => 'no attachment';

  @override
  String get outboxMonitorPayloadSizeLabel => 'Size';

  @override
  String get outboxMonitorRetries => 'retries';

  @override
  String get outboxMonitorRetriesLabel => 'Retries';

  @override
  String get outboxMonitorRetry => 'retry';

  @override
  String get outboxMonitorRetryConfirmLabel => 'Retry Now';

  @override
  String get outboxMonitorRetryConfirmMessage => 'Retry this sync item now?';

  @override
  String get outboxMonitorRetryFailed => 'Retry failed. Please try again.';

  @override
  String get outboxMonitorRetryQueued => 'Retry scheduled';

  @override
  String get outboxMonitorSubjectLabel => 'Subject';

  @override
  String get outboxMonitorVolumeChartTitle => 'Daily sync volume';

  @override
  String get privateLabel => 'Private';

  @override
  String get projectAgentNotProvisioned =>
      'No project agent has been provisioned for this project yet.';

  @override
  String get projectAgentSectionTitle => 'Agent';

  @override
  String projectCountSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count projects',
      one: '$count project',
    );
    return '$_temp0';
  }

  @override
  String get projectCreateButton => 'New Project';

  @override
  String get projectCreateTitle => 'Create Project';

  @override
  String get projectDetailTitle => 'Project Details';

  @override
  String get projectErrorCreateFailed => 'Error creating project.';

  @override
  String get projectErrorLoadFailed => 'Failed to load project data.';

  @override
  String get projectErrorLoadProjects => 'Error loading projects';

  @override
  String get projectErrorUpdateFailed =>
      'Failed to update project. Please try again.';

  @override
  String get projectFilterLabel => 'Project';

  @override
  String get projectHealthBandAtRisk => 'At Risk';

  @override
  String get projectHealthBandBlocked => 'Blocked';

  @override
  String get projectHealthBandOnTrack => 'On Track';

  @override
  String get projectHealthBandSurviving => 'Surviving';

  @override
  String get projectHealthBandWatch => 'Watch';

  @override
  String get projectHealthSectionTitle => 'Project health';

  @override
  String projectHealthSummary(int projectCount, int taskCount) {
    String _temp0 = intl.Intl.pluralLogic(
      projectCount,
      locale: localeName,
      other: '$projectCount projects',
      one: '$projectCount project',
    );
    String _temp1 = intl.Intl.pluralLogic(
      taskCount,
      locale: localeName,
      other: '$taskCount tasks',
      one: '$taskCount task',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get projectHealthTitle => 'Projects';

  @override
  String projectLinkedTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count linked tasks',
      one: '$count linked task',
    );
    return '$_temp0';
  }

  @override
  String get projectLinkedTasks => 'Linked Tasks';

  @override
  String get projectManageTooltip => 'Manage projects';

  @override
  String get projectNoLinkedTasks => 'No tasks linked yet';

  @override
  String get projectNoProjects => 'No projects yet';

  @override
  String get projectNotFound => 'Project not found';

  @override
  String get projectPickerLabel => 'Project';

  @override
  String get projectPickerUnassigned => 'No project';

  @override
  String get projectRecommendationDismissTooltip => 'Dismiss';

  @override
  String get projectRecommendationResolveTooltip => 'Mark resolved';

  @override
  String get projectRecommendationUpdateError =>
      'Couldn\'t update the recommendation. Please try again.';

  @override
  String get projectRecommendationsTitle => 'Recommended next steps';

  @override
  String get projectShowcaseAiReportTitle => 'AI Report';

  @override
  String projectShowcaseBlockedLegend(int count) {
    return '$count Blocked';
  }

  @override
  String projectShowcaseBlockedTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks blocked',
      one: '$count task blocked',
    );
    return '$_temp0';
  }

  @override
  String projectShowcaseCompletedLegend(int count) {
    return '$count Completed';
  }

  @override
  String get projectShowcaseDescriptionTitle => 'Description';

  @override
  String projectShowcaseDueDate(String date) {
    return 'Due $date';
  }

  @override
  String get projectShowcaseHealthScoreDescription =>
      'This score is based on task velocity, blockers, and time left to deadline.';

  @override
  String get projectShowcaseHealthScoreTitle => 'Health Score';

  @override
  String get projectShowcaseNoResults => 'No projects match your search.';

  @override
  String get projectShowcaseOneOnOneReviewsTab => 'One-on-one Reviews';

  @override
  String get projectShowcaseOngoing => 'Ongoing';

  @override
  String get projectShowcaseProjectTasksTab => 'Project Tasks';

  @override
  String get projectShowcaseSearchHint => 'Search projects';

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
      other: '$completed/$total tasks completed',
      one: '$completed/$total task completed',
    );
    return '$_temp0';
  }

  @override
  String projectShowcaseUpdatedHoursAgo(int hours) {
    return 'Updated ${hours}h ago ↻';
  }

  @override
  String projectShowcaseUpdatedMinutesAgo(int minutes) {
    return 'Updated ${minutes}m ago ↻';
  }

  @override
  String get projectShowcaseUsefulness => 'Usefulness';

  @override
  String get projectShowcaseViewBlocker => 'View blocker';

  @override
  String get projectStatusActive => 'Active';

  @override
  String get projectStatusArchived => 'Archived';

  @override
  String get projectStatusChangeTitle => 'Change Status';

  @override
  String get projectStatusCompleted => 'Completed';

  @override
  String get projectStatusMonitoring => 'Monitoring';

  @override
  String get projectStatusOnHold => 'On Hold';

  @override
  String get projectStatusOpen => 'Open';

  @override
  String get projectSummaryOutdated => 'Summary outdated.';

  @override
  String projectSummaryOutdatedScheduled(String date, String time) {
    return 'Summary outdated. Next update $date at $time.';
  }

  @override
  String get projectTargetDateLabel => 'Target Date';

  @override
  String get projectTitleLabel => 'Project Title';

  @override
  String get projectTitleRequired => 'Project title cannot be empty';

  @override
  String get projectsFilterStatusLabel => 'Status:';

  @override
  String get projectsFilterTooltip => 'Filter projects';

  @override
  String get promptDefaultModelBadge => 'Default';

  @override
  String get promptGenerationCardTitle => 'AI Coding Prompt';

  @override
  String get promptGenerationCopiedSnackbar => 'Prompt copied to clipboard';

  @override
  String get promptGenerationCopyButton => 'Copy Prompt';

  @override
  String get promptGenerationCopyTooltip => 'Copy prompt to clipboard';

  @override
  String get promptGenerationExpandTooltip => 'Show full prompt';

  @override
  String get promptGenerationFullPromptLabel => 'Full Prompt:';

  @override
  String get promptSelectionModalTitle => 'Select Preconfigured Prompt';

  @override
  String get provisionedSyncBundleImported => 'Provisioning code imported';

  @override
  String get provisionedSyncConfigureButton => 'Configure';

  @override
  String get provisionedSyncCopiedToClipboard => 'Copied to clipboard';

  @override
  String get provisionedSyncDisconnect => 'Disconnect';

  @override
  String get provisionedSyncDone => 'Sync configured successfully';

  @override
  String get provisionedSyncError => 'Configuration failed';

  @override
  String get provisionedSyncErrorConfigurationFailed =>
      'An error occurred during configuration. Please try again.';

  @override
  String get provisionedSyncErrorLoginFailed =>
      'Login failed. Please check your credentials and try again.';

  @override
  String get provisionedSyncImportButton => 'Import';

  @override
  String get provisionedSyncImportHint => 'Paste provisioning code here';

  @override
  String get provisionedSyncImportTitle => 'Sync Setup';

  @override
  String get provisionedSyncInvalidBundle => 'Invalid provisioning code';

  @override
  String get provisionedSyncJoiningRoom => 'Joining sync room...';

  @override
  String get provisionedSyncLoggingIn => 'Logging in...';

  @override
  String get provisionedSyncPasteClipboard => 'Paste from clipboard';

  @override
  String get provisionedSyncReady => 'Scan this QR code on your mobile device';

  @override
  String get provisionedSyncRetry => 'Retry';

  @override
  String get provisionedSyncRotatingPassword => 'Securing account...';

  @override
  String get provisionedSyncScanButton => 'Scan QR Code';

  @override
  String get provisionedSyncShowQr => 'Show provisioning QR';

  @override
  String get provisionedSyncSubtitle =>
      'Set up sync from a provisioning bundle';

  @override
  String get provisionedSyncSummaryHomeserver => 'Homeserver';

  @override
  String get provisionedSyncSummaryRoom => 'Room';

  @override
  String get provisionedSyncSummaryUser => 'User';

  @override
  String get provisionedSyncTitle => 'Provisioned Sync';

  @override
  String get provisionedSyncVerifyDevicesTitle => 'Device Verification';

  @override
  String get queueCatchUpNowButton => 'Catch up now';

  @override
  String get queueCatchUpNowDone => 'Catch-up kicked — queue is draining.';

  @override
  String queueCatchUpNowError(String reason) {
    return 'Catch-up failed: $reason';
  }

  @override
  String get queueDepthCardEmpty => 'Queue empty — worker is caught up.';

  @override
  String get queueDepthCardLoading => 'Reading queue depth…';

  @override
  String get queueDepthCardTitle => 'Inbound queue';

  @override
  String get queueFetchAllHistoryCancel => 'Cancel';

  @override
  String queueFetchAllHistoryCancelled(int events) {
    String _temp0 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: '$events events',
      one: '1 event',
      zero: 'no events',
    );
    return 'Cancelled — $_temp0 fetched so far.';
  }

  @override
  String get queueFetchAllHistoryClose => 'Close';

  @override
  String get queueFetchAllHistoryDescription =>
      'Walks the room\'s entire visible history into the queue. Safe to cancel; a later run resumes from where pagination stopped.';

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
      other: 'Fetched $events events across $_temp0.',
      one: 'Fetched 1 event across $_temp1.',
      zero: 'No events fetched.',
    );
    return '$_temp2';
  }

  @override
  String queueFetchAllHistoryError(String reason) {
    return 'Fetch stopped: $reason';
  }

  @override
  String get queueFetchAllHistoryErrorUnknown => 'Fetch stopped unexpectedly.';

  @override
  String queueFetchAllHistoryProgress(int events, int pages) {
    String _temp0 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: 'Page $pages  ·  $events events fetched',
      one: 'Page $pages  ·  1 event fetched',
    );
    return '$_temp0';
  }

  @override
  String get queueFetchAllHistoryTitle => 'Fetching history';

  @override
  String queueSkippedBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count skipped',
      one: '1 skipped',
    );
    return '$_temp0';
  }

  @override
  String queueSkippedCardBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count sync events the queue gave up on. Tap retry to re-attempt.',
      one: '1 sync event the queue gave up on. Tap retry to re-attempt.',
    );
    return '$_temp0';
  }

  @override
  String get queueSkippedCardTitle => 'Skipped events';

  @override
  String get queueSkippedRetryAll => 'Retry skipped events';

  @override
  String queueSkippedRetryAllDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events queued for retry.',
      one: '1 event queued for retry.',
      zero: 'No skipped events to retry.',
    );
    return '$_temp0';
  }

  @override
  String queueSkippedRetryAllError(String reason) {
    return 'Retry failed: $reason';
  }

  @override
  String get referenceImageContinue => 'Continue';

  @override
  String referenceImageContinueWithCount(int count) {
    return 'Continue ($count)';
  }

  @override
  String get referenceImageLoadError =>
      'Failed to load images. Please try again.';

  @override
  String get referenceImageSelectionSubtitle =>
      'Choose up to 5 images to guide the AI\'s visual style';

  @override
  String get referenceImageSelectionTitle => 'Select Reference Images';

  @override
  String get referenceImageSkip => 'Skip';

  @override
  String get saveButton => 'Save';

  @override
  String get saveButtonLabel => 'Save';

  @override
  String get saveLabel => 'Save';

  @override
  String get saveSuccessful => 'Saved successfully';

  @override
  String get searchHint => 'Search...';

  @override
  String get searchModeFullText => 'Full Text';

  @override
  String get searchModeVector => 'Vector';

  @override
  String get searchTasksHint => 'Search tasks...';

  @override
  String get selectButton => 'Select';

  @override
  String get selectColor => 'Select Color';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get sessionRatingCardLabel => 'Session Rating';

  @override
  String get sessionRatingChallengeJustRight => 'Just right';

  @override
  String get sessionRatingChallengeTooEasy => 'Too easy';

  @override
  String get sessionRatingChallengeTooHard => 'Too challenging';

  @override
  String get sessionRatingDifficultyLabel => 'This work felt...';

  @override
  String get sessionRatingEditButton => 'Edit Rating';

  @override
  String get sessionRatingEnergyQuestion => 'How energized did you feel?';

  @override
  String get sessionRatingFocusQuestion => 'How focused were you?';

  @override
  String get sessionRatingNoteHint => 'Quick note (optional)';

  @override
  String get sessionRatingProductivityQuestion =>
      'How productive was this session?';

  @override
  String get sessionRatingRateAction => 'Rate Session';

  @override
  String get sessionRatingSaveButton => 'Save';

  @override
  String get sessionRatingSaveError =>
      'Failed to save rating. Please try again.';

  @override
  String get sessionRatingSkipButton => 'Skip';

  @override
  String get sessionRatingTitle => 'Rate this session';

  @override
  String get sessionRatingViewAction => 'View Rating';

  @override
  String get settingThemingDark => 'Dark Theme';

  @override
  String get settingThemingLight => 'Light Theme';

  @override
  String get settingsAboutAppInformation => 'App Information';

  @override
  String get settingsAboutAppTagline => 'Your Personal Journal';

  @override
  String get settingsAboutBuildType => 'Build Type';

  @override
  String get settingsAboutDailyOsPersonalizationTitle =>
      'Daily OS personalization';

  @override
  String get settingsAboutDailyOsUserNameHelper =>
      'Used only for the Daily OS greeting on this device.';

  @override
  String get settingsAboutDailyOsUserNameLabel => 'Your name';

  @override
  String get settingsAboutJournalEntries => 'Journal Entries';

  @override
  String get settingsAboutPlatform => 'Platform';

  @override
  String get settingsAboutTitle => 'About Lotti';

  @override
  String get settingsAboutVersion => 'Version';

  @override
  String get settingsAboutYourData => 'Your Data';

  @override
  String get settingsAdvancedAboutSubtitle =>
      'Learn more about the Lotti application';

  @override
  String get settingsAdvancedHealthImportSubtitle =>
      'Import health-related data from external sources';

  @override
  String get settingsAdvancedMaintenanceSubtitle =>
      'Perform maintenance tasks to optimize application performance';

  @override
  String get settingsAdvancedOutboxSubtitle => 'Manage sync items';

  @override
  String get settingsAdvancedSubtitle => 'Advanced settings and maintenance';

  @override
  String get settingsAdvancedTitle => 'Advanced Settings';

  @override
  String get settingsAgentsInstancesSubtitle => 'Running agents';

  @override
  String get settingsAgentsPendingWakesSubtitle => 'Scheduled wake timers';

  @override
  String get settingsAgentsSoulsSubtitle => 'Long-lived agent personalities';

  @override
  String get settingsAgentsStatsSubtitle => 'Token usage and activity';

  @override
  String get settingsAgentsTemplatesSubtitle => 'Shared agent blueprints';

  @override
  String get settingsAiModelsSubtitle =>
      'Per-provider model rows and capabilities';

  @override
  String get settingsAiModelsTitle => 'Models';

  @override
  String get settingsAiProfilesSubtitle => 'Providers and models';

  @override
  String get settingsAiProfilesTitle => 'Inference Profiles';

  @override
  String get settingsAiProvidersSubtitle => 'Connected AI providers and keys';

  @override
  String get settingsAiProvidersTitle => 'Providers';

  @override
  String get settingsAiSubtitle =>
      'Configure AI providers, models, and prompts';

  @override
  String get settingsAiTitle => 'AI Settings';

  @override
  String get settingsBeamPageEditModelTitle => 'Edit model';

  @override
  String get settingsBeamPageEditProfileTitle => 'Edit profile';

  @override
  String get settingsCategoriesCreateTitle => 'Create category';

  @override
  String get settingsCategoriesDetailsLabel => 'Edit category';

  @override
  String get settingsCategoriesEmptyState => 'No categories found';

  @override
  String get settingsCategoriesEmptyStateHint =>
      'Create a category to organize your entries';

  @override
  String get settingsCategoriesErrorLoading => 'Error loading categories';

  @override
  String get settingsCategoriesNameLabel => 'Category name';

  @override
  String settingsCategoriesNoMatchQuery(String query) {
    return 'No categories match \"$query\"';
  }

  @override
  String get settingsCategoriesSearchHint => 'Search categories…';

  @override
  String get settingsCategoriesSubtitle => 'Categories with AI settings';

  @override
  String settingsCategoriesTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks',
      one: '$count task',
    );
    return '$_temp0';
  }

  @override
  String get settingsCategoriesTitle => 'Categories';

  @override
  String get settingsConflictsTitle => 'Sync Conflicts';

  @override
  String get settingsDashboardDetailsLabel => 'Edit dashboard';

  @override
  String get settingsDashboardSaveLabel => 'Save';

  @override
  String get settingsDashboardsCreateTitle => 'Create dashboard';

  @override
  String get settingsDashboardsEmptyState => 'No dashboards yet';

  @override
  String get settingsDashboardsEmptyStateHint =>
      'Tap the + button to create your first dashboard.';

  @override
  String get settingsDashboardsErrorLoading => 'Error loading dashboards';

  @override
  String settingsDashboardsNoMatchQuery(String query) {
    return 'No dashboards match \"$query\"';
  }

  @override
  String get settingsDashboardsSearchHint => 'Search dashboards…';

  @override
  String get settingsDashboardsSubtitle => 'Customize your dashboard views';

  @override
  String get settingsDashboardsTitle => 'Dashboards';

  @override
  String get settingsDefinitionsSubtitle =>
      'Habits, categories, labels, dashboards, and measurables';

  @override
  String get settingsDefinitionsTitle => 'Definitions';

  @override
  String get settingsFlagsEmptySearch => 'No flags match your search';

  @override
  String get settingsFlagsSearchHint => 'Search flags';

  @override
  String get settingsFlagsSubtitle => 'Configure feature flags and options';

  @override
  String get settingsFlagsTitle => 'Config Flags';

  @override
  String get settingsHabitsCreateTitle => 'Create habit';

  @override
  String get settingsHabitsDeleteTooltip => 'Delete Habit';

  @override
  String get settingsHabitsDescriptionLabel => 'Description (optional)';

  @override
  String get settingsHabitsDetailsLabel => 'Edit habit';

  @override
  String get settingsHabitsEmptyState => 'No habits yet';

  @override
  String get settingsHabitsEmptyStateHint =>
      'Tap the + button to create your first habit.';

  @override
  String get settingsHabitsErrorLoading => 'Error loading habits';

  @override
  String get settingsHabitsNameLabel => 'Habit name';

  @override
  String settingsHabitsNoMatchQuery(String query) {
    return 'No habits match \"$query\"';
  }

  @override
  String get settingsHabitsPrivateLabel => 'Private: ';

  @override
  String get settingsHabitsSaveLabel => 'Save';

  @override
  String get settingsHabitsSearchHint => 'Search habits…';

  @override
  String get settingsHabitsSubtitle => 'Manage your habits and routines';

  @override
  String get settingsHabitsTitle => 'Habits';

  @override
  String get settingsHealthImportFromDate => 'Start';

  @override
  String get settingsHealthImportTitle => 'Health Import';

  @override
  String get settingsHealthImportToDate => 'End';

  @override
  String get settingsLabelsCategoriesAdd => 'Add category';

  @override
  String get settingsLabelsCategoriesHeading => 'Applicable categories';

  @override
  String get settingsLabelsCategoriesNone => 'Applies to all categories';

  @override
  String get settingsLabelsCategoriesRemoveTooltip => 'Remove';

  @override
  String get settingsLabelsColorHeading => 'Select a color';

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
    return 'Create \"$query\" label';
  }

  @override
  String settingsLabelsNoMatchQuery(String query) {
    return 'No labels match \"$query\"';
  }

  @override
  String get settingsLabelsPrivateDescription =>
      'Private labels only appear when “Show private entries” is enabled.';

  @override
  String get settingsLabelsPrivateTitle => 'Private label';

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
      other: '$count tasks',
      one: '1 task',
    );
    return 'Used on $_temp0';
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
  String get settingsLoggingSlowQueries => 'Slow Database Queries';

  @override
  String get settingsLoggingSlowQueriesSubtitle =>
      'Writes slow queries to slow_queries-YYYY-MM-DD.log';

  @override
  String get settingsMaintenanceTitle => 'Maintenance';

  @override
  String get settingsMatrixAccept => 'Accept';

  @override
  String get settingsMatrixAcceptVerificationLabel =>
      'Other device shows emojis, continue';

  @override
  String get settingsMatrixCancel => 'Cancel';

  @override
  String get settingsMatrixContinueVerificationLabel =>
      'Accept on other device to continue';

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
  String get settingsMatrixDone => 'Done';

  @override
  String get settingsMatrixLastUpdated => 'Last updated:';

  @override
  String get settingsMatrixListUnverifiedLabel => 'Unverified devices';

  @override
  String get settingsMatrixMaintenanceSubtitle =>
      'Run Matrix maintenance tasks and recovery tools';

  @override
  String get settingsMatrixMaintenanceTitle => 'Maintenance';

  @override
  String get settingsMatrixMetrics => 'Sync Metrics';

  @override
  String get settingsMatrixNextPage => 'Next Page';

  @override
  String get settingsMatrixNoUnverifiedLabel => 'No unverified devices';

  @override
  String get settingsMatrixPreviousPage => 'Previous Page';

  @override
  String settingsMatrixRoomInviteMessage(String roomId, String senderId) {
    return 'Invite to room $roomId from $senderId. Accept?';
  }

  @override
  String get settingsMatrixRoomInviteTitle => 'Room invite';

  @override
  String get settingsMatrixSentMessagesLabel => 'Sent messages:';

  @override
  String get settingsMatrixStartVerificationLabel => 'Start Verification';

  @override
  String get settingsMatrixStatsTitle => 'Matrix Stats';

  @override
  String get settingsMatrixTitle => 'Sync Settings';

  @override
  String get settingsMatrixUnverifiedDevicesPage => 'Unverified Devices';

  @override
  String get settingsMatrixVerificationCancelledLabel =>
      'Cancelled on other device...';

  @override
  String get settingsMatrixVerificationSuccessConfirm => 'Got it';

  @override
  String settingsMatrixVerificationSuccessLabel(
    String deviceName,
    String deviceID,
  ) {
    return 'You\'ve successfully verified $deviceName ($deviceID)';
  }

  @override
  String get settingsMatrixVerifyConfirm =>
      'Confirm on other device that the emojis below are displayed on both devices, in the same order:';

  @override
  String get settingsMatrixVerifyIncomingConfirm =>
      'Confirm that the emojis below are displayed on both devices, in the same order:';

  @override
  String get settingsMatrixVerifyLabel => 'Verify';

  @override
  String get settingsMeasurableAggregationLabel =>
      'Default Aggregation Type (optional)';

  @override
  String get settingsMeasurableDeleteTooltip => 'Delete measurable type';

  @override
  String get settingsMeasurableDescriptionLabel => 'Description (optional)';

  @override
  String get settingsMeasurableDetailsLabel => 'Edit measurable';

  @override
  String get settingsMeasurableNameLabel => 'Measurable name';

  @override
  String get settingsMeasurablePrivateLabel => 'Private: ';

  @override
  String get settingsMeasurableSaveLabel => 'Save';

  @override
  String get settingsMeasurableUnitLabel => 'Unit abbreviation (optional)';

  @override
  String get settingsMeasurablesCreateTitle => 'Create measurable';

  @override
  String get settingsMeasurablesEmptyState => 'No measurables yet';

  @override
  String get settingsMeasurablesEmptyStateHint =>
      'Tap the + button to create your first measurable.';

  @override
  String get settingsMeasurablesErrorLoading => 'Error loading measurables';

  @override
  String settingsMeasurablesNoMatchQuery(String query) {
    return 'No measurables match \"$query\"';
  }

  @override
  String get settingsMeasurablesSearchHint => 'Search measurables…';

  @override
  String get settingsMeasurablesSubtitle => 'Configure measurable data types';

  @override
  String get settingsMeasurablesTitle => 'Measurable Types';

  @override
  String get settingsResetGeminiConfirm => 'Reset';

  @override
  String get settingsResetGeminiConfirmQuestion =>
      'This will show the Gemini setup dialog again. Continue?';

  @override
  String get settingsResetGeminiSubtitle =>
      'Show the Gemini AI setup dialog again';

  @override
  String get settingsResetGeminiTitle => 'Reset Gemini Setup Dialog';

  @override
  String get settingsResetHintsConfirm => 'Confirm';

  @override
  String get settingsResetHintsConfirmQuestion =>
      'Reset in‑app hints shown across the app?';

  @override
  String settingsResetHintsResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Reset $count hints',
      one: 'Reset one hint',
      zero: 'Reset zero hints',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetHintsSubtitle =>
      'Clear one‑time tips and onboarding hints';

  @override
  String get settingsResetHintsTitle => 'Reset In‑App Hints';

  @override
  String get settingsSyncConflictsSubtitle =>
      'Resolve synchronization conflicts to ensure data consistency';

  @override
  String get settingsSyncNodeProfileCapabilitiesEmpty =>
      'None detected — auto-trigger of synced audio inference will not target this device.';

  @override
  String get settingsSyncNodeProfileCapabilitiesLabel =>
      'Detected AI capabilities';

  @override
  String get settingsSyncNodeProfileCapabilityMlxAudio => 'MLX Audio (local)';

  @override
  String get settingsSyncNodeProfileCapabilityOllamaLlm => 'Ollama LLM';

  @override
  String get settingsSyncNodeProfileCapabilityVoxtral => 'Voxtral (local)';

  @override
  String get settingsSyncNodeProfileCapabilityWhisper => 'Whisper (local)';

  @override
  String get settingsSyncNodeProfileDisplayNameHelper =>
      'Visible to your other devices when picking which one to pin a profile to.';

  @override
  String get settingsSyncNodeProfileDisplayNameLabel => 'Device display name';

  @override
  String get settingsSyncNodeProfileKnownNodesEmpty =>
      'No other devices have published a profile yet.';

  @override
  String get settingsSyncNodeProfileKnownNodesTitle => 'Known sync devices';

  @override
  String get settingsSyncNodeProfileSaveButton => 'Save';

  @override
  String get settingsSyncNodeProfileSubtitle =>
      'Name this device and review capabilities visible to your other devices.';

  @override
  String get settingsSyncNodeProfileTitle => 'This device';

  @override
  String get settingsSyncOutboxTitle => 'Sync Outbox';

  @override
  String get settingsSyncStatsSubtitle => 'Inspect sync pipeline metrics';

  @override
  String get settingsSyncSubtitle => 'Configure sync and view stats';

  @override
  String get settingsThemingAutomatic => 'Automatic';

  @override
  String get settingsThemingDark => 'Dark Appearance';

  @override
  String get settingsThemingLight => 'Light Appearance';

  @override
  String get settingsThemingSubtitle => 'Customize app appearance and themes';

  @override
  String get settingsThemingTitle => 'Theming';

  @override
  String get settingsV2CategoryEmptyBody => 'Pick a sub-setting on the left.';

  @override
  String get settingsV2DetailRootCrumb => 'Settings';

  @override
  String get settingsV2EmptyStateBody => 'Pick a section on the left to begin.';

  @override
  String get settingsV2ResizeHandleLabel => 'Resize settings tree';

  @override
  String get settingsV2UnimplementedTitle => 'Panel not yet implemented';

  @override
  String get settingsWhatsNewSubtitle => 'See the latest updates and features';

  @override
  String get settingsWhatsNewTitle => 'What\'s New';

  @override
  String get sidebarRunningTimerLabel => 'Running timer';

  @override
  String get sidebarRunningTimerStopTooltip => 'Stop timer';

  @override
  String get sidebarToggleCollapseLabel => 'Collapse sidebar';

  @override
  String get sidebarToggleExpandLabel => 'Expand sidebar';

  @override
  String get sidebarWakesCancelTooltip => 'Cancel wake';

  @override
  String get sidebarWakesHeader => 'Wakes';

  @override
  String get sidebarWakesNow => 'now';

  @override
  String get sidebarWakesOpenList => 'Open list';

  @override
  String get skillsSectionTitle => 'Skills';

  @override
  String get speechDictionaryHelper =>
      'Semicolon-separated terms (max 50 chars) for better speech recognition';

  @override
  String get speechDictionaryHint => 'macOS; Kirkjubæjarklaustur; Claude Code';

  @override
  String get speechDictionaryLabel => 'Speech Dictionary';

  @override
  String get speechDictionarySectionDescription =>
      'Add terms that are often misspelled by speech recognition (names, places, technical terms)';

  @override
  String get speechDictionarySectionTitle => 'Speech Recognition';

  @override
  String speechDictionaryWarning(Object count) {
    return 'Large dictionary ($count terms) may increase API costs';
  }

  @override
  String get speechModalSelectLanguage => 'Select Language';

  @override
  String get speechModalTitle => 'Speech Recognition';

  @override
  String syncActivityIndicatorSemantics(int outbox, int inbox) {
    return 'Sync activity. Outbox: $outbox. Inbox: $inbox. Open sync outbox.';
  }

  @override
  String get syncDeleteConfigConfirm => 'YES, I\'M SURE';

  @override
  String get syncDeleteConfigQuestion =>
      'Do you want to delete the sync configuration?';

  @override
  String get syncEntitiesConfirm => 'START SYNC';

  @override
  String get syncEntitiesMessage => 'Choose the entities you want to sync.';

  @override
  String get syncEntitiesSuccessDescription => 'Everything is up to date.';

  @override
  String get syncEntitiesSuccessTitle => 'Sync complete';

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
  String get syncListPayloadKindLabel => 'Payload';

  @override
  String get syncListUnknownPayload => 'Unknown payload';

  @override
  String get syncNotLoggedInToast => 'Sync is not logged in';

  @override
  String get syncPayloadAgentBundle => 'Agent bundle';

  @override
  String get syncPayloadAgentEntity => 'Agent entity';

  @override
  String get syncPayloadAgentLink => 'Agent link';

  @override
  String get syncPayloadAiConfig => 'AI configuration';

  @override
  String get syncPayloadAiConfigDelete => 'AI configuration delete';

  @override
  String get syncPayloadBackfillRequest => 'Backfill request';

  @override
  String get syncPayloadBackfillResponse => 'Backfill response';

  @override
  String get syncPayloadConfigFlag => 'Config flag';

  @override
  String get syncPayloadEntityDefinition => 'Entity definition';

  @override
  String get syncPayloadEntryLink => 'Entry link';

  @override
  String get syncPayloadJournalEntity => 'Journal entry';

  @override
  String get syncPayloadNotification => 'Notification';

  @override
  String get syncPayloadNotificationStateUpdate => 'Notification state update';

  @override
  String get syncPayloadOutboxBundle => 'Outbox bundle';

  @override
  String get syncPayloadSyncNodeProfile => 'Sync node profile';

  @override
  String get syncPayloadThemingSelection => 'Theming selection';

  @override
  String get syncStepAgentEntities => 'Agent entities';

  @override
  String get syncStepAgentLinks => 'Agent links';

  @override
  String get syncStepAiSettings => 'AI settings';

  @override
  String get syncStepBackfillAgentEntityClocks =>
      'Backfill agent entity clocks';

  @override
  String get syncStepBackfillAgentLinkClocks => 'Backfill agent link clocks';

  @override
  String get syncStepCategories => 'Categories';

  @override
  String get syncStepComplete => 'Complete';

  @override
  String get syncStepDashboards => 'Dashboards';

  @override
  String get syncStepHabits => 'Habits';

  @override
  String get syncStepLabels => 'Labels';

  @override
  String get syncStepMeasurables => 'Measurables';

  @override
  String get taskActionBarAudioRecordingActive => 'Audio recording in progress';

  @override
  String get taskActionBarMoreActions => 'More actions';

  @override
  String get taskActionBarOpenRunningTimer => 'Open running timer';

  @override
  String get taskActionBarStopTracking => 'Stop time tracking';

  @override
  String get taskActionBarTrackTime => 'Track time';

  @override
  String get taskAgentCancelTimerTooltip => 'Cancel';

  @override
  String taskAgentCountdownTooltip(String countdown) {
    return 'Next auto-run in $countdown';
  }

  @override
  String get taskAgentCreateChipLabel => 'Assign Agent';

  @override
  String taskAgentCreateError(String error) {
    return 'Failed to create agent: $error';
  }

  @override
  String get taskAgentRunNowTooltip => 'Refresh';

  @override
  String get taskCategoryAllLabel => 'all';

  @override
  String get taskCategoryLabel => 'Category:';

  @override
  String get taskCategoryUnassignedLabel => 'unassigned';

  @override
  String get taskDueDateLabel => 'Due Date';

  @override
  String taskDueDateWithDate(String date) {
    return 'Due: $date';
  }

  @override
  String taskDueInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'Due in $_temp0';
  }

  @override
  String get taskDueToday => 'Due Today';

  @override
  String get taskDueTomorrow => 'Due Tomorrow';

  @override
  String get taskDueYesterday => 'Due Yesterday';

  @override
  String get taskEditTitleLabel => 'Edit task title';

  @override
  String get taskEstimateLabel => 'Estimate:';

  @override
  String get taskLanguageArabic => 'Arabic';

  @override
  String get taskLanguageBengali => 'Bengali';

  @override
  String get taskLanguageBulgarian => 'Bulgarian';

  @override
  String get taskLanguageChinese => 'Chinese';

  @override
  String get taskLanguageCroatian => 'Croatian';

  @override
  String get taskLanguageCzech => 'Czech';

  @override
  String get taskLanguageDanish => 'Danish';

  @override
  String get taskLanguageDutch => 'Dutch';

  @override
  String get taskLanguageEnglish => 'English';

  @override
  String get taskLanguageEstonian => 'Estonian';

  @override
  String get taskLanguageFinnish => 'Finnish';

  @override
  String get taskLanguageFrench => 'French';

  @override
  String get taskLanguageGerman => 'German';

  @override
  String get taskLanguageGreek => 'Greek';

  @override
  String get taskLanguageHebrew => 'Hebrew';

  @override
  String get taskLanguageHindi => 'Hindi';

  @override
  String get taskLanguageHungarian => 'Hungarian';

  @override
  String get taskLanguageIgbo => 'Igbo';

  @override
  String get taskLanguageIndonesian => 'Indonesian';

  @override
  String get taskLanguageItalian => 'Italian';

  @override
  String get taskLanguageJapanese => 'Japanese';

  @override
  String get taskLanguageKorean => 'Korean';

  @override
  String get taskLanguageLabel => 'Language';

  @override
  String get taskLanguageLatvian => 'Latvian';

  @override
  String get taskLanguageLithuanian => 'Lithuanian';

  @override
  String get taskLanguageNigerianPidgin => 'Nigerian Pidgin';

  @override
  String get taskLanguageNorwegian => 'Norwegian';

  @override
  String get taskLanguagePolish => 'Polish';

  @override
  String get taskLanguagePortuguese => 'Portuguese';

  @override
  String get taskLanguageRomanian => 'Romanian';

  @override
  String get taskLanguageRussian => 'Russian';

  @override
  String get taskLanguageSelectedLabel => 'Currently selected';

  @override
  String get taskLanguageSerbian => 'Serbian';

  @override
  String get taskLanguageSetAction => 'Set language';

  @override
  String get taskLanguageSlovak => 'Slovak';

  @override
  String get taskLanguageSlovenian => 'Slovenian';

  @override
  String get taskLanguageSpanish => 'Spanish';

  @override
  String get taskLanguageSwahili => 'Swahili';

  @override
  String get taskLanguageSwedish => 'Swedish';

  @override
  String get taskLanguageThai => 'Thai';

  @override
  String get taskLanguageTurkish => 'Turkish';

  @override
  String get taskLanguageTwi => 'Twi';

  @override
  String get taskLanguageUkrainian => 'Ukrainian';

  @override
  String get taskLanguageVietnamese => 'Vietnamese';

  @override
  String get taskLanguageYoruba => 'Yoruba';

  @override
  String get taskNoDueDateLabel => 'No due date';

  @override
  String get taskNoEstimateLabel => 'No estimate';

  @override
  String taskOverdueByDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'Overdue by $_temp0';
  }

  @override
  String get taskShowcaseAudio => 'Audio';

  @override
  String taskShowcaseCompletedCount(int completed, int total) {
    return '$completed / $total done';
  }

  @override
  String taskShowcaseDueDate(String date) {
    return 'Due: $date';
  }

  @override
  String get taskShowcaseJumpToSection => 'Jump to section';

  @override
  String get taskShowcaseLinked => 'Linked';

  @override
  String get taskShowcaseNoResults => 'No tasks match your search.';

  @override
  String get taskShowcaseReadMore => 'Read more';

  @override
  String taskShowcaseRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recordings',
      one: '1 recording',
    );
    return '$_temp0';
  }

  @override
  String taskShowcaseTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks',
      one: '1 task',
    );
    return '$_temp0';
  }

  @override
  String get taskShowcaseTaskDescription => 'Task description';

  @override
  String get taskShowcaseTimeTracker => 'Time Tracker';

  @override
  String get taskShowcaseTodo => 'Todo';

  @override
  String get taskShowcaseTodos => 'Todos';

  @override
  String get taskStatusAll => 'All';

  @override
  String get taskStatusBlocked => 'Blocked';

  @override
  String get taskStatusDone => 'Done';

  @override
  String get taskStatusGroomed => 'Groomed';

  @override
  String get taskStatusInProgress => 'In Progress';

  @override
  String get taskStatusLabel => 'Status:';

  @override
  String get taskStatusOnHold => 'On Hold';

  @override
  String get taskStatusOpen => 'Open';

  @override
  String get taskStatusRejected => 'Rejected';

  @override
  String get taskTitleEmpty => 'No title';

  @override
  String get taskUntitled => '(untitled)';

  @override
  String get tasksAddLabelButton => 'Add Label';

  @override
  String get tasksAgentFilterAll => 'All';

  @override
  String get tasksAgentFilterHasAgent => 'Has Agent';

  @override
  String get tasksAgentFilterNoAgent => 'No Agent';

  @override
  String get tasksAgentFilterTitle => 'Agent';

  @override
  String get tasksFilterApplyTitle => 'Apply filter';

  @override
  String get tasksFilterClearAll => 'Clear all';

  @override
  String get tasksFilterTitle => 'Tasks Filter';

  @override
  String get tasksLabelFilterAll => 'All';

  @override
  String get tasksLabelFilterTitle => 'Label';

  @override
  String get tasksLabelFilterUnlabeled => 'Unlabeled';

  @override
  String get tasksLabelsDialogClose => 'Close';

  @override
  String get tasksLabelsSheetApply => 'Apply';

  @override
  String get tasksLabelsSheetSearchHint => 'Search labels…';

  @override
  String get tasksLabelsUpdateFailed => 'Failed to update labels';

  @override
  String get tasksPriorityFilterAll => 'All';

  @override
  String get tasksPriorityFilterTitle => 'Priority';

  @override
  String get tasksPriorityP0 => 'Urgent';

  @override
  String get tasksPriorityP0Description => 'Urgent (ASAP)';

  @override
  String get tasksPriorityP1 => 'High';

  @override
  String get tasksPriorityP1Description => 'High (Soon)';

  @override
  String get tasksPriorityP2 => 'Medium';

  @override
  String get tasksPriorityP2Description => 'Medium (Default)';

  @override
  String get tasksPriorityP3 => 'Low';

  @override
  String get tasksPriorityP3Description => 'Low (Whenever)';

  @override
  String get tasksPriorityPickerTitle => 'Select priority';

  @override
  String get tasksQuickFilterClear => 'Clear';

  @override
  String get tasksQuickFilterLabelsActiveTitle => 'Active label filters';

  @override
  String get tasksQuickFilterUnassignedLabel => 'Unassigned';

  @override
  String get tasksSavedFilterDeleteConfirmTooltip => 'Tap again to delete';

  @override
  String get tasksSavedFilterDeleteTooltip => 'Delete saved filter';

  @override
  String get tasksSavedFilterDragHandleSemantics => 'Drag to reorder';

  @override
  String get tasksSavedFilterRenameSemantics => 'Rename saved filter';

  @override
  String get tasksSavedFilterToastDeleted => 'Filter deleted';

  @override
  String tasksSavedFilterToastSaved(String name) {
    return 'Saved \'$name\'';
  }

  @override
  String tasksSavedFilterToastUpdated(String name) {
    return 'Updated \'$name\'';
  }

  @override
  String get tasksSavedFiltersSaveButtonLabel => 'Save';

  @override
  String get tasksSavedFiltersSavePopupCancel => 'Cancel';

  @override
  String tasksSavedFiltersSavePopupHelper(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filters active. Saved to sidebar under Tasks.',
      one: '1 filter active. Saved to sidebar under Tasks.',
    );
    return '$_temp0';
  }

  @override
  String get tasksSavedFiltersSavePopupHint => 'e.g. Blocked or on hold';

  @override
  String get tasksSavedFiltersSavePopupSave => 'Save';

  @override
  String get tasksSavedFiltersSavePopupTitle => 'Name this filter';

  @override
  String get tasksSearchModeLabel => 'Search mode';

  @override
  String get tasksShowCreationDate => 'Show creation date on cards';

  @override
  String get tasksShowDueDate => 'Show due date on cards';

  @override
  String get tasksSortByCreationDate => 'Created';

  @override
  String get tasksSortByDueDate => 'Due Date';

  @override
  String get tasksSortByLabel => 'Sort by';

  @override
  String get tasksSortByPriority => 'Priority';

  @override
  String get thinkingDisclosureCopied => 'Reasoning copied';

  @override
  String get thinkingDisclosureCopy => 'Copy reasoning';

  @override
  String get thinkingDisclosureHide => 'Hide reasoning';

  @override
  String get thinkingDisclosureShow => 'Show reasoning';

  @override
  String get thinkingDisclosureStateCollapsed => 'collapsed';

  @override
  String get thinkingDisclosureStateExpanded => 'expanded';

  @override
  String get timeEntryItemEnd => 'End';

  @override
  String get timeEntryItemRunning => 'Running';

  @override
  String get timeEntryItemStart => 'Start';

  @override
  String get unlinkButton => 'Unlink';

  @override
  String get unlinkTaskConfirm => 'Are you sure you want to unlink this task?';

  @override
  String get unlinkTaskTitle => 'Unlink Task';

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
  String get viewMenuTitle => 'View';

  @override
  String get viewMenuZoomIn => 'Zoom In';

  @override
  String get viewMenuZoomOut => 'Zoom Out';

  @override
  String get viewMenuZoomReset => 'Actual Size';

  @override
  String get whatsNewDoneButton => 'Done';

  @override
  String get whatsNewSkipButton => 'Skip';
}

/// The translations for English, as used in the United Kingdom (`en_GB`).
class AppLocalizationsEnGb extends AppLocalizationsEn {
  AppLocalizationsEnGb() : super('en_GB');

  @override
  String get agentControlsReanalyzeButton => 'Re-analyse';

  @override
  String get aiSetupWizardCreatesOptimized =>
      'Creates optimised models, prompts, and a test category';

  @override
  String get categoryCreationError =>
      'Failed to create category. Please try again.';

  @override
  String get categoryDeleteConfirmation =>
      'This action cannot be undone. All entries in this category will remain but will no longer be categorised.';

  @override
  String get categoryFavoriteDescription => 'Mark this category as a favourite';

  @override
  String get colorLabel => 'Colour';

  @override
  String get configFlagEnableAiStreaming =>
      'Enable AI streaming for task actions';

  @override
  String get configFlagEnableAiStreamingDescription =>
      'Stream AI responses for task-related actions. Turn off to buffer responses and keep the UI smoother.';

  @override
  String get configFlagEnableDailyOs => 'Enable DailyOS';

  @override
  String get configFlagEnableDailyOsDescription =>
      'Show the DailyOS page in the main navigation.';

  @override
  String get configFlagEnableDashboardsPage => 'Enable Dashboards page';

  @override
  String get configFlagEnableDashboardsPageDescription =>
      'Show the Dashboards page in the main navigation. View your data and insights in customisable dashboards.';

  @override
  String get configFlagEnableHabitsPage => 'Enable Habits page';

  @override
  String get configFlagEnableLogging => 'Enable logging';

  @override
  String get configFlagEnableMatrix => 'Enable Matrix sync';

  @override
  String get configFlagRecordLocationDescription =>
      'Automatically record your location with new entries. This helps with location-based organisation and search.';

  @override
  String get configFlagResendAttachments => 'Resend attachments';

  @override
  String get configFlagResendAttachmentsDescription =>
      'Enable this to automatically resend failed attachment uploads when the connection is restored.';

  @override
  String get conflictsResolved => 'resolved';

  @override
  String get conflictsUnresolved => 'unresolved';

  @override
  String get createCategoryTitle => 'Create category';

  @override
  String get createEntryLabel => 'Create new entry';

  @override
  String get createEntryTitle => 'Add';

  @override
  String get customColor => 'Custom Colour';

  @override
  String get dailyOsUncategorized => 'Uncategorised';

  @override
  String get dashboardActiveLabel => 'Active';

  @override
  String get dashboardAddChartsTitle => 'Charts';

  @override
  String get dashboardAddHabitButton => 'Habit Charts';

  @override
  String get dashboardAddHabitTitle => 'Habit Charts';

  @override
  String get dashboardAddHealthButton => 'Health Charts';

  @override
  String get dashboardAddHealthTitle => 'Health Charts';

  @override
  String get dashboardAddMeasurementButton => 'Measurement Charts';

  @override
  String get dashboardAddMeasurementTitle => 'Measurement Charts';

  @override
  String get dashboardAddSurveyButton => 'Survey Charts';

  @override
  String get dashboardAddSurveyTitle => 'Survey Charts';

  @override
  String get dashboardAddWorkoutButton => 'Workout Charts';

  @override
  String get dashboardAddWorkoutTitle => 'Workout Charts';

  @override
  String get dashboardAggregationLabel => 'Aggregation Type:';

  @override
  String get dashboardCategoryLabel => 'Category';

  @override
  String get dashboardCopyHint => 'Save & Copy dashboard config';

  @override
  String get dashboardDeleteConfirm => 'YES, DELETE THIS DASHBOARD';

  @override
  String get dashboardDeleteHint => 'Delete dashboard';

  @override
  String get dashboardDeleteQuestion => 'Do you want to delete this dashboard?';

  @override
  String get dashboardDescriptionLabel => 'Description (optional)';

  @override
  String get dashboardNameLabel => 'Dashboard name';

  @override
  String get dashboardNotFound => 'Dashboard not found';

  @override
  String get dashboardPrivateLabel => 'Private';

  @override
  String get doneButton => 'Done';

  @override
  String get editMenuTitle => 'Edit';

  @override
  String get editorPlaceholder => 'Enter notes...';

  @override
  String get entryActions => 'Actions';

  @override
  String get entryLabelsActionSubtitle =>
      'Assign labels to organise this entry';

  @override
  String get entryTypeLabelChecklistItem => 'To Do';

  @override
  String get eventNameLabel => 'Event:';

  @override
  String get favoriteLabel => 'Favourite';

  @override
  String get fileMenuNewEllipsis => 'New ...';

  @override
  String get fileMenuNewEntry => 'New Entry';

  @override
  String get fileMenuNewScreenshot => 'Screenshot';

  @override
  String get fileMenuNewTask => 'Task';

  @override
  String get fileMenuTitle => 'File';

  @override
  String get habitActiveFromLabel => 'Start date';

  @override
  String get habitArchivedLabel => 'Archived';

  @override
  String get habitCategoryHint => 'Select category';

  @override
  String get habitCategoryLabel => 'Category';

  @override
  String get habitDashboardHint => 'Select dashboard';

  @override
  String get habitDashboardLabel => 'Dashboard';

  @override
  String get habitDeleteConfirm => 'YES, DELETE THIS HABIT';

  @override
  String get habitDeleteQuestion => 'Do you want to delete this habit?';

  @override
  String get habitPriorityLabel => 'Priority';

  @override
  String get habitShowAlertAtLabel => 'Show alert at';

  @override
  String get habitShowFromLabel => 'Show from';

  @override
  String get habitsCompletedHeader => 'Completed';

  @override
  String get habitsFilterAll => 'all';

  @override
  String get habitsFilterCompleted => 'done';

  @override
  String get habitsFilterOpenNow => 'due';

  @override
  String get habitsFilterPendingLater => 'later';

  @override
  String get habitsOpenHeader => 'Due now';

  @override
  String get habitsPendingLaterHeader => 'Later today';

  @override
  String get journalCopyImageLabel => 'Copy image';

  @override
  String get journalDateFromLabel => 'Date from:';

  @override
  String get journalDateInvalid => 'Invalid Date Range';

  @override
  String get journalDateNowButton => 'Now';

  @override
  String get journalDateSaveButton => 'SAVE';

  @override
  String get journalDateToLabel => 'Date to:';

  @override
  String get journalDeleteConfirm => 'YES, DELETE THIS ENTRY';

  @override
  String get journalDeleteHint => 'Delete entry';

  @override
  String get journalDeleteQuestion =>
      'Do you want to delete this journal entry?';

  @override
  String get journalDurationLabel => 'Duration:';

  @override
  String get journalFavoriteTooltip => 'starred only';

  @override
  String get journalFlaggedTooltip => 'flagged only';

  @override
  String get journalHideMapHint => 'Hide map';

  @override
  String get journalLinkFromHint => 'Link from';

  @override
  String get journalLinkToHint => 'Link to';

  @override
  String get journalLinkedFromLabel => 'Linked from:';

  @override
  String get journalPrivateTooltip => 'private only';

  @override
  String get journalSearchHint => 'Search journal…';

  @override
  String get journalShowMapHint => 'Show map';

  @override
  String get journalToggleFlaggedTitle => 'Flagged';

  @override
  String get journalTogglePrivateTitle => 'Private';

  @override
  String get journalToggleStarredTitle => 'Favourite';

  @override
  String get journalUnlinkConfirm => 'YES, UNLINK ENTRY';

  @override
  String get journalUnlinkHint => 'Unlink';

  @override
  String get journalUnlinkQuestion =>
      'Are you sure you want to unlink this entry?';

  @override
  String get maintenanceDeleteEditorDb => 'Delete editor drafts database';

  @override
  String get maintenanceDeleteEditorDbDescription =>
      'Delete editor drafts database';

  @override
  String get maintenanceDeleteSyncDb => 'Delete sync database';

  @override
  String get maintenanceDeleteSyncDbDescription => 'Delete sync database';

  @override
  String get maintenancePurgeDeleted => 'Purge deleted items';

  @override
  String get maintenancePurgeDeletedDescription =>
      'Purge all deleted items permanently';

  @override
  String get maintenanceReSync => 'Re-sync messages';

  @override
  String get maintenanceReSyncDescription => 'Re-sync messages from server';

  @override
  String get maintenanceRecreateFts5 => 'Recreate full-text index';

  @override
  String get maintenanceRecreateFts5Description =>
      'Recreate full-text search index';

  @override
  String get maintenanceSyncDefinitions =>
      'Sync measurables, dashboards, habits, categories, AI settings';

  @override
  String get maintenanceSyncDefinitionsDescription =>
      'Sync measurables, dashboards, habits, categories, and AI settings';

  @override
  String get measurableDeleteConfirm => 'YES, DELETE THIS MEASURABLE';

  @override
  String get measurableDeleteQuestion =>
      'Do you want to delete this measurable data type?';

  @override
  String get measurableNotFound => 'Measurable not found';

  @override
  String get navTabTitleCalendar => 'DailyOS';

  @override
  String get navTabTitleHabits => 'Habits';

  @override
  String get navTabTitleInsights => 'Insights';

  @override
  String get navTabTitleJournal => 'Logbook';

  @override
  String get navTabTitleSettings => 'Settings';

  @override
  String get navTabTitleTasks => 'Tasks';

  @override
  String get outboxMonitorLabelError => 'error';

  @override
  String get outboxMonitorLabelPending => 'pending';

  @override
  String get outboxMonitorLabelSent => 'sent';

  @override
  String get outboxMonitorNoAttachment => 'no attachment';

  @override
  String get outboxMonitorRetries => 'retries';

  @override
  String get outboxMonitorRetry => 'retry';

  @override
  String get saveLabel => 'Save';

  @override
  String get searchHint => 'Search…';

  @override
  String get selectColor => 'Select Colour';

  @override
  String get sessionRatingEnergyQuestion => 'How energised did you feel?';

  @override
  String get settingsAboutAppInformation => 'App Information';

  @override
  String get settingsAboutAppTagline => 'Your Personal Journal';

  @override
  String get settingsAboutBuildType => 'Build Type';

  @override
  String get settingsAboutJournalEntries => 'Journal Entries';

  @override
  String get settingsAboutPlatform => 'Platform';

  @override
  String get settingsAboutTitle => 'About Lotti';

  @override
  String get settingsAboutVersion => 'Version';

  @override
  String get settingsAboutYourData => 'Your Data';

  @override
  String get settingsAdvancedMaintenanceSubtitle =>
      'Perform maintenance tasks to optimise application performance';

  @override
  String get settingsAdvancedTitle => 'Advanced Settings';

  @override
  String get settingsCategoriesEmptyStateHint =>
      'Create a category to organise your entries';

  @override
  String get settingsLabelsColorHeading => 'Select a colour';

  @override
  String get settingsLabelsSubtitle => 'Organise tasks with coloured labels';

  @override
  String get settingsSyncConflictsSubtitle =>
      'Resolve synchronisation conflicts to ensure data consistency';
}

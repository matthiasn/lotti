import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_cs.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ro.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('cs'),
    Locale('de'),
    Locale('en', 'GB'),
    Locale('es'),
    Locale('fr'),
    Locale('ro'),
  ];

  /// No description provided for @activeLabel.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeLabel;

  /// No description provided for @addActionAddAudioRecording.
  ///
  /// In en, this message translates to:
  /// **'Audio Recording'**
  String get addActionAddAudioRecording;

  /// No description provided for @addActionAddChecklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get addActionAddChecklist;

  /// No description provided for @addActionAddEvent.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get addActionAddEvent;

  /// No description provided for @addActionAddImageFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste Image'**
  String get addActionAddImageFromClipboard;

  /// No description provided for @addActionAddScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Screenshot'**
  String get addActionAddScreenshot;

  /// No description provided for @addActionAddTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get addActionAddTask;

  /// No description provided for @addActionAddText.
  ///
  /// In en, this message translates to:
  /// **'Text Entry'**
  String get addActionAddText;

  /// No description provided for @addActionAddTimer.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get addActionAddTimer;

  /// No description provided for @addActionAddTimeRecording.
  ///
  /// In en, this message translates to:
  /// **'Timer Entry'**
  String get addActionAddTimeRecording;

  /// No description provided for @addActionImportImage.
  ///
  /// In en, this message translates to:
  /// **'Import Image'**
  String get addActionImportImage;

  /// No description provided for @addHabitCommentLabel.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get addHabitCommentLabel;

  /// No description provided for @addHabitDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Completed at'**
  String get addHabitDateLabel;

  /// No description provided for @addMeasurementCommentLabel.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get addMeasurementCommentLabel;

  /// No description provided for @addMeasurementDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Observed at'**
  String get addMeasurementDateLabel;

  /// No description provided for @addMeasurementSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get addMeasurementSaveButton;

  /// No description provided for @addToDictionary.
  ///
  /// In en, this message translates to:
  /// **'Add to Dictionary'**
  String get addToDictionary;

  /// No description provided for @addToDictionaryDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Term already exists in dictionary'**
  String get addToDictionaryDuplicate;

  /// No description provided for @addToDictionaryNoCategory.
  ///
  /// In en, this message translates to:
  /// **'Cannot add to dictionary: task has no category'**
  String get addToDictionaryNoCategory;

  /// No description provided for @addToDictionarySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save dictionary'**
  String get addToDictionarySaveFailed;

  /// No description provided for @addToDictionarySuccess.
  ///
  /// In en, this message translates to:
  /// **'Term added to dictionary'**
  String get addToDictionarySuccess;

  /// No description provided for @addToDictionaryTooLong.
  ///
  /// In en, this message translates to:
  /// **'Term too long (max 50 characters)'**
  String get addToDictionaryTooLong;

  /// No description provided for @agentABComparisonChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose {option}'**
  String agentABComparisonChoose(String option);

  /// No description provided for @agentABComparisonOption.
  ///
  /// In en, this message translates to:
  /// **'Option {option}'**
  String agentABComparisonOption(String option);

  /// No description provided for @agentABComparisonPrefer.
  ///
  /// In en, this message translates to:
  /// **'I prefer Option {option}'**
  String agentABComparisonPrefer(String option);

  /// No description provided for @agentBinaryChoiceNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get agentBinaryChoiceNo;

  /// No description provided for @agentBinaryChoiceYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get agentBinaryChoiceYes;

  /// No description provided for @agentCategoryRatingsScaleMax.
  ///
  /// In en, this message translates to:
  /// **'Fix first'**
  String get agentCategoryRatingsScaleMax;

  /// No description provided for @agentCategoryRatingsScaleMin.
  ///
  /// In en, this message translates to:
  /// **'Leave it'**
  String get agentCategoryRatingsScaleMin;

  /// No description provided for @agentCategoryRatingsStarLabel.
  ///
  /// In en, this message translates to:
  /// **'{starIndex} of {totalStars} stars'**
  String agentCategoryRatingsStarLabel(int starIndex, int totalStars);

  /// No description provided for @agentCategoryRatingsSubmit.
  ///
  /// In en, this message translates to:
  /// **'Use These Priorities'**
  String get agentCategoryRatingsSubmit;

  /// No description provided for @agentCategoryRatingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How important is it that I fix each of these? 1 means leave it alone, 5 means fix it first.'**
  String get agentCategoryRatingsSubtitle;

  /// No description provided for @agentCategoryRatingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Help Me Prioritize'**
  String get agentCategoryRatingsTitle;

  /// No description provided for @agentControlsActionError.
  ///
  /// In en, this message translates to:
  /// **'Action failed: {error}'**
  String agentControlsActionError(String error);

  /// No description provided for @agentControlsDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get agentControlsDeleteButton;

  /// No description provided for @agentControlsDeleteDialogContent.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete all data for this agent, including its history, reports, and observations. This cannot be undone.'**
  String get agentControlsDeleteDialogContent;

  /// No description provided for @agentControlsDeleteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Agent?'**
  String get agentControlsDeleteDialogTitle;

  /// No description provided for @agentControlsDestroyButton.
  ///
  /// In en, this message translates to:
  /// **'Destroy'**
  String get agentControlsDestroyButton;

  /// No description provided for @agentControlsDestroyDialogContent.
  ///
  /// In en, this message translates to:
  /// **'This will permanently deactivate the agent. Its history will be preserved for audit.'**
  String get agentControlsDestroyDialogContent;

  /// No description provided for @agentControlsDestroyDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Destroy Agent?'**
  String get agentControlsDestroyDialogTitle;

  /// No description provided for @agentControlsDestroyedMessage.
  ///
  /// In en, this message translates to:
  /// **'This agent has been destroyed.'**
  String get agentControlsDestroyedMessage;

  /// No description provided for @agentControlsPauseButton.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get agentControlsPauseButton;

  /// No description provided for @agentControlsReanalyzeButton.
  ///
  /// In en, this message translates to:
  /// **'Re-analyze'**
  String get agentControlsReanalyzeButton;

  /// No description provided for @agentControlsResumeButton.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get agentControlsResumeButton;

  /// No description provided for @agentConversationEmpty.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet.'**
  String get agentConversationEmpty;

  /// No description provided for @agentConversationThreadSummary.
  ///
  /// In en, this message translates to:
  /// **'{messageCount} messages, {toolCallCount} tool calls · {shortId}'**
  String agentConversationThreadSummary(
    int messageCount,
    int toolCallCount,
    String shortId,
  );

  /// No description provided for @agentConversationTokenCount.
  ///
  /// In en, this message translates to:
  /// **'{tokenCount} tokens'**
  String agentConversationTokenCount(String tokenCount);

  /// No description provided for @agentDefaultProfileLabel.
  ///
  /// In en, this message translates to:
  /// **'Default inference profile'**
  String get agentDefaultProfileLabel;

  /// No description provided for @agentDetailErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading agent: {error}'**
  String agentDetailErrorLoading(String error);

  /// No description provided for @agentDetailNotFound.
  ///
  /// In en, this message translates to:
  /// **'Agent not found.'**
  String get agentDetailNotFound;

  /// No description provided for @agentDetailUnexpectedType.
  ///
  /// In en, this message translates to:
  /// **'Unexpected entity type.'**
  String get agentDetailUnexpectedType;

  /// No description provided for @agentEvolutionApprovalRate.
  ///
  /// In en, this message translates to:
  /// **'Approval Rate'**
  String get agentEvolutionApprovalRate;

  /// No description provided for @agentEvolutionChartMttrTrend.
  ///
  /// In en, this message translates to:
  /// **'MTTR Trend'**
  String get agentEvolutionChartMttrTrend;

  /// No description provided for @agentEvolutionChartSuccessRateTrend.
  ///
  /// In en, this message translates to:
  /// **'Success Trend'**
  String get agentEvolutionChartSuccessRateTrend;

  /// No description provided for @agentEvolutionChartVersionPerformance.
  ///
  /// In en, this message translates to:
  /// **'By Version'**
  String get agentEvolutionChartVersionPerformance;

  /// No description provided for @agentEvolutionChartWakeHistory.
  ///
  /// In en, this message translates to:
  /// **'Wake History'**
  String get agentEvolutionChartWakeHistory;

  /// No description provided for @agentEvolutionChatPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Share feedback or ask about performance...'**
  String get agentEvolutionChatPlaceholder;

  /// No description provided for @agentEvolutionCurrentDirectives.
  ///
  /// In en, this message translates to:
  /// **'Current Directives'**
  String get agentEvolutionCurrentDirectives;

  /// No description provided for @agentEvolutionDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get agentEvolutionDashboardTitle;

  /// No description provided for @agentEvolutionHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Evolution History'**
  String get agentEvolutionHistoryTitle;

  /// No description provided for @agentEvolutionMetricActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get agentEvolutionMetricActive;

  /// No description provided for @agentEvolutionMetricAvgDuration.
  ///
  /// In en, this message translates to:
  /// **'Avg Duration'**
  String get agentEvolutionMetricAvgDuration;

  /// No description provided for @agentEvolutionMetricFailures.
  ///
  /// In en, this message translates to:
  /// **'Failures'**
  String get agentEvolutionMetricFailures;

  /// No description provided for @agentEvolutionMetricSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get agentEvolutionMetricSuccess;

  /// No description provided for @agentEvolutionMetricWakes.
  ///
  /// In en, this message translates to:
  /// **'Wakes'**
  String get agentEvolutionMetricWakes;

  /// No description provided for @agentEvolutionNoSessions.
  ///
  /// In en, this message translates to:
  /// **'No evolution sessions yet'**
  String get agentEvolutionNoSessions;

  /// No description provided for @agentEvolutionNoteRecorded.
  ///
  /// In en, this message translates to:
  /// **'Note Recorded'**
  String get agentEvolutionNoteRecorded;

  /// No description provided for @agentEvolutionProposalApprovalFailed.
  ///
  /// In en, this message translates to:
  /// **'Approval failed — please try again'**
  String get agentEvolutionProposalApprovalFailed;

  /// No description provided for @agentEvolutionProposalRationale.
  ///
  /// In en, this message translates to:
  /// **'Rationale'**
  String get agentEvolutionProposalRationale;

  /// No description provided for @agentEvolutionProposalRejected.
  ///
  /// In en, this message translates to:
  /// **'Proposal rejected — continue the conversation'**
  String get agentEvolutionProposalRejected;

  /// No description provided for @agentEvolutionProposalTitle.
  ///
  /// In en, this message translates to:
  /// **'Proposed Changes'**
  String get agentEvolutionProposalTitle;

  /// No description provided for @agentEvolutionProposedDirectives.
  ///
  /// In en, this message translates to:
  /// **'Proposed Directives'**
  String get agentEvolutionProposedDirectives;

  /// No description provided for @agentEvolutionSessionAbandoned.
  ///
  /// In en, this message translates to:
  /// **'Session ended without changes'**
  String get agentEvolutionSessionAbandoned;

  /// No description provided for @agentEvolutionSessionCompleted.
  ///
  /// In en, this message translates to:
  /// **'Session completed — version {version} created'**
  String agentEvolutionSessionCompleted(int version);

  /// No description provided for @agentEvolutionSessionCount.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get agentEvolutionSessionCount;

  /// No description provided for @agentEvolutionSessionError.
  ///
  /// In en, this message translates to:
  /// **'Failed to start evolution session'**
  String get agentEvolutionSessionError;

  /// No description provided for @agentEvolutionSessionProgress.
  ///
  /// In en, this message translates to:
  /// **'Session {sessionNumber} of {totalSessions}'**
  String agentEvolutionSessionProgress(int sessionNumber, int totalSessions);

  /// No description provided for @agentEvolutionSessionStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting evolution session...'**
  String get agentEvolutionSessionStarting;

  /// No description provided for @agentEvolutionSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Evolution #{sessionNumber}'**
  String agentEvolutionSessionTitle(int sessionNumber);

  /// No description provided for @agentEvolutionSoulCurrentField.
  ///
  /// In en, this message translates to:
  /// **'Current — {field}'**
  String agentEvolutionSoulCurrentField(String field);

  /// No description provided for @agentEvolutionSoulProposedField.
  ///
  /// In en, this message translates to:
  /// **'Proposed — {field}'**
  String agentEvolutionSoulProposedField(String field);

  /// No description provided for @agentEvolutionStatusAbandoned.
  ///
  /// In en, this message translates to:
  /// **'Abandoned'**
  String get agentEvolutionStatusAbandoned;

  /// No description provided for @agentEvolutionStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get agentEvolutionStatusActive;

  /// No description provided for @agentEvolutionStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get agentEvolutionStatusCompleted;

  /// No description provided for @agentEvolutionTimelineFeedbackLabel.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get agentEvolutionTimelineFeedbackLabel;

  /// No description provided for @agentEvolutionVersionProposed.
  ///
  /// In en, this message translates to:
  /// **'Version proposed'**
  String get agentEvolutionVersionProposed;

  /// No description provided for @agentFeedbackCategoryAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get agentFeedbackCategoryAccuracy;

  /// No description provided for @agentFeedbackCategoryBreakdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Category Breakdown'**
  String get agentFeedbackCategoryBreakdownTitle;

  /// No description provided for @agentFeedbackCategoryCommunication.
  ///
  /// In en, this message translates to:
  /// **'Communication'**
  String get agentFeedbackCategoryCommunication;

  /// No description provided for @agentFeedbackCategoryGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get agentFeedbackCategoryGeneral;

  /// No description provided for @agentFeedbackCategoryPrioritization.
  ///
  /// In en, this message translates to:
  /// **'Prioritization'**
  String get agentFeedbackCategoryPrioritization;

  /// No description provided for @agentFeedbackCategoryTimeliness.
  ///
  /// In en, this message translates to:
  /// **'Timeliness'**
  String get agentFeedbackCategoryTimeliness;

  /// No description provided for @agentFeedbackCategoryTooling.
  ///
  /// In en, this message translates to:
  /// **'Tooling'**
  String get agentFeedbackCategoryTooling;

  /// No description provided for @agentFeedbackClassificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Feedback Classification'**
  String get agentFeedbackClassificationTitle;

  /// No description provided for @agentFeedbackExcellenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Notes of Excellence'**
  String get agentFeedbackExcellenceTitle;

  /// No description provided for @agentFeedbackGrievancesTitle.
  ///
  /// In en, this message translates to:
  /// **'Grievances'**
  String get agentFeedbackGrievancesTitle;

  /// No description provided for @agentFeedbackHighPriorityTitle.
  ///
  /// In en, this message translates to:
  /// **'High-Priority Feedback'**
  String get agentFeedbackHighPriorityTitle;

  /// No description provided for @agentFeedbackItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String agentFeedbackItemCount(int count);

  /// No description provided for @agentFeedbackSourceDecision.
  ///
  /// In en, this message translates to:
  /// **'Decision'**
  String get agentFeedbackSourceDecision;

  /// No description provided for @agentFeedbackSourceMetric.
  ///
  /// In en, this message translates to:
  /// **'Metric'**
  String get agentFeedbackSourceMetric;

  /// No description provided for @agentFeedbackSourceObservation.
  ///
  /// In en, this message translates to:
  /// **'Observation'**
  String get agentFeedbackSourceObservation;

  /// No description provided for @agentFeedbackSourceRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get agentFeedbackSourceRating;

  /// No description provided for @agentInstancesEmptyFiltered.
  ///
  /// In en, this message translates to:
  /// **'No instances match your filters.'**
  String get agentInstancesEmptyFiltered;

  /// No description provided for @agentInstancesFilterClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get agentInstancesFilterClearAll;

  /// No description provided for @agentInstancesFilterClearSection.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get agentInstancesFilterClearSection;

  /// No description provided for @agentInstancesFilterSectionSoul.
  ///
  /// In en, this message translates to:
  /// **'Soul'**
  String get agentInstancesFilterSectionSoul;

  /// No description provided for @agentInstancesFilterSectionStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get agentInstancesFilterSectionStatus;

  /// No description provided for @agentInstancesFilterSectionType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get agentInstancesFilterSectionType;

  /// No description provided for @agentInstancesGroupActiveCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 active} other{{count} active}}'**
  String agentInstancesGroupActiveCount(int count);

  /// No description provided for @agentInstancesGroupBySoul.
  ///
  /// In en, this message translates to:
  /// **'Soul'**
  String get agentInstancesGroupBySoul;

  /// No description provided for @agentInstancesGroupByStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get agentInstancesGroupByStatus;

  /// No description provided for @agentInstancesGroupByType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get agentInstancesGroupByType;

  /// No description provided for @agentInstancesKindEvolution.
  ///
  /// In en, this message translates to:
  /// **'Evolution'**
  String get agentInstancesKindEvolution;

  /// No description provided for @agentInstancesKindTaskAgent.
  ///
  /// In en, this message translates to:
  /// **'Task Agent'**
  String get agentInstancesKindTaskAgent;

  /// No description provided for @agentInstancesPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Agent Instances'**
  String get agentInstancesPageTitle;

  /// No description provided for @agentInstancesResultCountAll.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 instance} other{{count} instances}}'**
  String agentInstancesResultCountAll(int count);

  /// No description provided for @agentInstancesResultCountFiltered.
  ///
  /// In en, this message translates to:
  /// **'{filtered} of {total}'**
  String agentInstancesResultCountFiltered(int filtered, int total);

  /// No description provided for @agentInstancesSearchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get agentInstancesSearchClear;

  /// No description provided for @agentInstancesSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search instances…'**
  String get agentInstancesSearchPlaceholder;

  /// No description provided for @agentInstancesSortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get agentInstancesSortName;

  /// No description provided for @agentInstancesSortOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get agentInstancesSortOldest;

  /// No description provided for @agentInstancesSortRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get agentInstancesSortRecent;

  /// No description provided for @agentInstancesTitle.
  ///
  /// In en, this message translates to:
  /// **'Instances'**
  String get agentInstancesTitle;

  /// No description provided for @agentInstancesToolbarFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get agentInstancesToolbarFilters;

  /// No description provided for @agentInstancesToolbarGroupBy.
  ///
  /// In en, this message translates to:
  /// **'Group by'**
  String get agentInstancesToolbarGroupBy;

  /// No description provided for @agentInstancesUnassignedSoul.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get agentInstancesUnassignedSoul;

  /// No description provided for @agentLifecycleActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get agentLifecycleActive;

  /// No description provided for @agentLifecycleCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get agentLifecycleCreated;

  /// No description provided for @agentLifecycleDestroyed.
  ///
  /// In en, this message translates to:
  /// **'Destroyed'**
  String get agentLifecycleDestroyed;

  /// No description provided for @agentLifecycleDormant.
  ///
  /// In en, this message translates to:
  /// **'Dormant'**
  String get agentLifecycleDormant;

  /// No description provided for @agentMessageKindAction.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get agentMessageKindAction;

  /// No description provided for @agentMessageKindMilestone.
  ///
  /// In en, this message translates to:
  /// **'Milestone'**
  String get agentMessageKindMilestone;

  /// No description provided for @agentMessageKindObservation.
  ///
  /// In en, this message translates to:
  /// **'Observation'**
  String get agentMessageKindObservation;

  /// No description provided for @agentMessageKindRetraction.
  ///
  /// In en, this message translates to:
  /// **'Retraction'**
  String get agentMessageKindRetraction;

  /// No description provided for @agentMessageKindSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get agentMessageKindSummary;

  /// No description provided for @agentMessageKindSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get agentMessageKindSystem;

  /// No description provided for @agentMessageKindSystemPrompt.
  ///
  /// In en, this message translates to:
  /// **'System Prompt'**
  String get agentMessageKindSystemPrompt;

  /// No description provided for @agentMessageKindThought.
  ///
  /// In en, this message translates to:
  /// **'Thought'**
  String get agentMessageKindThought;

  /// No description provided for @agentMessageKindToolResult.
  ///
  /// In en, this message translates to:
  /// **'Tool Result'**
  String get agentMessageKindToolResult;

  /// No description provided for @agentMessageKindUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get agentMessageKindUser;

  /// No description provided for @agentMessagePayloadEmpty.
  ///
  /// In en, this message translates to:
  /// **'(no content)'**
  String get agentMessagePayloadEmpty;

  /// No description provided for @agentMessagesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages yet.'**
  String get agentMessagesEmpty;

  /// No description provided for @agentMessagesErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Failed to load messages: {error}'**
  String agentMessagesErrorLoading(String error);

  /// No description provided for @agentObservationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No observations recorded yet.'**
  String get agentObservationsEmpty;

  /// No description provided for @agentPendingWakesActivityHourDetail.
  ///
  /// In en, this message translates to:
  /// **'{hour}: {count, plural, =1{1 wake} other{{count} wakes}} ({reasons})'**
  String agentPendingWakesActivityHourDetail(
    String hour,
    int count,
    String reasons,
  );

  /// No description provided for @agentPendingWakesActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Wake Activity (24h)'**
  String get agentPendingWakesActivityTitle;

  /// No description provided for @agentPendingWakesActivityTotal.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 total wake} other{{count} total wakes}}'**
  String agentPendingWakesActivityTotal(int count);

  /// No description provided for @agentPendingWakesDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove wake'**
  String get agentPendingWakesDeleteTooltip;

  /// No description provided for @agentPendingWakesEmptyFiltered.
  ///
  /// In en, this message translates to:
  /// **'No wakes match your filters.'**
  String get agentPendingWakesEmptyFiltered;

  /// No description provided for @agentPendingWakesFilterSectionType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get agentPendingWakesFilterSectionType;

  /// No description provided for @agentPendingWakesGroupByType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get agentPendingWakesGroupByType;

  /// No description provided for @agentPendingWakesPendingLabel.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get agentPendingWakesPendingLabel;

  /// No description provided for @agentPendingWakesRunningHeading.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Running now} other{Running now ({count})}}'**
  String agentPendingWakesRunningHeading(int count);

  /// No description provided for @agentPendingWakesScheduledLabel.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get agentPendingWakesScheduledLabel;

  /// No description provided for @agentPendingWakesSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search wakes…'**
  String get agentPendingWakesSearchPlaceholder;

  /// No description provided for @agentPendingWakesSortDueLatest.
  ///
  /// In en, this message translates to:
  /// **'Due latest'**
  String get agentPendingWakesSortDueLatest;

  /// No description provided for @agentPendingWakesSortDueSoonest.
  ///
  /// In en, this message translates to:
  /// **'Due soonest'**
  String get agentPendingWakesSortDueSoonest;

  /// No description provided for @agentPendingWakesTitle.
  ///
  /// In en, this message translates to:
  /// **'Wake Cycles'**
  String get agentPendingWakesTitle;

  /// No description provided for @agentReportHistoryBadge.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get agentReportHistoryBadge;

  /// No description provided for @agentReportHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No report snapshots yet.'**
  String get agentReportHistoryEmpty;

  /// No description provided for @agentReportHistoryError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred while loading the report history.'**
  String get agentReportHistoryError;

  /// No description provided for @agentReportNone.
  ///
  /// In en, this message translates to:
  /// **'No report available yet.'**
  String get agentReportNone;

  /// No description provided for @agentRitualReviewAction.
  ///
  /// In en, this message translates to:
  /// **'Start Conversation'**
  String get agentRitualReviewAction;

  /// No description provided for @agentRitualReviewNegativeSignals.
  ///
  /// In en, this message translates to:
  /// **'Negative'**
  String get agentRitualReviewNegativeSignals;

  /// No description provided for @agentRitualReviewNeutralSignals.
  ///
  /// In en, this message translates to:
  /// **'Neutral'**
  String get agentRitualReviewNeutralSignals;

  /// No description provided for @agentRitualReviewNoFeedback.
  ///
  /// In en, this message translates to:
  /// **'No feedback signals in this window'**
  String get agentRitualReviewNoFeedback;

  /// No description provided for @agentRitualReviewNoNegativeSignals.
  ///
  /// In en, this message translates to:
  /// **'No negative feedback signals in this tab'**
  String get agentRitualReviewNoNegativeSignals;

  /// No description provided for @agentRitualReviewNoNeutralSignals.
  ///
  /// In en, this message translates to:
  /// **'No neutral feedback signals in this tab'**
  String get agentRitualReviewNoNeutralSignals;

  /// No description provided for @agentRitualReviewNoPositiveSignals.
  ///
  /// In en, this message translates to:
  /// **'No positive feedback signals in this tab'**
  String get agentRitualReviewNoPositiveSignals;

  /// No description provided for @agentRitualReviewPositiveSignals.
  ///
  /// In en, this message translates to:
  /// **'Positive'**
  String get agentRitualReviewPositiveSignals;

  /// No description provided for @agentRitualReviewProposalSection.
  ///
  /// In en, this message translates to:
  /// **'Current Proposal'**
  String get agentRitualReviewProposalSection;

  /// No description provided for @agentRitualReviewSessionHistory.
  ///
  /// In en, this message translates to:
  /// **'Session History'**
  String get agentRitualReviewSessionHistory;

  /// No description provided for @agentRitualReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'1-on-1'**
  String get agentRitualReviewTitle;

  /// No description provided for @agentRitualSummaryApprovedChangesHeading.
  ///
  /// In en, this message translates to:
  /// **'Approved changes'**
  String get agentRitualSummaryApprovedChangesHeading;

  /// No description provided for @agentRitualSummaryConversationHeading.
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get agentRitualSummaryConversationHeading;

  /// No description provided for @agentRitualSummaryRecapHeading.
  ///
  /// In en, this message translates to:
  /// **'Session Recap'**
  String get agentRitualSummaryRecapHeading;

  /// No description provided for @agentRitualSummaryRoleAssistant.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get agentRitualSummaryRoleAssistant;

  /// No description provided for @agentRitualSummaryRoleUser.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get agentRitualSummaryRoleUser;

  /// No description provided for @agentRitualSummaryStartHint.
  ///
  /// In en, this message translates to:
  /// **'Start a 1-on-1 to review what bothered you, what worked, and what should change next.'**
  String get agentRitualSummaryStartHint;

  /// No description provided for @agentRitualSummarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recent 1-on-1s, real wake activity, and the changes you agreed to.'**
  String get agentRitualSummarySubtitle;

  /// No description provided for @agentRitualSummaryTokensSinceLast.
  ///
  /// In en, this message translates to:
  /// **'Tokens since last 1-on-1'**
  String get agentRitualSummaryTokensSinceLast;

  /// No description provided for @agentRitualSummaryWakeHistory30Days.
  ///
  /// In en, this message translates to:
  /// **'Wake activity (last 30 days)'**
  String get agentRitualSummaryWakeHistory30Days;

  /// No description provided for @agentRitualSummaryWakesSinceLast.
  ///
  /// In en, this message translates to:
  /// **'Wakes since last 1-on-1'**
  String get agentRitualSummaryWakesSinceLast;

  /// No description provided for @agentRunningIndicator.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get agentRunningIndicator;

  /// No description provided for @agentSessionProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Session Progress'**
  String get agentSessionProgressTitle;

  /// No description provided for @agentSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Templates, instances, and monitoring'**
  String get agentSettingsSubtitle;

  /// No description provided for @agentSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get agentSettingsTitle;

  /// No description provided for @agentSoulAntiSycophancyLabel.
  ///
  /// In en, this message translates to:
  /// **'Anti-Sycophancy Policy'**
  String get agentSoulAntiSycophancyLabel;

  /// No description provided for @agentSoulAssignedTemplatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Assigned Templates'**
  String get agentSoulAssignedTemplatesTitle;

  /// No description provided for @agentSoulAssignmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Soul'**
  String get agentSoulAssignmentLabel;

  /// No description provided for @agentSoulCoachingStyleLabel.
  ///
  /// In en, this message translates to:
  /// **'Coaching Style'**
  String get agentSoulCoachingStyleLabel;

  /// No description provided for @agentSoulCreatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Soul created'**
  String get agentSoulCreatedSuccess;

  /// No description provided for @agentSoulCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Soul'**
  String get agentSoulCreateTitle;

  /// No description provided for @agentSoulDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will remove the soul and all its versions.'**
  String get agentSoulDeleteConfirmBody;

  /// No description provided for @agentSoulDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Soul'**
  String get agentSoulDeleteConfirmTitle;

  /// No description provided for @agentSoulDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Soul Detail'**
  String get agentSoulDetailTitle;

  /// No description provided for @agentSoulDisplayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get agentSoulDisplayNameLabel;

  /// No description provided for @agentSoulEvolutionHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Soul Evolution History'**
  String get agentSoulEvolutionHistoryTitle;

  /// No description provided for @agentSoulEvolutionNoSessions.
  ///
  /// In en, this message translates to:
  /// **'No soul evolution sessions yet'**
  String get agentSoulEvolutionNoSessions;

  /// No description provided for @agentSoulFieldAntiSycophancy.
  ///
  /// In en, this message translates to:
  /// **'Anti-Sycophancy'**
  String get agentSoulFieldAntiSycophancy;

  /// No description provided for @agentSoulFieldCoachingStyle.
  ///
  /// In en, this message translates to:
  /// **'Coaching Style'**
  String get agentSoulFieldCoachingStyle;

  /// No description provided for @agentSoulFieldToneBounds.
  ///
  /// In en, this message translates to:
  /// **'Tone Bounds'**
  String get agentSoulFieldToneBounds;

  /// No description provided for @agentSoulFieldVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get agentSoulFieldVoice;

  /// No description provided for @agentSoulInfoTab.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get agentSoulInfoTab;

  /// No description provided for @agentSoulNoneAssigned.
  ///
  /// In en, this message translates to:
  /// **'No soul assigned'**
  String get agentSoulNoneAssigned;

  /// No description provided for @agentSoulNotFound.
  ///
  /// In en, this message translates to:
  /// **'Soul not found'**
  String get agentSoulNotFound;

  /// No description provided for @agentSoulProposalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Proposed personality changes'**
  String get agentSoulProposalSubtitle;

  /// No description provided for @agentSoulProposalTitle.
  ///
  /// In en, this message translates to:
  /// **'Soul Personality Proposal'**
  String get agentSoulProposalTitle;

  /// No description provided for @agentSoulReviewHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Refine personality across all templates sharing this soul. The evolution agent sees feedback from every template that uses this personality.'**
  String get agentSoulReviewHeroSubtitle;

  /// No description provided for @agentSoulReviewStartAction.
  ///
  /// In en, this message translates to:
  /// **'Start Personality Review'**
  String get agentSoulReviewStartAction;

  /// No description provided for @agentSoulReviewStartHint.
  ///
  /// In en, this message translates to:
  /// **'Start a personality-focused session to review feedback and evolve voice, tone, coaching style, and directness.'**
  String get agentSoulReviewStartHint;

  /// No description provided for @agentSoulReviewTemplateCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 template sharing this soul} other{{count} templates sharing this soul}}'**
  String agentSoulReviewTemplateCount(int count);

  /// No description provided for @agentSoulReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Soul 1-on-1'**
  String get agentSoulReviewTitle;

  /// No description provided for @agentSoulRollbackAction.
  ///
  /// In en, this message translates to:
  /// **'Roll Back to This Version'**
  String get agentSoulRollbackAction;

  /// No description provided for @agentSoulRollbackConfirm.
  ///
  /// In en, this message translates to:
  /// **'Roll back to version {version}? All templates using this soul will pick up the change.'**
  String agentSoulRollbackConfirm(int version);

  /// No description provided for @agentSoulSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Soul'**
  String get agentSoulSelectTitle;

  /// No description provided for @agentSoulsEmptyFiltered.
  ///
  /// In en, this message translates to:
  /// **'No souls match your filters.'**
  String get agentSoulsEmptyFiltered;

  /// No description provided for @agentSoulSettingsTab.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get agentSoulSettingsTab;

  /// No description provided for @agentSoulsSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search souls…'**
  String get agentSoulsSearchPlaceholder;

  /// No description provided for @agentSoulsTitle.
  ///
  /// In en, this message translates to:
  /// **'Souls'**
  String get agentSoulsTitle;

  /// No description provided for @agentSoulToneBoundsLabel.
  ///
  /// In en, this message translates to:
  /// **'Tone Bounds'**
  String get agentSoulToneBoundsLabel;

  /// No description provided for @agentSoulVersionHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Version History'**
  String get agentSoulVersionHistoryTitle;

  /// No description provided for @agentSoulVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String agentSoulVersionLabel(int version);

  /// No description provided for @agentSoulVersionSaved.
  ///
  /// In en, this message translates to:
  /// **'New soul version saved'**
  String get agentSoulVersionSaved;

  /// No description provided for @agentSoulVoiceDirectiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Voice Directive'**
  String get agentSoulVoiceDirectiveLabel;

  /// No description provided for @agentStateConsecutiveFailures.
  ///
  /// In en, this message translates to:
  /// **'Consecutive failures'**
  String get agentStateConsecutiveFailures;

  /// No description provided for @agentStateErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Failed to load state: {error}'**
  String agentStateErrorLoading(String error);

  /// No description provided for @agentStateHeading.
  ///
  /// In en, this message translates to:
  /// **'State Info'**
  String get agentStateHeading;

  /// No description provided for @agentStateLastWake.
  ///
  /// In en, this message translates to:
  /// **'Last wake'**
  String get agentStateLastWake;

  /// No description provided for @agentStateNextWake.
  ///
  /// In en, this message translates to:
  /// **'Next wake'**
  String get agentStateNextWake;

  /// No description provided for @agentStateRevision.
  ///
  /// In en, this message translates to:
  /// **'Revision'**
  String get agentStateRevision;

  /// No description provided for @agentStateSleepingUntil.
  ///
  /// In en, this message translates to:
  /// **'Sleeping until'**
  String get agentStateSleepingUntil;

  /// No description provided for @agentStateWakeCount.
  ///
  /// In en, this message translates to:
  /// **'Wake count'**
  String get agentStateWakeCount;

  /// No description provided for @agentStatsAllDayLegend.
  ///
  /// In en, this message translates to:
  /// **'All Day'**
  String get agentStatsAllDayLegend;

  /// No description provided for @agentStatsAverageLabel.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get agentStatsAverageLabel;

  /// No description provided for @agentStatsByTimeLegend.
  ///
  /// In en, this message translates to:
  /// **'Daily by {time}'**
  String agentStatsByTimeLegend(String time);

  /// No description provided for @agentStatsCacheRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Cache Rate'**
  String get agentStatsCacheRateLabel;

  /// No description provided for @agentStatsDailyUsageHeading.
  ///
  /// In en, this message translates to:
  /// **'Daily Usage'**
  String get agentStatsDailyUsageHeading;

  /// No description provided for @agentStatsInputLabel.
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get agentStatsInputLabel;

  /// No description provided for @agentStatsNoUsage.
  ///
  /// In en, this message translates to:
  /// **'No token usage recorded in the past 7 days.'**
  String get agentStatsNoUsage;

  /// No description provided for @agentStatsOutputLabel.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get agentStatsOutputLabel;

  /// No description provided for @agentStatsSourceActiveFor.
  ///
  /// In en, this message translates to:
  /// **'Active for {duration}'**
  String agentStatsSourceActiveFor(String duration);

  /// No description provided for @agentStatsSourceActivityHeading.
  ///
  /// In en, this message translates to:
  /// **'Agent Activity'**
  String get agentStatsSourceActivityHeading;

  /// No description provided for @agentStatsSourceWakes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 wake} other{{count} wakes}}'**
  String agentStatsSourceWakes(int count);

  /// No description provided for @agentStatsTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get agentStatsTabTitle;

  /// No description provided for @agentStatsThoughtsLabel.
  ///
  /// In en, this message translates to:
  /// **'Thoughts'**
  String get agentStatsThoughtsLabel;

  /// No description provided for @agentStatsTodayLabel.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get agentStatsTodayLabel;

  /// No description provided for @agentStatsTokensPerWakeLabel.
  ///
  /// In en, this message translates to:
  /// **'Tokens / Wake'**
  String get agentStatsTokensPerWakeLabel;

  /// No description provided for @agentStatsTokensUnit.
  ///
  /// In en, this message translates to:
  /// **'tokens'**
  String get agentStatsTokensUnit;

  /// No description provided for @agentStatsUsageAboveAverage.
  ///
  /// In en, this message translates to:
  /// **'You\'re using more tokens today than you usually do by {time}.'**
  String agentStatsUsageAboveAverage(String time);

  /// No description provided for @agentStatsUsageBelowAverage.
  ///
  /// In en, this message translates to:
  /// **'You\'re using fewer tokens today than you usually do by {time}.'**
  String agentStatsUsageBelowAverage(String time);

  /// No description provided for @agentStatsWakesLabel.
  ///
  /// In en, this message translates to:
  /// **'Wakes'**
  String get agentStatsWakesLabel;

  /// Label for the current value in an agent-proposed time entry edit diff.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get agentSuggestionTimeEntryUpdateCurrent;

  /// Marker shown next to an unchanged current value in an agent-proposed time entry edit diff.
  ///
  /// In en, this message translates to:
  /// **'(unchanged)'**
  String get agentSuggestionTimeEntryUpdateNoChange;

  /// Label for the proposed value in an agent-proposed time entry edit diff.
  ///
  /// In en, this message translates to:
  /// **'Proposed'**
  String get agentSuggestionTimeEntryUpdateProposed;

  /// Message shown when the original time entry cannot be loaded for an agent-proposed edit.
  ///
  /// In en, this message translates to:
  /// **'Original entry not available'**
  String get agentSuggestionTimeEntryUpdateUnavailable;

  /// No description provided for @agentTabActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get agentTabActivity;

  /// No description provided for @agentTabConversations.
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get agentTabConversations;

  /// No description provided for @agentTabObservations.
  ///
  /// In en, this message translates to:
  /// **'Observations'**
  String get agentTabObservations;

  /// No description provided for @agentTabReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get agentTabReports;

  /// No description provided for @agentTabStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get agentTabStats;

  /// Heading for the aggregate token usage section in agent template stats.
  ///
  /// In en, this message translates to:
  /// **'Aggregate Token Usage'**
  String get agentTemplateAggregateTokenUsageHeading;

  /// Label shown next to the template assigned to an agent.
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get agentTemplateAssignedLabel;

  /// Snackbar message after successfully creating a new template.
  ///
  /// In en, this message translates to:
  /// **'Template created'**
  String get agentTemplateCreatedSuccess;

  /// Page title for the create-template form.
  ///
  /// In en, this message translates to:
  /// **'Create Template'**
  String get agentTemplateCreateTitle;

  /// Confirmation dialog message when deleting a template.
  ///
  /// In en, this message translates to:
  /// **'Delete this template? This cannot be undone.'**
  String get agentTemplateDeleteConfirm;

  /// Error message when trying to delete a template that has active instances.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete: active agents are using this template.'**
  String get agentTemplateDeleteHasInstances;

  /// Label for the template display name input field.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get agentTemplateDisplayNameLabel;

  /// Page title for the edit-template form.
  ///
  /// In en, this message translates to:
  /// **'Edit Template'**
  String get agentTemplateEditTitle;

  /// Button to accept and save proposed directive changes.
  ///
  /// In en, this message translates to:
  /// **'Approve & Save'**
  String get agentTemplateEvolveApprove;

  /// Button to reject the proposed directive changes.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get agentTemplateEvolveReject;

  /// Placeholder hint for the general directive text field.
  ///
  /// In en, this message translates to:
  /// **'Define the agent\'s personality, tools, objectives, and interaction style...'**
  String get agentTemplateGeneralDirectiveHint;

  /// Label for the general directive text field (persona, tools, objectives).
  ///
  /// In en, this message translates to:
  /// **'General Directive'**
  String get agentTemplateGeneralDirectiveLabel;

  /// Heading for the per-instance breakdown section in agent template stats.
  ///
  /// In en, this message translates to:
  /// **'Per-Instance Breakdown'**
  String get agentTemplateInstanceBreakdownHeading;

  /// Display name for the Daily OS day-agent template kind.
  ///
  /// In en, this message translates to:
  /// **'Day Agent'**
  String get agentTemplateKindDayAgent;

  /// Display name for the template-improver agent kind.
  ///
  /// In en, this message translates to:
  /// **'Template Improver'**
  String get agentTemplateKindImprover;

  /// Display name for the project-agent template kind.
  ///
  /// In en, this message translates to:
  /// **'Project Agent'**
  String get agentTemplateKindProjectAgent;

  /// Display name for the task-agent template kind.
  ///
  /// In en, this message translates to:
  /// **'Task Agent'**
  String get agentTemplateKindTaskAgent;

  /// Metric label for the total number of agent wakes.
  ///
  /// In en, this message translates to:
  /// **'Total Wakes'**
  String get agentTemplateMetricsTotalWakes;

  /// Text shown when an agent has no template assigned.
  ///
  /// In en, this message translates to:
  /// **'No template assigned'**
  String get agentTemplateNoneAssigned;

  /// Message shown when no templates exist for agent creation.
  ///
  /// In en, this message translates to:
  /// **'No templates available. Create one in Settings first.'**
  String get agentTemplateNoTemplates;

  /// Error message when a referenced template cannot be found.
  ///
  /// In en, this message translates to:
  /// **'Template not found'**
  String get agentTemplateNotFound;

  /// Placeholder shown when a template has no version history.
  ///
  /// In en, this message translates to:
  /// **'No versions'**
  String get agentTemplateNoVersions;

  /// Placeholder hint for the report directive text field.
  ///
  /// In en, this message translates to:
  /// **'Define the report structure, required sections, and formatting rules...'**
  String get agentTemplateReportDirectiveHint;

  /// Label for the report directive text field (report formatting).
  ///
  /// In en, this message translates to:
  /// **'Report Directive'**
  String get agentTemplateReportDirectiveLabel;

  /// No description provided for @agentTemplateReportsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No reports yet.'**
  String get agentTemplateReportsEmpty;

  /// Tab label for the reports tab in agent template detail.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get agentTemplateReportsTab;

  /// Button label to roll back a template to a previous version.
  ///
  /// In en, this message translates to:
  /// **'Roll Back to This Version'**
  String get agentTemplateRollbackAction;

  /// No description provided for @agentTemplateRollbackConfirm.
  ///
  /// In en, this message translates to:
  /// **'Roll back to version {version}? The agent will use this version on its next wake.'**
  String agentTemplateRollbackConfirm(int version);

  /// Button label to save current edits as a new template version.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get agentTemplateSaveNewVersion;

  /// Title for the template selection dialog when creating an agent.
  ///
  /// In en, this message translates to:
  /// **'Select Template'**
  String get agentTemplateSelectTitle;

  /// No description provided for @agentTemplatesEmptyFiltered.
  ///
  /// In en, this message translates to:
  /// **'No templates match your filters.'**
  String get agentTemplatesEmptyFiltered;

  /// Tab label for the settings tab in agent template detail.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get agentTemplateSettingsTab;

  /// No description provided for @agentTemplatesFilterSectionKind.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get agentTemplatesFilterSectionKind;

  /// No description provided for @agentTemplatesGroupByKind.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get agentTemplatesGroupByKind;

  /// No description provided for @agentTemplatesGroupNone.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get agentTemplatesGroupNone;

  /// No description provided for @agentTemplatesSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search templates…'**
  String get agentTemplatesSearchPlaceholder;

  /// Tab label for the stats tab in agent template detail.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get agentTemplateStatsTab;

  /// Label for the active template status.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get agentTemplateStatusActive;

  /// Label for the archived template status.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get agentTemplateStatusArchived;

  /// Page title for the agent templates list.
  ///
  /// In en, this message translates to:
  /// **'Agent Templates'**
  String get agentTemplatesTitle;

  /// Hint explaining that changing an agent's template requires recreating it.
  ///
  /// In en, this message translates to:
  /// **'To use a different template, destroy this agent and create a new one.'**
  String get agentTemplateSwitchHint;

  /// Section title for the list of template version history entries.
  ///
  /// In en, this message translates to:
  /// **'Version History'**
  String get agentTemplateVersionHistoryTitle;

  /// No description provided for @agentTemplateVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String agentTemplateVersionLabel(int version);

  /// Snackbar message after successfully saving a new template version.
  ///
  /// In en, this message translates to:
  /// **'New version saved'**
  String get agentTemplateVersionSaved;

  /// No description provided for @agentThreadReportLabel.
  ///
  /// In en, this message translates to:
  /// **'Report produced during this wake'**
  String get agentThreadReportLabel;

  /// No description provided for @agentTokenUsageCachedTokens.
  ///
  /// In en, this message translates to:
  /// **'Cached'**
  String get agentTokenUsageCachedTokens;

  /// No description provided for @agentTokenUsageEmpty.
  ///
  /// In en, this message translates to:
  /// **'No token usage recorded yet.'**
  String get agentTokenUsageEmpty;

  /// No description provided for @agentTokenUsageErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Failed to load token usage: {error}'**
  String agentTokenUsageErrorLoading(String error);

  /// No description provided for @agentTokenUsageHeading.
  ///
  /// In en, this message translates to:
  /// **'Token Usage'**
  String get agentTokenUsageHeading;

  /// No description provided for @agentTokenUsageInputTokens.
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get agentTokenUsageInputTokens;

  /// No description provided for @agentTokenUsageModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get agentTokenUsageModel;

  /// No description provided for @agentTokenUsageOutputTokens.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get agentTokenUsageOutputTokens;

  /// No description provided for @agentTokenUsageThoughtsTokens.
  ///
  /// In en, this message translates to:
  /// **'Thoughts'**
  String get agentTokenUsageThoughtsTokens;

  /// No description provided for @agentTokenUsageTotalTokens.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get agentTokenUsageTotalTokens;

  /// No description provided for @agentTokenUsageWakeCount.
  ///
  /// In en, this message translates to:
  /// **'Wakes'**
  String get agentTokenUsageWakeCount;

  /// No description provided for @aggregationDailyAvg.
  ///
  /// In en, this message translates to:
  /// **'Daily average'**
  String get aggregationDailyAvg;

  /// No description provided for @aggregationDailyMax.
  ///
  /// In en, this message translates to:
  /// **'Daily maximum'**
  String get aggregationDailyMax;

  /// No description provided for @aggregationDailySum.
  ///
  /// In en, this message translates to:
  /// **'Daily sum'**
  String get aggregationDailySum;

  /// No description provided for @aggregationHourlySum.
  ///
  /// In en, this message translates to:
  /// **'Hourly sum'**
  String get aggregationHourlySum;

  /// No description provided for @aggregationNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get aggregationNone;

  /// No description provided for @aiAssistantTitle.
  ///
  /// In en, this message translates to:
  /// **'Generate…'**
  String get aiAssistantTitle;

  /// No description provided for @aiBatchToggleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Switch to standard recording'**
  String get aiBatchToggleTooltip;

  /// No description provided for @aiCapabilityChipImageGeneration.
  ///
  /// In en, this message translates to:
  /// **'Image generation'**
  String get aiCapabilityChipImageGeneration;

  /// No description provided for @aiCapabilityChipImageRecognition.
  ///
  /// In en, this message translates to:
  /// **'Image recognition'**
  String get aiCapabilityChipImageRecognition;

  /// No description provided for @aiCapabilityChipThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get aiCapabilityChipThinking;

  /// No description provided for @aiCapabilityChipTranscription.
  ///
  /// In en, this message translates to:
  /// **'Transcription'**
  String get aiCapabilityChipTranscription;

  /// No description provided for @aiCardEmptyProposals.
  ///
  /// In en, this message translates to:
  /// **'No open proposals · agent will surface new changes here'**
  String get aiCardEmptyProposals;

  /// No description provided for @aiCardHistoryToggle.
  ///
  /// In en, this message translates to:
  /// **'History · {count}'**
  String aiCardHistoryToggle(int count);

  /// No description provided for @aiCardMenuActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get aiCardMenuActionDelete;

  /// No description provided for @aiCardMenuActionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get aiCardMenuActionEdit;

  /// No description provided for @aiCardOpenAgentInternals.
  ///
  /// In en, this message translates to:
  /// **'Open agent internals'**
  String get aiCardOpenAgentInternals;

  /// No description provided for @aiCardProposalConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get aiCardProposalConfirmed;

  /// No description provided for @aiCardProposalDismissed.
  ///
  /// In en, this message translates to:
  /// **'Dismissed'**
  String get aiCardProposalDismissed;

  /// No description provided for @aiCardProposalKindAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get aiCardProposalKindAdd;

  /// No description provided for @aiCardProposalKindDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get aiCardProposalKindDue;

  /// No description provided for @aiCardProposalKindEstimate.
  ///
  /// In en, this message translates to:
  /// **'Estimate'**
  String get aiCardProposalKindEstimate;

  /// No description provided for @aiCardProposalKindLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get aiCardProposalKindLabel;

  /// No description provided for @aiCardProposalKindPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get aiCardProposalKindPriority;

  /// No description provided for @aiCardProposalKindRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get aiCardProposalKindRemove;

  /// No description provided for @aiCardProposalKindStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get aiCardProposalKindStatus;

  /// No description provided for @aiCardProposalKindUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get aiCardProposalKindUpdate;

  /// No description provided for @aiCardReadMore.
  ///
  /// In en, this message translates to:
  /// **'Read more'**
  String get aiCardReadMore;

  /// No description provided for @aiCardShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get aiCardShowLess;

  /// No description provided for @aiCardTitle.
  ///
  /// In en, this message translates to:
  /// **'AI summary'**
  String get aiCardTitle;

  /// No description provided for @aiChatMessageCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get aiChatMessageCopied;

  /// No description provided for @aiConfigFailedToLoadModelsGeneric.
  ///
  /// In en, this message translates to:
  /// **'Failed to load models. Please try again.'**
  String get aiConfigFailedToLoadModelsGeneric;

  /// No description provided for @aiConfigNoModelsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No AI models are configured yet. Please add one in settings.'**
  String get aiConfigNoModelsAvailable;

  /// No description provided for @aiConfigNoSuitableModelsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No models meet the requirements for this prompt. Please configure models that support the required capabilities.'**
  String get aiConfigNoSuitableModelsAvailable;

  /// No description provided for @aiConfigSelectProviderModalTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Inference Provider'**
  String get aiConfigSelectProviderModalTitle;

  /// No description provided for @aiConfigSelectProviderTypeModalTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Provider Type'**
  String get aiConfigSelectProviderTypeModalTitle;

  /// No description provided for @aiConfigUseReasoningFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Use Reasoning'**
  String get aiConfigUseReasoningFieldLabel;

  /// No description provided for @aiDeleteToastCascadeDescription.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Also removed 1 model: {names}} other{Also removed {count} models: {names}}}'**
  String aiDeleteToastCascadeDescription(int count, String names);

  /// No description provided for @aiDeleteToastErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete {name}'**
  String aiDeleteToastErrorTitle(String name);

  /// No description provided for @aiDeleteToastModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Model deleted'**
  String get aiDeleteToastModelTitle;

  /// No description provided for @aiDeleteToastProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile deleted'**
  String get aiDeleteToastProfileTitle;

  /// No description provided for @aiDeleteToastPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Prompt deleted'**
  String get aiDeleteToastPromptTitle;

  /// No description provided for @aiDeleteToastProviderTitle.
  ///
  /// In en, this message translates to:
  /// **'Provider deleted'**
  String get aiDeleteToastProviderTitle;

  /// No description provided for @aiDeleteToastSkillTitle.
  ///
  /// In en, this message translates to:
  /// **'Skill deleted'**
  String get aiDeleteToastSkillTitle;

  /// No description provided for @aiDeleteToastUndoAction.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get aiDeleteToastUndoAction;

  /// No description provided for @aiFormCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get aiFormCancel;

  /// No description provided for @aiFormFixErrors.
  ///
  /// In en, this message translates to:
  /// **'Please fix errors before saving'**
  String get aiFormFixErrors;

  /// No description provided for @aiFormNoChanges.
  ///
  /// In en, this message translates to:
  /// **'No unsaved changes'**
  String get aiFormNoChanges;

  /// No description provided for @aiImageAnalysisPickerDefaultBadge.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get aiImageAnalysisPickerDefaultBadge;

  /// No description provided for @aiImageAnalysisPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick an image analysis model'**
  String get aiImageAnalysisPickerTitle;

  /// No description provided for @aiInferenceErrorAuthenticationTitle.
  ///
  /// In en, this message translates to:
  /// **'Authentication Failed'**
  String get aiInferenceErrorAuthenticationTitle;

  /// No description provided for @aiInferenceErrorConnectionFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection Failed'**
  String get aiInferenceErrorConnectionFailedTitle;

  /// No description provided for @aiInferenceErrorInvalidRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Invalid Request'**
  String get aiInferenceErrorInvalidRequestTitle;

  /// No description provided for @aiInferenceErrorRateLimitTitle.
  ///
  /// In en, this message translates to:
  /// **'Rate Limit Exceeded'**
  String get aiInferenceErrorRateLimitTitle;

  /// No description provided for @aiInferenceErrorRetryButton.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get aiInferenceErrorRetryButton;

  /// No description provided for @aiInferenceErrorServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Server Error'**
  String get aiInferenceErrorServerTitle;

  /// No description provided for @aiInferenceErrorSuggestionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Suggestions:'**
  String get aiInferenceErrorSuggestionsTitle;

  /// No description provided for @aiInferenceErrorTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Request Timed Out'**
  String get aiInferenceErrorTimeoutTitle;

  /// No description provided for @aiInferenceErrorUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get aiInferenceErrorUnknownTitle;

  /// No description provided for @aiInternalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Agent internals'**
  String get aiInternalsTitle;

  /// No description provided for @aiModelDownloadCloseButton.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get aiModelDownloadCloseButton;

  /// No description provided for @aiModelDownloadDialogDescription.
  ///
  /// In en, this message translates to:
  /// **'Lotti will download {modelName} into the MLX Audio cache and use it for local speech processing.'**
  String aiModelDownloadDialogDescription(String modelName);

  /// No description provided for @aiModelDownloadDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Install {modelName}'**
  String aiModelDownloadDialogTitle(String modelName);

  /// No description provided for @aiModelDownloadInstallTooltip.
  ///
  /// In en, this message translates to:
  /// **'Install model'**
  String get aiModelDownloadInstallTooltip;

  /// No description provided for @aiModelDownloadOpenProgressTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show download progress'**
  String get aiModelDownloadOpenProgressTooltip;

  /// No description provided for @aiModelDownloadStatusChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking model status'**
  String get aiModelDownloadStatusChecking;

  /// No description provided for @aiModelDownloadStatusDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading {percent}%'**
  String aiModelDownloadStatusDownloading(int percent);

  /// No description provided for @aiModelDownloadStatusDownloadingIndeterminate.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get aiModelDownloadStatusDownloadingIndeterminate;

  /// No description provided for @aiModelDownloadStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get aiModelDownloadStatusFailed;

  /// No description provided for @aiModelDownloadStatusInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get aiModelDownloadStatusInstalled;

  /// No description provided for @aiModelDownloadStatusNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'Not installed'**
  String get aiModelDownloadStatusNotInstalled;

  /// No description provided for @aiModelDownloadStatusUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Apple Silicon required'**
  String get aiModelDownloadStatusUnsupported;

  /// No description provided for @aiModelInstallChoiceCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get aiModelInstallChoiceCancelButton;

  /// No description provided for @aiModelInstallChoiceDescription.
  ///
  /// In en, this message translates to:
  /// **'Pick the local speech-to-text model to download first. You can install the others later from the model list.'**
  String get aiModelInstallChoiceDescription;

  /// No description provided for @aiModelInstallChoiceInstallButton.
  ///
  /// In en, this message translates to:
  /// **'Install model'**
  String get aiModelInstallChoiceInstallButton;

  /// No description provided for @aiModelInstallChoiceRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get aiModelInstallChoiceRecommended;

  /// No description provided for @aiModelInstallChoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose MLX Audio model'**
  String get aiModelInstallChoiceTitle;

  /// No description provided for @aiOllamaModelInstalledSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Model \"{modelName}\" installed successfully!'**
  String aiOllamaModelInstalledSuccessfully(String modelName);

  /// No description provided for @aiPickProviderBadgeDesktopOnly.
  ///
  /// In en, this message translates to:
  /// **'DESKTOP ONLY'**
  String get aiPickProviderBadgeDesktopOnly;

  /// No description provided for @aiPickProviderBadgeNew.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get aiPickProviderBadgeNew;

  /// No description provided for @aiPickProviderBadgeRecommended.
  ///
  /// In en, this message translates to:
  /// **'RECOMMENDED'**
  String get aiPickProviderBadgeRecommended;

  /// No description provided for @aiPickProviderContinueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get aiPickProviderContinueButton;

  /// No description provided for @aiPickProviderDontShowAgainButton.
  ///
  /// In en, this message translates to:
  /// **'Don\'t show again'**
  String get aiPickProviderDontShowAgainButton;

  /// No description provided for @aiPickProviderFooterHint.
  ///
  /// In en, this message translates to:
  /// **'You can add more providers later in Settings → AI. Your API key is stored locally.'**
  String get aiPickProviderFooterHint;

  /// No description provided for @aiPickProviderModalTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up AI features'**
  String get aiPickProviderModalTitle;

  /// No description provided for @aiPickProviderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a provider to get started. We\'ll set up models and a starting profile automatically.'**
  String get aiPickProviderSubtitle;

  /// No description provided for @aiProfileCardActiveBadge.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get aiProfileCardActiveBadge;

  /// No description provided for @aiProfileModelPickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search models…'**
  String get aiProfileModelPickerSearchHint;

  /// No description provided for @aiProfileSlotModelMissing.
  ///
  /// In en, this message translates to:
  /// **'missing'**
  String get aiProfileSlotModelMissing;

  /// No description provided for @aiPromptGenerationPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a prompt generation model'**
  String get aiPromptGenerationPickerTitle;

  /// No description provided for @aiProviderAlibabaDescription.
  ///
  /// In en, this message translates to:
  /// **'Alibaba Cloud\'s Qwen family of models via DashScope API'**
  String get aiProviderAlibabaDescription;

  /// No description provided for @aiProviderAlibabaName.
  ///
  /// In en, this message translates to:
  /// **'Alibaba Cloud (Qwen)'**
  String get aiProviderAlibabaName;

  /// No description provided for @aiProviderAnthropicDescription.
  ///
  /// In en, this message translates to:
  /// **'Anthropic\'s Claude family of AI assistants'**
  String get aiProviderAnthropicDescription;

  /// No description provided for @aiProviderAnthropicName.
  ///
  /// In en, this message translates to:
  /// **'Anthropic Claude'**
  String get aiProviderAnthropicName;

  /// No description provided for @aiProviderCardDraftBadge.
  ///
  /// In en, this message translates to:
  /// **'DRAFT'**
  String get aiProviderCardDraftBadge;

  /// No description provided for @aiProviderCardFixButton.
  ///
  /// In en, this message translates to:
  /// **'Fix'**
  String get aiProviderCardFixButton;

  /// No description provided for @aiProviderCardMenuTooltip.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get aiProviderCardMenuTooltip;

  /// Right-side meta on a connected provider card when no last-used data is available.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 model} other{{count} models}}'**
  String aiProviderCardModelCount(int count);

  /// Right-side meta on a connected provider card combining model count with a last-used label.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 model · last used {lastUsed}} other{{count} models · last used {lastUsed}}}'**
  String aiProviderCardModelCountWithLastUsed(int count, String lastUsed);

  /// No description provided for @aiProviderCardOllamaHint.
  ///
  /// In en, this message translates to:
  /// **'Make sure Ollama is running'**
  String get aiProviderCardOllamaHint;

  /// Provider card status line when the provider has a key + at least one model row.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Connected · 1 model} other{Connected · {count} models}}'**
  String aiProviderCardStatusConnected(int count);

  /// No description provided for @aiProviderCardStatusConnectedShort.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get aiProviderCardStatusConnectedShort;

  /// No description provided for @aiProviderCardStatusInvalidKey.
  ///
  /// In en, this message translates to:
  /// **'Invalid key'**
  String get aiProviderCardStatusInvalidKey;

  /// No description provided for @aiProviderCardStatusOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline · Make sure Ollama is running'**
  String get aiProviderCardStatusOffline;

  /// No description provided for @aiProviderCardStatusOfflineShort.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get aiProviderCardStatusOfflineShort;

  /// No description provided for @aiProviderConnectBackToProviders.
  ///
  /// In en, this message translates to:
  /// **'Back to providers'**
  String get aiProviderConnectBackToProviders;

  /// No description provided for @aiProviderConnectBreadcrumbAdd.
  ///
  /// In en, this message translates to:
  /// **'Add provider'**
  String get aiProviderConnectBreadcrumbAdd;

  /// No description provided for @aiProviderConnectFieldBaseUrlHint.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to use the official endpoint'**
  String get aiProviderConnectFieldBaseUrlHint;

  /// No description provided for @aiProviderConnectFieldBaseUrlLabelOptional.
  ///
  /// In en, this message translates to:
  /// **'Base URL (optional)'**
  String get aiProviderConnectFieldBaseUrlLabelOptional;

  /// No description provided for @aiProviderConnectFieldBaseUrlPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'https://api.example.com'**
  String get aiProviderConnectFieldBaseUrlPlaceholder;

  /// No description provided for @aiProviderConnectFieldDisplayNameHint.
  ///
  /// In en, this message translates to:
  /// **'Shown in your provider list'**
  String get aiProviderConnectFieldDisplayNameHint;

  /// No description provided for @aiProviderConnectionCheckingLabel.
  ///
  /// In en, this message translates to:
  /// **'Checking key, listing available models…'**
  String get aiProviderConnectionCheckingLabel;

  /// No description provided for @aiProviderConnectionFailedBadResponseDetail.
  ///
  /// In en, this message translates to:
  /// **'Unexpected response shape: {type}'**
  String aiProviderConnectionFailedBadResponseDetail(String type);

  /// No description provided for @aiProviderConnectionFailedHttpDetail.
  ///
  /// In en, this message translates to:
  /// **'HTTP {status} · {message}'**
  String aiProviderConnectionFailedHttpDetail(int status, String message);

  /// No description provided for @aiProviderConnectionFailedInvalidBaseUrlDetail.
  ///
  /// In en, this message translates to:
  /// **'Base URL must include http(s) scheme and host (e.g. https://api.example.com)'**
  String get aiProviderConnectionFailedInvalidBaseUrlDetail;

  /// No description provided for @aiProviderConnectionFailedNetworkDetail.
  ///
  /// In en, this message translates to:
  /// **'{message}'**
  String aiProviderConnectionFailedNetworkDetail(String message);

  /// No description provided for @aiProviderConnectionFailedTimeoutDetail.
  ///
  /// In en, this message translates to:
  /// **'Request timed out'**
  String get aiProviderConnectionFailedTimeoutDetail;

  /// No description provided for @aiProviderConnectionFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach {providerName}. Check the key or your network.'**
  String aiProviderConnectionFailedTitle(String providerName);

  /// No description provided for @aiProviderConnectionRetestButton.
  ///
  /// In en, this message translates to:
  /// **'Re-test'**
  String get aiProviderConnectionRetestButton;

  /// No description provided for @aiProviderConnectionRetryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get aiProviderConnectionRetryButton;

  /// No description provided for @aiProviderConnectionVerifiedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 model available on your account · responded in {ms}ms} other{{count} models available on your account · responded in {ms}ms}}'**
  String aiProviderConnectionVerifiedSubtitle(int count, int ms);

  /// No description provided for @aiProviderConnectionVerifiedTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection verified'**
  String get aiProviderConnectionVerifiedTitle;

  /// No description provided for @aiProviderConnectKeyHelperLink.
  ///
  /// In en, this message translates to:
  /// **'Get a key at {url}'**
  String aiProviderConnectKeyHelperLink(String url);

  /// No description provided for @aiProviderConnectKeyHiddenLabel.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get aiProviderConnectKeyHiddenLabel;

  /// No description provided for @aiProviderConnectKeyPrivacyHint.
  ///
  /// In en, this message translates to:
  /// **'Your API key never leaves your device.'**
  String get aiProviderConnectKeyPrivacyHint;

  /// No description provided for @aiProviderConnectPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect {providerName}'**
  String aiProviderConnectPageTitle(String providerName);

  /// No description provided for @aiProviderConnectSaveAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Save & continue'**
  String get aiProviderConnectSaveAndContinue;

  /// No description provided for @aiProviderConnectSaveAsDraft.
  ///
  /// In en, this message translates to:
  /// **'Save as draft'**
  String get aiProviderConnectSaveAsDraft;

  /// No description provided for @aiProviderConnectSavedAsDraftToast.
  ///
  /// In en, this message translates to:
  /// **'Saved as draft'**
  String get aiProviderConnectSavedAsDraftToast;

  /// No description provided for @aiProviderConnectStepChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose provider'**
  String get aiProviderConnectStepChoose;

  /// No description provided for @aiProviderConnectStepConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get aiProviderConnectStepConnect;

  /// No description provided for @aiProviderConnectStepReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get aiProviderConnectStepReview;

  /// No description provided for @aiProviderDetailActiveProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Active profile'**
  String get aiProviderDetailActiveProfileTitle;

  /// No description provided for @aiProviderDetailAddModelButton.
  ///
  /// In en, this message translates to:
  /// **'Add model'**
  String get aiProviderDetailAddModelButton;

  /// No description provided for @aiProviderDetailApiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get aiProviderDetailApiKeyLabel;

  /// No description provided for @aiProviderDetailBackTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get aiProviderDetailBackTooltip;

  /// No description provided for @aiProviderDetailBaseUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get aiProviderDetailBaseUrlLabel;

  /// No description provided for @aiProviderDetailConnectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get aiProviderDetailConnectionTitle;

  /// No description provided for @aiProviderDetailDangerZoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get aiProviderDetailDangerZoneTitle;

  /// No description provided for @aiProviderDetailDisplayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get aiProviderDetailDisplayNameLabel;

  /// No description provided for @aiProviderDetailEditButton.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get aiProviderDetailEditButton;

  /// No description provided for @aiProviderDetailEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit provider'**
  String get aiProviderDetailEditTooltip;

  /// No description provided for @aiProviderDetailLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load this provider. Try again from the AI Settings list.'**
  String get aiProviderDetailLoadError;

  /// No description provided for @aiProviderDetailMissingMessage.
  ///
  /// In en, this message translates to:
  /// **'This provider is no longer available.'**
  String get aiProviderDetailMissingMessage;

  /// Models section heading on the provider detail page; suffixes the count when one or more models exist.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Models} =1{Models · 1} other{Models · {count}}}'**
  String aiProviderDetailModelsTitle(int count);

  /// No description provided for @aiProviderDetailNoModelsMessage.
  ///
  /// In en, this message translates to:
  /// **'No models yet. Add one to start using this provider.'**
  String get aiProviderDetailNoModelsMessage;

  /// No description provided for @aiProviderDetailPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Provider details'**
  String get aiProviderDetailPageTitle;

  /// No description provided for @aiProviderDetailRemoveButton.
  ///
  /// In en, this message translates to:
  /// **'Remove provider'**
  String get aiProviderDetailRemoveButton;

  /// No description provided for @aiProviderDetailRemoveDescription.
  ///
  /// In en, this message translates to:
  /// **'Deletes the provider and every model that depends on it. This cannot be undone.'**
  String get aiProviderDetailRemoveDescription;

  /// No description provided for @aiProviderDetailRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this provider'**
  String get aiProviderDetailRemoveTitle;

  /// No description provided for @aiProviderDetailValueUnset.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get aiProviderDetailValueUnset;

  /// No description provided for @aiProviderEmbeddedRuntimeHint.
  ///
  /// In en, this message translates to:
  /// **'Runs embedded in the Apple app process. No local server or Base URL is required.'**
  String get aiProviderEmbeddedRuntimeHint;

  /// No description provided for @aiProviderGeminiDescription.
  ///
  /// In en, this message translates to:
  /// **'Google\'s Gemini AI models'**
  String get aiProviderGeminiDescription;

  /// No description provided for @aiProviderGeminiName.
  ///
  /// In en, this message translates to:
  /// **'Google Gemini'**
  String get aiProviderGeminiName;

  /// No description provided for @aiProviderGenericOpenAiDescription.
  ///
  /// In en, this message translates to:
  /// **'API compatible with OpenAI format'**
  String get aiProviderGenericOpenAiDescription;

  /// No description provided for @aiProviderGenericOpenAiName.
  ///
  /// In en, this message translates to:
  /// **'OpenAI Compatible'**
  String get aiProviderGenericOpenAiName;

  /// No description provided for @aiProviderMistralDescription.
  ///
  /// In en, this message translates to:
  /// **'Mistral AI cloud API with native audio transcription'**
  String get aiProviderMistralDescription;

  /// No description provided for @aiProviderMistralName.
  ///
  /// In en, this message translates to:
  /// **'Mistral'**
  String get aiProviderMistralName;

  /// No description provided for @aiProviderMlxAudioDescription.
  ///
  /// In en, this message translates to:
  /// **'Embedded MLX Audio models for local STT and TTS on Apple Silicon'**
  String get aiProviderMlxAudioDescription;

  /// No description provided for @aiProviderMlxAudioName.
  ///
  /// In en, this message translates to:
  /// **'MLX Audio (local)'**
  String get aiProviderMlxAudioName;

  /// No description provided for @aiProviderNebiusAiStudioDescription.
  ///
  /// In en, this message translates to:
  /// **'Nebius AI Studio\'s models'**
  String get aiProviderNebiusAiStudioDescription;

  /// No description provided for @aiProviderNebiusAiStudioName.
  ///
  /// In en, this message translates to:
  /// **'Nebius AI Studio'**
  String get aiProviderNebiusAiStudioName;

  /// No description provided for @aiProviderOllamaDescription.
  ///
  /// In en, this message translates to:
  /// **'Run inference locally with Ollama'**
  String get aiProviderOllamaDescription;

  /// No description provided for @aiProviderOllamaName.
  ///
  /// In en, this message translates to:
  /// **'Ollama'**
  String get aiProviderOllamaName;

  /// No description provided for @aiProviderOmlxDescription.
  ///
  /// In en, this message translates to:
  /// **'Local OpenAI-compatible oMLX inference for MLX models'**
  String get aiProviderOmlxDescription;

  /// No description provided for @aiProviderOmlxName.
  ///
  /// In en, this message translates to:
  /// **'oMLX (local)'**
  String get aiProviderOmlxName;

  /// No description provided for @aiProviderOpenAiDescription.
  ///
  /// In en, this message translates to:
  /// **'OpenAI\'s GPT models'**
  String get aiProviderOpenAiDescription;

  /// No description provided for @aiProviderOpenAiName.
  ///
  /// In en, this message translates to:
  /// **'OpenAI'**
  String get aiProviderOpenAiName;

  /// No description provided for @aiProviderOpenRouterDescription.
  ///
  /// In en, this message translates to:
  /// **'OpenRouter\'s models'**
  String get aiProviderOpenRouterDescription;

  /// No description provided for @aiProviderOpenRouterName.
  ///
  /// In en, this message translates to:
  /// **'OpenRouter'**
  String get aiProviderOpenRouterName;

  /// No description provided for @aiProviderSelectContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get aiProviderSelectContinue;

  /// No description provided for @aiProviderSelectDontShowAgain.
  ///
  /// In en, this message translates to:
  /// **'Don\'t Show Again'**
  String get aiProviderSelectDontShowAgain;

  /// No description provided for @aiProviderSetupOptionGeminiDescription.
  ///
  /// In en, this message translates to:
  /// **'Multimodal models with audio transcription. Requires API key.'**
  String get aiProviderSetupOptionGeminiDescription;

  /// No description provided for @aiProviderSetupOptionMistralDescription.
  ///
  /// In en, this message translates to:
  /// **'European AI with reasoning (Magistral) and audio (Voxtral) models.'**
  String get aiProviderSetupOptionMistralDescription;

  /// No description provided for @aiProviderSetupOptionOpenAiDescription.
  ///
  /// In en, this message translates to:
  /// **'GPT models for chat and reasoning. Requires API key with credits.'**
  String get aiProviderSetupOptionOpenAiDescription;

  /// No description provided for @aiProviderTaglineAlibaba.
  ///
  /// In en, this message translates to:
  /// **'Qwen models · multimodal · long context'**
  String get aiProviderTaglineAlibaba;

  /// No description provided for @aiProviderTaglineAnthropic.
  ///
  /// In en, this message translates to:
  /// **'Claude family · long context'**
  String get aiProviderTaglineAnthropic;

  /// No description provided for @aiProviderTaglineGemini.
  ///
  /// In en, this message translates to:
  /// **'Multimodal · audio transcription'**
  String get aiProviderTaglineGemini;

  /// No description provided for @aiProviderTaglineMlxAudio.
  ///
  /// In en, this message translates to:
  /// **'Embedded · Apple Silicon · local audio'**
  String get aiProviderTaglineMlxAudio;

  /// No description provided for @aiProviderTaglineOllama.
  ///
  /// In en, this message translates to:
  /// **'Runs locally · no cloud calls'**
  String get aiProviderTaglineOllama;

  /// No description provided for @aiProviderTaglineOmlx.
  ///
  /// In en, this message translates to:
  /// **'Local MLX inference · OpenAI-compatible'**
  String get aiProviderTaglineOmlx;

  /// No description provided for @aiProviderTaglineOpenAi.
  ///
  /// In en, this message translates to:
  /// **'GPT family · vision + reasoning'**
  String get aiProviderTaglineOpenAi;

  /// No description provided for @aiProviderUnknownName.
  ///
  /// In en, this message translates to:
  /// **'AI provider'**
  String get aiProviderUnknownName;

  /// No description provided for @aiProviderVoxtralDescription.
  ///
  /// In en, this message translates to:
  /// **'Local Voxtral transcription (up to 30 min audio, 13 languages)'**
  String get aiProviderVoxtralDescription;

  /// No description provided for @aiProviderVoxtralName.
  ///
  /// In en, this message translates to:
  /// **'Voxtral (local)'**
  String get aiProviderVoxtralName;

  /// No description provided for @aiProviderWhisperDescription.
  ///
  /// In en, this message translates to:
  /// **'Local Whisper transcription with OpenAI-compatible API'**
  String get aiProviderWhisperDescription;

  /// No description provided for @aiProviderWhisperName.
  ///
  /// In en, this message translates to:
  /// **'Whisper (local)'**
  String get aiProviderWhisperName;

  /// No description provided for @aiRealtimeToggleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Switch to live transcription'**
  String get aiRealtimeToggleTooltip;

  /// No description provided for @aiResponseDeleteCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get aiResponseDeleteCancel;

  /// No description provided for @aiResponseDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get aiResponseDeleteConfirm;

  /// No description provided for @aiResponseDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete AI response. Please try again.'**
  String get aiResponseDeleteError;

  /// No description provided for @aiResponseDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete AI Response'**
  String get aiResponseDeleteTitle;

  /// No description provided for @aiResponseDeleteWarning.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this AI response? This cannot be undone.'**
  String get aiResponseDeleteWarning;

  /// No description provided for @aiResponseTypeAudioTranscription.
  ///
  /// In en, this message translates to:
  /// **'Audio Transcription'**
  String get aiResponseTypeAudioTranscription;

  /// No description provided for @aiResponseTypeChecklistUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checklist Updates'**
  String get aiResponseTypeChecklistUpdates;

  /// No description provided for @aiResponseTypeImageAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Image Analysis'**
  String get aiResponseTypeImageAnalysis;

  /// No description provided for @aiResponseTypeImagePromptGeneration.
  ///
  /// In en, this message translates to:
  /// **'Image Prompt'**
  String get aiResponseTypeImagePromptGeneration;

  /// No description provided for @aiResponseTypePromptGeneration.
  ///
  /// In en, this message translates to:
  /// **'Generated Prompt'**
  String get aiResponseTypePromptGeneration;

  /// No description provided for @aiResponseTypeTaskSummary.
  ///
  /// In en, this message translates to:
  /// **'Task Summary'**
  String get aiResponseTypeTaskSummary;

  /// No description provided for @aiRunningActivityOpenProgress.
  ///
  /// In en, this message translates to:
  /// **'Show AI progress'**
  String get aiRunningActivityOpenProgress;

  /// No description provided for @aiSettingsAddedLabel.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get aiSettingsAddedLabel;

  /// No description provided for @aiSettingsAddModelButton.
  ///
  /// In en, this message translates to:
  /// **'Add model'**
  String get aiSettingsAddModelButton;

  /// No description provided for @aiSettingsAddModelTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add this model to your provider'**
  String get aiSettingsAddModelTooltip;

  /// No description provided for @aiSettingsAddProfileButton.
  ///
  /// In en, this message translates to:
  /// **'Add Profile'**
  String get aiSettingsAddProfileButton;

  /// No description provided for @aiSettingsAddProviderButton.
  ///
  /// In en, this message translates to:
  /// **'Add provider'**
  String get aiSettingsAddProviderButton;

  /// No description provided for @aiSettingsClearAllFiltersTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear all filters'**
  String get aiSettingsClearAllFiltersTooltip;

  /// No description provided for @aiSettingsClearFiltersButton.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get aiSettingsClearFiltersButton;

  /// No description provided for @aiSettingsCounterModels.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get aiSettingsCounterModels;

  /// No description provided for @aiSettingsCounterProfiles.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get aiSettingsCounterProfiles;

  /// No description provided for @aiSettingsCounterProviders.
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get aiSettingsCounterProviders;

  /// No description provided for @aiSettingsEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Add one to unlock transcription, image recognition, image generation, and semantic search.'**
  String get aiSettingsEmptyDescription;

  /// No description provided for @aiSettingsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No providers yet'**
  String get aiSettingsEmptyTitle;

  /// No description provided for @aiSettingsFilterByCapabilityTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter by {capability} capability'**
  String aiSettingsFilterByCapabilityTooltip(String capability);

  /// No description provided for @aiSettingsFilterByProviderTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter by {provider}'**
  String aiSettingsFilterByProviderTooltip(String provider);

  /// No description provided for @aiSettingsFilterByReasoningTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter by reasoning capability'**
  String get aiSettingsFilterByReasoningTooltip;

  /// No description provided for @aiSettingsFtueBannerDescription.
  ///
  /// In en, this message translates to:
  /// **'Takes about a minute. Lotti will set up models and a starting profile for you.'**
  String get aiSettingsFtueBannerDescription;

  /// No description provided for @aiSettingsFtueBannerStartButton.
  ///
  /// In en, this message translates to:
  /// **'Start setup'**
  String get aiSettingsFtueBannerStartButton;

  /// No description provided for @aiSettingsFtueBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Add your first AI provider'**
  String get aiSettingsFtueBannerTitle;

  /// No description provided for @aiSettingsModalityAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get aiSettingsModalityAudio;

  /// No description provided for @aiSettingsModalityText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get aiSettingsModalityText;

  /// No description provided for @aiSettingsModalityVision.
  ///
  /// In en, this message translates to:
  /// **'Vision'**
  String get aiSettingsModalityVision;

  /// No description provided for @aiSettingsNoModelsConfigured.
  ///
  /// In en, this message translates to:
  /// **'No AI models configured'**
  String get aiSettingsNoModelsConfigured;

  /// No description provided for @aiSettingsNoProvidersConfigured.
  ///
  /// In en, this message translates to:
  /// **'No AI providers configured'**
  String get aiSettingsNoProvidersConfigured;

  /// No description provided for @aiSettingsPageLead.
  ///
  /// In en, this message translates to:
  /// **'Configure AI providers, the models Lotti can call, and the inference profiles that decide which model handles which task.'**
  String get aiSettingsPageLead;

  /// No description provided for @aiSettingsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Settings'**
  String get aiSettingsPageTitle;

  /// No description provided for @aiSettingsReasoningLabel.
  ///
  /// In en, this message translates to:
  /// **'Reasoning'**
  String get aiSettingsReasoningLabel;

  /// No description provided for @aiSettingsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search AI configurations...'**
  String get aiSettingsSearchHint;

  /// No description provided for @aiSettingsSearchHintShort.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get aiSettingsSearchHintShort;

  /// No description provided for @aiSettingsTabModels.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get aiSettingsTabModels;

  /// No description provided for @aiSettingsTabProfiles.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get aiSettingsTabProfiles;

  /// No description provided for @aiSettingsTabProviders.
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get aiSettingsTabProviders;

  /// No description provided for @aiSetupPreviewAcceptButton.
  ///
  /// In en, this message translates to:
  /// **'Accept & finish'**
  String get aiSetupPreviewAcceptButton;

  /// No description provided for @aiSetupPreviewAlreadyAddedSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Already added'**
  String get aiSetupPreviewAlreadyAddedSectionLabel;

  /// No description provided for @aiSetupPreviewCategoryFooter.
  ///
  /// In en, this message translates to:
  /// **'Set up a test category {categoryName} to try it out.'**
  String aiSetupPreviewCategoryFooter(String categoryName);

  /// No description provided for @aiSetupPreviewConnectedHeader.
  ///
  /// In en, this message translates to:
  /// **'{providerName} connected'**
  String aiSetupPreviewConnectedHeader(String providerName);

  /// No description provided for @aiSetupPreviewCustomizeButton.
  ///
  /// In en, this message translates to:
  /// **'Customize'**
  String get aiSetupPreviewCustomizeButton;

  /// No description provided for @aiSetupPreviewLead.
  ///
  /// In en, this message translates to:
  /// **'Review what Lotti will add. Uncheck anything you don\'t want; you can always set it up later by hand.'**
  String get aiSetupPreviewLead;

  /// No description provided for @aiSetupPreviewLiveBadge.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get aiSetupPreviewLiveBadge;

  /// No description provided for @aiSetupPreviewModalTitle.
  ///
  /// In en, this message translates to:
  /// **'{providerName} setup'**
  String aiSetupPreviewModalTitle(String providerName);

  /// No description provided for @aiSetupPreviewModelsSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get aiSetupPreviewModelsSectionLabel;

  /// No description provided for @aiSetupPreviewProfileSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Inference profile'**
  String get aiSetupPreviewProfileSectionLabel;

  /// No description provided for @aiSetupPreviewProfileSetActiveBadge.
  ///
  /// In en, this message translates to:
  /// **'Set active'**
  String get aiSetupPreviewProfileSetActiveBadge;

  /// No description provided for @aiSetupResultBulletCategoryCreated.
  ///
  /// In en, this message translates to:
  /// **'Set up a test category {categoryName} to try it out'**
  String aiSetupResultBulletCategoryCreated(String categoryName);

  /// No description provided for @aiSetupResultBulletCategoryReused.
  ///
  /// In en, this message translates to:
  /// **'Reusing existing test category {categoryName}'**
  String aiSetupResultBulletCategoryReused(String categoryName);

  /// No description provided for @aiSetupResultBulletModels.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Configured 1 model} other{Configured {count} models}}'**
  String aiSetupResultBulletModels(int count);

  /// No description provided for @aiSetupResultBulletProfile.
  ///
  /// In en, this message translates to:
  /// **'Created inference profile {profileName}'**
  String aiSetupResultBulletProfile(String profileName);

  /// No description provided for @aiSetupResultErrorsHeader.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 issue} other{{count} issues}} during setup'**
  String aiSetupResultErrorsHeader(int count);

  /// No description provided for @aiSetupResultHeader.
  ///
  /// In en, this message translates to:
  /// **'{providerName} is connected'**
  String aiSetupResultHeader(String providerName);

  /// No description provided for @aiSetupResultKnownModelsMissing.
  ///
  /// In en, this message translates to:
  /// **'Failed to find required {providerName} model configurations'**
  String aiSetupResultKnownModelsMissing(String providerName);

  /// No description provided for @aiSetupResultLead.
  ///
  /// In en, this message translates to:
  /// **'We set things up for you. AI features are ready to use in your journal.'**
  String get aiSetupResultLead;

  /// No description provided for @aiSetupResultModalTitle.
  ///
  /// In en, this message translates to:
  /// **'{providerName} ready'**
  String aiSetupResultModalTitle(String providerName);

  /// No description provided for @aiSetupResultStartUsingButton.
  ///
  /// In en, this message translates to:
  /// **'Start using AI'**
  String get aiSetupResultStartUsingButton;

  /// No description provided for @aiSetupWizardCreatesOptimized.
  ///
  /// In en, this message translates to:
  /// **'Creates optimized models, prompts, and a test category'**
  String get aiSetupWizardCreatesOptimized;

  /// No description provided for @aiSetupWizardDescription.
  ///
  /// In en, this message translates to:
  /// **'Set up or refresh models, prompts, and test category for {providerName}'**
  String aiSetupWizardDescription(String providerName);

  /// No description provided for @aiSetupWizardRunButton.
  ///
  /// In en, this message translates to:
  /// **'Run Setup'**
  String get aiSetupWizardRunButton;

  /// No description provided for @aiSetupWizardRunLabel.
  ///
  /// In en, this message translates to:
  /// **'Run Setup Wizard'**
  String get aiSetupWizardRunLabel;

  /// No description provided for @aiSetupWizardRunningButton.
  ///
  /// In en, this message translates to:
  /// **'Running...'**
  String get aiSetupWizardRunningButton;

  /// No description provided for @aiSetupWizardSafeToRunMultiple.
  ///
  /// In en, this message translates to:
  /// **'Safe to run multiple times - existing items will be kept'**
  String get aiSetupWizardSafeToRunMultiple;

  /// No description provided for @aiSetupWizardTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Setup Wizard'**
  String get aiSetupWizardTitle;

  /// No description provided for @aiSummaryPlayTooltip.
  ///
  /// In en, this message translates to:
  /// **'Play summary'**
  String get aiSummaryPlayTooltip;

  /// No description provided for @aiSummaryPreparingTooltip.
  ///
  /// In en, this message translates to:
  /// **'Preparing audio'**
  String get aiSummaryPreparingTooltip;

  /// No description provided for @aiSummarySpeakTooltip.
  ///
  /// In en, this message translates to:
  /// **'Read summary aloud locally'**
  String get aiSummarySpeakTooltip;

  /// No description provided for @aiSummaryStopTooltip.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get aiSummaryStopTooltip;

  /// No description provided for @aiSummaryThinkingLabel.
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get aiSummaryThinkingLabel;

  /// No description provided for @aiSummaryTtsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Text-to-speech isn\'t available'**
  String get aiSummaryTtsUnavailable;

  /// No description provided for @aiTaskSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Task Summary'**
  String get aiTaskSummaryTitle;

  /// No description provided for @aiTranscriptionPickerDefaultBadge.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get aiTranscriptionPickerDefaultBadge;

  /// No description provided for @aiTranscriptionPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a transcription model'**
  String get aiTranscriptionPickerTitle;

  /// No description provided for @apiKeyAddPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Provider'**
  String get apiKeyAddPageTitle;

  /// No description provided for @apiKeyAuthenticationDescription.
  ///
  /// In en, this message translates to:
  /// **'Secure your API connection'**
  String get apiKeyAuthenticationDescription;

  /// No description provided for @apiKeyAuthenticationTitle.
  ///
  /// In en, this message translates to:
  /// **'Authentication'**
  String get apiKeyAuthenticationTitle;

  /// No description provided for @apiKeyAvailableModelsDescription.
  ///
  /// In en, this message translates to:
  /// **'Quick-add preconfigured models for this provider'**
  String get apiKeyAvailableModelsDescription;

  /// No description provided for @apiKeyAvailableModelsTitle.
  ///
  /// In en, this message translates to:
  /// **'Available Models'**
  String get apiKeyAvailableModelsTitle;

  /// No description provided for @apiKeyBaseUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get apiKeyBaseUrlLabel;

  /// No description provided for @apiKeyDisplayNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a friendly name'**
  String get apiKeyDisplayNameHint;

  /// No description provided for @apiKeyDisplayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get apiKeyDisplayNameLabel;

  /// No description provided for @apiKeyEditGoBackButton.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get apiKeyEditGoBackButton;

  /// No description provided for @apiKeyEditLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load API key configuration'**
  String get apiKeyEditLoadError;

  /// No description provided for @apiKeyEditLoadErrorRetry.
  ///
  /// In en, this message translates to:
  /// **'Please try again or contact support'**
  String get apiKeyEditLoadErrorRetry;

  /// No description provided for @apiKeyEditPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Provider'**
  String get apiKeyEditPageTitle;

  /// No description provided for @apiKeyHideTooltip.
  ///
  /// In en, this message translates to:
  /// **'Hide API Key'**
  String get apiKeyHideTooltip;

  /// No description provided for @apiKeyInputHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your API key'**
  String get apiKeyInputHint;

  /// No description provided for @apiKeyInputLabel.
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get apiKeyInputLabel;

  /// No description provided for @apiKeyKnownModelInputLabel.
  ///
  /// In en, this message translates to:
  /// **'In: {modalities}'**
  String apiKeyKnownModelInputLabel(String modalities);

  /// No description provided for @apiKeyKnownModelOutputLabel.
  ///
  /// In en, this message translates to:
  /// **'Out: {modalities}'**
  String apiKeyKnownModelOutputLabel(String modalities);

  /// No description provided for @apiKeyProviderConfigDescription.
  ///
  /// In en, this message translates to:
  /// **'Configure your AI inference provider settings'**
  String get apiKeyProviderConfigDescription;

  /// No description provided for @apiKeyProviderConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Provider Configuration'**
  String get apiKeyProviderConfigTitle;

  /// No description provided for @apiKeyProviderTypeHint.
  ///
  /// In en, this message translates to:
  /// **'Select a provider type'**
  String get apiKeyProviderTypeHint;

  /// No description provided for @apiKeyProviderTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Provider Type'**
  String get apiKeyProviderTypeLabel;

  /// No description provided for @apiKeyShowTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show API Key'**
  String get apiKeyShowTooltip;

  /// No description provided for @audioRecordingCancel.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get audioRecordingCancel;

  /// No description provided for @audioRecordingListening.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get audioRecordingListening;

  /// No description provided for @audioRecordingRealtime.
  ///
  /// In en, this message translates to:
  /// **'Live Transcription'**
  String get audioRecordingRealtime;

  /// No description provided for @audioRecordings.
  ///
  /// In en, this message translates to:
  /// **'Audio Recordings'**
  String get audioRecordings;

  /// No description provided for @audioRecordingStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get audioRecordingStandard;

  /// No description provided for @audioRecordingStop.
  ///
  /// In en, this message translates to:
  /// **'STOP'**
  String get audioRecordingStop;

  /// No description provided for @backfillAdvancedRecoveryActions.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 action} other{{count} actions}}'**
  String backfillAdvancedRecoveryActions(int count);

  /// No description provided for @backfillAdvancedRecoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced recovery'**
  String get backfillAdvancedRecoveryTitle;

  /// No description provided for @backfillAskPeersConfirmAccept.
  ///
  /// In en, this message translates to:
  /// **'Ask peers'**
  String get backfillAskPeersConfirmAccept;

  /// No description provided for @backfillAskPeersConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{This flips 1 unresolvable sequence-log entry back to missing so the normal backfill sweep re-asks peers. Peers who still have the payload will respond; truly unrecoverable entries will retire again after the 7-day amnesty window.} other{This flips all {count} unresolvable sequence-log entries back to missing so the normal backfill sweep re-asks peers. Peers who still have the payload will respond; truly unrecoverable entries will retire again after the 7-day amnesty window.}}'**
  String backfillAskPeersConfirmContent(int count);

  /// No description provided for @backfillAskPeersConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask peers again for unresolvable entries?'**
  String get backfillAskPeersConfirmTitle;

  /// No description provided for @backfillAskPeersDescription.
  ///
  /// In en, this message translates to:
  /// **'Flip every unresolvable sequence-log entry back to missing and let the normal backfill sweep re-ask peers.'**
  String get backfillAskPeersDescription;

  /// No description provided for @backfillAskPeersProcessing.
  ///
  /// In en, this message translates to:
  /// **'Reopening…'**
  String get backfillAskPeersProcessing;

  /// No description provided for @backfillAskPeersTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask peers for unresolvable'**
  String get backfillAskPeersTitle;

  /// No description provided for @backfillAskPeersTrigger.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Ask peers for 1 entry} other{Ask peers for {count} entries}}'**
  String backfillAskPeersTrigger(int count);

  /// No description provided for @backfillCatchUpDescription.
  ///
  /// In en, this message translates to:
  /// **'Pull recent missing entries from peers right now.'**
  String get backfillCatchUpDescription;

  /// No description provided for @backfillDevicesMeta.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 device ID} other{{count} device IDs}}'**
  String backfillDevicesMeta(int count);

  /// No description provided for @backfillManualDescription.
  ///
  /// In en, this message translates to:
  /// **'Request all missing entries regardless of age. Use this to recover older sync gaps.'**
  String get backfillManualDescription;

  /// No description provided for @backfillManualProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get backfillManualProcessing;

  /// No description provided for @backfillManualTitle.
  ///
  /// In en, this message translates to:
  /// **'Manual Backfill'**
  String get backfillManualTitle;

  /// No description provided for @backfillManualTrigger.
  ///
  /// In en, this message translates to:
  /// **'Request Missing Entries'**
  String get backfillManualTrigger;

  /// No description provided for @backfillReRequestDescription.
  ///
  /// In en, this message translates to:
  /// **'Re-request entries that were requested but never received. Use this when responses are stuck.'**
  String get backfillReRequestDescription;

  /// No description provided for @backfillReRequestProcessing.
  ///
  /// In en, this message translates to:
  /// **'Re-requesting...'**
  String get backfillReRequestProcessing;

  /// No description provided for @backfillReRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Re-Request Pending'**
  String get backfillReRequestTitle;

  /// No description provided for @backfillReRequestTrigger.
  ///
  /// In en, this message translates to:
  /// **'Re-Request Pending Entries'**
  String get backfillReRequestTrigger;

  /// No description provided for @backfillResetUnresolvableDescription.
  ///
  /// In en, this message translates to:
  /// **'Reset entries marked as unresolvable back to missing so they can be re-requested. Use after sequence log repopulation.'**
  String get backfillResetUnresolvableDescription;

  /// No description provided for @backfillResetUnresolvableProcessing.
  ///
  /// In en, this message translates to:
  /// **'Resetting...'**
  String get backfillResetUnresolvableProcessing;

  /// No description provided for @backfillResetUnresolvableTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Unresolvable'**
  String get backfillResetUnresolvableTitle;

  /// No description provided for @backfillResetUnresolvableTrigger.
  ///
  /// In en, this message translates to:
  /// **'Reset Unresolvable Entries'**
  String get backfillResetUnresolvableTrigger;

  /// No description provided for @backfillRetireStuckConfirmAccept.
  ///
  /// In en, this message translates to:
  /// **'Retire now'**
  String get backfillRetireStuckConfirmAccept;

  /// No description provided for @backfillRetireStuckConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{This marks 1 currently-open (missing or requested) sequence-log entry as unresolvable. Use this to unblock the watermark when entries have been stuck for a while without the 7-day amnesty window having passed. Entries can still be resurrected if their payload later arrives on disk with a valid vector clock.} other{This marks {count} currently-open (missing or requested) sequence-log entries as unresolvable. Use this to unblock the watermark when entries have been stuck for a while without the 7-day amnesty window having passed. Entries can still be resurrected if their payload later arrives on disk with a valid vector clock.}}'**
  String backfillRetireStuckConfirmContent(int count);

  /// No description provided for @backfillRetireStuckConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Retire stuck entries now?'**
  String get backfillRetireStuckConfirmTitle;

  /// No description provided for @backfillRetireStuckDescription.
  ///
  /// In en, this message translates to:
  /// **'Force every currently-open missing or requested sequence-log entry to unresolvable. Skips the 7-day amnesty — use only for stuck rows blocking the watermark.'**
  String get backfillRetireStuckDescription;

  /// No description provided for @backfillRetireStuckProcessing.
  ///
  /// In en, this message translates to:
  /// **'Retiring…'**
  String get backfillRetireStuckProcessing;

  /// No description provided for @backfillRetireStuckTitle.
  ///
  /// In en, this message translates to:
  /// **'Retire stuck entries'**
  String get backfillRetireStuckTitle;

  /// No description provided for @backfillRetireStuckTrigger.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Retire 1 stuck entry} other{Retire {count} stuck entries}}'**
  String backfillRetireStuckTrigger(int count);

  /// No description provided for @backfillSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage sync gap recovery'**
  String get backfillSettingsSubtitle;

  /// No description provided for @backfillSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Backfill sync'**
  String get backfillSettingsTitle;

  /// No description provided for @backfillStatsBackfilled.
  ///
  /// In en, this message translates to:
  /// **'Backfilled'**
  String get backfillStatsBackfilled;

  /// No description provided for @backfillStatsBurned.
  ///
  /// In en, this message translates to:
  /// **'Burned'**
  String get backfillStatsBurned;

  /// No description provided for @backfillStatsDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get backfillStatsDeleted;

  /// No description provided for @backfillStatsMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get backfillStatsMissing;

  /// No description provided for @backfillStatsNoData.
  ///
  /// In en, this message translates to:
  /// **'No sync data available'**
  String get backfillStatsNoData;

  /// No description provided for @backfillStatsReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get backfillStatsReceived;

  /// No description provided for @backfillStatsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh stats'**
  String get backfillStatsRefresh;

  /// No description provided for @backfillStatsRequested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get backfillStatsRequested;

  /// No description provided for @backfillStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync statistics'**
  String get backfillStatsTitle;

  /// No description provided for @backfillStatsTotalEntries.
  ///
  /// In en, this message translates to:
  /// **'Total entries'**
  String get backfillStatsTotalEntries;

  /// No description provided for @backfillStatsUnresolvable.
  ///
  /// In en, this message translates to:
  /// **'Unresolvable'**
  String get backfillStatsUnresolvable;

  /// No description provided for @backfillStatusInboundQueue.
  ///
  /// In en, this message translates to:
  /// **'Inbound queue'**
  String get backfillStatusInboundQueue;

  /// No description provided for @backfillStatusMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get backfillStatusMissing;

  /// No description provided for @backfillStatusSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get backfillStatusSkipped;

  /// No description provided for @backfillToggleDescription.
  ///
  /// In en, this message translates to:
  /// **'Requests missing entries from the last 24 hours.'**
  String get backfillToggleDescription;

  /// No description provided for @backfillToggleTitle.
  ///
  /// In en, this message translates to:
  /// **'Automatic backfill'**
  String get backfillToggleTitle;

  /// No description provided for @basicSettings.
  ///
  /// In en, this message translates to:
  /// **'Basic settings'**
  String get basicSettings;

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @categoryActiveDescription.
  ///
  /// In en, this message translates to:
  /// **'Inactive categories won\'t appear in selection lists'**
  String get categoryActiveDescription;

  /// No description provided for @categoryActiveSwitchDescription.
  ///
  /// In en, this message translates to:
  /// **'Selectable for new entries'**
  String get categoryActiveSwitchDescription;

  /// No description provided for @categoryAiDefaultsDescription.
  ///
  /// In en, this message translates to:
  /// **'Set default AI profile and agent template for new tasks in this category'**
  String get categoryAiDefaultsDescription;

  /// No description provided for @categoryAiDefaultsTitle.
  ///
  /// In en, this message translates to:
  /// **'AI defaults'**
  String get categoryAiDefaultsTitle;

  /// No description provided for @categoryCreationError.
  ///
  /// In en, this message translates to:
  /// **'Failed to create category. Please try again.'**
  String get categoryCreationError;

  /// No description provided for @categoryDayPlanDescription.
  ///
  /// In en, this message translates to:
  /// **'Make this category available for selection in the day plan'**
  String get categoryDayPlanDescription;

  /// No description provided for @categoryDayPlanLabel.
  ///
  /// In en, this message translates to:
  /// **'Day planning'**
  String get categoryDayPlanLabel;

  /// No description provided for @categoryDefaultLanguageDescription.
  ///
  /// In en, this message translates to:
  /// **'Set a default language for tasks in this category'**
  String get categoryDefaultLanguageDescription;

  /// No description provided for @categoryDefaultProfileHint.
  ///
  /// In en, this message translates to:
  /// **'Select a profile'**
  String get categoryDefaultProfileHint;

  /// No description provided for @categoryDefaultTemplateHint.
  ///
  /// In en, this message translates to:
  /// **'Select a template'**
  String get categoryDefaultTemplateHint;

  /// No description provided for @categoryDefaultTemplateLabel.
  ///
  /// In en, this message translates to:
  /// **'Default agent template'**
  String get categoryDefaultTemplateLabel;

  /// No description provided for @categoryDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'YES, DELETE THIS CATEGORY'**
  String get categoryDeleteConfirm;

  /// No description provided for @categoryDeleteConfirmation.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone. All entries in this category will remain but will no longer be categorized.'**
  String get categoryDeleteConfirmation;

  /// No description provided for @categoryDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Category?'**
  String get categoryDeleteTitle;

  /// No description provided for @categoryFavoriteBadgeLabel.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get categoryFavoriteBadgeLabel;

  /// No description provided for @categoryFavoriteDescription.
  ///
  /// In en, this message translates to:
  /// **'Mark this category as a favorite'**
  String get categoryFavoriteDescription;

  /// No description provided for @categoryIconChooseHint.
  ///
  /// In en, this message translates to:
  /// **'Select an icon'**
  String get categoryIconChooseHint;

  /// No description provided for @categoryIconCreateHint.
  ///
  /// In en, this message translates to:
  /// **'Select an icon'**
  String get categoryIconCreateHint;

  /// No description provided for @categoryIconEditHint.
  ///
  /// In en, this message translates to:
  /// **'Select a different icon'**
  String get categoryIconEditHint;

  /// No description provided for @categoryIconLabel.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get categoryIconLabel;

  /// No description provided for @categoryIconPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose icon'**
  String get categoryIconPickerTitle;

  /// No description provided for @categoryNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Category name is required'**
  String get categoryNameRequired;

  /// No description provided for @categoryNotFound.
  ///
  /// In en, this message translates to:
  /// **'Category not found'**
  String get categoryNotFound;

  /// No description provided for @categoryPrivateBadgeLabel.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get categoryPrivateBadgeLabel;

  /// No description provided for @categoryPrivateDescription.
  ///
  /// In en, this message translates to:
  /// **'Only visible when private entries are shown'**
  String get categoryPrivateDescription;

  /// No description provided for @categorySearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search categories...'**
  String get categorySearchPlaceholder;

  /// No description provided for @changeSetCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Proposed changes'**
  String get changeSetCardTitle;

  /// No description provided for @changeSetConfirmAll.
  ///
  /// In en, this message translates to:
  /// **'Confirm all'**
  String get changeSetConfirmAll;

  /// No description provided for @changeSetConfirmAllPartialIssues.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item had partial issues} other{{count} items had partial issues}}'**
  String changeSetConfirmAllPartialIssues(int count);

  /// No description provided for @changeSetConfirmError.
  ///
  /// In en, this message translates to:
  /// **'Failed to apply change'**
  String get changeSetConfirmError;

  /// No description provided for @changeSetItemConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Change applied'**
  String get changeSetItemConfirmed;

  /// No description provided for @changeSetItemConfirmedWithWarning.
  ///
  /// In en, this message translates to:
  /// **'Applied with warning: {warning}'**
  String changeSetItemConfirmedWithWarning(String warning);

  /// No description provided for @changeSetItemRejected.
  ///
  /// In en, this message translates to:
  /// **'Change rejected'**
  String get changeSetItemRejected;

  /// No description provided for @changeSetPendingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} pending'**
  String changeSetPendingCount(int count);

  /// No description provided for @changeSetSwipeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get changeSetSwipeConfirm;

  /// No description provided for @changeSetSwipeReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get changeSetSwipeReject;

  /// No description provided for @chatInputCancelRealtime.
  ///
  /// In en, this message translates to:
  /// **'Cancel (Esc)'**
  String get chatInputCancelRealtime;

  /// No description provided for @chatInputCancelRecording.
  ///
  /// In en, this message translates to:
  /// **'Cancel recording (Esc)'**
  String get chatInputCancelRecording;

  /// No description provided for @chatInputConfigureModel.
  ///
  /// In en, this message translates to:
  /// **'Configure model'**
  String get chatInputConfigureModel;

  /// No description provided for @chatInputHintDefault.
  ///
  /// In en, this message translates to:
  /// **'Ask about your tasks and productivity...'**
  String get chatInputHintDefault;

  /// No description provided for @chatInputHintSelectModel.
  ///
  /// In en, this message translates to:
  /// **'Select a model to start chatting'**
  String get chatInputHintSelectModel;

  /// No description provided for @chatInputListening.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get chatInputListening;

  /// No description provided for @chatInputPleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait...'**
  String get chatInputPleaseWait;

  /// No description provided for @chatInputProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get chatInputProcessing;

  /// No description provided for @chatInputRecordVoice.
  ///
  /// In en, this message translates to:
  /// **'Record voice message'**
  String get chatInputRecordVoice;

  /// No description provided for @chatInputSendTooltip.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get chatInputSendTooltip;

  /// No description provided for @chatInputStartRealtime.
  ///
  /// In en, this message translates to:
  /// **'Start live transcription'**
  String get chatInputStartRealtime;

  /// No description provided for @chatInputStopRealtime.
  ///
  /// In en, this message translates to:
  /// **'Stop live transcription'**
  String get chatInputStopRealtime;

  /// No description provided for @chatInputStopTranscribe.
  ///
  /// In en, this message translates to:
  /// **'Stop and transcribe'**
  String get chatInputStopTranscribe;

  /// No description provided for @checklistAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add a new item'**
  String get checklistAddItem;

  /// Confidence level label in the AI suggestion dialog
  ///
  /// In en, this message translates to:
  /// **'Confidence: {level}'**
  String checklistAiConfidenceLabel(String level);

  /// No description provided for @checklistAiMarkComplete.
  ///
  /// In en, this message translates to:
  /// **'Mark Complete'**
  String get checklistAiMarkComplete;

  /// No description provided for @checklistAiSuggestionBody.
  ///
  /// In en, this message translates to:
  /// **'This item appears to be completed:'**
  String get checklistAiSuggestionBody;

  /// No description provided for @checklistAiSuggestionTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Suggestion'**
  String get checklistAiSuggestionTitle;

  /// No description provided for @checklistAllDone.
  ///
  /// In en, this message translates to:
  /// **'All items completed!'**
  String get checklistAllDone;

  /// No description provided for @checklistCollapseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get checklistCollapseTooltip;

  /// No description provided for @checklistCompletedShort.
  ///
  /// In en, this message translates to:
  /// **'{completed}/{total} done'**
  String checklistCompletedShort(int completed, int total);

  /// No description provided for @checklistDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete checklist?'**
  String get checklistDelete;

  /// No description provided for @checklistExpandTooltip.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get checklistExpandTooltip;

  /// No description provided for @checklistExportAsMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Export checklist as Markdown'**
  String get checklistExportAsMarkdown;

  /// No description provided for @checklistExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get checklistExportFailed;

  /// No description provided for @checklistItemArchived.
  ///
  /// In en, this message translates to:
  /// **'Item archived'**
  String get checklistItemArchived;

  /// No description provided for @checklistItemArchiveUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get checklistItemArchiveUndo;

  /// No description provided for @checklistItemDeleteCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get checklistItemDeleteCancel;

  /// No description provided for @checklistItemDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get checklistItemDeleteConfirm;

  /// No description provided for @checklistItemDeleted.
  ///
  /// In en, this message translates to:
  /// **'Item deleted'**
  String get checklistItemDeleted;

  /// No description provided for @checklistItemDeleteWarning.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get checklistItemDeleteWarning;

  /// No description provided for @checklistMarkdownCopied.
  ///
  /// In en, this message translates to:
  /// **'Checklist copied as Markdown'**
  String get checklistMarkdownCopied;

  /// No description provided for @checklistMoreTooltip.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get checklistMoreTooltip;

  /// No description provided for @checklistNoneDone.
  ///
  /// In en, this message translates to:
  /// **'No completed items yet.'**
  String get checklistNoneDone;

  /// No description provided for @checklistNothingToExport.
  ///
  /// In en, this message translates to:
  /// **'No items to export'**
  String get checklistNothingToExport;

  /// No description provided for @checklistProgressSemantics.
  ///
  /// In en, this message translates to:
  /// **'Checklist progress'**
  String get checklistProgressSemantics;

  /// No description provided for @checklistShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get checklistShare;

  /// No description provided for @checklistShareHint.
  ///
  /// In en, this message translates to:
  /// **'Long press to share'**
  String get checklistShareHint;

  /// No description provided for @checklistsReorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get checklistsReorder;

  /// No description provided for @clearButton.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearButton;

  /// No description provided for @colorCustomLabel.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get colorCustomLabel;

  /// No description provided for @colorLabel.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get colorLabel;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @commonUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get commonUnknown;

  /// No description provided for @completeHabitFailButton.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get completeHabitFailButton;

  /// No description provided for @completeHabitSkipButton.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get completeHabitSkipButton;

  /// No description provided for @completeHabitSuccessButton.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get completeHabitSuccessButton;

  /// No description provided for @configFlagAttemptEmbeddingDescription.
  ///
  /// In en, this message translates to:
  /// **'When enabled, the app will attempt to generate embeddings for your entries to improve search and related content suggestions.'**
  String get configFlagAttemptEmbeddingDescription;

  /// No description provided for @configFlagDailyOsNextEnabled.
  ///
  /// In en, this message translates to:
  /// **'Use next-gen agentic DailyOS'**
  String get configFlagDailyOsNextEnabled;

  /// No description provided for @configFlagDailyOsNextEnabledDescription.
  ///
  /// In en, this message translates to:
  /// **'Replace the current DailyOS surface with the new voice-first, agent-led capture and reconcile flow. Early preview — backend logic is mocked.'**
  String get configFlagDailyOsNextEnabledDescription;

  /// No description provided for @configFlagEnableAiStreaming.
  ///
  /// In en, this message translates to:
  /// **'Enable AI streaming for task actions'**
  String get configFlagEnableAiStreaming;

  /// No description provided for @configFlagEnableAiStreamingDescription.
  ///
  /// In en, this message translates to:
  /// **'Stream AI responses for task-related actions. Turn off to buffer responses and keep the UI smoother.'**
  String get configFlagEnableAiStreamingDescription;

  /// No description provided for @configFlagEnableAiSummaryTts.
  ///
  /// In en, this message translates to:
  /// **'AI summary playback'**
  String get configFlagEnableAiSummaryTts;

  /// No description provided for @configFlagEnableAiSummaryTtsDescription.
  ///
  /// In en, this message translates to:
  /// **'Show the local text-to-speech button on task AI summaries. Requires an installed MLX Audio TTS model.'**
  String get configFlagEnableAiSummaryTtsDescription;

  /// No description provided for @configFlagEnableDailyOs.
  ///
  /// In en, this message translates to:
  /// **'Enable DailyOS'**
  String get configFlagEnableDailyOs;

  /// No description provided for @configFlagEnableDailyOsDescription.
  ///
  /// In en, this message translates to:
  /// **'Show the DailyOS page in the main navigation.'**
  String get configFlagEnableDailyOsDescription;

  /// No description provided for @configFlagEnableDashboardsPage.
  ///
  /// In en, this message translates to:
  /// **'Enable Dashboards page'**
  String get configFlagEnableDashboardsPage;

  /// No description provided for @configFlagEnableDashboardsPageDescription.
  ///
  /// In en, this message translates to:
  /// **'Show the Dashboards page in the main navigation. View your data and insights in customizable dashboards.'**
  String get configFlagEnableDashboardsPageDescription;

  /// No description provided for @configFlagEnableEmbeddings.
  ///
  /// In en, this message translates to:
  /// **'Generate Embeddings'**
  String get configFlagEnableEmbeddings;

  /// No description provided for @configFlagEnableEvents.
  ///
  /// In en, this message translates to:
  /// **'Enable Events'**
  String get configFlagEnableEvents;

  /// No description provided for @configFlagEnableEventsDescription.
  ///
  /// In en, this message translates to:
  /// **'Show the Events feature to create, track, and manage events in your journal.'**
  String get configFlagEnableEventsDescription;

  /// No description provided for @configFlagEnableForkHealing.
  ///
  /// In en, this message translates to:
  /// **'Agent fork healing'**
  String get configFlagEnableForkHealing;

  /// No description provided for @configFlagEnableForkHealingDescription.
  ///
  /// In en, this message translates to:
  /// **'Heal divergent agent histories from multi-device use by merging them at the next wake.'**
  String get configFlagEnableForkHealingDescription;

  /// No description provided for @configFlagEnableHabitsPage.
  ///
  /// In en, this message translates to:
  /// **'Enable Habits page'**
  String get configFlagEnableHabitsPage;

  /// No description provided for @configFlagEnableHabitsPageDescription.
  ///
  /// In en, this message translates to:
  /// **'Show the Habits page in the main navigation. Track and manage your daily habits here.'**
  String get configFlagEnableHabitsPageDescription;

  /// No description provided for @configFlagEnableKnowledgeGraph.
  ///
  /// In en, this message translates to:
  /// **'Knowledge Graph'**
  String get configFlagEnableKnowledgeGraph;

  /// No description provided for @configFlagEnableKnowledgeGraphDescription.
  ///
  /// In en, this message translates to:
  /// **'Show the experimental knowledge graph explorer on tasks — a visual map of links between tasks, entries, and projects.'**
  String get configFlagEnableKnowledgeGraphDescription;

  /// No description provided for @configFlagEnableLogging.
  ///
  /// In en, this message translates to:
  /// **'Enable logging'**
  String get configFlagEnableLogging;

  /// No description provided for @configFlagEnableLoggingDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable detailed logging for debugging purposes. This may impact performance.'**
  String get configFlagEnableLoggingDescription;

  /// No description provided for @configFlagEnableMatrix.
  ///
  /// In en, this message translates to:
  /// **'Enable Matrix sync'**
  String get configFlagEnableMatrix;

  /// No description provided for @configFlagEnableMatrixDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable the Matrix integration to sync your entries across devices and with other Matrix users.'**
  String get configFlagEnableMatrixDescription;

  /// No description provided for @configFlagEnableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications?'**
  String get configFlagEnableNotifications;

  /// No description provided for @configFlagEnableNotificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Receive notifications for reminders, updates, and important events.'**
  String get configFlagEnableNotificationsDescription;

  /// No description provided for @configFlagEnableProjects.
  ///
  /// In en, this message translates to:
  /// **'Enable Projects'**
  String get configFlagEnableProjects;

  /// No description provided for @configFlagEnableProjectsDescription.
  ///
  /// In en, this message translates to:
  /// **'Show project management features for organizing tasks into projects.'**
  String get configFlagEnableProjectsDescription;

  /// No description provided for @configFlagEnableSessionRatings.
  ///
  /// In en, this message translates to:
  /// **'Enable Session Ratings'**
  String get configFlagEnableSessionRatings;

  /// No description provided for @configFlagEnableSessionRatingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Prompt for a quick session rating when you stop a timer.'**
  String get configFlagEnableSessionRatingsDescription;

  /// No description provided for @configFlagEnableSyncedAlerts.
  ///
  /// In en, this message translates to:
  /// **'Synced alerts'**
  String get configFlagEnableSyncedAlerts;

  /// No description provided for @configFlagEnableSyncedAlertsDescription.
  ///
  /// In en, this message translates to:
  /// **'Sync AI and task alerts across devices and allow them to schedule local OS notifications.'**
  String get configFlagEnableSyncedAlertsDescription;

  /// No description provided for @configFlagEnableTooltip.
  ///
  /// In en, this message translates to:
  /// **'Enable tooltips'**
  String get configFlagEnableTooltip;

  /// No description provided for @configFlagEnableTooltipDescription.
  ///
  /// In en, this message translates to:
  /// **'Show helpful tooltips throughout the app to guide you through features.'**
  String get configFlagEnableTooltipDescription;

  /// No description provided for @configFlagEnableVectorSearch.
  ///
  /// In en, this message translates to:
  /// **'Vector Search'**
  String get configFlagEnableVectorSearch;

  /// No description provided for @configFlagEnableVectorSearchDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable vector search in task filters. Requires embeddings to be enabled and Ollama running.'**
  String get configFlagEnableVectorSearchDescription;

  /// No description provided for @configFlagEnableWhatsNew.
  ///
  /// In en, this message translates to:
  /// **'Show What\'s New'**
  String get configFlagEnableWhatsNew;

  /// No description provided for @configFlagEnableWhatsNewDescription.
  ///
  /// In en, this message translates to:
  /// **'Highlight new features and changes inside the Settings tree.'**
  String get configFlagEnableWhatsNewDescription;

  /// No description provided for @configFlagPrivate.
  ///
  /// In en, this message translates to:
  /// **'Show private entries?'**
  String get configFlagPrivate;

  /// No description provided for @configFlagPrivateDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable this to make your entries private by default. Private entries are only visible to you.'**
  String get configFlagPrivateDescription;

  /// No description provided for @configFlagRecordLocation.
  ///
  /// In en, this message translates to:
  /// **'Record location'**
  String get configFlagRecordLocation;

  /// No description provided for @configFlagRecordLocationDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatically record your location with new entries. This helps with location-based organization and search.'**
  String get configFlagRecordLocationDescription;

  /// No description provided for @configFlagResendAttachments.
  ///
  /// In en, this message translates to:
  /// **'Resend attachments'**
  String get configFlagResendAttachments;

  /// No description provided for @configFlagResendAttachmentsDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable this to automatically resend failed attachment uploads when the connection is restored.'**
  String get configFlagResendAttachmentsDescription;

  /// No description provided for @configFlagShowSidebarWakeQueue.
  ///
  /// In en, this message translates to:
  /// **'Show sidebar wake queue'**
  String get configFlagShowSidebarWakeQueue;

  /// No description provided for @configFlagShowSidebarWakeQueueDescription.
  ///
  /// In en, this message translates to:
  /// **'Show the inline Wake Queue above Settings — header, the next two pending wakes with countdowns, and a link to the full list.'**
  String get configFlagShowSidebarWakeQueueDescription;

  /// No description provided for @configFlagShowSyncActivityIndicator.
  ///
  /// In en, this message translates to:
  /// **'Show sync activity indicator'**
  String get configFlagShowSyncActivityIndicator;

  /// No description provided for @configFlagShowSyncActivityIndicatorDescription.
  ///
  /// In en, this message translates to:
  /// **'Show live sync activity in the sidebar — a tx/rx LED strip with outbox and inbox depth.'**
  String get configFlagShowSyncActivityIndicatorDescription;

  /// No description provided for @conflictApplyButton.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get conflictApplyButton;

  /// No description provided for @conflictApplyFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t apply resolution'**
  String get conflictApplyFailedTitle;

  /// No description provided for @conflictBannerAgoDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String conflictBannerAgoDays(int count);

  /// No description provided for @conflictBannerAgoHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 h ago} other{{count} h ago}}'**
  String conflictBannerAgoHours(int count);

  /// No description provided for @conflictBannerAgoJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get conflictBannerAgoJustNow;

  /// No description provided for @conflictBannerAgoMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 min ago} other{{count} min ago}}'**
  String conflictBannerAgoMinutes(int count);

  /// Conflict summary banner first line.
  ///
  /// In en, this message translates to:
  /// **'{entity} · diverged {ago}'**
  String conflictBannerDivergedAgo(String entity, String ago);

  /// Conflict summary banner subline listing differing fields, e.g. 'Title · word count differ'.
  ///
  /// In en, this message translates to:
  /// **'Differs in: {fields}'**
  String conflictBannerFieldsDifferList(String fields);

  /// No description provided for @conflictCombineApply.
  ///
  /// In en, this message translates to:
  /// **'Apply combined'**
  String get conflictCombineApply;

  /// No description provided for @conflictCombineStartFrom.
  ///
  /// In en, this message translates to:
  /// **'Start from'**
  String get conflictCombineStartFrom;

  /// No description provided for @conflictConfirmDeletion.
  ///
  /// In en, this message translates to:
  /// **'Confirm deletion'**
  String get conflictConfirmDeletion;

  /// No description provided for @conflictDeleteVsEditDescription.
  ///
  /// In en, this message translates to:
  /// **'This entry was edited on one device and deleted on another. Nothing is removed until you choose.'**
  String get conflictDeleteVsEditDescription;

  /// No description provided for @conflictDeleteVsEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Deleted on one device'**
  String get conflictDeleteVsEditTitle;

  /// No description provided for @conflictDetailEntryNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Entry not found'**
  String get conflictDetailEntryNotFoundTitle;

  /// No description provided for @conflictDetailLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load conflict'**
  String get conflictDetailLoadErrorTitle;

  /// No description provided for @conflictDetailNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Conflict not found'**
  String get conflictDetailNotFoundTitle;

  /// No description provided for @conflictDiffRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get conflictDiffRecommended;

  /// No description provided for @conflictDiffUnchanged.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 field unchanged} other{{count} fields unchanged}}'**
  String conflictDiffUnchanged(int count);

  /// No description provided for @conflictFieldBody.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get conflictFieldBody;

  /// No description provided for @conflictFieldCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get conflictFieldCategory;

  /// No description provided for @conflictFieldDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get conflictFieldDuration;

  /// No description provided for @conflictFieldEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get conflictFieldEnd;

  /// No description provided for @conflictFieldFlag.
  ///
  /// In en, this message translates to:
  /// **'Flag'**
  String get conflictFieldFlag;

  /// No description provided for @conflictFieldOther.
  ///
  /// In en, this message translates to:
  /// **'Other details'**
  String get conflictFieldOther;

  /// No description provided for @conflictFieldOtherDescription.
  ///
  /// In en, this message translates to:
  /// **'These versions differ in details not shown individually here.'**
  String get conflictFieldOtherDescription;

  /// No description provided for @conflictFieldPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get conflictFieldPrivate;

  /// No description provided for @conflictFieldStarred.
  ///
  /// In en, this message translates to:
  /// **'Starred'**
  String get conflictFieldStarred;

  /// No description provided for @conflictFieldStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get conflictFieldStart;

  /// No description provided for @conflictFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get conflictFieldTitle;

  /// No description provided for @conflictFieldWordCount.
  ///
  /// In en, this message translates to:
  /// **'word count'**
  String get conflictFieldWordCount;

  /// No description provided for @conflictFlagFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Follow-up needed'**
  String get conflictFlagFollowUp;

  /// No description provided for @conflictFlagImport.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get conflictFlagImport;

  /// No description provided for @conflictFlagNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get conflictFlagNone;

  /// No description provided for @conflictFooterHelperLocalSelected.
  ///
  /// In en, this message translates to:
  /// **'Will keep your local edit and discard the synced version.'**
  String get conflictFooterHelperLocalSelected;

  /// No description provided for @conflictFooterHelperPickASide.
  ///
  /// In en, this message translates to:
  /// **'Pick a side to apply.'**
  String get conflictFooterHelperPickASide;

  /// No description provided for @conflictFooterHelperRemoteSelected.
  ///
  /// In en, this message translates to:
  /// **'Will accept the synced version and discard your local edit.'**
  String get conflictFooterHelperRemoteSelected;

  /// No description provided for @conflictHeaderPillEntries.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 entry} other{{count} entries}}'**
  String conflictHeaderPillEntries(int count);

  /// No description provided for @conflictHeaderPillFieldsDiffer.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 field differs} other{{count} fields differ}}'**
  String conflictHeaderPillFieldsDiffer(int count);

  /// No description provided for @conflictKeepEdited.
  ///
  /// In en, this message translates to:
  /// **'Keep the edited version'**
  String get conflictKeepEdited;

  /// Screen-reader label for a row in the conflicts list. Reads status, timestamp, entity type, and the full conflict id.
  ///
  /// In en, this message translates to:
  /// **'{status}, {timestamp}, {entityType}, conflict {id}'**
  String conflictListItemSemanticsLabel(
    String status,
    String timestamp,
    String entityType,
    String id,
  );

  /// Tooltip on the truncated conflict id in the list row, revealing the full id.
  ///
  /// In en, this message translates to:
  /// **'Conflict ID: {id}'**
  String conflictListItemTooltipFullId(String id);

  /// No description provided for @conflictMetaLocalEdit.
  ///
  /// In en, this message translates to:
  /// **'local edit'**
  String get conflictMetaLocalEdit;

  /// No description provided for @conflictMetaVecPrefix.
  ///
  /// In en, this message translates to:
  /// **'vec'**
  String get conflictMetaVecPrefix;

  /// No description provided for @conflictMetaViaSync.
  ///
  /// In en, this message translates to:
  /// **'via sync'**
  String get conflictMetaViaSync;

  /// No description provided for @conflictNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 entry was edited on two devices} other{{count} entries were edited on two devices}}'**
  String conflictNotificationBody(int count);

  /// No description provided for @conflictNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync needs your review'**
  String get conflictNotificationTitle;

  /// No description provided for @conflictPageLeadDesktop.
  ///
  /// In en, this message translates to:
  /// **'Differences highlighted inline. Click a side to use that version, or open Edit & merge to combine them.'**
  String get conflictPageLeadDesktop;

  /// No description provided for @conflictPageLeadMobile.
  ///
  /// In en, this message translates to:
  /// **'Differences highlighted inline. Tap a side to use that version.'**
  String get conflictPageLeadMobile;

  /// No description provided for @conflictPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync conflict'**
  String get conflictPageTitle;

  /// No description provided for @conflictPickerCombine.
  ///
  /// In en, this message translates to:
  /// **'Combine…'**
  String get conflictPickerCombine;

  /// No description provided for @conflictPickerEditMerge.
  ///
  /// In en, this message translates to:
  /// **'Edit & merge…'**
  String get conflictPickerEditMerge;

  /// No description provided for @conflictPickerUseFromSync.
  ///
  /// In en, this message translates to:
  /// **'Use from sync'**
  String get conflictPickerUseFromSync;

  /// No description provided for @conflictPickerUseThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Use this device'**
  String get conflictPickerUseThisDevice;

  /// No description provided for @conflictResolvedToast.
  ///
  /// In en, this message translates to:
  /// **'Conflict resolved'**
  String get conflictResolvedToast;

  /// No description provided for @conflictsEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Everything is in sync right now. Resolved items stay available in the other filter.'**
  String get conflictsEmptyDescription;

  /// No description provided for @conflictsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No conflicts detected'**
  String get conflictsEmptyTitle;

  /// No description provided for @conflictSideFromSync.
  ///
  /// In en, this message translates to:
  /// **'FROM SYNC'**
  String get conflictSideFromSync;

  /// No description provided for @conflictSideThisDevice.
  ///
  /// In en, this message translates to:
  /// **'THIS DEVICE'**
  String get conflictSideThisDevice;

  /// No description provided for @conflictsResolved.
  ///
  /// In en, this message translates to:
  /// **'resolved'**
  String get conflictsResolved;

  /// No description provided for @conflictsUnresolved.
  ///
  /// In en, this message translates to:
  /// **'unresolved'**
  String get conflictsUnresolved;

  /// No description provided for @conflictValueAbsent.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get conflictValueAbsent;

  /// No description provided for @conflictValueNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get conflictValueNo;

  /// No description provided for @conflictValueYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get conflictValueYes;

  /// Word count shown on the conflict detail meta row.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} word} other{{count} words}}'**
  String conflictWordCount(int count);

  /// No description provided for @copyAsMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Copy as Markdown'**
  String get copyAsMarkdown;

  /// No description provided for @copyAsText.
  ///
  /// In en, this message translates to:
  /// **'Copy as text'**
  String get copyAsText;

  /// No description provided for @correctionExampleCancel.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get correctionExampleCancel;

  /// No description provided for @correctionExamplePending.
  ///
  /// In en, this message translates to:
  /// **'Saving correction in {seconds}s...'**
  String correctionExamplePending(int seconds);

  /// No description provided for @correctionExamplesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No corrections captured yet. Edit a checklist item to add your first example.'**
  String get correctionExamplesEmpty;

  /// No description provided for @correctionExamplesSectionDescription.
  ///
  /// In en, this message translates to:
  /// **'When you manually correct checklist items, those corrections are saved here and used to improve AI suggestions.'**
  String get correctionExamplesSectionDescription;

  /// No description provided for @correctionExamplesSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Checklist correction examples'**
  String get correctionExamplesSectionTitle;

  /// No description provided for @correctionExamplesWarning.
  ///
  /// In en, this message translates to:
  /// **'You have {count} corrections. Only the most recent {max} will be used in AI prompts. Consider deleting old or redundant examples.'**
  String correctionExamplesWarning(int count, int max);

  /// No description provided for @coverArtChipActive.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get coverArtChipActive;

  /// No description provided for @coverArtChipSet.
  ///
  /// In en, this message translates to:
  /// **'Set cover'**
  String get coverArtChipSet;

  /// No description provided for @coverArtGenerationComplete.
  ///
  /// In en, this message translates to:
  /// **'Cover art ready!'**
  String get coverArtGenerationComplete;

  /// No description provided for @coverArtGenerationDismissHint.
  ///
  /// In en, this message translates to:
  /// **'You can close this — generation continues in the background'**
  String get coverArtGenerationDismissHint;

  /// No description provided for @createButton.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createButton;

  /// No description provided for @createCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Create category'**
  String get createCategoryTitle;

  /// No description provided for @createEntryLabel.
  ///
  /// In en, this message translates to:
  /// **'Create new entry'**
  String get createEntryLabel;

  /// No description provided for @createEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get createEntryTitle;

  /// No description provided for @createNewLinkedTask.
  ///
  /// In en, this message translates to:
  /// **'Create new linked task...'**
  String get createNewLinkedTask;

  /// No description provided for @customColor.
  ///
  /// In en, this message translates to:
  /// **'Custom Color'**
  String get customColor;

  /// No description provided for @dailyOsActual.
  ///
  /// In en, this message translates to:
  /// **'Actual'**
  String get dailyOsActual;

  /// No description provided for @dailyOsAddBlock.
  ///
  /// In en, this message translates to:
  /// **'Add Block'**
  String get dailyOsAddBlock;

  /// No description provided for @dailyOsAddBudget.
  ///
  /// In en, this message translates to:
  /// **'Add Budget'**
  String get dailyOsAddBudget;

  /// No description provided for @dailyOsAddNote.
  ///
  /// In en, this message translates to:
  /// **'Add a note...'**
  String get dailyOsAddNote;

  /// No description provided for @dailyOsAgreeToPlan.
  ///
  /// In en, this message translates to:
  /// **'Agree to Plan'**
  String get dailyOsAgreeToPlan;

  /// No description provided for @dailyOsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get dailyOsCancel;

  /// No description provided for @dailyOsCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get dailyOsCategory;

  /// No description provided for @dailyOsChooseCategory.
  ///
  /// In en, this message translates to:
  /// **'Choose a category...'**
  String get dailyOsChooseCategory;

  /// No description provided for @dailyOsDayPlan.
  ///
  /// In en, this message translates to:
  /// **'Day Plan'**
  String get dailyOsDayPlan;

  /// No description provided for @dailyOsDaySummary.
  ///
  /// In en, this message translates to:
  /// **'Day Summary'**
  String get dailyOsDaySummary;

  /// No description provided for @dailyOsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get dailyOsDelete;

  /// No description provided for @dailyOsDeletePlannedBlock.
  ///
  /// In en, this message translates to:
  /// **'Delete Block?'**
  String get dailyOsDeletePlannedBlock;

  /// No description provided for @dailyOsDeletePlannedBlockConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will remove the planned block from your timeline.'**
  String get dailyOsDeletePlannedBlockConfirm;

  /// No description provided for @dailyOsDraftMessage.
  ///
  /// In en, this message translates to:
  /// **'Plan is in draft. Agree to lock it in.'**
  String get dailyOsDraftMessage;

  /// No description provided for @dailyOsDueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get dailyOsDueToday;

  /// No description provided for @dailyOsDueTodayShort.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get dailyOsDueTodayShort;

  /// No description provided for @dailyOsDurationHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour} other{{count} hours}}'**
  String dailyOsDurationHours(int count);

  /// No description provided for @dailyOsDurationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String dailyOsDurationHoursMinutes(int hours, int minutes);

  /// No description provided for @dailyOsDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute} other{{count} minutes}}'**
  String dailyOsDurationMinutes(int count);

  /// No description provided for @dailyOsEditPlannedBlock.
  ///
  /// In en, this message translates to:
  /// **'Edit Planned Block'**
  String get dailyOsEditPlannedBlock;

  /// No description provided for @dailyOsEndTime.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get dailyOsEndTime;

  /// No description provided for @dailyOsExpandToMove.
  ///
  /// In en, this message translates to:
  /// **'Expand timeline to drag this block'**
  String get dailyOsExpandToMove;

  /// No description provided for @dailyOsExpandToMoveMore.
  ///
  /// In en, this message translates to:
  /// **'Expand timeline to move further'**
  String get dailyOsExpandToMoveMore;

  /// No description provided for @dailyOsFailedToLoadBudgets.
  ///
  /// In en, this message translates to:
  /// **'Failed to load budgets'**
  String get dailyOsFailedToLoadBudgets;

  /// No description provided for @dailyOsFailedToLoadTimeline.
  ///
  /// In en, this message translates to:
  /// **'Failed to load timeline'**
  String get dailyOsFailedToLoadTimeline;

  /// No description provided for @dailyOsFold.
  ///
  /// In en, this message translates to:
  /// **'Fold'**
  String get dailyOsFold;

  /// No description provided for @dailyOsInvalidTimeRange.
  ///
  /// In en, this message translates to:
  /// **'Invalid time range'**
  String get dailyOsInvalidTimeRange;

  /// No description provided for @dailyOsNearLimit.
  ///
  /// In en, this message translates to:
  /// **'Near limit'**
  String get dailyOsNearLimit;

  /// No description provided for @dailyOsNextAgendaCapacityComfortable.
  ///
  /// In en, this message translates to:
  /// **'Comfortable'**
  String get dailyOsNextAgendaCapacityComfortable;

  /// No description provided for @dailyOsNextAgendaCapacityNearFull.
  ///
  /// In en, this message translates to:
  /// **'Near full'**
  String get dailyOsNextAgendaCapacityNearFull;

  /// No description provided for @dailyOsNextAgendaCapacityNoPlan.
  ///
  /// In en, this message translates to:
  /// **'No plan yet'**
  String get dailyOsNextAgendaCapacityNoPlan;

  /// No description provided for @dailyOsNextAgendaCapacityOf.
  ///
  /// In en, this message translates to:
  /// **'of {capacity}'**
  String dailyOsNextAgendaCapacityOf(String capacity);

  /// No description provided for @dailyOsNextAgendaCapacityOver.
  ///
  /// In en, this message translates to:
  /// **'Over capacity'**
  String get dailyOsNextAgendaCapacityOver;

  /// No description provided for @dailyOsNextAgendaDonutLeft.
  ///
  /// In en, this message translates to:
  /// **'left'**
  String get dailyOsNextAgendaDonutLeft;

  /// No description provided for @dailyOsNextAgendaDonutOver.
  ///
  /// In en, this message translates to:
  /// **'over'**
  String get dailyOsNextAgendaDonutOver;

  /// No description provided for @dailyOsNextAgendaHeadlineLeft.
  ///
  /// In en, this message translates to:
  /// **'{duration} left'**
  String dailyOsNextAgendaHeadlineLeft(String duration);

  /// No description provided for @dailyOsNextAgendaHeadlineOver.
  ///
  /// In en, this message translates to:
  /// **'{duration} over'**
  String dailyOsNextAgendaHeadlineOver(String duration);

  /// No description provided for @dailyOsNextAgendaNoPlanBody.
  ///
  /// In en, this message translates to:
  /// **'Your tracked time is here either way — speak a check-in and I\'ll draft a day around it.'**
  String get dailyOsNextAgendaNoPlanBody;

  /// No description provided for @dailyOsNextAgendaNoPlanSummary.
  ///
  /// In en, this message translates to:
  /// **'{duration} tracked so far. Speak a check-in and I\'ll draft a day around it.'**
  String dailyOsNextAgendaNoPlanSummary(String duration);

  /// No description provided for @dailyOsNextAgendaNoPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'No plan yet for today.'**
  String get dailyOsNextAgendaNoPlanTitle;

  /// No description provided for @dailyOsNextAgendaStateDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get dailyOsNextAgendaStateDone;

  /// No description provided for @dailyOsNextAgendaStateInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get dailyOsNextAgendaStateInProgress;

  /// No description provided for @dailyOsNextAgendaStateOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get dailyOsNextAgendaStateOpen;

  /// No description provided for @dailyOsNextAgendaStateOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get dailyOsNextAgendaStateOverdue;

  /// No description provided for @dailyOsNextAgendaSummary.
  ///
  /// In en, this message translates to:
  /// **'{scheduled} of {capacity} committed'**
  String dailyOsNextAgendaSummary(String scheduled, String capacity);

  /// No description provided for @dailyOsNextAgendaTrackedLegend.
  ///
  /// In en, this message translates to:
  /// **'Tracked · {duration} · {completedCount} done'**
  String dailyOsNextAgendaTrackedLegend(String duration, int completedCount);

  /// No description provided for @dailyOsNextCaptureCaptured.
  ///
  /// In en, this message translates to:
  /// **'Got it.'**
  String get dailyOsNextCaptureCaptured;

  /// No description provided for @dailyOsNextCaptureDoneCta.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get dailyOsNextCaptureDoneCta;

  /// No description provided for @dailyOsNextCaptureErrorMicrophonePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission was denied.'**
  String get dailyOsNextCaptureErrorMicrophonePermissionDenied;

  /// No description provided for @dailyOsNextCaptureErrorNoActiveRealtimeSession.
  ///
  /// In en, this message translates to:
  /// **'No active realtime session.'**
  String get dailyOsNextCaptureErrorNoActiveRealtimeSession;

  /// No description provided for @dailyOsNextCaptureErrorNoAudioRecorded.
  ///
  /// In en, this message translates to:
  /// **'No audio was recorded.'**
  String get dailyOsNextCaptureErrorNoAudioRecorded;

  /// No description provided for @dailyOsNextCaptureErrorRealtimeTranscriptionFailed.
  ///
  /// In en, this message translates to:
  /// **'Realtime transcription failed.'**
  String get dailyOsNextCaptureErrorRealtimeTranscriptionFailed;

  /// No description provided for @dailyOsNextCaptureErrorRealtimeTranscriptionStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Realtime transcription could not start.'**
  String get dailyOsNextCaptureErrorRealtimeTranscriptionStartFailed;

  /// No description provided for @dailyOsNextCaptureErrorRecordingStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Recording could not start.'**
  String get dailyOsNextCaptureErrorRecordingStartFailed;

  /// No description provided for @dailyOsNextCaptureErrorTranscriptionFailed.
  ///
  /// In en, this message translates to:
  /// **'Transcription failed.'**
  String get dailyOsNextCaptureErrorTranscriptionFailed;

  /// No description provided for @dailyOsNextCaptureHeadlineCaptured.
  ///
  /// In en, this message translates to:
  /// **'Does this look right?'**
  String get dailyOsNextCaptureHeadlineCaptured;

  /// No description provided for @dailyOsNextCaptureHeadlineLead.
  ///
  /// In en, this message translates to:
  /// **'What’s on your mind'**
  String get dailyOsNextCaptureHeadlineLead;

  /// No description provided for @dailyOsNextCaptureHeadlineListening.
  ///
  /// In en, this message translates to:
  /// **'I’m listening.'**
  String get dailyOsNextCaptureHeadlineListening;

  /// No description provided for @dailyOsNextCaptureHeadlineTail.
  ///
  /// In en, this message translates to:
  /// **'for today?'**
  String get dailyOsNextCaptureHeadlineTail;

  /// No description provided for @dailyOsNextCaptureHeadlineTailForDate.
  ///
  /// In en, this message translates to:
  /// **'for {date}?'**
  String dailyOsNextCaptureHeadlineTailForDate(String date);

  /// No description provided for @dailyOsNextCaptureHeadlineTailTomorrow.
  ///
  /// In en, this message translates to:
  /// **'for tomorrow?'**
  String get dailyOsNextCaptureHeadlineTailTomorrow;

  /// No description provided for @dailyOsNextCaptureHeadlineTailYesterday.
  ///
  /// In en, this message translates to:
  /// **'for yesterday?'**
  String get dailyOsNextCaptureHeadlineTailYesterday;

  /// No description provided for @dailyOsNextCaptureHeadlineTranscribing.
  ///
  /// In en, this message translates to:
  /// **'Writing that down…'**
  String get dailyOsNextCaptureHeadlineTranscribing;

  /// No description provided for @dailyOsNextCaptureIdleClick.
  ///
  /// In en, this message translates to:
  /// **'Click to talk'**
  String get dailyOsNextCaptureIdleClick;

  /// No description provided for @dailyOsNextCaptureIdleExample.
  ///
  /// In en, this message translates to:
  /// **'“Deep work this morning, a walk after lunch, emails before five.”'**
  String get dailyOsNextCaptureIdleExample;

  /// No description provided for @dailyOsNextCaptureIdleHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to talk · type instead'**
  String get dailyOsNextCaptureIdleHint;

  /// No description provided for @dailyOsNextCaptureIdleTalk.
  ///
  /// In en, this message translates to:
  /// **'Tap to talk'**
  String get dailyOsNextCaptureIdleTalk;

  /// No description provided for @dailyOsNextCaptureListeningStatus.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get dailyOsNextCaptureListeningStatus;

  /// No description provided for @dailyOsNextCapturePastPrompt.
  ///
  /// In en, this message translates to:
  /// **'Anything you still want to track from {date}?'**
  String dailyOsNextCapturePastPrompt(String date);

  /// No description provided for @dailyOsNextCaptureReconcileCta.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get dailyOsNextCaptureReconcileCta;

  /// No description provided for @dailyOsNextCapturesPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'Captures'**
  String get dailyOsNextCapturesPanelTitle;

  /// No description provided for @dailyOsNextCaptureTranscribing.
  ///
  /// In en, this message translates to:
  /// **'Transcribing…'**
  String get dailyOsNextCaptureTranscribing;

  /// No description provided for @dailyOsNextCaptureTranscriptHint.
  ///
  /// In en, this message translates to:
  /// **'Fix anything the transcript got wrong before planning.'**
  String get dailyOsNextCaptureTranscriptHint;

  /// No description provided for @dailyOsNextCaptureTranscriptLabel.
  ///
  /// In en, this message translates to:
  /// **'Review transcript'**
  String get dailyOsNextCaptureTranscriptLabel;

  /// No description provided for @dailyOsNextCaptureTypeInstead.
  ///
  /// In en, this message translates to:
  /// **'Type instead'**
  String get dailyOsNextCaptureTypeInstead;

  /// No description provided for @dailyOsNextCaptureVoiceButtonReset.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get dailyOsNextCaptureVoiceButtonReset;

  /// No description provided for @dailyOsNextCaptureVoiceButtonStart.
  ///
  /// In en, this message translates to:
  /// **'Start listening'**
  String get dailyOsNextCaptureVoiceButtonStart;

  /// No description provided for @dailyOsNextCaptureVoiceButtonStop.
  ///
  /// In en, this message translates to:
  /// **'Stop listening'**
  String get dailyOsNextCaptureVoiceButtonStop;

  /// No description provided for @dailyOsNextCategoryFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get dailyOsNextCategoryFilterAll;

  /// No description provided for @dailyOsNextCategoryFilterDescription.
  ///
  /// In en, this message translates to:
  /// **'Only categories enabled for day planning are surfaced for Daily OS automated processing.'**
  String get dailyOsNextCategoryFilterDescription;

  /// No description provided for @dailyOsNextCategoryFilterEmpty.
  ///
  /// In en, this message translates to:
  /// **'No categories enabled for day planning yet.'**
  String get dailyOsNextCategoryFilterEmpty;

  /// No description provided for @dailyOsNextCategoryFilterIncludeAll.
  ///
  /// In en, this message translates to:
  /// **'Include all'**
  String get dailyOsNextCategoryFilterIncludeAll;

  /// No description provided for @dailyOsNextCategoryFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'Processing categories'**
  String get dailyOsNextCategoryFilterTitle;

  /// No description provided for @dailyOsNextCategoryFilterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Choose Daily OS processing categories'**
  String get dailyOsNextCategoryFilterTooltip;

  /// No description provided for @dailyOsNextCommitCapacityNote.
  ///
  /// In en, this message translates to:
  /// **'{scheduled} of {capacity} committed. Comfortable margin — you can absorb one surprise.'**
  String dailyOsNextCommitCapacityNote(String scheduled, String capacity);

  /// No description provided for @dailyOsNextCommitDraftOverline.
  ///
  /// In en, this message translates to:
  /// **'YOUR DAY, DRAFTED'**
  String get dailyOsNextCommitDraftOverline;

  /// No description provided for @dailyOsNextCommitExplainer.
  ///
  /// In en, this message translates to:
  /// **'Sign off to move today from draft to committed.'**
  String get dailyOsNextCommitExplainer;

  /// No description provided for @dailyOsNextCommitFinalStepEyebrow.
  ///
  /// In en, this message translates to:
  /// **'FINAL STEP'**
  String get dailyOsNextCommitFinalStepEyebrow;

  /// No description provided for @dailyOsNextCommitHeadline.
  ///
  /// In en, this message translates to:
  /// **'Make it yours.'**
  String get dailyOsNextCommitHeadline;

  /// No description provided for @dailyOsNextCommitHoldHelper.
  ///
  /// In en, this message translates to:
  /// **'Hold for a second to sign off'**
  String get dailyOsNextCommitHoldHelper;

  /// No description provided for @dailyOsNextCommitHoldWordDone.
  ///
  /// In en, this message translates to:
  /// **'Committed'**
  String get dailyOsNextCommitHoldWordDone;

  /// No description provided for @dailyOsNextCommitHoldWordHolding.
  ///
  /// In en, this message translates to:
  /// **'Keep holding'**
  String get dailyOsNextCommitHoldWordHolding;

  /// No description provided for @dailyOsNextCommitHoldWordIdle.
  ///
  /// In en, this message translates to:
  /// **'Hold'**
  String get dailyOsNextCommitHoldWordIdle;

  /// No description provided for @dailyOsNextCommitLockingIn.
  ///
  /// In en, this message translates to:
  /// **'Locking in…'**
  String get dailyOsNextCommitLockingIn;

  /// No description provided for @dailyOsNextCommitShepherdSubline.
  ///
  /// In en, this message translates to:
  /// **'I\'ll shepherd it — you do the work.'**
  String get dailyOsNextCommitShepherdSubline;

  /// No description provided for @dailyOsNextCommitSubCaption.
  ///
  /// In en, this message translates to:
  /// **'You can still talk to me afterward — but the bones stay put.'**
  String get dailyOsNextCommitSubCaption;

  /// No description provided for @dailyOsNextCommitTitle.
  ///
  /// In en, this message translates to:
  /// **'Lock it in'**
  String get dailyOsNextCommitTitle;

  /// No description provided for @dailyOsNextCommitTodayIsYours.
  ///
  /// In en, this message translates to:
  /// **'Today is yours.'**
  String get dailyOsNextCommitTodayIsYours;

  /// No description provided for @dailyOsNextDayBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get dailyOsNextDayBack;

  /// No description provided for @dailyOsNextDayCheckInCta.
  ///
  /// In en, this message translates to:
  /// **'Speak a check-in'**
  String get dailyOsNextDayCheckInCta;

  /// No description provided for @dailyOsNextDayDeleteDialogBody.
  ///
  /// In en, this message translates to:
  /// **'The drafted blocks for this day will be removed. Captures and their audio recordings stay in your journal.'**
  String get dailyOsNextDayDeleteDialogBody;

  /// No description provided for @dailyOsNextDayDeleteDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get dailyOsNextDayDeleteDialogCancel;

  /// No description provided for @dailyOsNextDayDeleteDialogConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get dailyOsNextDayDeleteDialogConfirm;

  /// No description provided for @dailyOsNextDayDeleteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this plan?'**
  String get dailyOsNextDayDeleteDialogTitle;

  /// No description provided for @dailyOsNextDayLockInCta.
  ///
  /// In en, this message translates to:
  /// **'Lock in'**
  String get dailyOsNextDayLockInCta;

  /// No description provided for @dailyOsNextDayMenuDeletePlan.
  ///
  /// In en, this message translates to:
  /// **'Delete plan'**
  String get dailyOsNextDayMenuDeletePlan;

  /// No description provided for @dailyOsNextDayMenuInspectAgent.
  ///
  /// In en, this message translates to:
  /// **'Inspect agent'**
  String get dailyOsNextDayMenuInspectAgent;

  /// No description provided for @dailyOsNextDayMoreTooltip.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get dailyOsNextDayMoreTooltip;

  /// No description provided for @dailyOsNextDayRefineCta.
  ///
  /// In en, this message translates to:
  /// **'Refine'**
  String get dailyOsNextDayRefineCta;

  /// No description provided for @dailyOsNextDayRefineFooterHint.
  ///
  /// In en, this message translates to:
  /// **'Talk to reshape the plan — you\'ll see every change before anything is saved.'**
  String get dailyOsNextDayRefineFooterHint;

  /// No description provided for @dailyOsNextDayTitle.
  ///
  /// In en, this message translates to:
  /// **'Your day'**
  String get dailyOsNextDayTitle;

  /// No description provided for @dailyOsNextDayWhyChipLabel.
  ///
  /// In en, this message translates to:
  /// **'WHY'**
  String get dailyOsNextDayWhyChipLabel;

  /// No description provided for @dailyOsNextDayWrapUpCta.
  ///
  /// In en, this message translates to:
  /// **'Wrap up'**
  String get dailyOsNextDayWrapUpCta;

  /// No description provided for @dailyOsNextDraftingHeader.
  ///
  /// In en, this message translates to:
  /// **'Drafting your day…'**
  String get dailyOsNextDraftingHeader;

  /// No description provided for @dailyOsNextDraftingNudgeAccept.
  ///
  /// In en, this message translates to:
  /// **'Yes, protect mornings'**
  String get dailyOsNextDraftingNudgeAccept;

  /// No description provided for @dailyOsNextDraftingNudgeDecline.
  ///
  /// In en, this message translates to:
  /// **'Not today'**
  String get dailyOsNextDraftingNudgeDecline;

  /// No description provided for @dailyOsNextDraftingReasoningOverline.
  ///
  /// In en, this message translates to:
  /// **'✦ REASONING'**
  String get dailyOsNextDraftingReasoningOverline;

  /// No description provided for @dailyOsNextDraftingStatusAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Sequencing the afternoon…'**
  String get dailyOsNextDraftingStatusAfternoon;

  /// No description provided for @dailyOsNextDraftingStatusAlmost.
  ///
  /// In en, this message translates to:
  /// **'Almost there…'**
  String get dailyOsNextDraftingStatusAlmost;

  /// No description provided for @dailyOsNextDraftingStatusBreathing.
  ///
  /// In en, this message translates to:
  /// **'Leaving room to breathe…'**
  String get dailyOsNextDraftingStatusBreathing;

  /// No description provided for @dailyOsNextDraftingStatusDeepWork.
  ///
  /// In en, this message translates to:
  /// **'Placing deep work first…'**
  String get dailyOsNextDraftingStatusDeepWork;

  /// No description provided for @dailyOsNextDraftingStatusMatching.
  ///
  /// In en, this message translates to:
  /// **'Matching tasks to your day…'**
  String get dailyOsNextDraftingStatusMatching;

  /// No description provided for @dailyOsNextDraftingStatusReading.
  ///
  /// In en, this message translates to:
  /// **'Reading your check-in…'**
  String get dailyOsNextDraftingStatusReading;

  /// No description provided for @dailyOsNextDraftingStatusTimings.
  ///
  /// In en, this message translates to:
  /// **'Double-checking timings…'**
  String get dailyOsNextDraftingStatusTimings;

  /// No description provided for @dailyOsNextDraftingStatusYesterday.
  ///
  /// In en, this message translates to:
  /// **'Looking at yesterday\'s rhythm…'**
  String get dailyOsNextDraftingStatusYesterday;

  /// No description provided for @dailyOsNextEditTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Edit title'**
  String get dailyOsNextEditTitleHint;

  /// No description provided for @dailyOsNextGenericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again in a moment.'**
  String get dailyOsNextGenericError;

  /// No description provided for @dailyOsNextGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon.'**
  String get dailyOsNextGreetingAfternoon;

  /// No description provided for @dailyOsNextGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening.'**
  String get dailyOsNextGreetingEvening;

  /// No description provided for @dailyOsNextGreetingHiName.
  ///
  /// In en, this message translates to:
  /// **'Hi {name} 👋'**
  String dailyOsNextGreetingHiName(String name);

  /// No description provided for @dailyOsNextGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning.'**
  String get dailyOsNextGreetingMorning;

  /// No description provided for @dailyOsNextKnowledgeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get dailyOsNextKnowledgeConfirm;

  /// No description provided for @dailyOsNextKnowledgeConfirmedHeader.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get dailyOsNextKnowledgeConfirmedHeader;

  /// No description provided for @dailyOsNextKnowledgeEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get dailyOsNextKnowledgeEdit;

  /// No description provided for @dailyOsNextKnowledgeEditCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get dailyOsNextKnowledgeEditCancel;

  /// No description provided for @dailyOsNextKnowledgeEditHookHint.
  ///
  /// In en, this message translates to:
  /// **'One-line summary'**
  String get dailyOsNextKnowledgeEditHookHint;

  /// No description provided for @dailyOsNextKnowledgeEditSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get dailyOsNextKnowledgeEditSave;

  /// No description provided for @dailyOsNextKnowledgeEditStatementHint.
  ///
  /// In en, this message translates to:
  /// **'What should I remember?'**
  String get dailyOsNextKnowledgeEditStatementHint;

  /// No description provided for @dailyOsNextKnowledgeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet — I\'ll remember what you tell me.'**
  String get dailyOsNextKnowledgeEmpty;

  /// No description provided for @dailyOsNextKnowledgeNudge.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 thing I noticed — review} other{{count} things I noticed — review}}'**
  String dailyOsNextKnowledgeNudge(int count);

  /// No description provided for @dailyOsNextKnowledgeProposedHeader.
  ///
  /// In en, this message translates to:
  /// **'Awaiting your confirmation'**
  String get dailyOsNextKnowledgeProposedHeader;

  /// No description provided for @dailyOsNextKnowledgeRetract.
  ///
  /// In en, this message translates to:
  /// **'Forget'**
  String get dailyOsNextKnowledgeRetract;

  /// No description provided for @dailyOsNextKnowledgeStale.
  ///
  /// In en, this message translates to:
  /// **'Still true?'**
  String get dailyOsNextKnowledgeStale;

  /// No description provided for @dailyOsNextKnowledgeTitle.
  ///
  /// In en, this message translates to:
  /// **'What I\'ve learned'**
  String get dailyOsNextKnowledgeTitle;

  /// No description provided for @dailyOsNextParsedCardBreakLinkTooltip.
  ///
  /// In en, this message translates to:
  /// **'Break link'**
  String get dailyOsNextParsedCardBreakLinkTooltip;

  /// No description provided for @dailyOsNextPlanViewAgenda.
  ///
  /// In en, this message translates to:
  /// **'Agenda'**
  String get dailyOsNextPlanViewAgenda;

  /// No description provided for @dailyOsNextPlanViewDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get dailyOsNextPlanViewDay;

  /// No description provided for @dailyOsNextReconcileBadgeMatched.
  ///
  /// In en, this message translates to:
  /// **'MATCHED'**
  String get dailyOsNextReconcileBadgeMatched;

  /// No description provided for @dailyOsNextReconcileBadgeNew.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get dailyOsNextReconcileBadgeNew;

  /// No description provided for @dailyOsNextReconcileBadgeUpdate.
  ///
  /// In en, this message translates to:
  /// **'UPDATE'**
  String get dailyOsNextReconcileBadgeUpdate;

  /// No description provided for @dailyOsNextReconcileBuildDayCta.
  ///
  /// In en, this message translates to:
  /// **'Build my day'**
  String get dailyOsNextReconcileBuildDayCta;

  /// No description provided for @dailyOsNextReconcileDecideOverline.
  ///
  /// In en, this message translates to:
  /// **'WORTH DECIDING ON'**
  String get dailyOsNextReconcileDecideOverline;

  /// No description provided for @dailyOsNextReconcileDefaultBehaviorHint.
  ///
  /// In en, this message translates to:
  /// **'Decisions here feed into the plan — no decision means \"leave it where it is.\"'**
  String get dailyOsNextReconcileDefaultBehaviorHint;

  /// No description provided for @dailyOsNextReconcileError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {detail}'**
  String dailyOsNextReconcileError(String detail);

  /// No description provided for @dailyOsNextReconcileHeadline.
  ///
  /// In en, this message translates to:
  /// **'Here’s what I heard.'**
  String get dailyOsNextReconcileHeadline;

  /// No description provided for @dailyOsNextReconcileHeardEmpty.
  ///
  /// In en, this message translates to:
  /// **'Capture cards will appear here once parsing finishes.'**
  String get dailyOsNextReconcileHeardEmpty;

  /// No description provided for @dailyOsNextReconcileHeardOverline.
  ///
  /// In en, this message translates to:
  /// **'HEARD'**
  String get dailyOsNextReconcileHeardOverline;

  /// No description provided for @dailyOsNextReconcileLowConfidence.
  ///
  /// In en, this message translates to:
  /// **'low confidence'**
  String get dailyOsNextReconcileLowConfidence;

  /// No description provided for @dailyOsNextReconcileReRecord.
  ///
  /// In en, this message translates to:
  /// **'Re-record'**
  String get dailyOsNextReconcileReRecord;

  /// No description provided for @dailyOsNextReconcileVoiceHint.
  ///
  /// In en, this message translates to:
  /// **'Review decisions before building your day'**
  String get dailyOsNextReconcileVoiceHint;

  /// No description provided for @dailyOsNextRefineAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get dailyOsNextRefineAccept;

  /// No description provided for @dailyOsNextRefineCurrentPlan.
  ///
  /// In en, this message translates to:
  /// **'CURRENT PLAN'**
  String get dailyOsNextRefineCurrentPlan;

  /// No description provided for @dailyOsNextRefineDiffAdded.
  ///
  /// In en, this message translates to:
  /// **'ADDED'**
  String get dailyOsNextRefineDiffAdded;

  /// No description provided for @dailyOsNextRefineDiffDropped.
  ///
  /// In en, this message translates to:
  /// **'DROPPED'**
  String get dailyOsNextRefineDiffDropped;

  /// No description provided for @dailyOsNextRefineDiffMoved.
  ///
  /// In en, this message translates to:
  /// **'MOVED'**
  String get dailyOsNextRefineDiffMoved;

  /// No description provided for @dailyOsNextRefineHeadlineDiffReady.
  ///
  /// In en, this message translates to:
  /// **'Here’s what I’d change.'**
  String get dailyOsNextRefineHeadlineDiffReady;

  /// No description provided for @dailyOsNextRefineHeadlineIdle.
  ///
  /// In en, this message translates to:
  /// **'What should change?'**
  String get dailyOsNextRefineHeadlineIdle;

  /// No description provided for @dailyOsNextRefineHeadlineThinking.
  ///
  /// In en, this message translates to:
  /// **'Reworking your plan…'**
  String get dailyOsNextRefineHeadlineThinking;

  /// No description provided for @dailyOsNextRefineKeepTalking.
  ///
  /// In en, this message translates to:
  /// **'Keep talking'**
  String get dailyOsNextRefineKeepTalking;

  /// No description provided for @dailyOsNextRefineLooksGood.
  ///
  /// In en, this message translates to:
  /// **'Looks good'**
  String get dailyOsNextRefineLooksGood;

  /// No description provided for @dailyOsNextRefineNoChanges.
  ///
  /// In en, this message translates to:
  /// **'No plan changes came back. Reword it and try again.'**
  String get dailyOsNextRefineNoChanges;

  /// No description provided for @dailyOsNextRefineOverline.
  ///
  /// In en, this message translates to:
  /// **'🎤 REFINEMENT'**
  String get dailyOsNextRefineOverline;

  /// No description provided for @dailyOsNextRefineRevert.
  ///
  /// In en, this message translates to:
  /// **'Revert'**
  String get dailyOsNextRefineRevert;

  /// No description provided for @dailyOsNextRefineStatusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Locked in.'**
  String get dailyOsNextRefineStatusAccepted;

  /// No description provided for @dailyOsNextRefineStatusDiffReady.
  ///
  /// In en, this message translates to:
  /// **'Here\'s what changed.'**
  String get dailyOsNextRefineStatusDiffReady;

  /// No description provided for @dailyOsNextRefineStatusIdle.
  ///
  /// In en, this message translates to:
  /// **'Tap to talk.'**
  String get dailyOsNextRefineStatusIdle;

  /// No description provided for @dailyOsNextRefineStatusListening.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get dailyOsNextRefineStatusListening;

  /// No description provided for @dailyOsNextRefineStatusThinking.
  ///
  /// In en, this message translates to:
  /// **'✦ Reworking the plan…'**
  String get dailyOsNextRefineStatusThinking;

  /// No description provided for @dailyOsNextRefineTitle.
  ///
  /// In en, this message translates to:
  /// **'Refine the plan'**
  String get dailyOsNextRefineTitle;

  /// No description provided for @dailyOsNextRenameFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t rename — try again.'**
  String get dailyOsNextRenameFailed;

  /// No description provided for @dailyOsNextShutdownCarryoverDrop.
  ///
  /// In en, this message translates to:
  /// **'Drop'**
  String get dailyOsNextShutdownCarryoverDrop;

  /// No description provided for @dailyOsNextShutdownCarryoverDropped.
  ///
  /// In en, this message translates to:
  /// **'Dropped'**
  String get dailyOsNextShutdownCarryoverDropped;

  /// No description provided for @dailyOsNextShutdownCarryoverOverline.
  ///
  /// In en, this message translates to:
  /// **'CARRIES FORWARD'**
  String get dailyOsNextShutdownCarryoverOverline;

  /// No description provided for @dailyOsNextShutdownCarryoverPickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get dailyOsNextShutdownCarryoverPickDate;

  /// No description provided for @dailyOsNextShutdownCarryoverScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get dailyOsNextShutdownCarryoverScheduled;

  /// No description provided for @dailyOsNextShutdownCloseDay.
  ///
  /// In en, this message translates to:
  /// **'Close the day'**
  String get dailyOsNextShutdownCloseDay;

  /// No description provided for @dailyOsNextShutdownCompletedOverline.
  ///
  /// In en, this message translates to:
  /// **'WHAT YOU DID'**
  String get dailyOsNextShutdownCompletedOverline;

  /// No description provided for @dailyOsNextShutdownMetricEnergy.
  ///
  /// In en, this message translates to:
  /// **'ENERGY'**
  String get dailyOsNextShutdownMetricEnergy;

  /// No description provided for @dailyOsNextShutdownMetricEnergyDelta.
  ///
  /// In en, this message translates to:
  /// **'{delta} vs. week'**
  String dailyOsNextShutdownMetricEnergyDelta(String delta);

  /// No description provided for @dailyOsNextShutdownMetricFlow.
  ///
  /// In en, this message translates to:
  /// **'FLOW SESSIONS'**
  String get dailyOsNextShutdownMetricFlow;

  /// No description provided for @dailyOsNextShutdownMetricFocus.
  ///
  /// In en, this message translates to:
  /// **'FOCUS TIME'**
  String get dailyOsNextShutdownMetricFocus;

  /// No description provided for @dailyOsNextShutdownMetricSwitches.
  ///
  /// In en, this message translates to:
  /// **'CONTEXT SWITCHES'**
  String get dailyOsNextShutdownMetricSwitches;

  /// No description provided for @dailyOsNextShutdownMetricSwitchesAvg.
  ///
  /// In en, this message translates to:
  /// **'avg {avg} this week'**
  String dailyOsNextShutdownMetricSwitchesAvg(String avg);

  /// No description provided for @dailyOsNextShutdownReflectionOverline.
  ///
  /// In en, this message translates to:
  /// **'💬 ONE-LINE REFLECTION'**
  String get dailyOsNextShutdownReflectionOverline;

  /// No description provided for @dailyOsNextShutdownReflectionPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g., morning was sharp, afternoon dragged after coffee with Sarah ran long.'**
  String get dailyOsNextShutdownReflectionPlaceholder;

  /// No description provided for @dailyOsNextShutdownReflectionPrompt.
  ///
  /// In en, this message translates to:
  /// **'How did today land? (This feeds tomorrow\'s draft.)'**
  String get dailyOsNextShutdownReflectionPrompt;

  /// No description provided for @dailyOsNextShutdownReflectionSpeak.
  ///
  /// In en, this message translates to:
  /// **'Speak it'**
  String get dailyOsNextShutdownReflectionSpeak;

  /// No description provided for @dailyOsNextShutdownReflectionSubmit.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get dailyOsNextShutdownReflectionSubmit;

  /// No description provided for @dailyOsNextShutdownReflectionThanks.
  ///
  /// In en, this message translates to:
  /// **'Got it — feeding tomorrow.'**
  String get dailyOsNextShutdownReflectionThanks;

  /// No description provided for @dailyOsNextShutdownSaveAndClose.
  ///
  /// In en, this message translates to:
  /// **'Save & close'**
  String get dailyOsNextShutdownSaveAndClose;

  /// No description provided for @dailyOsNextShutdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Close out the day'**
  String get dailyOsNextShutdownTitle;

  /// No description provided for @dailyOsNextShutdownTomorrowOverline.
  ///
  /// In en, this message translates to:
  /// **'✦ FOR TOMORROW'**
  String get dailyOsNextShutdownTomorrowOverline;

  /// No description provided for @dailyOsNextStateDueOnDate.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String dailyOsNextStateDueOnDate(String date);

  /// No description provided for @dailyOsNextStateDueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get dailyOsNextStateDueToday;

  /// No description provided for @dailyOsNextStateInProgress.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{In progress} =1{In progress · 1 session} other{In progress · {count} sessions}}'**
  String dailyOsNextStateInProgress(int count);

  /// No description provided for @dailyOsNextStateOverdue.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{Overdue} =1{Overdue · 1 day} other{Overdue · {days} days}}'**
  String dailyOsNextStateOverdue(int days);

  /// No description provided for @dailyOsNextStateOverdueOnDate.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{Overdue on {date}} =1{Overdue by 1 day on {date}} other{Overdue by {days} days on {date}}}'**
  String dailyOsNextStateOverdueOnDate(int days, String date);

  /// No description provided for @dailyOsNextStateRecurringMissed.
  ///
  /// In en, this message translates to:
  /// **'Recurring · missed'**
  String get dailyOsNextStateRecurringMissed;

  /// No description provided for @dailyOsNextTimelineActual.
  ///
  /// In en, this message translates to:
  /// **'Actual'**
  String get dailyOsNextTimelineActual;

  /// No description provided for @dailyOsNextTimelineBoth.
  ///
  /// In en, this message translates to:
  /// **'Plan and actual'**
  String get dailyOsNextTimelineBoth;

  /// No description provided for @dailyOsNextTimelineMeridiemAm.
  ///
  /// In en, this message translates to:
  /// **'AM'**
  String get dailyOsNextTimelineMeridiemAm;

  /// No description provided for @dailyOsNextTimelineMeridiemAmShort.
  ///
  /// In en, this message translates to:
  /// **'am'**
  String get dailyOsNextTimelineMeridiemAmShort;

  /// No description provided for @dailyOsNextTimelineMeridiemPm.
  ///
  /// In en, this message translates to:
  /// **'PM'**
  String get dailyOsNextTimelineMeridiemPm;

  /// No description provided for @dailyOsNextTimelineMeridiemPmShort.
  ///
  /// In en, this message translates to:
  /// **'pm'**
  String get dailyOsNextTimelineMeridiemPmShort;

  /// No description provided for @dailyOsNextTimelinePlanned.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get dailyOsNextTimelinePlanned;

  /// No description provided for @dailyOsNextTimelineSessionOf.
  ///
  /// In en, this message translates to:
  /// **'Session {index} of {total}'**
  String dailyOsNextTimelineSessionOf(int index, int total);

  /// No description provided for @dailyOsNextTimelineShowBoth.
  ///
  /// In en, this message translates to:
  /// **'Show plan and actual together'**
  String get dailyOsNextTimelineShowBoth;

  /// No description provided for @dailyOsNextTimelineShowPaged.
  ///
  /// In en, this message translates to:
  /// **'Show swipeable plan and actual'**
  String get dailyOsNextTimelineShowPaged;

  /// No description provided for @dailyOsNextTimelineSwipeHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe for actual · pinch vertically to zoom'**
  String get dailyOsNextTimelineSwipeHint;

  /// No description provided for @dailyOsNextTimelineTracked.
  ///
  /// In en, this message translates to:
  /// **'tracked'**
  String get dailyOsNextTimelineTracked;

  /// No description provided for @dailyOsNextTimeSpentEarlierSessions.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 earlier session} other{{count} earlier sessions}}'**
  String dailyOsNextTimeSpentEarlierSessions(int count);

  /// No description provided for @dailyOsNextTimeSpentShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get dailyOsNextTimeSpentShowLess;

  /// No description provided for @dailyOsNextTimeSpentSummary.
  ///
  /// In en, this message translates to:
  /// **'{duration} · {completedCount} done'**
  String dailyOsNextTimeSpentSummary(String duration, int completedCount);

  /// No description provided for @dailyOsNextTimeSpentTitle.
  ///
  /// In en, this message translates to:
  /// **'TODAY SO FAR'**
  String get dailyOsNextTimeSpentTitle;

  /// No description provided for @dailyOsNextTimeSpentTitlePast.
  ///
  /// In en, this message translates to:
  /// **'TIME SPENT'**
  String get dailyOsNextTimeSpentTitlePast;

  /// No description provided for @dailyOsNextTriageConfirmDefer.
  ///
  /// In en, this message translates to:
  /// **'Deferred'**
  String get dailyOsNextTriageConfirmDefer;

  /// No description provided for @dailyOsNextTriageConfirmDone.
  ///
  /// In en, this message translates to:
  /// **'Marked done'**
  String get dailyOsNextTriageConfirmDone;

  /// No description provided for @dailyOsNextTriageConfirmDoNow.
  ///
  /// In en, this message translates to:
  /// **'Done now'**
  String get dailyOsNextTriageConfirmDoNow;

  /// No description provided for @dailyOsNextTriageConfirmDrop.
  ///
  /// In en, this message translates to:
  /// **'Dropped'**
  String get dailyOsNextTriageConfirmDrop;

  /// No description provided for @dailyOsNextTriageConfirmToday.
  ///
  /// In en, this message translates to:
  /// **'Added to today'**
  String get dailyOsNextTriageConfirmToday;

  /// No description provided for @dailyOsNextTriageDefer.
  ///
  /// In en, this message translates to:
  /// **'Defer'**
  String get dailyOsNextTriageDefer;

  /// No description provided for @dailyOsNextTriageDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get dailyOsNextTriageDone;

  /// No description provided for @dailyOsNextTriageDoNow.
  ///
  /// In en, this message translates to:
  /// **'Do now'**
  String get dailyOsNextTriageDoNow;

  /// No description provided for @dailyOsNextTriageDrop.
  ///
  /// In en, this message translates to:
  /// **'Drop'**
  String get dailyOsNextTriageDrop;

  /// No description provided for @dailyOsNextTriageToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dailyOsNextTriageToday;

  /// No description provided for @dailyOsNoBudgets.
  ///
  /// In en, this message translates to:
  /// **'No time budgets'**
  String get dailyOsNoBudgets;

  /// No description provided for @dailyOsNoBudgetsHint.
  ///
  /// In en, this message translates to:
  /// **'Add budgets to track how you spend your time across categories.'**
  String get dailyOsNoBudgetsHint;

  /// No description provided for @dailyOsNoBudgetWarning.
  ///
  /// In en, this message translates to:
  /// **'No time budgeted'**
  String get dailyOsNoBudgetWarning;

  /// No description provided for @dailyOsNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get dailyOsNote;

  /// No description provided for @dailyOsNoTimeline.
  ///
  /// In en, this message translates to:
  /// **'No timeline entries'**
  String get dailyOsNoTimeline;

  /// No description provided for @dailyOsNoTimelineHint.
  ///
  /// In en, this message translates to:
  /// **'Start a timer or add planned blocks to see your day.'**
  String get dailyOsNoTimelineHint;

  /// No description provided for @dailyOsOnTrack.
  ///
  /// In en, this message translates to:
  /// **'On track'**
  String get dailyOsOnTrack;

  /// No description provided for @dailyOsOver.
  ///
  /// In en, this message translates to:
  /// **'Over'**
  String get dailyOsOver;

  /// No description provided for @dailyOsOverallProgress.
  ///
  /// In en, this message translates to:
  /// **'Overall Progress'**
  String get dailyOsOverallProgress;

  /// No description provided for @dailyOsOverBudget.
  ///
  /// In en, this message translates to:
  /// **'Over budget'**
  String get dailyOsOverBudget;

  /// No description provided for @dailyOsOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get dailyOsOverdue;

  /// No description provided for @dailyOsOverdueShort.
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get dailyOsOverdueShort;

  /// No description provided for @dailyOsPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get dailyOsPlan;

  /// No description provided for @dailyOsPlanCreated.
  ///
  /// In en, this message translates to:
  /// **'Plan created successfully'**
  String get dailyOsPlanCreated;

  /// No description provided for @dailyOsPlanCreatedDescription.
  ///
  /// In en, this message translates to:
  /// **'Your time blocks have been saved. You can start tracking your tasks.'**
  String get dailyOsPlanCreatedDescription;

  /// No description provided for @dailyOsPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get dailyOsPlanned;

  /// No description provided for @dailyOsPlanWithoutVoice.
  ///
  /// In en, this message translates to:
  /// **'Plan without voice'**
  String get dailyOsPlanWithoutVoice;

  /// No description provided for @dailyOsQuickCreateTask.
  ///
  /// In en, this message translates to:
  /// **'Create task for this budget'**
  String get dailyOsQuickCreateTask;

  /// No description provided for @dailyOsReAgree.
  ///
  /// In en, this message translates to:
  /// **'Re-agree'**
  String get dailyOsReAgree;

  /// No description provided for @dailyOsRecorded.
  ///
  /// In en, this message translates to:
  /// **'Recorded'**
  String get dailyOsRecorded;

  /// No description provided for @dailyOsRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get dailyOsRemaining;

  /// No description provided for @dailyOsReviewMessage.
  ///
  /// In en, this message translates to:
  /// **'Changes detected. Review your plan.'**
  String get dailyOsReviewMessage;

  /// No description provided for @dailyOsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get dailyOsSave;

  /// No description provided for @dailyOsSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save plan'**
  String get dailyOsSaveError;

  /// No description provided for @dailyOsSaveErrorDescription.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get dailyOsSaveErrorDescription;

  /// No description provided for @dailyOsSavePlan.
  ///
  /// In en, this message translates to:
  /// **'Save plan'**
  String get dailyOsSavePlan;

  /// No description provided for @dailyOsSelectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select Category'**
  String get dailyOsSelectCategory;

  /// No description provided for @dailyOsSetTimeBlocks.
  ///
  /// In en, this message translates to:
  /// **'Set time blocks'**
  String get dailyOsSetTimeBlocks;

  /// No description provided for @dailyOsSetTimeBlocksAddNew.
  ///
  /// In en, this message translates to:
  /// **'Add new time block'**
  String get dailyOsSetTimeBlocksAddNew;

  /// No description provided for @dailyOsSetTimeBlocksFavourites.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get dailyOsSetTimeBlocksFavourites;

  /// No description provided for @dailyOsSetTimeBlocksOther.
  ///
  /// In en, this message translates to:
  /// **'Other categories'**
  String get dailyOsSetTimeBlocksOther;

  /// No description provided for @dailyOsSetTimeBlocksTapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to add time block'**
  String get dailyOsSetTimeBlocksTapHint;

  /// No description provided for @dailyOsStartTime.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get dailyOsStartTime;

  /// No description provided for @dailyOsTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get dailyOsTasks;

  /// No description provided for @dailyOsTimeBudgets.
  ///
  /// In en, this message translates to:
  /// **'Time Budgets'**
  String get dailyOsTimeBudgets;

  /// No description provided for @dailyOsTimeLeft.
  ///
  /// In en, this message translates to:
  /// **'{time} left'**
  String dailyOsTimeLeft(String time);

  /// No description provided for @dailyOsTimeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get dailyOsTimeline;

  /// No description provided for @dailyOsTimeOver.
  ///
  /// In en, this message translates to:
  /// **'+{time} over'**
  String dailyOsTimeOver(String time);

  /// No description provided for @dailyOsTimeRange.
  ///
  /// In en, this message translates to:
  /// **'Time Range'**
  String get dailyOsTimeRange;

  /// No description provided for @dailyOsTimesUp.
  ///
  /// In en, this message translates to:
  /// **'Time\'s up'**
  String get dailyOsTimesUp;

  /// No description provided for @dailyOsTodayButton.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dailyOsTodayButton;

  /// No description provided for @dailyOsUncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get dailyOsUncategorized;

  /// No description provided for @dashboardActiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get dashboardActiveLabel;

  /// No description provided for @dashboardActiveSwitchDescription.
  ///
  /// In en, this message translates to:
  /// **'Shown in the dashboards list'**
  String get dashboardActiveSwitchDescription;

  /// No description provided for @dashboardAddChartsTitle.
  ///
  /// In en, this message translates to:
  /// **'Charts'**
  String get dashboardAddChartsTitle;

  /// No description provided for @dashboardAddHabitButton.
  ///
  /// In en, this message translates to:
  /// **'Habit Charts'**
  String get dashboardAddHabitButton;

  /// No description provided for @dashboardAddHabitTitle.
  ///
  /// In en, this message translates to:
  /// **'Habit Charts'**
  String get dashboardAddHabitTitle;

  /// No description provided for @dashboardAddHealthButton.
  ///
  /// In en, this message translates to:
  /// **'Health Charts'**
  String get dashboardAddHealthButton;

  /// No description provided for @dashboardAddHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'Health Charts'**
  String get dashboardAddHealthTitle;

  /// No description provided for @dashboardAddMeasurementButton.
  ///
  /// In en, this message translates to:
  /// **'Measurement Charts'**
  String get dashboardAddMeasurementButton;

  /// No description provided for @dashboardAddMeasurementTitle.
  ///
  /// In en, this message translates to:
  /// **'Measurement Charts'**
  String get dashboardAddMeasurementTitle;

  /// No description provided for @dashboardAddMeasurementTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add measurement'**
  String get dashboardAddMeasurementTooltip;

  /// No description provided for @dashboardAddSurveyButton.
  ///
  /// In en, this message translates to:
  /// **'Survey Charts'**
  String get dashboardAddSurveyButton;

  /// No description provided for @dashboardAddSurveyTitle.
  ///
  /// In en, this message translates to:
  /// **'Survey Charts'**
  String get dashboardAddSurveyTitle;

  /// No description provided for @dashboardAddWorkoutButton.
  ///
  /// In en, this message translates to:
  /// **'Workout Charts'**
  String get dashboardAddWorkoutButton;

  /// No description provided for @dashboardAddWorkoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Workout Charts'**
  String get dashboardAddWorkoutTitle;

  /// No description provided for @dashboardAggregationDailyAverage.
  ///
  /// In en, this message translates to:
  /// **'Daily average'**
  String get dashboardAggregationDailyAverage;

  /// No description provided for @dashboardAggregationDailyMax.
  ///
  /// In en, this message translates to:
  /// **'Daily max'**
  String get dashboardAggregationDailyMax;

  /// No description provided for @dashboardAggregationDailyTotal.
  ///
  /// In en, this message translates to:
  /// **'Daily total'**
  String get dashboardAggregationDailyTotal;

  /// No description provided for @dashboardAggregationHourlyTotal.
  ///
  /// In en, this message translates to:
  /// **'Hourly total'**
  String get dashboardAggregationHourlyTotal;

  /// No description provided for @dashboardAggregationLabel.
  ///
  /// In en, this message translates to:
  /// **'Aggregation Type:'**
  String get dashboardAggregationLabel;

  /// No description provided for @dashboardCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get dashboardCategoryLabel;

  /// No description provided for @dashboardChartNoData.
  ///
  /// In en, this message translates to:
  /// **'No data in this range'**
  String get dashboardChartNoData;

  /// No description provided for @dashboardCopyHint.
  ///
  /// In en, this message translates to:
  /// **'Save & Copy dashboard config'**
  String get dashboardCopyHint;

  /// No description provided for @dashboardCopyLabel.
  ///
  /// In en, this message translates to:
  /// **'Save and copy configuration'**
  String get dashboardCopyLabel;

  /// No description provided for @dashboardDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'YES, DELETE THIS DASHBOARD'**
  String get dashboardDeleteConfirm;

  /// No description provided for @dashboardDeleteHint.
  ///
  /// In en, this message translates to:
  /// **'Delete dashboard'**
  String get dashboardDeleteHint;

  /// No description provided for @dashboardDeleteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Do you want to delete this dashboard?'**
  String get dashboardDeleteQuestion;

  /// No description provided for @dashboardDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get dashboardDescriptionLabel;

  /// No description provided for @dashboardHealthBloodPressure.
  ///
  /// In en, this message translates to:
  /// **'Blood Pressure'**
  String get dashboardHealthBloodPressure;

  /// No description provided for @dashboardHealthDiastolic.
  ///
  /// In en, this message translates to:
  /// **'Diastolic'**
  String get dashboardHealthDiastolic;

  /// No description provided for @dashboardHealthSystolic.
  ///
  /// In en, this message translates to:
  /// **'Systolic'**
  String get dashboardHealthSystolic;

  /// No description provided for @dashboardNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Dashboard name'**
  String get dashboardNameLabel;

  /// No description provided for @dashboardNotFound.
  ///
  /// In en, this message translates to:
  /// **'Dashboard not found'**
  String get dashboardNotFound;

  /// No description provided for @dashboardPrivateLabel.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get dashboardPrivateLabel;

  /// No description provided for @dashboardTakeSurveyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Take survey'**
  String get dashboardTakeSurveyTooltip;

  /// No description provided for @defaultLanguage.
  ///
  /// In en, this message translates to:
  /// **'Default Language'**
  String get defaultLanguage;

  /// No description provided for @deleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButton;

  /// No description provided for @deleteDeviceLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete device'**
  String get deleteDeviceLabel;

  /// No description provided for @designSystemActionVariantTitle.
  ///
  /// In en, this message translates to:
  /// **'With Action'**
  String get designSystemActionVariantTitle;

  /// No description provided for @designSystemActivatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Activated'**
  String get designSystemActivatedLabel;

  /// No description provided for @designSystemAvatarAwayLabel.
  ///
  /// In en, this message translates to:
  /// **'Away'**
  String get designSystemAvatarAwayLabel;

  /// No description provided for @designSystemAvatarBusyLabel.
  ///
  /// In en, this message translates to:
  /// **'Busy'**
  String get designSystemAvatarBusyLabel;

  /// No description provided for @designSystemAvatarConnectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get designSystemAvatarConnectedLabel;

  /// No description provided for @designSystemAvatarEnabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get designSystemAvatarEnabledLabel;

  /// No description provided for @designSystemAvatarSizeMatrixTitle.
  ///
  /// In en, this message translates to:
  /// **'Size Matrix'**
  String get designSystemAvatarSizeMatrixTitle;

  /// No description provided for @designSystemAvatarStatusMatrixTitle.
  ///
  /// In en, this message translates to:
  /// **'Status Matrix'**
  String get designSystemAvatarStatusMatrixTitle;

  /// No description provided for @designSystemBackLabel.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get designSystemBackLabel;

  /// No description provided for @designSystemBreadcrumbCurrentLabel.
  ///
  /// In en, this message translates to:
  /// **'Breadcrumbs'**
  String get designSystemBreadcrumbCurrentLabel;

  /// No description provided for @designSystemBreadcrumbDesignSystemLabel.
  ///
  /// In en, this message translates to:
  /// **'Design System'**
  String get designSystemBreadcrumbDesignSystemLabel;

  /// No description provided for @designSystemBreadcrumbHomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get designSystemBreadcrumbHomeLabel;

  /// No description provided for @designSystemBreadcrumbMobileLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get designSystemBreadcrumbMobileLabel;

  /// No description provided for @designSystemBreadcrumbProjectsLabel.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get designSystemBreadcrumbProjectsLabel;

  /// No description provided for @designSystemBreadcrumbSampleLabel.
  ///
  /// In en, this message translates to:
  /// **'Breadcrumb'**
  String get designSystemBreadcrumbSampleLabel;

  /// No description provided for @designSystemBreadcrumbTrailTitle.
  ///
  /// In en, this message translates to:
  /// **'Breadcrumb Trail'**
  String get designSystemBreadcrumbTrailTitle;

  /// No description provided for @designSystemCalendarPickerLabel.
  ///
  /// In en, this message translates to:
  /// **'Calendar Picker'**
  String get designSystemCalendarPickerLabel;

  /// No description provided for @designSystemCalendarViewsTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar Views'**
  String get designSystemCalendarViewsTitle;

  /// No description provided for @designSystemCaptionDescriptionSample.
  ///
  /// In en, this message translates to:
  /// **'Removing all users unpublished this project. Add users to publish it again.'**
  String get designSystemCaptionDescriptionSample;

  /// No description provided for @designSystemCaptionIconLeftLabel.
  ///
  /// In en, this message translates to:
  /// **'Left icon'**
  String get designSystemCaptionIconLeftLabel;

  /// No description provided for @designSystemCaptionIconTopLabel.
  ///
  /// In en, this message translates to:
  /// **'Top icon'**
  String get designSystemCaptionIconTopLabel;

  /// No description provided for @designSystemCaptionNoIconLabel.
  ///
  /// In en, this message translates to:
  /// **'No icon'**
  String get designSystemCaptionNoIconLabel;

  /// No description provided for @designSystemCaptionTitleSample.
  ///
  /// In en, this message translates to:
  /// **'Caption title'**
  String get designSystemCaptionTitleSample;

  /// No description provided for @designSystemCaptionVariantsTitle.
  ///
  /// In en, this message translates to:
  /// **'Caption Variants'**
  String get designSystemCaptionVariantsTitle;

  /// No description provided for @designSystemCaptionWithActionsLabel.
  ///
  /// In en, this message translates to:
  /// **'With actions'**
  String get designSystemCaptionWithActionsLabel;

  /// No description provided for @designSystemCaptionWithoutActionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Without actions'**
  String get designSystemCaptionWithoutActionsLabel;

  /// No description provided for @designSystemCheckboxLabel.
  ///
  /// In en, this message translates to:
  /// **'Checkbox'**
  String get designSystemCheckboxLabel;

  /// No description provided for @designSystemContextMenuDeleteLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get designSystemContextMenuDeleteLabel;

  /// No description provided for @designSystemContextMenuVariantsTitle.
  ///
  /// In en, this message translates to:
  /// **'Context Menu Variants'**
  String get designSystemContextMenuVariantsTitle;

  /// No description provided for @designSystemCountdownVariantTitle.
  ///
  /// In en, this message translates to:
  /// **'With Countdown'**
  String get designSystemCountdownVariantTitle;

  /// No description provided for @designSystemDateCardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Date Cards'**
  String get designSystemDateCardsTitle;

  /// No description provided for @designSystemDefaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get designSystemDefaultLabel;

  /// No description provided for @designSystemDisabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get designSystemDisabledLabel;

  /// No description provided for @designSystemDividerLabelText.
  ///
  /// In en, this message translates to:
  /// **'Divider label'**
  String get designSystemDividerLabelText;

  /// No description provided for @designSystemDropdownComboboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Combobox'**
  String get designSystemDropdownComboboxTitle;

  /// No description provided for @designSystemDropdownFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get designSystemDropdownFieldLabel;

  /// No description provided for @designSystemDropdownInputLabel.
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get designSystemDropdownInputLabel;

  /// No description provided for @designSystemDropdownListTitle.
  ///
  /// In en, this message translates to:
  /// **'Dropdown list'**
  String get designSystemDropdownListTitle;

  /// No description provided for @designSystemDropdownMultiselectInputLabel.
  ///
  /// In en, this message translates to:
  /// **'Select teams'**
  String get designSystemDropdownMultiselectInputLabel;

  /// No description provided for @designSystemDropdownMultiselectTitle.
  ///
  /// In en, this message translates to:
  /// **'Multiselect'**
  String get designSystemDropdownMultiselectTitle;

  /// No description provided for @designSystemDropdownOptionAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get designSystemDropdownOptionAnalytics;

  /// No description provided for @designSystemDropdownOptionBackend.
  ///
  /// In en, this message translates to:
  /// **'Backend'**
  String get designSystemDropdownOptionBackend;

  /// No description provided for @designSystemDropdownOptionDesign.
  ///
  /// In en, this message translates to:
  /// **'Design'**
  String get designSystemDropdownOptionDesign;

  /// No description provided for @designSystemDropdownOptionFrontend.
  ///
  /// In en, this message translates to:
  /// **'Frontend'**
  String get designSystemDropdownOptionFrontend;

  /// No description provided for @designSystemDropdownOptionGrowth.
  ///
  /// In en, this message translates to:
  /// **'Growth'**
  String get designSystemDropdownOptionGrowth;

  /// No description provided for @designSystemDropdownOptionMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get designSystemDropdownOptionMobile;

  /// No description provided for @designSystemDropdownOptionQa.
  ///
  /// In en, this message translates to:
  /// **'QA'**
  String get designSystemDropdownOptionQa;

  /// No description provided for @designSystemErrorLabel.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get designSystemErrorLabel;

  /// No description provided for @designSystemFileUploadClickLabel.
  ///
  /// In en, this message translates to:
  /// **'Click to upload'**
  String get designSystemFileUploadClickLabel;

  /// No description provided for @designSystemFileUploadCompleteLabel.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get designSystemFileUploadCompleteLabel;

  /// No description provided for @designSystemFileUploadDefaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get designSystemFileUploadDefaultLabel;

  /// No description provided for @designSystemFileUploadDragLabel.
  ///
  /// In en, this message translates to:
  /// **'or drag and drop'**
  String get designSystemFileUploadDragLabel;

  /// No description provided for @designSystemFileUploadDropZoneSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Drop Zone'**
  String get designSystemFileUploadDropZoneSectionTitle;

  /// No description provided for @designSystemFileUploadErrorLabel.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get designSystemFileUploadErrorLabel;

  /// No description provided for @designSystemFileUploadFailedText.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get designSystemFileUploadFailedText;

  /// No description provided for @designSystemFileUploadHintText.
  ///
  /// In en, this message translates to:
  /// **'SVG, PNG, JPG or GIF (max. 800×400px)'**
  String get designSystemFileUploadHintText;

  /// No description provided for @designSystemFileUploadHoverLabel.
  ///
  /// In en, this message translates to:
  /// **'Hover'**
  String get designSystemFileUploadHoverLabel;

  /// No description provided for @designSystemFileUploadItemSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'File Items'**
  String get designSystemFileUploadItemSectionTitle;

  /// No description provided for @designSystemFileUploadRetryLabel.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get designSystemFileUploadRetryLabel;

  /// No description provided for @designSystemFileUploadUploadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get designSystemFileUploadUploadingLabel;

  /// No description provided for @designSystemFilledLabel.
  ///
  /// In en, this message translates to:
  /// **'Filled'**
  String get designSystemFilledLabel;

  /// No description provided for @designSystemHeaderApiDocumentationLabel.
  ///
  /// In en, this message translates to:
  /// **'API Documentation'**
  String get designSystemHeaderApiDocumentationLabel;

  /// No description provided for @designSystemHeaderBackActionLabel.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get designSystemHeaderBackActionLabel;

  /// No description provided for @designSystemHeaderDesktopSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Desktop'**
  String get designSystemHeaderDesktopSectionTitle;

  /// No description provided for @designSystemHeaderHelpActionLabel.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get designSystemHeaderHelpActionLabel;

  /// No description provided for @designSystemHeaderMobileSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get designSystemHeaderMobileSectionTitle;

  /// No description provided for @designSystemHeaderNotificationsActionLabel.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get designSystemHeaderNotificationsActionLabel;

  /// No description provided for @designSystemHeaderSearchActionLabel.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get designSystemHeaderSearchActionLabel;

  /// No description provided for @designSystemHorizontalLabel.
  ///
  /// In en, this message translates to:
  /// **'Horizontal'**
  String get designSystemHorizontalLabel;

  /// No description provided for @designSystemHoverLabel.
  ///
  /// In en, this message translates to:
  /// **'Hover'**
  String get designSystemHoverLabel;

  /// No description provided for @designSystemInfoLabel.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get designSystemInfoLabel;

  /// No description provided for @designSystemInputErrorSample.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get designSystemInputErrorSample;

  /// No description provided for @designSystemInputHelperSample.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get designSystemInputHelperSample;

  /// No description provided for @designSystemInputHintSample.
  ///
  /// In en, this message translates to:
  /// **'Placeholder...'**
  String get designSystemInputHintSample;

  /// No description provided for @designSystemInputLabelSample.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get designSystemInputLabelSample;

  /// No description provided for @designSystemInputVariantsTitle.
  ///
  /// In en, this message translates to:
  /// **'Input Variants'**
  String get designSystemInputVariantsTitle;

  /// No description provided for @designSystemInputWithErrorLabel.
  ///
  /// In en, this message translates to:
  /// **'With error'**
  String get designSystemInputWithErrorLabel;

  /// No description provided for @designSystemInputWithHelperLabel.
  ///
  /// In en, this message translates to:
  /// **'With helper text'**
  String get designSystemInputWithHelperLabel;

  /// No description provided for @designSystemInputWithIconsLabel.
  ///
  /// In en, this message translates to:
  /// **'With icons'**
  String get designSystemInputWithIconsLabel;

  /// No description provided for @designSystemListItemActivatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Activated'**
  String get designSystemListItemActivatedLabel;

  /// No description provided for @designSystemListItemOneLineLabel.
  ///
  /// In en, this message translates to:
  /// **'One line'**
  String get designSystemListItemOneLineLabel;

  /// No description provided for @designSystemListItemSubtitleSample.
  ///
  /// In en, this message translates to:
  /// **'Subtitle'**
  String get designSystemListItemSubtitleSample;

  /// No description provided for @designSystemListItemTitleSample.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get designSystemListItemTitleSample;

  /// No description provided for @designSystemListItemTwoLinesLabel.
  ///
  /// In en, this message translates to:
  /// **'Two lines'**
  String get designSystemListItemTwoLinesLabel;

  /// No description provided for @designSystemListItemVariantsTitle.
  ///
  /// In en, this message translates to:
  /// **'List Item Variants'**
  String get designSystemListItemVariantsTitle;

  /// No description provided for @designSystemListItemWithDividerLabel.
  ///
  /// In en, this message translates to:
  /// **'With divider'**
  String get designSystemListItemWithDividerLabel;

  /// No description provided for @designSystemMediumLabel.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get designSystemMediumLabel;

  /// No description provided for @designSystemMyDailyDurationHoursMinutesCompact.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String designSystemMyDailyDurationHoursMinutesCompact(int hours, int minutes);

  /// No description provided for @designSystemMyDailyEditPlanLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit plan'**
  String get designSystemMyDailyEditPlanLabel;

  /// No description provided for @designSystemMyDailyGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning.'**
  String get designSystemMyDailyGreetingMorning;

  /// No description provided for @designSystemMyDailyGreetingWithName.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}'**
  String designSystemMyDailyGreetingWithName(String name);

  /// No description provided for @designSystemMyDailyHikeWithDanielaTitle.
  ///
  /// In en, this message translates to:
  /// **'Hiking with Daniela'**
  String get designSystemMyDailyHikeWithDanielaTitle;

  /// No description provided for @designSystemMyDailyLunchBreakTitle.
  ///
  /// In en, this message translates to:
  /// **'Lunch break'**
  String get designSystemMyDailyLunchBreakTitle;

  /// No description provided for @designSystemMyDailyMeetingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Meetings'**
  String get designSystemMyDailyMeetingsLabel;

  /// No description provided for @designSystemMyDailyMeetingWithDannyTitle.
  ///
  /// In en, this message translates to:
  /// **'Meeting with Danny'**
  String get designSystemMyDailyMeetingWithDannyTitle;

  /// No description provided for @designSystemMyDailyProfileActionLabel.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get designSystemMyDailyProfileActionLabel;

  /// No description provided for @designSystemMyDailySkiWithMattTitle.
  ///
  /// In en, this message translates to:
  /// **'Go skiing with Matt'**
  String get designSystemMyDailySkiWithMattTitle;

  /// No description provided for @designSystemMyDailyTapToExpandLabel.
  ///
  /// In en, this message translates to:
  /// **'Tap to expand'**
  String get designSystemMyDailyTapToExpandLabel;

  /// No description provided for @designSystemNavigationCollapsedLabel.
  ///
  /// In en, this message translates to:
  /// **'Collapsed'**
  String get designSystemNavigationCollapsedLabel;

  /// No description provided for @designSystemNavigationDailyFilterSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Filter'**
  String get designSystemNavigationDailyFilterSectionTitle;

  /// No description provided for @designSystemNavigationExpandedLabel.
  ///
  /// In en, this message translates to:
  /// **'Expanded'**
  String get designSystemNavigationExpandedLabel;

  /// No description provided for @designSystemNavigationFilterByBlockLabel.
  ///
  /// In en, this message translates to:
  /// **'Filter by block'**
  String get designSystemNavigationFilterByBlockLabel;

  /// No description provided for @designSystemNavigationHikingLabel.
  ///
  /// In en, this message translates to:
  /// **'Hiking'**
  String get designSystemNavigationHikingLabel;

  /// No description provided for @designSystemNavigationHolidayLabel.
  ///
  /// In en, this message translates to:
  /// **'Holiday'**
  String get designSystemNavigationHolidayLabel;

  /// No description provided for @designSystemNavigationInsightsLabel.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get designSystemNavigationInsightsLabel;

  /// No description provided for @designSystemNavigationLottiTasksLabel.
  ///
  /// In en, this message translates to:
  /// **'Lotti Tasks'**
  String get designSystemNavigationLottiTasksLabel;

  /// No description provided for @designSystemNavigationMyDailyLabel.
  ///
  /// In en, this message translates to:
  /// **'My Daily'**
  String get designSystemNavigationMyDailyLabel;

  /// No description provided for @designSystemNavigationNewLabel.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get designSystemNavigationNewLabel;

  /// No description provided for @designSystemNavigationPlaceholderLabel.
  ///
  /// In en, this message translates to:
  /// **'Placeholder'**
  String get designSystemNavigationPlaceholderLabel;

  /// No description provided for @designSystemNavigationSidebarSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Sidebar Variants'**
  String get designSystemNavigationSidebarSectionTitle;

  /// No description provided for @designSystemNavigationSubComponentsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Sub-components'**
  String get designSystemNavigationSubComponentsSectionTitle;

  /// No description provided for @designSystemNavigationTabBarSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Tab Bar Variants'**
  String get designSystemNavigationTabBarSectionTitle;

  /// No description provided for @designSystemPressedLabel.
  ///
  /// In en, this message translates to:
  /// **'Pressed'**
  String get designSystemPressedLabel;

  /// No description provided for @designSystemProgressBarChunkyLabel.
  ///
  /// In en, this message translates to:
  /// **'Chunky'**
  String get designSystemProgressBarChunkyLabel;

  /// No description provided for @designSystemProgressBarLabelAndPercentageLabel.
  ///
  /// In en, this message translates to:
  /// **'Label + Percentage'**
  String get designSystemProgressBarLabelAndPercentageLabel;

  /// No description provided for @designSystemProgressBarLabelOnlyLabel.
  ///
  /// In en, this message translates to:
  /// **'Label only'**
  String get designSystemProgressBarLabelOnlyLabel;

  /// No description provided for @designSystemProgressBarOffLabel.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get designSystemProgressBarOffLabel;

  /// No description provided for @designSystemProgressBarPercentageOnlyLabel.
  ///
  /// In en, this message translates to:
  /// **'Percentage'**
  String get designSystemProgressBarPercentageOnlyLabel;

  /// No description provided for @designSystemProgressBarQuestBarLabel.
  ///
  /// In en, this message translates to:
  /// **'Quest bar'**
  String get designSystemProgressBarQuestBarLabel;

  /// No description provided for @designSystemProgressBarQuestLabel.
  ///
  /// In en, this message translates to:
  /// **'Mega prize label'**
  String get designSystemProgressBarQuestLabel;

  /// No description provided for @designSystemProgressBarSampleLabel.
  ///
  /// In en, this message translates to:
  /// **'Progress bar label'**
  String get designSystemProgressBarSampleLabel;

  /// No description provided for @designSystemRadioButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Radio button'**
  String get designSystemRadioButtonLabel;

  /// No description provided for @designSystemScrollbarSizesTitle.
  ///
  /// In en, this message translates to:
  /// **'Scrollbar Sizes'**
  String get designSystemScrollbarSizesTitle;

  /// No description provided for @designSystemSearchFilledText.
  ///
  /// In en, this message translates to:
  /// **'Lotti search'**
  String get designSystemSearchFilledText;

  /// No description provided for @designSystemSearchHintLabel.
  ///
  /// In en, this message translates to:
  /// **'Type user'**
  String get designSystemSearchHintLabel;

  /// No description provided for @designSystemSelectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get designSystemSelectedLabel;

  /// No description provided for @designSystemSizeScaleTitle.
  ///
  /// In en, this message translates to:
  /// **'Size Scale'**
  String get designSystemSizeScaleTitle;

  /// No description provided for @designSystemSmallLabel.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get designSystemSmallLabel;

  /// No description provided for @designSystemSpinnerPlainLabel.
  ///
  /// In en, this message translates to:
  /// **'Plain'**
  String get designSystemSpinnerPlainLabel;

  /// No description provided for @designSystemSpinnerSkeletonPulseLabel.
  ///
  /// In en, this message translates to:
  /// **'Pulse'**
  String get designSystemSpinnerSkeletonPulseLabel;

  /// No description provided for @designSystemSpinnerSkeletonsTitle.
  ///
  /// In en, this message translates to:
  /// **'Skeletons'**
  String get designSystemSpinnerSkeletonsTitle;

  /// No description provided for @designSystemSpinnerSkeletonWaveLabel.
  ///
  /// In en, this message translates to:
  /// **'Wave'**
  String get designSystemSpinnerSkeletonWaveLabel;

  /// No description provided for @designSystemSpinnerSpinnersTitle.
  ///
  /// In en, this message translates to:
  /// **'Spinners'**
  String get designSystemSpinnerSpinnersTitle;

  /// No description provided for @designSystemSpinnerTrackLabel.
  ///
  /// In en, this message translates to:
  /// **'With track'**
  String get designSystemSpinnerTrackLabel;

  /// No description provided for @designSystemSplitButtonDropdownSemantics.
  ///
  /// In en, this message translates to:
  /// **'Open {label} options'**
  String designSystemSplitButtonDropdownSemantics(String label);

  /// No description provided for @designSystemStateMatrixTitle.
  ///
  /// In en, this message translates to:
  /// **'State Matrix'**
  String get designSystemStateMatrixTitle;

  /// No description provided for @designSystemSuccessLabel.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get designSystemSuccessLabel;

  /// No description provided for @designSystemTabBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Tab Bar'**
  String get designSystemTabBarTitle;

  /// No description provided for @designSystemTabPendingLabel.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get designSystemTabPendingLabel;

  /// No description provided for @designSystemTaskListBlockedLabel.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get designSystemTaskListBlockedLabel;

  /// No description provided for @designSystemTaskListDefaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get designSystemTaskListDefaultLabel;

  /// No description provided for @designSystemTaskListHoverLabel.
  ///
  /// In en, this message translates to:
  /// **'Hover'**
  String get designSystemTaskListHoverLabel;

  /// No description provided for @designSystemTaskListItemSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Task List Item Variants'**
  String get designSystemTaskListItemSectionTitle;

  /// No description provided for @designSystemTaskListOnHoldLabel.
  ///
  /// In en, this message translates to:
  /// **'On Hold'**
  String get designSystemTaskListOnHoldLabel;

  /// No description provided for @designSystemTaskListOpenLabel.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get designSystemTaskListOpenLabel;

  /// No description provided for @designSystemTaskListPressedLabel.
  ///
  /// In en, this message translates to:
  /// **'Pressed'**
  String get designSystemTaskListPressedLabel;

  /// No description provided for @designSystemTaskListSampleTime.
  ///
  /// In en, this message translates to:
  /// **'8:00-9:30am'**
  String get designSystemTaskListSampleTime;

  /// No description provided for @designSystemTaskListSampleTitle.
  ///
  /// In en, this message translates to:
  /// **'User Testing'**
  String get designSystemTaskListSampleTitle;

  /// No description provided for @designSystemTaskListWithDividerLabel.
  ///
  /// In en, this message translates to:
  /// **'With divider'**
  String get designSystemTaskListWithDividerLabel;

  /// No description provided for @designSystemTextareaErrorSample.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get designSystemTextareaErrorSample;

  /// No description provided for @designSystemTextareaHelperSample.
  ///
  /// In en, this message translates to:
  /// **'Enter your message here'**
  String get designSystemTextareaHelperSample;

  /// No description provided for @designSystemTextareaHintSample.
  ///
  /// In en, this message translates to:
  /// **'Type something...'**
  String get designSystemTextareaHintSample;

  /// No description provided for @designSystemTextareaLabelSample.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get designSystemTextareaLabelSample;

  /// No description provided for @designSystemTextareaVariantsTitle.
  ///
  /// In en, this message translates to:
  /// **'Textarea Variants'**
  String get designSystemTextareaVariantsTitle;

  /// No description provided for @designSystemTextareaWithCounterLabel.
  ///
  /// In en, this message translates to:
  /// **'With counter'**
  String get designSystemTextareaWithCounterLabel;

  /// No description provided for @designSystemTextareaWithErrorLabel.
  ///
  /// In en, this message translates to:
  /// **'With error'**
  String get designSystemTextareaWithErrorLabel;

  /// No description provided for @designSystemTextareaWithHelperLabel.
  ///
  /// In en, this message translates to:
  /// **'With helper text'**
  String get designSystemTextareaWithHelperLabel;

  /// No description provided for @designSystemTimePickerFormatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Time Formats'**
  String get designSystemTimePickerFormatsTitle;

  /// No description provided for @designSystemTimePickerTwelveHourLabel.
  ///
  /// In en, this message translates to:
  /// **'12-hour'**
  String get designSystemTimePickerTwelveHourLabel;

  /// No description provided for @designSystemTimePickerTwentyFourHourLabel.
  ///
  /// In en, this message translates to:
  /// **'24-hour'**
  String get designSystemTimePickerTwentyFourHourLabel;

  /// No description provided for @designSystemTitleOnlyVariantTitle.
  ///
  /// In en, this message translates to:
  /// **'Title Only Variant'**
  String get designSystemTitleOnlyVariantTitle;

  /// No description provided for @designSystemToastDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Notification details'**
  String get designSystemToastDetailsLabel;

  /// No description provided for @designSystemToggleLabel.
  ///
  /// In en, this message translates to:
  /// **'Toggle label'**
  String get designSystemToggleLabel;

  /// No description provided for @designSystemTooltipIconMessageSample.
  ///
  /// In en, this message translates to:
  /// **'Helpful information about this field'**
  String get designSystemTooltipIconMessageSample;

  /// No description provided for @designSystemTooltipIconVariantsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tooltip Icon'**
  String get designSystemTooltipIconVariantsTitle;

  /// No description provided for @designSystemUndoLabel.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get designSystemUndoLabel;

  /// No description provided for @designSystemVariantMatrixTitle.
  ///
  /// In en, this message translates to:
  /// **'Variant Matrix'**
  String get designSystemVariantMatrixTitle;

  /// No description provided for @designSystemVerticalLabel.
  ///
  /// In en, this message translates to:
  /// **'Vertical'**
  String get designSystemVerticalLabel;

  /// No description provided for @designSystemWarningLabel.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get designSystemWarningLabel;

  /// No description provided for @designSystemWeeklyCalendarLabel.
  ///
  /// In en, this message translates to:
  /// **'Weekly Calendar'**
  String get designSystemWeeklyCalendarLabel;

  /// No description provided for @designSystemWithLabelLabel.
  ///
  /// In en, this message translates to:
  /// **'With label'**
  String get designSystemWithLabelLabel;

  /// No description provided for @desktopEmptyStateSelectDashboard.
  ///
  /// In en, this message translates to:
  /// **'Select a dashboard to view details'**
  String get desktopEmptyStateSelectDashboard;

  /// No description provided for @desktopEmptyStateSelectProject.
  ///
  /// In en, this message translates to:
  /// **'Select a project to view details'**
  String get desktopEmptyStateSelectProject;

  /// No description provided for @desktopEmptyStateSelectTask.
  ///
  /// In en, this message translates to:
  /// **'Select a task to view details'**
  String get desktopEmptyStateSelectTask;

  /// No description provided for @deviceDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Device {deviceName} deleted successfully'**
  String deviceDeletedSuccess(String deviceName);

  /// No description provided for @deviceDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete device: {error}'**
  String deviceDeleteFailed(String error);

  /// No description provided for @doneButton.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneButton;

  /// No description provided for @editMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editMenuTitle;

  /// No description provided for @editorInsertDivider.
  ///
  /// In en, this message translates to:
  /// **'Insert divider'**
  String get editorInsertDivider;

  /// No description provided for @editorPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter notes...'**
  String get editorPlaceholder;

  /// No description provided for @embeddingSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get embeddingSelectAll;

  /// No description provided for @embeddingUnselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get embeddingUnselectAll;

  /// No description provided for @enhancedPromptFormPreconfiguredPromptDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose from ready-made prompt templates'**
  String get enhancedPromptFormPreconfiguredPromptDescription;

  /// No description provided for @enterCategoryName.
  ///
  /// In en, this message translates to:
  /// **'Enter category name'**
  String get enterCategoryName;

  /// No description provided for @entryActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get entryActions;

  /// No description provided for @entryLabelsActionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Assign labels to organize this entry'**
  String get entryLabelsActionSubtitle;

  /// No description provided for @entryLabelsActionTitle.
  ///
  /// In en, this message translates to:
  /// **'Labels'**
  String get entryLabelsActionTitle;

  /// No description provided for @entryLabelsEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit labels'**
  String get entryLabelsEditTooltip;

  /// No description provided for @entryLabelsHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Labels'**
  String get entryLabelsHeaderTitle;

  /// No description provided for @entryLabelsNoLabels.
  ///
  /// In en, this message translates to:
  /// **'No labels assigned'**
  String get entryLabelsNoLabels;

  /// No description provided for @entryTypeLabelAiResponse.
  ///
  /// In en, this message translates to:
  /// **'AI Response'**
  String get entryTypeLabelAiResponse;

  /// No description provided for @entryTypeLabelChecklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get entryTypeLabelChecklist;

  /// No description provided for @entryTypeLabelChecklistItem.
  ///
  /// In en, this message translates to:
  /// **'To Do'**
  String get entryTypeLabelChecklistItem;

  /// No description provided for @entryTypeLabelHabitCompletionEntry.
  ///
  /// In en, this message translates to:
  /// **'Habit'**
  String get entryTypeLabelHabitCompletionEntry;

  /// No description provided for @entryTypeLabelJournalAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get entryTypeLabelJournalAudio;

  /// No description provided for @entryTypeLabelJournalEntry.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get entryTypeLabelJournalEntry;

  /// No description provided for @entryTypeLabelJournalEvent.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get entryTypeLabelJournalEvent;

  /// No description provided for @entryTypeLabelJournalImage.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get entryTypeLabelJournalImage;

  /// No description provided for @entryTypeLabelMeasurementEntry.
  ///
  /// In en, this message translates to:
  /// **'Measured'**
  String get entryTypeLabelMeasurementEntry;

  /// No description provided for @entryTypeLabelQuantitativeEntry.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get entryTypeLabelQuantitativeEntry;

  /// No description provided for @entryTypeLabelSurveyEntry.
  ///
  /// In en, this message translates to:
  /// **'Survey'**
  String get entryTypeLabelSurveyEntry;

  /// No description provided for @entryTypeLabelTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get entryTypeLabelTask;

  /// No description provided for @entryTypeLabelWorkoutEntry.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get entryTypeLabelWorkoutEntry;

  /// No description provided for @eventNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Event:'**
  String get eventNameLabel;

  /// No description provided for @favoriteLabel.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get favoriteLabel;

  /// No description provided for @fileMenuNewEllipsis.
  ///
  /// In en, this message translates to:
  /// **'New ...'**
  String get fileMenuNewEllipsis;

  /// No description provided for @fileMenuNewEntry.
  ///
  /// In en, this message translates to:
  /// **'New Entry'**
  String get fileMenuNewEntry;

  /// No description provided for @fileMenuNewScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Screenshot'**
  String get fileMenuNewScreenshot;

  /// No description provided for @fileMenuNewTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get fileMenuNewTask;

  /// No description provided for @fileMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get fileMenuTitle;

  /// No description provided for @filterSelectionNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get filterSelectionNoMatches;

  /// No description provided for @geminiThinkingModeHighDescription.
  ///
  /// In en, this message translates to:
  /// **'Deepest reasoning; can increase latency and cost.'**
  String get geminiThinkingModeHighDescription;

  /// No description provided for @geminiThinkingModeHighLabel.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get geminiThinkingModeHighLabel;

  /// No description provided for @geminiThinkingModeLowDescription.
  ///
  /// In en, this message translates to:
  /// **'Low reasoning for fast everyday prompts.'**
  String get geminiThinkingModeLowDescription;

  /// No description provided for @geminiThinkingModeLowLabel.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get geminiThinkingModeLowLabel;

  /// No description provided for @geminiThinkingModeMediumDescription.
  ///
  /// In en, this message translates to:
  /// **'Balanced reasoning for more careful answers.'**
  String get geminiThinkingModeMediumDescription;

  /// No description provided for @geminiThinkingModeMediumLabel.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get geminiThinkingModeMediumLabel;

  /// No description provided for @geminiThinkingModeMinimalDescription.
  ///
  /// In en, this message translates to:
  /// **'Fastest setting; Gemini may still think briefly on complex prompts.'**
  String get geminiThinkingModeMinimalDescription;

  /// No description provided for @geminiThinkingModeMinimalLabel.
  ///
  /// In en, this message translates to:
  /// **'Minimal'**
  String get geminiThinkingModeMinimalLabel;

  /// No description provided for @generateCoverArt.
  ///
  /// In en, this message translates to:
  /// **'Generate Cover Art'**
  String get generateCoverArt;

  /// No description provided for @generateCoverArtSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create image from voice description'**
  String get generateCoverArtSubtitle;

  /// No description provided for @habitActiveFromLabel.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get habitActiveFromLabel;

  /// No description provided for @habitActiveSwitchDescription.
  ///
  /// In en, this message translates to:
  /// **'Shown on the Habits page'**
  String get habitActiveSwitchDescription;

  /// No description provided for @habitArchivedLabel.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get habitArchivedLabel;

  /// No description provided for @habitCategoryHint.
  ///
  /// In en, this message translates to:
  /// **'Select a category'**
  String get habitCategoryHint;

  /// No description provided for @habitCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get habitCategoryLabel;

  /// No description provided for @habitCloseCompletionLabel.
  ///
  /// In en, this message translates to:
  /// **'Close habit completion'**
  String get habitCloseCompletionLabel;

  /// No description provided for @habitCompleteSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Record {habit}'**
  String habitCompleteSemanticLabel(String habit);

  /// No description provided for @habitCompletionStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get habitCompletionStatusCompleted;

  /// No description provided for @habitCompletionStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get habitCompletionStatusFailed;

  /// No description provided for @habitCompletionStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get habitCompletionStatusOpen;

  /// No description provided for @habitCompletionStatusSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get habitCompletionStatusSkipped;

  /// No description provided for @habitDashboardHint.
  ///
  /// In en, this message translates to:
  /// **'Select a dashboard'**
  String get habitDashboardHint;

  /// No description provided for @habitDashboardLabel.
  ///
  /// In en, this message translates to:
  /// **'Dashboard (optional)'**
  String get habitDashboardLabel;

  /// No description provided for @habitDayStatusSemantic.
  ///
  /// In en, this message translates to:
  /// **'{habit}, {status}'**
  String habitDayStatusSemantic(String habit, String status);

  /// No description provided for @habitDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'YES, DELETE THIS HABIT'**
  String get habitDeleteConfirm;

  /// No description provided for @habitDeleteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Do you want to delete this habit?'**
  String get habitDeleteQuestion;

  /// No description provided for @habitHeatmapDaySemantic.
  ///
  /// In en, this message translates to:
  /// **'{date}, {done} of {total} done'**
  String habitHeatmapDaySemantic(String date, int done, int total);

  /// No description provided for @habitLogOtherDayHint.
  ///
  /// In en, this message translates to:
  /// **'Hold to log another day'**
  String get habitLogOtherDayHint;

  /// No description provided for @habitNotRecordedLabel.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get habitNotRecordedLabel;

  /// No description provided for @habitPriorityLabel.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get habitPriorityLabel;

  /// No description provided for @habitsAboveGoal.
  ///
  /// In en, this message translates to:
  /// **'On track'**
  String get habitsAboveGoal;

  /// No description provided for @habitsActiveHabitsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 active habit} other{{count} active habits}}'**
  String habitsActiveHabitsCount(int count);

  /// No description provided for @habitsAllDoneToday.
  ///
  /// In en, this message translates to:
  /// **'All done today'**
  String get habitsAllDoneToday;

  /// No description provided for @habitsCompletedHeader.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get habitsCompletedHeader;

  /// No description provided for @habitsCompletionRateTitle.
  ///
  /// In en, this message translates to:
  /// **'Completion rate'**
  String get habitsCompletionRateTitle;

  /// No description provided for @habitsConsistencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Consistency'**
  String get habitsConsistencyTitle;

  /// No description provided for @habitsDayFailedPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% recorded fails'**
  String habitsDayFailedPercent(int percent);

  /// No description provided for @habitsDaySkippedPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% skipped'**
  String habitsDaySkippedPercent(int percent);

  /// No description provided for @habitsDaySuccessfulPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% successful'**
  String habitsDaySuccessfulPercent(int percent);

  /// No description provided for @habitsDoneTodayLabel.
  ///
  /// In en, this message translates to:
  /// **'Done today'**
  String get habitsDoneTodayLabel;

  /// No description provided for @habitSectionOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get habitSectionOptionsTitle;

  /// No description provided for @habitSectionScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get habitSectionScheduleTitle;

  /// No description provided for @habitsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'all'**
  String get habitsFilterAll;

  /// No description provided for @habitsFilterCompleted.
  ///
  /// In en, this message translates to:
  /// **'done'**
  String get habitsFilterCompleted;

  /// No description provided for @habitsFilterOpenNow.
  ///
  /// In en, this message translates to:
  /// **'due'**
  String get habitsFilterOpenNow;

  /// No description provided for @habitsFilterPendingLater.
  ///
  /// In en, this message translates to:
  /// **'later'**
  String get habitsFilterPendingLater;

  /// No description provided for @habitsGoalLineLabel.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get habitsGoalLineLabel;

  /// No description provided for @habitsHeatmapEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add a habit to start building your consistency'**
  String get habitsHeatmapEmpty;

  /// No description provided for @habitsHeatmapLess.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get habitsHeatmapLess;

  /// No description provided for @habitsHeatmapMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get habitsHeatmapMore;

  /// No description provided for @habitShowAlertAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Show alert at'**
  String get habitShowAlertAtLabel;

  /// No description provided for @habitShowFromLabel.
  ///
  /// In en, this message translates to:
  /// **'Show from'**
  String get habitShowFromLabel;

  /// No description provided for @habitsLaggardHint.
  ///
  /// In en, this message translates to:
  /// **'{habit} — kept {kept} of {active}'**
  String habitsLaggardHint(String habit, int kept, int active);

  /// No description provided for @habitsOpenHeader.
  ///
  /// In en, this message translates to:
  /// **'Due now'**
  String get habitsOpenHeader;

  /// No description provided for @habitsPendingLaterHeader.
  ///
  /// In en, this message translates to:
  /// **'Later today'**
  String get habitsPendingLaterHeader;

  /// No description provided for @habitsPointsToGoal.
  ///
  /// In en, this message translates to:
  /// **'{points, plural, one{1 pt to goal} other{{points} pts to goal}}'**
  String habitsPointsToGoal(int points);

  /// No description provided for @habitsRecordButton.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get habitsRecordButton;

  /// No description provided for @habitsRollingAverageLabel.
  ///
  /// In en, this message translates to:
  /// **'7-day avg'**
  String get habitsRollingAverageLabel;

  /// No description provided for @habitsStartStreakToday.
  ///
  /// In en, this message translates to:
  /// **'Start a streak today'**
  String get habitsStartStreakToday;

  /// No description provided for @habitsStreakLongCount.
  ///
  /// In en, this message translates to:
  /// **'{count} on a 7-day streak'**
  String habitsStreakLongCount(int count);

  /// No description provided for @habitsStreakShortCount.
  ///
  /// In en, this message translates to:
  /// **'{count} on a 3-day streak'**
  String habitsStreakShortCount(int count);

  /// No description provided for @habitsTapForBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Tap a day for the breakdown'**
  String get habitsTapForBreakdown;

  /// No description provided for @habitsToGoCount.
  ///
  /// In en, this message translates to:
  /// **'{count} to go'**
  String habitsToGoCount(int count);

  /// No description provided for @habitStreakDaysSemantic.
  ///
  /// In en, this message translates to:
  /// **'{count}-day streak'**
  String habitStreakDaysSemantic(int count);

  /// No description provided for @habitsVsPreviousWeek.
  ///
  /// In en, this message translates to:
  /// **'vs previous week'**
  String get habitsVsPreviousWeek;

  /// No description provided for @imageGenerationError.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate image'**
  String get imageGenerationError;

  /// No description provided for @imageGenerationGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating image...'**
  String get imageGenerationGenerating;

  /// No description provided for @imageGenerationProviderRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'The image provider rejected this request'**
  String get imageGenerationProviderRejectedTitle;

  /// No description provided for @imageGenerationWithReferences.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No reference images} =1{Using 1 reference image} other{Using {count} reference images}}'**
  String imageGenerationWithReferences(int count);

  /// No description provided for @imagePromptGenerationCardTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Image Prompt'**
  String get imagePromptGenerationCardTitle;

  /// No description provided for @imagePromptGenerationCopiedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Image prompt copied to clipboard'**
  String get imagePromptGenerationCopiedSnackbar;

  /// No description provided for @imagePromptGenerationCopyButton.
  ///
  /// In en, this message translates to:
  /// **'Copy Prompt'**
  String get imagePromptGenerationCopyButton;

  /// No description provided for @imagePromptGenerationCopyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy image prompt to clipboard'**
  String get imagePromptGenerationCopyTooltip;

  /// No description provided for @imagePromptGenerationExpandTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show full prompt'**
  String get imagePromptGenerationExpandTooltip;

  /// No description provided for @imagePromptGenerationFullPromptLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Image Prompt:'**
  String get imagePromptGenerationFullPromptLabel;

  /// No description provided for @images.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get images;

  /// No description provided for @inactiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactiveLabel;

  /// No description provided for @inactiveSwitchDescription.
  ///
  /// In en, this message translates to:
  /// **'Can be chosen for new entries when on'**
  String get inactiveSwitchDescription;

  /// No description provided for @inferenceProfileCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Profile'**
  String get inferenceProfileCreateTitle;

  /// No description provided for @inferenceProfileDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get inferenceProfileDescriptionLabel;

  /// No description provided for @inferenceProfileDesktopOnly.
  ///
  /// In en, this message translates to:
  /// **'Desktop Only'**
  String get inferenceProfileDesktopOnly;

  /// No description provided for @inferenceProfileDesktopOnlyDescription.
  ///
  /// In en, this message translates to:
  /// **'Only available on desktop platforms (e.g. for local models)'**
  String get inferenceProfileDesktopOnlyDescription;

  /// No description provided for @inferenceProfileDetailLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load profile: {error}'**
  String inferenceProfileDetailLoadError(String error);

  /// No description provided for @inferenceProfileDetailNotFound.
  ///
  /// In en, this message translates to:
  /// **'Profile not found'**
  String get inferenceProfileDetailNotFound;

  /// No description provided for @inferenceProfileEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get inferenceProfileEditTitle;

  /// No description provided for @inferenceProfileImageGeneration.
  ///
  /// In en, this message translates to:
  /// **'Image Generation'**
  String get inferenceProfileImageGeneration;

  /// No description provided for @inferenceProfileImageRecognition.
  ///
  /// In en, this message translates to:
  /// **'Image Recognition'**
  String get inferenceProfileImageRecognition;

  /// No description provided for @inferenceProfileNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Profile Name'**
  String get inferenceProfileNameLabel;

  /// No description provided for @inferenceProfileNameRequired.
  ///
  /// In en, this message translates to:
  /// **'A profile name is required'**
  String get inferenceProfileNameRequired;

  /// No description provided for @inferenceProfilePinnedHostHelper.
  ///
  /// In en, this message translates to:
  /// **'When set, only this device auto-runs inference for synced audio entries that use this profile.'**
  String get inferenceProfilePinnedHostHelper;

  /// No description provided for @inferenceProfilePinnedHostLabel.
  ///
  /// In en, this message translates to:
  /// **'Pinned device'**
  String get inferenceProfilePinnedHostLabel;

  /// No description provided for @inferenceProfilePinnedHostNoEligibleNodes.
  ///
  /// In en, this message translates to:
  /// **'No known devices advertise the providers this profile uses. Open Sync node settings on the target device.'**
  String get inferenceProfilePinnedHostNoEligibleNodes;

  /// No description provided for @inferenceProfilePinnedHostNoneHelper.
  ///
  /// In en, this message translates to:
  /// **'Synced audio entries are not auto-transcribed when no device is pinned.'**
  String get inferenceProfilePinnedHostNoneHelper;

  /// No description provided for @inferenceProfilePinnedHostNoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Not pinned (no auto-trigger)'**
  String get inferenceProfilePinnedHostNoneLabel;

  /// No description provided for @inferenceProfilePinnedHostThisDeviceSuffix.
  ///
  /// In en, this message translates to:
  /// **' (this device)'**
  String get inferenceProfilePinnedHostThisDeviceSuffix;

  /// No description provided for @inferenceProfileSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get inferenceProfileSaveButton;

  /// No description provided for @inferenceProfileSelectModel.
  ///
  /// In en, this message translates to:
  /// **'Select a model…'**
  String get inferenceProfileSelectModel;

  /// No description provided for @inferenceProfileSelectProfile.
  ///
  /// In en, this message translates to:
  /// **'Select a profile…'**
  String get inferenceProfileSelectProfile;

  /// No description provided for @inferenceProfilesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No inference profiles yet'**
  String get inferenceProfilesEmpty;

  /// No description provided for @inferenceProfileSkillModelRequired.
  ///
  /// In en, this message translates to:
  /// **'Requires {slotName} model to be set'**
  String inferenceProfileSkillModelRequired(String slotName);

  /// No description provided for @inferenceProfileSkillsSection.
  ///
  /// In en, this message translates to:
  /// **'Automated Skills'**
  String get inferenceProfileSkillsSection;

  /// No description provided for @inferenceProfileSkillUsesModel.
  ///
  /// In en, this message translates to:
  /// **'Uses {slotName} model'**
  String inferenceProfileSkillUsesModel(String slotName);

  /// No description provided for @inferenceProfilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Inference Profiles'**
  String get inferenceProfilesTitle;

  /// No description provided for @inferenceProfileThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get inferenceProfileThinking;

  /// No description provided for @inferenceProfileThinkingHighEnd.
  ///
  /// In en, this message translates to:
  /// **'Thinking (High-End)'**
  String get inferenceProfileThinkingHighEnd;

  /// No description provided for @inferenceProfileThinkingRequired.
  ///
  /// In en, this message translates to:
  /// **'A thinking model is required'**
  String get inferenceProfileThinkingRequired;

  /// No description provided for @inferenceProfileTranscription.
  ///
  /// In en, this message translates to:
  /// **'Transcription'**
  String get inferenceProfileTranscription;

  /// No description provided for @inputDataTypeAudioFilesDescription.
  ///
  /// In en, this message translates to:
  /// **'Use audio files as input'**
  String get inputDataTypeAudioFilesDescription;

  /// No description provided for @inputDataTypeAudioFilesName.
  ///
  /// In en, this message translates to:
  /// **'Audio Files'**
  String get inputDataTypeAudioFilesName;

  /// No description provided for @inputDataTypeImagesDescription.
  ///
  /// In en, this message translates to:
  /// **'Use images as input'**
  String get inputDataTypeImagesDescription;

  /// No description provided for @inputDataTypeImagesName.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get inputDataTypeImagesName;

  /// No description provided for @inputDataTypeTaskDescription.
  ///
  /// In en, this message translates to:
  /// **'Use the current task as input'**
  String get inputDataTypeTaskDescription;

  /// No description provided for @inputDataTypeTaskName.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get inputDataTypeTaskName;

  /// No description provided for @inputDataTypeTasksListDescription.
  ///
  /// In en, this message translates to:
  /// **'Use a list of tasks as input'**
  String get inputDataTypeTasksListDescription;

  /// No description provided for @inputDataTypeTasksListName.
  ///
  /// In en, this message translates to:
  /// **'Tasks List'**
  String get inputDataTypeTasksListName;

  /// No description provided for @insightsChartCompareCaption.
  ///
  /// In en, this message translates to:
  /// **'This period vs the previous'**
  String get insightsChartCompareCaption;

  /// No description provided for @insightsChartCompareCaptionPartial.
  ///
  /// In en, this message translates to:
  /// **'This period so far vs the previous'**
  String get insightsChartCompareCaptionPartial;

  /// No description provided for @insightsChartCompareHint.
  ///
  /// In en, this message translates to:
  /// **'Comparison shown in the table below'**
  String get insightsChartCompareHint;

  /// No description provided for @insightsChartCumulativeCaption.
  ///
  /// In en, this message translates to:
  /// **'Running total over the range'**
  String get insightsChartCumulativeCaption;

  /// No description provided for @insightsChartCumulativeShort.
  ///
  /// In en, this message translates to:
  /// **'Not enough days yet for a running total'**
  String get insightsChartCumulativeShort;

  /// No description provided for @insightsChartDailyCaption.
  ///
  /// In en, this message translates to:
  /// **'Time per day'**
  String get insightsChartDailyCaption;

  /// No description provided for @insightsChartHourlyCaption.
  ///
  /// In en, this message translates to:
  /// **'Time per hour'**
  String get insightsChartHourlyCaption;

  /// No description provided for @insightsChartPerDay.
  ///
  /// In en, this message translates to:
  /// **'Per day'**
  String get insightsChartPerDay;

  /// No description provided for @insightsChartPerHour.
  ///
  /// In en, this message translates to:
  /// **'Per hour'**
  String get insightsChartPerHour;

  /// No description provided for @insightsChartPerWeek.
  ///
  /// In en, this message translates to:
  /// **'Per week'**
  String get insightsChartPerWeek;

  /// No description provided for @insightsChartRunningTotal.
  ///
  /// In en, this message translates to:
  /// **'Running total'**
  String get insightsChartRunningTotal;

  /// No description provided for @insightsChartTitle.
  ///
  /// In en, this message translates to:
  /// **'Time by category'**
  String get insightsChartTitle;

  /// No description provided for @insightsChartWeeklyCaption.
  ///
  /// In en, this message translates to:
  /// **'Time per week'**
  String get insightsChartWeeklyCaption;

  /// No description provided for @insightsChooseFocusCategories.
  ///
  /// In en, this message translates to:
  /// **'Choose focus categories'**
  String get insightsChooseFocusCategories;

  /// No description provided for @insightsCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get insightsCompare;

  /// No description provided for @insightsCompareFullPeriod.
  ///
  /// In en, this message translates to:
  /// **'full period'**
  String get insightsCompareFullPeriod;

  /// No description provided for @insightsComparePrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get insightsComparePrevious;

  /// No description provided for @insightsCompareSameDays.
  ///
  /// In en, this message translates to:
  /// **'same days'**
  String get insightsCompareSameDays;

  /// No description provided for @insightsCompareTooltip.
  ///
  /// In en, this message translates to:
  /// **'Compare with the previous period'**
  String get insightsCompareTooltip;

  /// No description provided for @insightsCompareVs.
  ///
  /// In en, this message translates to:
  /// **'vs'**
  String get insightsCompareVs;

  /// No description provided for @insightsDeletedCategory.
  ///
  /// In en, this message translates to:
  /// **'Deleted category'**
  String get insightsDeletedCategory;

  /// No description provided for @insightsDeltaNew.
  ///
  /// In en, this message translates to:
  /// **'new'**
  String get insightsDeltaNew;

  /// No description provided for @insightsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Time you track on entries and tasks will show up here.'**
  String get insightsEmptyBody;

  /// No description provided for @insightsEmptyChart.
  ///
  /// In en, this message translates to:
  /// **'No data in this range'**
  String get insightsEmptyChart;

  /// No description provided for @insightsEmptyPreviousPeriod.
  ///
  /// In en, this message translates to:
  /// **'Show the previous period'**
  String get insightsEmptyPreviousPeriod;

  /// No description provided for @insightsEmptyShowYear.
  ///
  /// In en, this message translates to:
  /// **'View this year'**
  String get insightsEmptyShowYear;

  /// No description provided for @insightsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No tracked time in this range'**
  String get insightsEmptyTitle;

  /// No description provided for @insightsFocusCategoriesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No active categories yet.'**
  String get insightsFocusCategoriesEmpty;

  /// No description provided for @insightsFocusCategoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Focus categories'**
  String get insightsFocusCategoriesTitle;

  /// No description provided for @insightsKpiFocus.
  ///
  /// In en, this message translates to:
  /// **'FOCUS'**
  String get insightsKpiFocus;

  /// No description provided for @insightsKpiFocusHelp.
  ///
  /// In en, this message translates to:
  /// **'Categories you\'re watching'**
  String get insightsKpiFocusHelp;

  /// No description provided for @insightsKpiOther.
  ///
  /// In en, this message translates to:
  /// **'OTHER'**
  String get insightsKpiOther;

  /// No description provided for @insightsKpiOtherHelp.
  ///
  /// In en, this message translates to:
  /// **'Everything else'**
  String get insightsKpiOtherHelp;

  /// No description provided for @insightsKpiTopCategory.
  ///
  /// In en, this message translates to:
  /// **'Most on {category} · {share}'**
  String insightsKpiTopCategory(String category, String share);

  /// No description provided for @insightsKpiTotal.
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get insightsKpiTotal;

  /// No description provided for @insightsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load time data'**
  String get insightsLoadError;

  /// No description provided for @insightsOtherCategories.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get insightsOtherCategories;

  /// No description provided for @insightsPartialWeek.
  ///
  /// In en, this message translates to:
  /// **'partial week'**
  String get insightsPartialWeek;

  /// No description provided for @insightsPeriodDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get insightsPeriodDay;

  /// No description provided for @insightsPeriodJump.
  ///
  /// In en, this message translates to:
  /// **'Jump to a date'**
  String get insightsPeriodJump;

  /// No description provided for @insightsPeriodMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get insightsPeriodMonth;

  /// No description provided for @insightsPeriodNext.
  ///
  /// In en, this message translates to:
  /// **'Next period'**
  String get insightsPeriodNext;

  /// No description provided for @insightsPeriodPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous period'**
  String get insightsPeriodPrevious;

  /// No description provided for @insightsPeriodQuarter.
  ///
  /// In en, this message translates to:
  /// **'Quarter'**
  String get insightsPeriodQuarter;

  /// No description provided for @insightsPeriodToDateSuffix.
  ///
  /// In en, this message translates to:
  /// **'so far'**
  String get insightsPeriodToDateSuffix;

  /// No description provided for @insightsPeriodWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get insightsPeriodWeek;

  /// No description provided for @insightsPeriodYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get insightsPeriodYear;

  /// No description provided for @insightsRangeMonthToDate.
  ///
  /// In en, this message translates to:
  /// **'This month so far'**
  String get insightsRangeMonthToDate;

  /// No description provided for @insightsRangeMtd.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get insightsRangeMtd;

  /// No description provided for @insightsRangeYearToDate.
  ///
  /// In en, this message translates to:
  /// **'This year so far'**
  String get insightsRangeYearToDate;

  /// No description provided for @insightsRangeYtd.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get insightsRangeYtd;

  /// No description provided for @insightsRefreshError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh — showing the last loaded data'**
  String get insightsRefreshError;

  /// No description provided for @insightsTableAvgPerDay.
  ///
  /// In en, this message translates to:
  /// **'AVG/DAY'**
  String get insightsTableAvgPerDay;

  /// No description provided for @insightsTableCategory.
  ///
  /// In en, this message translates to:
  /// **'CATEGORY'**
  String get insightsTableCategory;

  /// No description provided for @insightsTableCompareNote.
  ///
  /// In en, this message translates to:
  /// **'Change is vs the previous period'**
  String get insightsTableCompareNote;

  /// No description provided for @insightsTableCurrent.
  ///
  /// In en, this message translates to:
  /// **'CURRENT'**
  String get insightsTableCurrent;

  /// No description provided for @insightsTableDelta.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get insightsTableDelta;

  /// No description provided for @insightsTablePrevious.
  ///
  /// In en, this message translates to:
  /// **'PREVIOUS'**
  String get insightsTablePrevious;

  /// No description provided for @insightsTableShare.
  ///
  /// In en, this message translates to:
  /// **'SHARE'**
  String get insightsTableShare;

  /// No description provided for @insightsTableTotal.
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get insightsTableTotal;

  /// No description provided for @insightsTimeAnalysisTitle.
  ///
  /// In en, this message translates to:
  /// **'Time Analysis'**
  String get insightsTimeAnalysisTitle;

  /// No description provided for @insightsUncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get insightsUncategorized;

  /// No description provided for @journalCopyImageLabel.
  ///
  /// In en, this message translates to:
  /// **'Copy image'**
  String get journalCopyImageLabel;

  /// No description provided for @journalDateFromLabel.
  ///
  /// In en, this message translates to:
  /// **'Date from:'**
  String get journalDateFromLabel;

  /// No description provided for @journalDateInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid Date Range'**
  String get journalDateInvalid;

  /// No description provided for @journalDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get journalDateLabel;

  /// No description provided for @journalDateNowButton.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get journalDateNowButton;

  /// No description provided for @journalDateSaveButton.
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get journalDateSaveButton;

  /// No description provided for @journalDateTimeRangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get journalDateTimeRangeTitle;

  /// No description provided for @journalDateToLabel.
  ///
  /// In en, this message translates to:
  /// **'Date to:'**
  String get journalDateToLabel;

  /// No description provided for @journalDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'YES, DELETE THIS ENTRY'**
  String get journalDeleteConfirm;

  /// No description provided for @journalDeleteHint.
  ///
  /// In en, this message translates to:
  /// **'Delete entry'**
  String get journalDeleteHint;

  /// No description provided for @journalDeleteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Do you want to delete this journal entry?'**
  String get journalDeleteQuestion;

  /// No description provided for @journalDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get journalDurationLabel;

  /// No description provided for @journalEndDateLabel.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get journalEndDateLabel;

  /// No description provided for @journalEndsAnotherDayHint.
  ///
  /// In en, this message translates to:
  /// **'Pick a separate end date'**
  String get journalEndsAnotherDayHint;

  /// No description provided for @journalEndsAnotherDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Ends on another day'**
  String get journalEndsAnotherDayLabel;

  /// No description provided for @journalEndTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get journalEndTimeLabel;

  /// No description provided for @journalFavoriteTooltip.
  ///
  /// In en, this message translates to:
  /// **'starred only'**
  String get journalFavoriteTooltip;

  /// No description provided for @journalFilterEntryTypesTitle.
  ///
  /// In en, this message translates to:
  /// **'Entry types'**
  String get journalFilterEntryTypesTitle;

  /// No description provided for @journalFilterFlagged.
  ///
  /// In en, this message translates to:
  /// **'Flagged'**
  String get journalFilterFlagged;

  /// No description provided for @journalFilterPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get journalFilterPrivate;

  /// No description provided for @journalFilterShowTitle.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get journalFilterShowTitle;

  /// No description provided for @journalFilterStarred.
  ///
  /// In en, this message translates to:
  /// **'Starred'**
  String get journalFilterStarred;

  /// No description provided for @journalFlaggedTooltip.
  ///
  /// In en, this message translates to:
  /// **'flagged only'**
  String get journalFlaggedTooltip;

  /// No description provided for @journalHideLinkHint.
  ///
  /// In en, this message translates to:
  /// **'Hide link'**
  String get journalHideLinkHint;

  /// No description provided for @journalHideMapHint.
  ///
  /// In en, this message translates to:
  /// **'Hide map'**
  String get journalHideMapHint;

  /// No description provided for @journalLinkedEntriesActivityFilterAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get journalLinkedEntriesActivityFilterAudio;

  /// No description provided for @journalLinkedEntriesActivityFilterCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get journalLinkedEntriesActivityFilterCode;

  /// No description provided for @journalLinkedEntriesActivityFilterImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get journalLinkedEntriesActivityFilterImages;

  /// No description provided for @journalLinkedEntriesActivityFilterTimer.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get journalLinkedEntriesActivityFilterTimer;

  /// No description provided for @journalLinkedEntriesFilterModalTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter & Sort'**
  String get journalLinkedEntriesFilterModalTitle;

  /// No description provided for @journalLinkedEntriesShowFlaggedOnly.
  ///
  /// In en, this message translates to:
  /// **'Show flagged entries only'**
  String get journalLinkedEntriesShowFlaggedOnly;

  /// No description provided for @journalLinkedEntriesShowHidden.
  ///
  /// In en, this message translates to:
  /// **'Show hidden entries'**
  String get journalLinkedEntriesShowHidden;

  /// No description provided for @journalLinkedEntriesSortLabel.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get journalLinkedEntriesSortLabel;

  /// No description provided for @journalLinkedEntriesSortNewestFirst.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get journalLinkedEntriesSortNewestFirst;

  /// No description provided for @journalLinkedEntriesSortOldestFirst.
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get journalLinkedEntriesSortOldestFirst;

  /// No description provided for @journalLinkedFromLabel.
  ///
  /// In en, this message translates to:
  /// **'Linked from:'**
  String get journalLinkedFromLabel;

  /// No description provided for @journalLinkFromHint.
  ///
  /// In en, this message translates to:
  /// **'Link from'**
  String get journalLinkFromHint;

  /// No description provided for @journalLinkToHint.
  ///
  /// In en, this message translates to:
  /// **'Link to'**
  String get journalLinkToHint;

  /// Chip shown when an entry's end time is earlier than its start time, indicating it ends on the next day.
  ///
  /// In en, this message translates to:
  /// **'Ends {date} (next day)'**
  String journalOvernightNextDay(String date);

  /// No description provided for @journalPrivateTooltip.
  ///
  /// In en, this message translates to:
  /// **'private only'**
  String get journalPrivateTooltip;

  /// No description provided for @journalSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search journal...'**
  String get journalSearchHint;

  /// No description provided for @journalShareHint.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get journalShareHint;

  /// No description provided for @journalShowLinkHint.
  ///
  /// In en, this message translates to:
  /// **'Show link'**
  String get journalShowLinkHint;

  /// No description provided for @journalShowMapHint.
  ///
  /// In en, this message translates to:
  /// **'Show map'**
  String get journalShowMapHint;

  /// No description provided for @journalStartDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get journalStartDateLabel;

  /// No description provided for @journalStartTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get journalStartTimeLabel;

  /// No description provided for @journalTodayButton.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get journalTodayButton;

  /// No description provided for @journalToggleFlaggedTitle.
  ///
  /// In en, this message translates to:
  /// **'Flagged'**
  String get journalToggleFlaggedTitle;

  /// No description provided for @journalTogglePrivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get journalTogglePrivateTitle;

  /// No description provided for @journalToggleStarredTitle.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get journalToggleStarredTitle;

  /// No description provided for @journalUnlinkConfirm.
  ///
  /// In en, this message translates to:
  /// **'YES, UNLINK ENTRY'**
  String get journalUnlinkConfirm;

  /// No description provided for @journalUnlinkHint.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get journalUnlinkHint;

  /// No description provided for @journalUnlinkQuestion.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to unlink this entry?'**
  String get journalUnlinkQuestion;

  /// No description provided for @knowledgeGraphEmpty.
  ///
  /// In en, this message translates to:
  /// **'No links to explore yet'**
  String get knowledgeGraphEmpty;

  /// No description provided for @knowledgeGraphError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the knowledge graph'**
  String get knowledgeGraphError;

  /// No description provided for @knowledgeGraphTitle.
  ///
  /// In en, this message translates to:
  /// **'Knowledge graph'**
  String get knowledgeGraphTitle;

  /// No description provided for @knowledgeGraphTooltip.
  ///
  /// In en, this message translates to:
  /// **'Explore links'**
  String get knowledgeGraphTooltip;

  /// No description provided for @linkedFromCaption.
  ///
  /// In en, this message translates to:
  /// **'from'**
  String get linkedFromCaption;

  /// No description provided for @linkedTaskImageBadge.
  ///
  /// In en, this message translates to:
  /// **'From linked task'**
  String get linkedTaskImageBadge;

  /// No description provided for @linkedTasksMenuTooltip.
  ///
  /// In en, this message translates to:
  /// **'Linked tasks options'**
  String get linkedTasksMenuTooltip;

  /// No description provided for @linkedTasksTitle.
  ///
  /// In en, this message translates to:
  /// **'Linked Tasks'**
  String get linkedTasksTitle;

  /// No description provided for @linkedToCaption.
  ///
  /// In en, this message translates to:
  /// **'to'**
  String get linkedToCaption;

  /// No description provided for @linkExistingTask.
  ///
  /// In en, this message translates to:
  /// **'Link existing task...'**
  String get linkExistingTask;

  /// No description provided for @loggingDomainAgentRuntime.
  ///
  /// In en, this message translates to:
  /// **'Agent runtime'**
  String get loggingDomainAgentRuntime;

  /// No description provided for @loggingDomainAgentWorkflow.
  ///
  /// In en, this message translates to:
  /// **'Agent workflow'**
  String get loggingDomainAgentWorkflow;

  /// No description provided for @loggingDomainAi.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get loggingDomainAi;

  /// No description provided for @loggingDomainCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar & time'**
  String get loggingDomainCalendar;

  /// No description provided for @loggingDomainChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get loggingDomainChat;

  /// No description provided for @loggingDomainDailyOs.
  ///
  /// In en, this message translates to:
  /// **'Daily OS'**
  String get loggingDomainDailyOs;

  /// No description provided for @loggingDomainDatabase.
  ///
  /// In en, this message translates to:
  /// **'Database'**
  String get loggingDomainDatabase;

  /// No description provided for @loggingDomainGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get loggingDomainGeneral;

  /// No description provided for @loggingDomainHabits.
  ///
  /// In en, this message translates to:
  /// **'Habits'**
  String get loggingDomainHabits;

  /// No description provided for @loggingDomainHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get loggingDomainHealth;

  /// No description provided for @loggingDomainLabels.
  ///
  /// In en, this message translates to:
  /// **'Labels'**
  String get loggingDomainLabels;

  /// No description provided for @loggingDomainLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get loggingDomainLocation;

  /// No description provided for @loggingDomainNavigation.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get loggingDomainNavigation;

  /// No description provided for @loggingDomainNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get loggingDomainNotifications;

  /// No description provided for @loggingDomainPersistence.
  ///
  /// In en, this message translates to:
  /// **'Persistence'**
  String get loggingDomainPersistence;

  /// No description provided for @loggingDomainRatings.
  ///
  /// In en, this message translates to:
  /// **'Ratings'**
  String get loggingDomainRatings;

  /// No description provided for @loggingDomainScreenshots.
  ///
  /// In en, this message translates to:
  /// **'Screenshots'**
  String get loggingDomainScreenshots;

  /// No description provided for @loggingDomainSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get loggingDomainSettings;

  /// No description provided for @loggingDomainSpeech.
  ///
  /// In en, this message translates to:
  /// **'Speech & audio'**
  String get loggingDomainSpeech;

  /// No description provided for @loggingDomainSync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get loggingDomainSync;

  /// No description provided for @loggingDomainTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks & checklists'**
  String get loggingDomainTasks;

  /// No description provided for @loggingDomainTheming.
  ///
  /// In en, this message translates to:
  /// **'Theming'**
  String get loggingDomainTheming;

  /// No description provided for @loggingDomainWhatsNew.
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get loggingDomainWhatsNew;

  /// No description provided for @maintenanceDeleteAgentDb.
  ///
  /// In en, this message translates to:
  /// **'Delete Agents Database'**
  String get maintenanceDeleteAgentDb;

  /// No description provided for @maintenanceDeleteAgentDbDescription.
  ///
  /// In en, this message translates to:
  /// **'Delete agents database and restart app'**
  String get maintenanceDeleteAgentDbDescription;

  /// No description provided for @maintenanceDeleteDatabaseConfirm.
  ///
  /// In en, this message translates to:
  /// **'YES, DELETE DATABASE'**
  String get maintenanceDeleteDatabaseConfirm;

  /// No description provided for @maintenanceDeleteDatabaseQuestion.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {databaseName} Database?'**
  String maintenanceDeleteDatabaseQuestion(String databaseName);

  /// No description provided for @maintenanceDeleteEditorDb.
  ///
  /// In en, this message translates to:
  /// **'Delete Editor Database'**
  String get maintenanceDeleteEditorDb;

  /// No description provided for @maintenanceDeleteEditorDbDescription.
  ///
  /// In en, this message translates to:
  /// **'Delete editor drafts database'**
  String get maintenanceDeleteEditorDbDescription;

  /// No description provided for @maintenanceDeleteSyncDb.
  ///
  /// In en, this message translates to:
  /// **'Delete Sync Database'**
  String get maintenanceDeleteSyncDb;

  /// No description provided for @maintenanceDeleteSyncDbDescription.
  ///
  /// In en, this message translates to:
  /// **'Delete sync database'**
  String get maintenanceDeleteSyncDbDescription;

  /// No description provided for @maintenanceGenerateEmbeddings.
  ///
  /// In en, this message translates to:
  /// **'Generate Embeddings'**
  String get maintenanceGenerateEmbeddings;

  /// No description provided for @maintenanceGenerateEmbeddingsConfirm.
  ///
  /// In en, this message translates to:
  /// **'YES, GENERATE'**
  String get maintenanceGenerateEmbeddingsConfirm;

  /// No description provided for @maintenanceGenerateEmbeddingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Generate embeddings for entries in selected categories'**
  String get maintenanceGenerateEmbeddingsDescription;

  /// No description provided for @maintenanceGenerateEmbeddingsMessage.
  ///
  /// In en, this message translates to:
  /// **'Select categories to generate embeddings for.'**
  String get maintenanceGenerateEmbeddingsMessage;

  /// No description provided for @maintenanceGenerateEmbeddingsProgress.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, =1{{processed} / {total} entry ({embedded} embedded)} other{{processed} / {total} entries ({embedded} embedded)}}'**
  String maintenanceGenerateEmbeddingsProgress(
    int processed,
    int total,
    int embedded,
  );

  /// No description provided for @maintenancePopulatePhaseAgentEntities.
  ///
  /// In en, this message translates to:
  /// **'Processing agent entities...'**
  String get maintenancePopulatePhaseAgentEntities;

  /// No description provided for @maintenancePopulatePhaseAgentLinks.
  ///
  /// In en, this message translates to:
  /// **'Processing agent links...'**
  String get maintenancePopulatePhaseAgentLinks;

  /// No description provided for @maintenancePopulatePhaseJournal.
  ///
  /// In en, this message translates to:
  /// **'Processing journal entries...'**
  String get maintenancePopulatePhaseJournal;

  /// No description provided for @maintenancePopulatePhaseLinks.
  ///
  /// In en, this message translates to:
  /// **'Processing entry links...'**
  String get maintenancePopulatePhaseLinks;

  /// No description provided for @maintenancePopulateSequenceLog.
  ///
  /// In en, this message translates to:
  /// **'Populate sync sequence log'**
  String get maintenancePopulateSequenceLog;

  /// No description provided for @maintenancePopulateSequenceLogComplete.
  ///
  /// In en, this message translates to:
  /// **'{count} entries indexed'**
  String maintenancePopulateSequenceLogComplete(int count);

  /// No description provided for @maintenancePopulateSequenceLogConfirm.
  ///
  /// In en, this message translates to:
  /// **'YES, POPULATE'**
  String get maintenancePopulateSequenceLogConfirm;

  /// No description provided for @maintenancePopulateSequenceLogDescription.
  ///
  /// In en, this message translates to:
  /// **'Index existing entries for backfill support'**
  String get maintenancePopulateSequenceLogDescription;

  /// No description provided for @maintenancePopulateSequenceLogMessage.
  ///
  /// In en, this message translates to:
  /// **'This will scan all journal entries and add them to the sync sequence log. This enables backfill responses for entries created before this feature was added.'**
  String get maintenancePopulateSequenceLogMessage;

  /// No description provided for @maintenancePurgeDeleted.
  ///
  /// In en, this message translates to:
  /// **'Purge deleted items'**
  String get maintenancePurgeDeleted;

  /// No description provided for @maintenancePurgeDeletedConfirm.
  ///
  /// In en, this message translates to:
  /// **'Yes, purge all'**
  String get maintenancePurgeDeletedConfirm;

  /// No description provided for @maintenancePurgeDeletedDescription.
  ///
  /// In en, this message translates to:
  /// **'Purge all deleted items permanently'**
  String get maintenancePurgeDeletedDescription;

  /// No description provided for @maintenancePurgeDeletedMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to purge all deleted items? This action cannot be undone.'**
  String get maintenancePurgeDeletedMessage;

  /// No description provided for @maintenancePurgeSentOutbox.
  ///
  /// In en, this message translates to:
  /// **'Purge old sent outbox items'**
  String get maintenancePurgeSentOutbox;

  /// No description provided for @maintenancePurgeSentOutboxConfirm.
  ///
  /// In en, this message translates to:
  /// **'YES, PURGE'**
  String get maintenancePurgeSentOutboxConfirm;

  /// No description provided for @maintenancePurgeSentOutboxDescription.
  ///
  /// In en, this message translates to:
  /// **'Delete sent outbox rows older than 7 days and reclaim disk'**
  String get maintenancePurgeSentOutboxDescription;

  /// No description provided for @maintenancePurgeSentOutboxQuestion.
  ///
  /// In en, this message translates to:
  /// **'Purge sent outbox items older than 7 days? This deletes already-sent rows in chunks and runs VACUUM to reclaim disk. Pending and error items are kept.'**
  String get maintenancePurgeSentOutboxQuestion;

  /// No description provided for @maintenanceRecreateFts5.
  ///
  /// In en, this message translates to:
  /// **'Recreate full-text index'**
  String get maintenanceRecreateFts5;

  /// No description provided for @maintenanceRecreateFts5Confirm.
  ///
  /// In en, this message translates to:
  /// **'YES, RECREATE INDEX'**
  String get maintenanceRecreateFts5Confirm;

  /// No description provided for @maintenanceRecreateFts5Description.
  ///
  /// In en, this message translates to:
  /// **'Recreate full-text search index'**
  String get maintenanceRecreateFts5Description;

  /// No description provided for @maintenanceRecreateFts5Message.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to recreate the full-text index? This may take some time.'**
  String get maintenanceRecreateFts5Message;

  /// No description provided for @maintenanceReSync.
  ///
  /// In en, this message translates to:
  /// **'Re-sync messages'**
  String get maintenanceReSync;

  /// No description provided for @maintenanceReSyncAgentEntities.
  ///
  /// In en, this message translates to:
  /// **'Agent entities'**
  String get maintenanceReSyncAgentEntities;

  /// No description provided for @maintenanceReSyncDescription.
  ///
  /// In en, this message translates to:
  /// **'Re-sync messages from server'**
  String get maintenanceReSyncDescription;

  /// No description provided for @maintenanceReSyncEntityTypes.
  ///
  /// In en, this message translates to:
  /// **'Entity types'**
  String get maintenanceReSyncEntityTypes;

  /// No description provided for @maintenanceReSyncJournalEntities.
  ///
  /// In en, this message translates to:
  /// **'Journal entities'**
  String get maintenanceReSyncJournalEntities;

  /// No description provided for @maintenanceReSyncSelectAtLeastOne.
  ///
  /// In en, this message translates to:
  /// **'Select at least one entity type'**
  String get maintenanceReSyncSelectAtLeastOne;

  /// No description provided for @maintenanceReSyncStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get maintenanceReSyncStart;

  /// No description provided for @maintenanceSyncDefinitions.
  ///
  /// In en, this message translates to:
  /// **'Sync measurables, dashboards, habits, categories, AI settings'**
  String get maintenanceSyncDefinitions;

  /// No description provided for @maintenanceSyncDefinitionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Sync measurables, dashboards, habits, categories, and AI settings'**
  String get maintenanceSyncDefinitionsDescription;

  /// No description provided for @manageLinks.
  ///
  /// In en, this message translates to:
  /// **'Manage links...'**
  String get manageLinks;

  /// No description provided for @measurableDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'YES, DELETE THIS MEASURABLE'**
  String get measurableDeleteConfirm;

  /// No description provided for @measurableDeleteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Do you want to delete this measurable data type?'**
  String get measurableDeleteQuestion;

  /// No description provided for @measurableNotFound.
  ///
  /// In en, this message translates to:
  /// **'Measurable not found'**
  String get measurableNotFound;

  /// No description provided for @measurementCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Add a note (optional)'**
  String get measurementCommentHint;

  /// No description provided for @measurementQuickAddLabel.
  ///
  /// In en, this message translates to:
  /// **'Quick add'**
  String get measurementQuickAddLabel;

  /// Context menu action that reveals a media file in Windows File Explorer.
  ///
  /// In en, this message translates to:
  /// **'Show in File Explorer'**
  String get mediaShowInFileExplorerAction;

  /// Context menu action that reveals a media file in the default Linux file manager.
  ///
  /// In en, this message translates to:
  /// **'Show in Files'**
  String get mediaShowInFilesAction;

  /// Context menu action that reveals a media file in macOS Finder.
  ///
  /// In en, this message translates to:
  /// **'Show in Finder'**
  String get mediaShowInFinderAction;

  /// No description provided for @modalityAudioDescription.
  ///
  /// In en, this message translates to:
  /// **'Audio processing capabilities'**
  String get modalityAudioDescription;

  /// No description provided for @modalityAudioName.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get modalityAudioName;

  /// No description provided for @modalityImageDescription.
  ///
  /// In en, this message translates to:
  /// **'Image processing capabilities'**
  String get modalityImageDescription;

  /// No description provided for @modalityImageName.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get modalityImageName;

  /// No description provided for @modalityTextDescription.
  ///
  /// In en, this message translates to:
  /// **'Text-based content and processing'**
  String get modalityTextDescription;

  /// No description provided for @modalityTextName.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get modalityTextName;

  /// No description provided for @modelAddPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Model'**
  String get modelAddPageTitle;

  /// No description provided for @modelEditBackTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get modelEditBackTooltip;

  /// No description provided for @modelEditDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe this model'**
  String get modelEditDescriptionHint;

  /// No description provided for @modelEditDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get modelEditDescriptionLabel;

  /// No description provided for @modelEditDisplayNameHint.
  ///
  /// In en, this message translates to:
  /// **'A friendly name for this model'**
  String get modelEditDisplayNameHint;

  /// No description provided for @modelEditDisplayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get modelEditDisplayNameLabel;

  /// No description provided for @modelEditFunctionCallingDescription.
  ///
  /// In en, this message translates to:
  /// **'This model supports function and tool calling.'**
  String get modelEditFunctionCallingDescription;

  /// No description provided for @modelEditFunctionCallingLabel.
  ///
  /// In en, this message translates to:
  /// **'Function calling'**
  String get modelEditFunctionCallingLabel;

  /// No description provided for @modelEditGeminiThinkingModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Gemini thinking mode'**
  String get modelEditGeminiThinkingModeLabel;

  /// No description provided for @modelEditInputModalitiesHint.
  ///
  /// In en, this message translates to:
  /// **'Select input types'**
  String get modelEditInputModalitiesHint;

  /// No description provided for @modelEditInputModalitiesLabel.
  ///
  /// In en, this message translates to:
  /// **'Input modalities'**
  String get modelEditInputModalitiesLabel;

  /// No description provided for @modelEditLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load model configuration'**
  String get modelEditLoadError;

  /// No description provided for @modelEditMaxTokensHint.
  ///
  /// In en, this message translates to:
  /// **'Optional — leave empty for unlimited'**
  String get modelEditMaxTokensHint;

  /// No description provided for @modelEditMaxTokensLabel.
  ///
  /// In en, this message translates to:
  /// **'Max completion tokens'**
  String get modelEditMaxTokensLabel;

  /// No description provided for @modelEditModalityNoneSelected.
  ///
  /// In en, this message translates to:
  /// **'None selected'**
  String get modelEditModalityNoneSelected;

  /// No description provided for @modelEditOutputModalitiesHint.
  ///
  /// In en, this message translates to:
  /// **'Select output types'**
  String get modelEditOutputModalitiesHint;

  /// No description provided for @modelEditOutputModalitiesLabel.
  ///
  /// In en, this message translates to:
  /// **'Output modalities'**
  String get modelEditOutputModalitiesLabel;

  /// No description provided for @modelEditPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Model'**
  String get modelEditPageTitle;

  /// No description provided for @modelEditProviderHint.
  ///
  /// In en, this message translates to:
  /// **'Select a provider'**
  String get modelEditProviderHint;

  /// No description provided for @modelEditProviderLabel.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get modelEditProviderLabel;

  /// No description provided for @modelEditProviderModelIdHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. gpt-4-turbo'**
  String get modelEditProviderModelIdHint;

  /// No description provided for @modelEditProviderModelIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Provider model ID'**
  String get modelEditProviderModelIdLabel;

  /// No description provided for @modelEditReasoningDescription.
  ///
  /// In en, this message translates to:
  /// **'This model uses extended thinking / chain-of-thought.'**
  String get modelEditReasoningDescription;

  /// No description provided for @modelEditReasoningLabel.
  ///
  /// In en, this message translates to:
  /// **'Reasoning model'**
  String get modelEditReasoningLabel;

  /// No description provided for @modelEditSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get modelEditSaveButton;

  /// No description provided for @modelEditSectionCapabilities.
  ///
  /// In en, this message translates to:
  /// **'Capabilities'**
  String get modelEditSectionCapabilities;

  /// No description provided for @modelEditSectionIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get modelEditSectionIdentity;

  /// No description provided for @modelManagementSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} model{count, plural, =1{} other{s}} selected'**
  String modelManagementSelectedCount(int count);

  /// No description provided for @multiSelectAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get multiSelectAddButton;

  /// No description provided for @multiSelectAddButtonWithCount.
  ///
  /// In en, this message translates to:
  /// **'Add ({count})'**
  String multiSelectAddButtonWithCount(int count);

  /// No description provided for @multiSelectNoItemsFound.
  ///
  /// In en, this message translates to:
  /// **'No items found'**
  String get multiSelectNoItemsFound;

  /// No description provided for @navTabMoreSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{More, 1 additional destination} other{More, {count} additional destinations}}'**
  String navTabMoreSemanticsLabel(int count);

  /// No description provided for @navTabTitleCalendar.
  ///
  /// In en, this message translates to:
  /// **'DailyOS'**
  String get navTabTitleCalendar;

  /// No description provided for @navTabTitleHabits.
  ///
  /// In en, this message translates to:
  /// **'Habits'**
  String get navTabTitleHabits;

  /// No description provided for @navTabTitleInsights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get navTabTitleInsights;

  /// No description provided for @navTabTitleJournal.
  ///
  /// In en, this message translates to:
  /// **'Logbook'**
  String get navTabTitleJournal;

  /// No description provided for @navTabTitleMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navTabTitleMore;

  /// No description provided for @navTabTitleProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get navTabTitleProjects;

  /// No description provided for @navTabTitleSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navTabTitleSettings;

  /// No description provided for @navTabTitleTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get navTabTitleTasks;

  /// No description provided for @nestedAiResponsesTitle.
  ///
  /// In en, this message translates to:
  /// **'{count} AI response{count, plural, =1{} other{s}}'**
  String nestedAiResponsesTitle(int count);

  /// No description provided for @noDefaultLanguage.
  ///
  /// In en, this message translates to:
  /// **'No default language'**
  String get noDefaultLanguage;

  /// No description provided for @noTasksFound.
  ///
  /// In en, this message translates to:
  /// **'No tasks found'**
  String get noTasksFound;

  /// No description provided for @noTasksToLink.
  ///
  /// In en, this message translates to:
  /// **'No tasks available to link'**
  String get noTasksToLink;

  /// No description provided for @notificationBellEmptySemantics.
  ///
  /// In en, this message translates to:
  /// **'Notifications, no unread alerts'**
  String get notificationBellEmptySemantics;

  /// No description provided for @notificationBellTooltip.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationBellTooltip;

  /// No description provided for @notificationBellUnseenSemantics.
  ///
  /// In en, this message translates to:
  /// **'Notifications, {count} unread {count, plural, =1{alert} other{alerts}}'**
  String notificationBellUnseenSemantics(int count);

  /// No description provided for @notificationInboxDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss notification'**
  String get notificationInboxDismiss;

  /// No description provided for @notificationInboxEmpty.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up.'**
  String get notificationInboxEmpty;

  /// No description provided for @notificationInboxError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load notifications.'**
  String get notificationInboxError;

  /// No description provided for @notificationInboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationInboxTitle;

  /// No description provided for @notificationSuggestionAttentionBodyFallback.
  ///
  /// In en, this message translates to:
  /// **'Open the task to review.'**
  String get notificationSuggestionAttentionBodyFallback;

  /// No description provided for @notificationSuggestionAttentionTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 suggestion needs your attention} other{{count} suggestions need your attention}}'**
  String notificationSuggestionAttentionTitle(int count);

  /// No description provided for @optionalCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category (optional)'**
  String get optionalCategoryLabel;

  /// No description provided for @outboxActionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get outboxActionRemove;

  /// No description provided for @outboxActionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get outboxActionRetry;

  /// No description provided for @outboxFailedReassurance.
  ///
  /// In en, this message translates to:
  /// **'Still saved on this device — it\'ll sync once the problem clears.'**
  String get outboxFailedReassurance;

  /// No description provided for @outboxFilterFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get outboxFilterFailed;

  /// No description provided for @outboxFilterWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get outboxFilterWaiting;

  /// No description provided for @outboxMonitorAttachmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get outboxMonitorAttachmentLabel;

  /// No description provided for @outboxMonitorDelete.
  ///
  /// In en, this message translates to:
  /// **'delete'**
  String get outboxMonitorDelete;

  /// No description provided for @outboxMonitorDeleteConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get outboxMonitorDeleteConfirmLabel;

  /// No description provided for @outboxMonitorDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this sync item? This action cannot be undone.'**
  String get outboxMonitorDeleteConfirmMessage;

  /// No description provided for @outboxMonitorDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed. Please try again.'**
  String get outboxMonitorDeleteFailed;

  /// No description provided for @outboxMonitorDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Item deleted'**
  String get outboxMonitorDeleteSuccess;

  /// No description provided for @outboxMonitorEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'There are no sync items in this view.'**
  String get outboxMonitorEmptyDescription;

  /// No description provided for @outboxMonitorEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Outbox is clear'**
  String get outboxMonitorEmptyTitle;

  /// No description provided for @outboxMonitorFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the outbox. Pull to refresh and try again.'**
  String get outboxMonitorFetchFailed;

  /// No description provided for @outboxMonitorLabelError.
  ///
  /// In en, this message translates to:
  /// **'error'**
  String get outboxMonitorLabelError;

  /// No description provided for @outboxMonitorLabelPending.
  ///
  /// In en, this message translates to:
  /// **'pending'**
  String get outboxMonitorLabelPending;

  /// No description provided for @outboxMonitorLabelSent.
  ///
  /// In en, this message translates to:
  /// **'sent'**
  String get outboxMonitorLabelSent;

  /// No description provided for @outboxMonitorLabelSuccess.
  ///
  /// In en, this message translates to:
  /// **'success'**
  String get outboxMonitorLabelSuccess;

  /// No description provided for @outboxMonitorNoAttachment.
  ///
  /// In en, this message translates to:
  /// **'no attachment'**
  String get outboxMonitorNoAttachment;

  /// No description provided for @outboxMonitorPayloadSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get outboxMonitorPayloadSizeLabel;

  /// No description provided for @outboxMonitorRetries.
  ///
  /// In en, this message translates to:
  /// **'retries'**
  String get outboxMonitorRetries;

  /// No description provided for @outboxMonitorRetriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Retries'**
  String get outboxMonitorRetriesLabel;

  /// No description provided for @outboxMonitorRetry.
  ///
  /// In en, this message translates to:
  /// **'retry'**
  String get outboxMonitorRetry;

  /// No description provided for @outboxMonitorRetryConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Retry Now'**
  String get outboxMonitorRetryConfirmLabel;

  /// No description provided for @outboxMonitorRetryConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Retry this sync item now?'**
  String get outboxMonitorRetryConfirmMessage;

  /// No description provided for @outboxMonitorRetryFailed.
  ///
  /// In en, this message translates to:
  /// **'Retry failed. Please try again.'**
  String get outboxMonitorRetryFailed;

  /// No description provided for @outboxMonitorRetryQueued.
  ///
  /// In en, this message translates to:
  /// **'Retry scheduled'**
  String get outboxMonitorRetryQueued;

  /// No description provided for @outboxMonitorSubjectLabel.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get outboxMonitorSubjectLabel;

  /// No description provided for @outboxMonitorVolumeChartTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily sync volume'**
  String get outboxMonitorVolumeChartTitle;

  /// No description provided for @outboxRemoveConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This change hasn\'t synced yet. Removing it here means it won\'t reach your other devices. It stays on this device.'**
  String get outboxRemoveConfirmMessage;

  /// No description provided for @outboxRemoveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove from queue?'**
  String get outboxRemoveConfirmTitle;

  /// No description provided for @outboxRetryAll.
  ///
  /// In en, this message translates to:
  /// **'Retry all'**
  String get outboxRetryAll;

  /// No description provided for @outboxShowDetails.
  ///
  /// In en, this message translates to:
  /// **'Show technical details'**
  String get outboxShowDetails;

  /// No description provided for @outboxStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send'**
  String get outboxStatusFailed;

  /// No description provided for @outboxStatusSending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get outboxStatusSending;

  /// No description provided for @outboxStatusSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get outboxStatusSent;

  /// No description provided for @outboxStatusWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting to send'**
  String get outboxStatusWaiting;

  /// No description provided for @outboxSummaryFailed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item couldn\'t send} other{{count} items couldn\'t send}}'**
  String outboxSummaryFailed(int count);

  /// No description provided for @outboxSummaryOffline.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item will send when you reconnect} other{{count} items will send when you reconnect}}'**
  String outboxSummaryOffline(int count);

  /// No description provided for @outboxSummarySending.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Sending 1 item…} other{Sending {count} items…}}'**
  String outboxSummarySending(int count);

  /// No description provided for @outboxSummarySynced.
  ///
  /// In en, this message translates to:
  /// **'Everything\'s synced'**
  String get outboxSummarySynced;

  /// No description provided for @outboxSummaryWaiting.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item waiting to send} other{{count} items waiting to send}}'**
  String outboxSummaryWaiting(int count);

  /// No description provided for @outboxTriedTimes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Tried once} other{Tried {count} times}}'**
  String outboxTriedTimes(int count);

  /// No description provided for @privateLabel.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get privateLabel;

  /// No description provided for @privateSwitchDescription.
  ///
  /// In en, this message translates to:
  /// **'Only visible when private entries are shown'**
  String get privateSwitchDescription;

  /// No description provided for @projectAgentNotProvisioned.
  ///
  /// In en, this message translates to:
  /// **'No project agent has been provisioned for this project yet.'**
  String get projectAgentNotProvisioned;

  /// No description provided for @projectAgentSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get projectAgentSectionTitle;

  /// No description provided for @projectCountSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} project} other{{count} projects}}'**
  String projectCountSummary(int count);

  /// No description provided for @projectCreateButton.
  ///
  /// In en, this message translates to:
  /// **'New Project'**
  String get projectCreateButton;

  /// No description provided for @projectCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Project'**
  String get projectCreateTitle;

  /// No description provided for @projectDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Project Details'**
  String get projectDetailTitle;

  /// No description provided for @projectErrorCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Error creating project.'**
  String get projectErrorCreateFailed;

  /// No description provided for @projectErrorLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load project data.'**
  String get projectErrorLoadFailed;

  /// No description provided for @projectErrorLoadProjects.
  ///
  /// In en, this message translates to:
  /// **'Error loading projects'**
  String get projectErrorLoadProjects;

  /// No description provided for @projectErrorUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update project. Please try again.'**
  String get projectErrorUpdateFailed;

  /// No description provided for @projectFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get projectFilterLabel;

  /// No description provided for @projectHealthBandAtRisk.
  ///
  /// In en, this message translates to:
  /// **'At Risk'**
  String get projectHealthBandAtRisk;

  /// No description provided for @projectHealthBandBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get projectHealthBandBlocked;

  /// No description provided for @projectHealthBandOnTrack.
  ///
  /// In en, this message translates to:
  /// **'On Track'**
  String get projectHealthBandOnTrack;

  /// No description provided for @projectHealthBandSurviving.
  ///
  /// In en, this message translates to:
  /// **'Surviving'**
  String get projectHealthBandSurviving;

  /// No description provided for @projectHealthBandWatch.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get projectHealthBandWatch;

  /// No description provided for @projectHealthSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Project health'**
  String get projectHealthSectionTitle;

  /// No description provided for @projectHealthSummary.
  ///
  /// In en, this message translates to:
  /// **'{projectCount, plural, one{{projectCount} project} other{{projectCount} projects}}, {taskCount, plural, one{{taskCount} task} other{{taskCount} tasks}}'**
  String projectHealthSummary(int projectCount, int taskCount);

  /// No description provided for @projectHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get projectHealthTitle;

  /// No description provided for @projectLinkedTaskCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} linked task} other{{count} linked tasks}}'**
  String projectLinkedTaskCount(int count);

  /// No description provided for @projectLinkedTasks.
  ///
  /// In en, this message translates to:
  /// **'Linked Tasks'**
  String get projectLinkedTasks;

  /// No description provided for @projectManageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Manage projects'**
  String get projectManageTooltip;

  /// No description provided for @projectNoLinkedTasks.
  ///
  /// In en, this message translates to:
  /// **'No tasks linked yet'**
  String get projectNoLinkedTasks;

  /// No description provided for @projectNoProjects.
  ///
  /// In en, this message translates to:
  /// **'No projects yet'**
  String get projectNoProjects;

  /// No description provided for @projectNotFound.
  ///
  /// In en, this message translates to:
  /// **'Project not found'**
  String get projectNotFound;

  /// No description provided for @projectPickerLabel.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get projectPickerLabel;

  /// No description provided for @projectPickerUnassigned.
  ///
  /// In en, this message translates to:
  /// **'No project'**
  String get projectPickerUnassigned;

  /// No description provided for @projectRecommendationDismissTooltip.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get projectRecommendationDismissTooltip;

  /// No description provided for @projectRecommendationResolveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Mark resolved'**
  String get projectRecommendationResolveTooltip;

  /// No description provided for @projectRecommendationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recommended next steps'**
  String get projectRecommendationsTitle;

  /// No description provided for @projectRecommendationUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the recommendation. Please try again.'**
  String get projectRecommendationUpdateError;

  /// No description provided for @projectsFilterStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status:'**
  String get projectsFilterStatusLabel;

  /// No description provided for @projectsFilterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter projects'**
  String get projectsFilterTooltip;

  /// No description provided for @projectShowcaseAiReportTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Report'**
  String get projectShowcaseAiReportTitle;

  /// No description provided for @projectShowcaseBlockedLegend.
  ///
  /// In en, this message translates to:
  /// **'{count} Blocked'**
  String projectShowcaseBlockedLegend(int count);

  /// No description provided for @projectShowcaseBlockedTaskCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} task blocked} other{{count} tasks blocked}}'**
  String projectShowcaseBlockedTaskCount(int count);

  /// No description provided for @projectShowcaseCompletedLegend.
  ///
  /// In en, this message translates to:
  /// **'{count} Completed'**
  String projectShowcaseCompletedLegend(int count);

  /// No description provided for @projectShowcaseDescriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get projectShowcaseDescriptionTitle;

  /// No description provided for @projectShowcaseDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String projectShowcaseDueDate(String date);

  /// No description provided for @projectShowcaseHealthScoreDescription.
  ///
  /// In en, this message translates to:
  /// **'This score is based on task velocity, blockers, and time left to deadline.'**
  String get projectShowcaseHealthScoreDescription;

  /// No description provided for @projectShowcaseHealthScoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Health Score'**
  String get projectShowcaseHealthScoreTitle;

  /// No description provided for @projectShowcaseNoResults.
  ///
  /// In en, this message translates to:
  /// **'No projects match your search.'**
  String get projectShowcaseNoResults;

  /// No description provided for @projectShowcaseOneOnOneReviewsTab.
  ///
  /// In en, this message translates to:
  /// **'One-on-one Reviews'**
  String get projectShowcaseOneOnOneReviewsTab;

  /// No description provided for @projectShowcaseOngoing.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get projectShowcaseOngoing;

  /// No description provided for @projectShowcaseProjectTasksTab.
  ///
  /// In en, this message translates to:
  /// **'Project Tasks'**
  String get projectShowcaseProjectTasksTab;

  /// No description provided for @projectShowcaseSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search projects'**
  String get projectShowcaseSearchHint;

  /// No description provided for @projectShowcaseSessionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} session} other{{count} sessions}}'**
  String projectShowcaseSessionsCount(int count);

  /// No description provided for @projectShowcaseTasksCompleted.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, one{{completed}/{total} task completed} other{{completed}/{total} tasks completed}}'**
  String projectShowcaseTasksCompleted(int completed, int total);

  /// No description provided for @projectShowcaseUpdatedHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'Updated {hours}h ago ↻'**
  String projectShowcaseUpdatedHoursAgo(int hours);

  /// No description provided for @projectShowcaseUpdatedMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'Updated {minutes}m ago ↻'**
  String projectShowcaseUpdatedMinutesAgo(int minutes);

  /// No description provided for @projectShowcaseUsefulness.
  ///
  /// In en, this message translates to:
  /// **'Usefulness'**
  String get projectShowcaseUsefulness;

  /// No description provided for @projectShowcaseViewBlocker.
  ///
  /// In en, this message translates to:
  /// **'View blocker'**
  String get projectShowcaseViewBlocker;

  /// No description provided for @projectStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get projectStatusActive;

  /// No description provided for @projectStatusArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get projectStatusArchived;

  /// No description provided for @projectStatusChangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Change Status'**
  String get projectStatusChangeTitle;

  /// No description provided for @projectStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get projectStatusCompleted;

  /// No description provided for @projectStatusMonitoring.
  ///
  /// In en, this message translates to:
  /// **'Monitoring'**
  String get projectStatusMonitoring;

  /// No description provided for @projectStatusOnHold.
  ///
  /// In en, this message translates to:
  /// **'On Hold'**
  String get projectStatusOnHold;

  /// No description provided for @projectStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get projectStatusOpen;

  /// No description provided for @projectSummaryOutdated.
  ///
  /// In en, this message translates to:
  /// **'Summary outdated.'**
  String get projectSummaryOutdated;

  /// No description provided for @projectSummaryOutdatedScheduled.
  ///
  /// In en, this message translates to:
  /// **'Summary outdated. Next update {date} at {time}.'**
  String projectSummaryOutdatedScheduled(String date, String time);

  /// No description provided for @projectTargetDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Target Date'**
  String get projectTargetDateLabel;

  /// No description provided for @projectTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Project Title'**
  String get projectTitleLabel;

  /// No description provided for @projectTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Project title cannot be empty'**
  String get projectTitleRequired;

  /// No description provided for @promptDefaultModelBadge.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get promptDefaultModelBadge;

  /// No description provided for @promptGenerationCardTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Coding Prompt'**
  String get promptGenerationCardTitle;

  /// No description provided for @promptGenerationCopiedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Prompt copied to clipboard'**
  String get promptGenerationCopiedSnackbar;

  /// No description provided for @promptGenerationCopyButton.
  ///
  /// In en, this message translates to:
  /// **'Copy Prompt'**
  String get promptGenerationCopyButton;

  /// No description provided for @promptGenerationCopyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy prompt to clipboard'**
  String get promptGenerationCopyTooltip;

  /// No description provided for @promptGenerationExpandTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show full prompt'**
  String get promptGenerationExpandTooltip;

  /// No description provided for @promptGenerationFullPromptLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Prompt:'**
  String get promptGenerationFullPromptLabel;

  /// No description provided for @promptSelectionModalTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Preconfigured Prompt'**
  String get promptSelectionModalTitle;

  /// No description provided for @provisionedSyncBundleImported.
  ///
  /// In en, this message translates to:
  /// **'Provisioning code imported'**
  String get provisionedSyncBundleImported;

  /// No description provided for @provisionedSyncConfigureButton.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get provisionedSyncConfigureButton;

  /// No description provided for @provisionedSyncCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get provisionedSyncCopiedToClipboard;

  /// No description provided for @provisionedSyncDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get provisionedSyncDisconnect;

  /// No description provided for @provisionedSyncDone.
  ///
  /// In en, this message translates to:
  /// **'Sync configured successfully'**
  String get provisionedSyncDone;

  /// No description provided for @provisionedSyncError.
  ///
  /// In en, this message translates to:
  /// **'Configuration failed'**
  String get provisionedSyncError;

  /// No description provided for @provisionedSyncErrorConfigurationFailed.
  ///
  /// In en, this message translates to:
  /// **'An error occurred during configuration. Please try again.'**
  String get provisionedSyncErrorConfigurationFailed;

  /// No description provided for @provisionedSyncErrorLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please check your credentials and try again.'**
  String get provisionedSyncErrorLoginFailed;

  /// No description provided for @provisionedSyncImportButton.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get provisionedSyncImportButton;

  /// No description provided for @provisionedSyncImportHint.
  ///
  /// In en, this message translates to:
  /// **'Paste provisioning code here'**
  String get provisionedSyncImportHint;

  /// No description provided for @provisionedSyncImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Setup'**
  String get provisionedSyncImportTitle;

  /// No description provided for @provisionedSyncInvalidBundle.
  ///
  /// In en, this message translates to:
  /// **'Invalid provisioning code'**
  String get provisionedSyncInvalidBundle;

  /// No description provided for @provisionedSyncJoiningRoom.
  ///
  /// In en, this message translates to:
  /// **'Joining sync room...'**
  String get provisionedSyncJoiningRoom;

  /// No description provided for @provisionedSyncLoggingIn.
  ///
  /// In en, this message translates to:
  /// **'Logging in...'**
  String get provisionedSyncLoggingIn;

  /// No description provided for @provisionedSyncPasteClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get provisionedSyncPasteClipboard;

  /// No description provided for @provisionedSyncReady.
  ///
  /// In en, this message translates to:
  /// **'Scan this QR code on your mobile device'**
  String get provisionedSyncReady;

  /// No description provided for @provisionedSyncRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get provisionedSyncRetry;

  /// No description provided for @provisionedSyncRotatingPassword.
  ///
  /// In en, this message translates to:
  /// **'Securing account...'**
  String get provisionedSyncRotatingPassword;

  /// No description provided for @provisionedSyncScanButton.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get provisionedSyncScanButton;

  /// No description provided for @provisionedSyncShowQr.
  ///
  /// In en, this message translates to:
  /// **'Show provisioning QR'**
  String get provisionedSyncShowQr;

  /// No description provided for @provisionedSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set up sync from a provisioning bundle'**
  String get provisionedSyncSubtitle;

  /// No description provided for @provisionedSyncSummaryHomeserver.
  ///
  /// In en, this message translates to:
  /// **'Homeserver'**
  String get provisionedSyncSummaryHomeserver;

  /// No description provided for @provisionedSyncSummaryRoom.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get provisionedSyncSummaryRoom;

  /// No description provided for @provisionedSyncSummaryUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get provisionedSyncSummaryUser;

  /// No description provided for @provisionedSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Provisioned Sync'**
  String get provisionedSyncTitle;

  /// No description provided for @provisionedSyncVerifyDevicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Device Verification'**
  String get provisionedSyncVerifyDevicesTitle;

  /// No description provided for @queueCatchUpNowButton.
  ///
  /// In en, this message translates to:
  /// **'Catch up now'**
  String get queueCatchUpNowButton;

  /// No description provided for @queueCatchUpNowDone.
  ///
  /// In en, this message translates to:
  /// **'Catch-up kicked — queue is draining.'**
  String get queueCatchUpNowDone;

  /// No description provided for @queueCatchUpNowError.
  ///
  /// In en, this message translates to:
  /// **'Catch-up failed: {reason}'**
  String queueCatchUpNowError(String reason);

  /// No description provided for @queueDepthCardEmpty.
  ///
  /// In en, this message translates to:
  /// **'Queue empty — worker is caught up.'**
  String get queueDepthCardEmpty;

  /// No description provided for @queueDepthCardLoading.
  ///
  /// In en, this message translates to:
  /// **'Reading queue depth…'**
  String get queueDepthCardLoading;

  /// No description provided for @queueDepthCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Inbound queue'**
  String get queueDepthCardTitle;

  /// No description provided for @queueFetchAllHistoryCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get queueFetchAllHistoryCancel;

  /// No description provided for @queueFetchAllHistoryCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled — {events, plural, =0{no events} =1{1 event} other{{events} events}} fetched so far.'**
  String queueFetchAllHistoryCancelled(int events);

  /// No description provided for @queueFetchAllHistoryClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get queueFetchAllHistoryClose;

  /// No description provided for @queueFetchAllHistoryDescription.
  ///
  /// In en, this message translates to:
  /// **'Walks the room\'s entire visible history into the queue. Safe to cancel; a later run resumes from where pagination stopped.'**
  String get queueFetchAllHistoryDescription;

  /// No description provided for @queueFetchAllHistoryDone.
  ///
  /// In en, this message translates to:
  /// **'{events, plural, =0{No events fetched.} =1{Fetched 1 event across {pages, plural, =1{1 page} other{{pages} pages}}.} other{Fetched {events} events across {pages, plural, =1{1 page} other{{pages} pages}}.}}'**
  String queueFetchAllHistoryDone(int events, int pages);

  /// No description provided for @queueFetchAllHistoryError.
  ///
  /// In en, this message translates to:
  /// **'Fetch stopped: {reason}'**
  String queueFetchAllHistoryError(String reason);

  /// No description provided for @queueFetchAllHistoryErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Fetch stopped unexpectedly.'**
  String get queueFetchAllHistoryErrorUnknown;

  /// No description provided for @queueFetchAllHistoryProgress.
  ///
  /// In en, this message translates to:
  /// **'{events, plural, =1{Page {pages}  ·  1 event fetched} other{Page {pages}  ·  {events} events fetched}}'**
  String queueFetchAllHistoryProgress(int events, int pages);

  /// No description provided for @queueFetchAllHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Fetching history'**
  String get queueFetchAllHistoryTitle;

  /// No description provided for @queueSkippedBadge.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 skipped} other{{count} skipped}}'**
  String queueSkippedBadge(int count);

  /// No description provided for @queueSkippedCardBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 sync event the queue gave up on. Tap retry to re-attempt.} other{{count} sync events the queue gave up on. Tap retry to re-attempt.}}'**
  String queueSkippedCardBody(int count);

  /// No description provided for @queueSkippedCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Skipped events'**
  String get queueSkippedCardTitle;

  /// No description provided for @queueSkippedRetryAll.
  ///
  /// In en, this message translates to:
  /// **'Retry skipped events'**
  String get queueSkippedRetryAll;

  /// No description provided for @queueSkippedRetryAllDone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No skipped events to retry.} =1{1 event queued for retry.} other{{count} events queued for retry.}}'**
  String queueSkippedRetryAllDone(int count);

  /// No description provided for @queueSkippedRetryAllError.
  ///
  /// In en, this message translates to:
  /// **'Retry failed: {reason}'**
  String queueSkippedRetryAllError(String reason);

  /// No description provided for @referenceImageContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get referenceImageContinue;

  /// No description provided for @referenceImageContinueWithCount.
  ///
  /// In en, this message translates to:
  /// **'Continue ({count})'**
  String referenceImageContinueWithCount(int count);

  /// No description provided for @referenceImageLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load images. Please try again.'**
  String get referenceImageLoadError;

  /// No description provided for @referenceImageSelectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose up to 5 images to guide the AI\'s visual style'**
  String get referenceImageSelectionSubtitle;

  /// No description provided for @referenceImageSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Reference Images'**
  String get referenceImageSelectionTitle;

  /// No description provided for @referenceImageSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get referenceImageSkip;

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @saveButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButtonLabel;

  /// No description provided for @saveLabel.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveLabel;

  /// No description provided for @saveShortcutTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save — Ctrl+S (⌘S on Mac)'**
  String get saveShortcutTooltip;

  /// No description provided for @saveSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Saved successfully'**
  String get saveSuccessful;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get searchHint;

  /// No description provided for @searchModeFullText.
  ///
  /// In en, this message translates to:
  /// **'Full Text'**
  String get searchModeFullText;

  /// No description provided for @searchModeVector.
  ///
  /// In en, this message translates to:
  /// **'Vector'**
  String get searchModeVector;

  /// No description provided for @searchTasksHint.
  ///
  /// In en, this message translates to:
  /// **'Search tasks...'**
  String get searchTasksHint;

  /// No description provided for @selectButton.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get selectButton;

  /// No description provided for @selectColor.
  ///
  /// In en, this message translates to:
  /// **'Select a color'**
  String get selectColor;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @sessionRatingCardLabel.
  ///
  /// In en, this message translates to:
  /// **'Session Rating'**
  String get sessionRatingCardLabel;

  /// No description provided for @sessionRatingChallengeJustRight.
  ///
  /// In en, this message translates to:
  /// **'Just right'**
  String get sessionRatingChallengeJustRight;

  /// No description provided for @sessionRatingChallengeTooEasy.
  ///
  /// In en, this message translates to:
  /// **'Too easy'**
  String get sessionRatingChallengeTooEasy;

  /// No description provided for @sessionRatingChallengeTooHard.
  ///
  /// In en, this message translates to:
  /// **'Too challenging'**
  String get sessionRatingChallengeTooHard;

  /// No description provided for @sessionRatingDifficultyLabel.
  ///
  /// In en, this message translates to:
  /// **'This work felt...'**
  String get sessionRatingDifficultyLabel;

  /// No description provided for @sessionRatingEditButton.
  ///
  /// In en, this message translates to:
  /// **'Edit Rating'**
  String get sessionRatingEditButton;

  /// No description provided for @sessionRatingEnergyQuestion.
  ///
  /// In en, this message translates to:
  /// **'How energized did you feel?'**
  String get sessionRatingEnergyQuestion;

  /// No description provided for @sessionRatingFocusQuestion.
  ///
  /// In en, this message translates to:
  /// **'How focused were you?'**
  String get sessionRatingFocusQuestion;

  /// No description provided for @sessionRatingNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Quick note (optional)'**
  String get sessionRatingNoteHint;

  /// No description provided for @sessionRatingProductivityQuestion.
  ///
  /// In en, this message translates to:
  /// **'How productive was this session?'**
  String get sessionRatingProductivityQuestion;

  /// No description provided for @sessionRatingRateAction.
  ///
  /// In en, this message translates to:
  /// **'Rate Session'**
  String get sessionRatingRateAction;

  /// No description provided for @sessionRatingSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get sessionRatingSaveButton;

  /// No description provided for @sessionRatingSaveError.
  ///
  /// In en, this message translates to:
  /// **'Failed to save rating. Please try again.'**
  String get sessionRatingSaveError;

  /// No description provided for @sessionRatingSkipButton.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get sessionRatingSkipButton;

  /// No description provided for @sessionRatingTitle.
  ///
  /// In en, this message translates to:
  /// **'Rate this session'**
  String get sessionRatingTitle;

  /// No description provided for @sessionRatingViewAction.
  ///
  /// In en, this message translates to:
  /// **'View Rating'**
  String get sessionRatingViewAction;

  /// No description provided for @settingsAboutAppInformation.
  ///
  /// In en, this message translates to:
  /// **'App Information'**
  String get settingsAboutAppInformation;

  /// No description provided for @settingsAboutAppTagline.
  ///
  /// In en, this message translates to:
  /// **'Your Personal Journal'**
  String get settingsAboutAppTagline;

  /// No description provided for @settingsAboutBuildType.
  ///
  /// In en, this message translates to:
  /// **'Build Type'**
  String get settingsAboutBuildType;

  /// No description provided for @settingsAboutDailyOsPersonalizationTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily OS personalization'**
  String get settingsAboutDailyOsPersonalizationTitle;

  /// No description provided for @settingsAboutDailyOsUserNameHelper.
  ///
  /// In en, this message translates to:
  /// **'Used only for the Daily OS greeting on this device.'**
  String get settingsAboutDailyOsUserNameHelper;

  /// No description provided for @settingsAboutDailyOsUserNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get settingsAboutDailyOsUserNameLabel;

  /// No description provided for @settingsAboutJournalEntries.
  ///
  /// In en, this message translates to:
  /// **'Journal Entries'**
  String get settingsAboutJournalEntries;

  /// No description provided for @settingsAboutPlatform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get settingsAboutPlatform;

  /// No description provided for @settingsAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About Lotti'**
  String get settingsAboutTitle;

  /// No description provided for @settingsAboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsAboutVersion;

  /// No description provided for @settingsAboutYourData.
  ///
  /// In en, this message translates to:
  /// **'Your Data'**
  String get settingsAboutYourData;

  /// No description provided for @settingsAdvancedAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Learn more about the Lotti application'**
  String get settingsAdvancedAboutSubtitle;

  /// No description provided for @settingsAdvancedHealthImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import health-related data from external sources'**
  String get settingsAdvancedHealthImportSubtitle;

  /// No description provided for @settingsAdvancedMaintenanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Perform maintenance tasks to optimize application performance'**
  String get settingsAdvancedMaintenanceSubtitle;

  /// No description provided for @settingsAdvancedOutboxSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage sync items'**
  String get settingsAdvancedOutboxSubtitle;

  /// No description provided for @settingsAdvancedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced settings and maintenance'**
  String get settingsAdvancedSubtitle;

  /// No description provided for @settingsAdvancedTitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced Settings'**
  String get settingsAdvancedTitle;

  /// No description provided for @settingsAgentsInstancesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Running agents'**
  String get settingsAgentsInstancesSubtitle;

  /// No description provided for @settingsAgentsPendingWakesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scheduled wake timers'**
  String get settingsAgentsPendingWakesSubtitle;

  /// No description provided for @settingsAgentsSoulsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Long-lived agent personalities'**
  String get settingsAgentsSoulsSubtitle;

  /// No description provided for @settingsAgentsStatsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Token usage and activity'**
  String get settingsAgentsStatsSubtitle;

  /// No description provided for @settingsAgentsTemplatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shared agent blueprints'**
  String get settingsAgentsTemplatesSubtitle;

  /// No description provided for @settingsAiModelsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Per-provider model rows and capabilities'**
  String get settingsAiModelsSubtitle;

  /// No description provided for @settingsAiModelsTitle.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get settingsAiModelsTitle;

  /// No description provided for @settingsAiProfilesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Providers and models'**
  String get settingsAiProfilesSubtitle;

  /// No description provided for @settingsAiProfilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Inference Profiles'**
  String get settingsAiProfilesTitle;

  /// No description provided for @settingsAiProvidersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connected AI providers and keys'**
  String get settingsAiProvidersSubtitle;

  /// No description provided for @settingsAiProvidersTitle.
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get settingsAiProvidersTitle;

  /// No description provided for @settingsAiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure AI providers, models, and prompts'**
  String get settingsAiSubtitle;

  /// No description provided for @settingsAiTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Settings'**
  String get settingsAiTitle;

  /// No description provided for @settingsBeamPageEditModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit model'**
  String get settingsBeamPageEditModelTitle;

  /// No description provided for @settingsBeamPageEditProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get settingsBeamPageEditProfileTitle;

  /// No description provided for @settingsCategoriesCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create category'**
  String get settingsCategoriesCreateTitle;

  /// No description provided for @settingsCategoriesDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get settingsCategoriesDetailsLabel;

  /// No description provided for @settingsCategoriesEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No categories yet'**
  String get settingsCategoriesEmptyState;

  /// No description provided for @settingsCategoriesEmptyStateHint.
  ///
  /// In en, this message translates to:
  /// **'Create a category to organize your entries'**
  String get settingsCategoriesEmptyStateHint;

  /// No description provided for @settingsCategoriesErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading categories'**
  String get settingsCategoriesErrorLoading;

  /// No description provided for @settingsCategoriesNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get settingsCategoriesNameLabel;

  /// No description provided for @settingsCategoriesNoMatchQuery.
  ///
  /// In en, this message translates to:
  /// **'No categories match \"{query}\"'**
  String settingsCategoriesNoMatchQuery(String query);

  /// No description provided for @settingsCategoriesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search categories…'**
  String get settingsCategoriesSearchHint;

  /// No description provided for @settingsCategoriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Categories with AI settings'**
  String get settingsCategoriesSubtitle;

  /// No description provided for @settingsCategoriesTaskCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} task} other{{count} tasks}}'**
  String settingsCategoriesTaskCount(int count);

  /// No description provided for @settingsCategoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get settingsCategoriesTitle;

  /// No description provided for @settingsCelebrationsChecklistDescription.
  ///
  /// In en, this message translates to:
  /// **'A pop and sparks when you check an item off'**
  String get settingsCelebrationsChecklistDescription;

  /// No description provided for @settingsCelebrationsChecklistTitle.
  ///
  /// In en, this message translates to:
  /// **'Checklist items'**
  String get settingsCelebrationsChecklistTitle;

  /// No description provided for @settingsCelebrationsHabitsDescription.
  ///
  /// In en, this message translates to:
  /// **'Glow and sparks when you complete a habit'**
  String get settingsCelebrationsHabitsDescription;

  /// No description provided for @settingsCelebrationsHabitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Habits'**
  String get settingsCelebrationsHabitsTitle;

  /// No description provided for @settingsCelebrationsSectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Play a flourish when you finish something. Switching one off keeps the completion and its haptic — it just skips the animation.'**
  String get settingsCelebrationsSectionDescription;

  /// No description provided for @settingsCelebrationsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Completion celebrations'**
  String get settingsCelebrationsSectionTitle;

  /// No description provided for @settingsCelebrationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Completion celebrations'**
  String get settingsCelebrationsSubtitle;

  /// No description provided for @settingsCelebrationsTasksDescription.
  ///
  /// In en, this message translates to:
  /// **'Glow and sparks when you move a task to Done'**
  String get settingsCelebrationsTasksDescription;

  /// No description provided for @settingsCelebrationsTasksTitle.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get settingsCelebrationsTasksTitle;

  /// No description provided for @settingsCelebrationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Animations'**
  String get settingsCelebrationsTitle;

  /// No description provided for @settingsConflictsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Conflicts'**
  String get settingsConflictsTitle;

  /// No description provided for @settingsDashboardDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit dashboard'**
  String get settingsDashboardDetailsLabel;

  /// No description provided for @settingsDashboardSaveLabel.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settingsDashboardSaveLabel;

  /// No description provided for @settingsDashboardsCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create dashboard'**
  String get settingsDashboardsCreateTitle;

  /// No description provided for @settingsDashboardsEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No dashboards yet'**
  String get settingsDashboardsEmptyState;

  /// No description provided for @settingsDashboardsEmptyStateHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the + button to create your first dashboard.'**
  String get settingsDashboardsEmptyStateHint;

  /// No description provided for @settingsDashboardsErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading dashboards'**
  String get settingsDashboardsErrorLoading;

  /// No description provided for @settingsDashboardsNoMatchQuery.
  ///
  /// In en, this message translates to:
  /// **'No dashboards match \"{query}\"'**
  String settingsDashboardsNoMatchQuery(String query);

  /// No description provided for @settingsDashboardsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search dashboards…'**
  String get settingsDashboardsSearchHint;

  /// No description provided for @settingsDashboardsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Customize your dashboard views'**
  String get settingsDashboardsSubtitle;

  /// No description provided for @settingsDashboardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboards'**
  String get settingsDashboardsTitle;

  /// No description provided for @settingsDefinitionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Habits, categories, labels, dashboards, and measurables'**
  String get settingsDefinitionsSubtitle;

  /// No description provided for @settingsDefinitionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Definitions'**
  String get settingsDefinitionsTitle;

  /// No description provided for @settingsFlagsEmptySearch.
  ///
  /// In en, this message translates to:
  /// **'No flags match your search'**
  String get settingsFlagsEmptySearch;

  /// No description provided for @settingsFlagsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search flags'**
  String get settingsFlagsSearchHint;

  /// No description provided for @settingsFlagsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure feature flags and options'**
  String get settingsFlagsSubtitle;

  /// No description provided for @settingsFlagsTitle.
  ///
  /// In en, this message translates to:
  /// **'Config Flags'**
  String get settingsFlagsTitle;

  /// No description provided for @settingsHabitsCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create habit'**
  String get settingsHabitsCreateTitle;

  /// No description provided for @settingsHabitsDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete Habit'**
  String get settingsHabitsDeleteTooltip;

  /// No description provided for @settingsHabitsDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get settingsHabitsDescriptionLabel;

  /// No description provided for @settingsHabitsDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit habit'**
  String get settingsHabitsDetailsLabel;

  /// No description provided for @settingsHabitsEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No habits yet'**
  String get settingsHabitsEmptyState;

  /// No description provided for @settingsHabitsEmptyStateHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the + button to create your first habit.'**
  String get settingsHabitsEmptyStateHint;

  /// No description provided for @settingsHabitsErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading habits'**
  String get settingsHabitsErrorLoading;

  /// No description provided for @settingsHabitsNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Habit name'**
  String get settingsHabitsNameLabel;

  /// No description provided for @settingsHabitsNoMatchQuery.
  ///
  /// In en, this message translates to:
  /// **'No habits match \"{query}\"'**
  String settingsHabitsNoMatchQuery(String query);

  /// No description provided for @settingsHabitsPrivateLabel.
  ///
  /// In en, this message translates to:
  /// **'Private: '**
  String get settingsHabitsPrivateLabel;

  /// No description provided for @settingsHabitsSaveLabel.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settingsHabitsSaveLabel;

  /// No description provided for @settingsHabitsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search habits…'**
  String get settingsHabitsSearchHint;

  /// No description provided for @settingsHabitsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your habits and routines'**
  String get settingsHabitsSubtitle;

  /// No description provided for @settingsHabitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Habits'**
  String get settingsHabitsTitle;

  /// No description provided for @settingsHealthImportActivity.
  ///
  /// In en, this message translates to:
  /// **'Import Activity Data'**
  String get settingsHealthImportActivity;

  /// No description provided for @settingsHealthImportBloodPressure.
  ///
  /// In en, this message translates to:
  /// **'Import Blood Pressure Data'**
  String get settingsHealthImportBloodPressure;

  /// No description provided for @settingsHealthImportBodyMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Import Body Measurement Data'**
  String get settingsHealthImportBodyMeasurement;

  /// No description provided for @settingsHealthImportFromDate.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get settingsHealthImportFromDate;

  /// No description provided for @settingsHealthImportHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Import Heart Rate Data'**
  String get settingsHealthImportHeartRate;

  /// No description provided for @settingsHealthImportSleep.
  ///
  /// In en, this message translates to:
  /// **'Import Sleep Data'**
  String get settingsHealthImportSleep;

  /// No description provided for @settingsHealthImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Health Import'**
  String get settingsHealthImportTitle;

  /// No description provided for @settingsHealthImportToDate.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get settingsHealthImportToDate;

  /// No description provided for @settingsHealthImportWorkout.
  ///
  /// In en, this message translates to:
  /// **'Import Workout Data'**
  String get settingsHealthImportWorkout;

  /// No description provided for @settingsLabelsCategoriesAdd.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get settingsLabelsCategoriesAdd;

  /// No description provided for @settingsLabelsCategoriesHeading.
  ///
  /// In en, this message translates to:
  /// **'Applicable categories'**
  String get settingsLabelsCategoriesHeading;

  /// No description provided for @settingsLabelsCategoriesNone.
  ///
  /// In en, this message translates to:
  /// **'Applies to all categories'**
  String get settingsLabelsCategoriesNone;

  /// No description provided for @settingsLabelsCategoriesRemoveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get settingsLabelsCategoriesRemoveTooltip;

  /// No description provided for @settingsLabelsColorHeading.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get settingsLabelsColorHeading;

  /// No description provided for @settingsLabelsColorSubheading.
  ///
  /// In en, this message translates to:
  /// **'Quick presets'**
  String get settingsLabelsColorSubheading;

  /// No description provided for @settingsLabelsCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create label'**
  String get settingsLabelsCreateTitle;

  /// No description provided for @settingsLabelsDeleteConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get settingsLabelsDeleteConfirmAction;

  /// No description provided for @settingsLabelsDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{labelName}\"? Tasks with this label will lose the assignment.'**
  String settingsLabelsDeleteConfirmMessage(Object labelName);

  /// No description provided for @settingsLabelsDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete label'**
  String get settingsLabelsDeleteConfirmTitle;

  /// No description provided for @settingsLabelsDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Label \"{labelName}\" deleted'**
  String settingsLabelsDeleteSuccess(Object labelName);

  /// No description provided for @settingsLabelsDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Explain when to apply this label'**
  String get settingsLabelsDescriptionHint;

  /// No description provided for @settingsLabelsDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get settingsLabelsDescriptionLabel;

  /// No description provided for @settingsLabelsEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit label'**
  String get settingsLabelsEditTitle;

  /// No description provided for @settingsLabelsEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No labels yet'**
  String get settingsLabelsEmptyState;

  /// No description provided for @settingsLabelsEmptyStateHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the + button to create your first label.'**
  String get settingsLabelsEmptyStateHint;

  /// No description provided for @settingsLabelsErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Failed to load labels'**
  String get settingsLabelsErrorLoading;

  /// No description provided for @settingsLabelsNameHint.
  ///
  /// In en, this message translates to:
  /// **'Bug, Release blocker, Sync…'**
  String get settingsLabelsNameHint;

  /// No description provided for @settingsLabelsNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Label name'**
  String get settingsLabelsNameLabel;

  /// No description provided for @settingsLabelsNoMatchCreate.
  ///
  /// In en, this message translates to:
  /// **'Create \"{query}\" label'**
  String settingsLabelsNoMatchCreate(String query);

  /// No description provided for @settingsLabelsNoMatchQuery.
  ///
  /// In en, this message translates to:
  /// **'No labels match \"{query}\"'**
  String settingsLabelsNoMatchQuery(String query);

  /// No description provided for @settingsLabelsPrivateDescription.
  ///
  /// In en, this message translates to:
  /// **'Only visible when private entries are shown'**
  String get settingsLabelsPrivateDescription;

  /// No description provided for @settingsLabelsPrivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get settingsLabelsPrivateTitle;

  /// No description provided for @settingsLabelsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search labels…'**
  String get settingsLabelsSearchHint;

  /// No description provided for @settingsLabelsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Organize tasks with colored labels'**
  String get settingsLabelsSubtitle;

  /// No description provided for @settingsLabelsTitle.
  ///
  /// In en, this message translates to:
  /// **'Labels'**
  String get settingsLabelsTitle;

  /// No description provided for @settingsLabelsUsageCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task} other{{count} tasks}}'**
  String settingsLabelsUsageCount(int count);

  /// No description provided for @settingsLoggingDomainsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Control which domains write to the log'**
  String get settingsLoggingDomainsSubtitle;

  /// No description provided for @settingsLoggingDomainsTitle.
  ///
  /// In en, this message translates to:
  /// **'Logging Domains'**
  String get settingsLoggingDomainsTitle;

  /// No description provided for @settingsLoggingGlobalToggle.
  ///
  /// In en, this message translates to:
  /// **'Enable Logging'**
  String get settingsLoggingGlobalToggle;

  /// No description provided for @settingsLoggingGlobalToggleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Master switch for all logging'**
  String get settingsLoggingGlobalToggleSubtitle;

  /// No description provided for @settingsLoggingSlowQueries.
  ///
  /// In en, this message translates to:
  /// **'Slow Database Queries'**
  String get settingsLoggingSlowQueries;

  /// No description provided for @settingsLoggingSlowQueriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Writes slow queries to slow_queries-YYYY-MM-DD.log'**
  String get settingsLoggingSlowQueriesSubtitle;

  /// No description provided for @settingsMaintenanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get settingsMaintenanceTitle;

  /// No description provided for @settingsMatrixAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get settingsMatrixAccept;

  /// No description provided for @settingsMatrixAcceptVerificationLabel.
  ///
  /// In en, this message translates to:
  /// **'Other device shows emojis, continue'**
  String get settingsMatrixAcceptVerificationLabel;

  /// No description provided for @settingsMatrixCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsMatrixCancel;

  /// No description provided for @settingsMatrixContinueVerificationLabel.
  ///
  /// In en, this message translates to:
  /// **'Accept on other device to continue'**
  String get settingsMatrixContinueVerificationLabel;

  /// No description provided for @settingsMatrixDiagnosticCopied.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic info copied to clipboard'**
  String get settingsMatrixDiagnosticCopied;

  /// No description provided for @settingsMatrixDiagnosticCopyButton.
  ///
  /// In en, this message translates to:
  /// **'Copy to Clipboard'**
  String get settingsMatrixDiagnosticCopyButton;

  /// No description provided for @settingsMatrixDiagnosticDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Diagnostic Info'**
  String get settingsMatrixDiagnosticDialogTitle;

  /// No description provided for @settingsMatrixDiagnosticShowButton.
  ///
  /// In en, this message translates to:
  /// **'Show Diagnostic Info'**
  String get settingsMatrixDiagnosticShowButton;

  /// No description provided for @settingsMatrixDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get settingsMatrixDone;

  /// No description provided for @settingsMatrixLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated:'**
  String get settingsMatrixLastUpdated;

  /// No description provided for @settingsMatrixListUnverifiedLabel.
  ///
  /// In en, this message translates to:
  /// **'Unverified devices'**
  String get settingsMatrixListUnverifiedLabel;

  /// No description provided for @settingsMatrixMaintenanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Run Matrix maintenance tasks and recovery tools'**
  String get settingsMatrixMaintenanceSubtitle;

  /// No description provided for @settingsMatrixMaintenanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get settingsMatrixMaintenanceTitle;

  /// No description provided for @settingsMatrixMetrics.
  ///
  /// In en, this message translates to:
  /// **'Sync Metrics'**
  String get settingsMatrixMetrics;

  /// No description provided for @settingsMatrixNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next Page'**
  String get settingsMatrixNextPage;

  /// No description provided for @settingsMatrixNoUnverifiedLabel.
  ///
  /// In en, this message translates to:
  /// **'No unverified devices'**
  String get settingsMatrixNoUnverifiedLabel;

  /// No description provided for @settingsMatrixPreviousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous Page'**
  String get settingsMatrixPreviousPage;

  /// No description provided for @settingsMatrixRoomInviteMessage.
  ///
  /// In en, this message translates to:
  /// **'Invite to room {roomId} from {senderId}. Accept?'**
  String settingsMatrixRoomInviteMessage(String roomId, String senderId);

  /// No description provided for @settingsMatrixRoomInviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Room invite'**
  String get settingsMatrixRoomInviteTitle;

  /// No description provided for @settingsMatrixSentMessagesLabel.
  ///
  /// In en, this message translates to:
  /// **'Sent messages:'**
  String get settingsMatrixSentMessagesLabel;

  /// No description provided for @settingsMatrixStartVerificationLabel.
  ///
  /// In en, this message translates to:
  /// **'Start Verification'**
  String get settingsMatrixStartVerificationLabel;

  /// No description provided for @settingsMatrixStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Matrix Stats'**
  String get settingsMatrixStatsTitle;

  /// No description provided for @settingsMatrixTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Settings'**
  String get settingsMatrixTitle;

  /// No description provided for @settingsMatrixUnverifiedDevicesPage.
  ///
  /// In en, this message translates to:
  /// **'Unverified Devices'**
  String get settingsMatrixUnverifiedDevicesPage;

  /// No description provided for @settingsMatrixVerificationCancelledLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancelled on other device...'**
  String get settingsMatrixVerificationCancelledLabel;

  /// No description provided for @settingsMatrixVerificationSuccessConfirm.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get settingsMatrixVerificationSuccessConfirm;

  /// No description provided for @settingsMatrixVerificationSuccessLabel.
  ///
  /// In en, this message translates to:
  /// **'You\'ve successfully verified {deviceName} ({deviceID})'**
  String settingsMatrixVerificationSuccessLabel(
    String deviceName,
    String deviceID,
  );

  /// No description provided for @settingsMatrixVerifyConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm on other device that the emojis below are displayed on both devices, in the same order:'**
  String get settingsMatrixVerifyConfirm;

  /// No description provided for @settingsMatrixVerifyIncomingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm that the emojis below are displayed on both devices, in the same order:'**
  String get settingsMatrixVerifyIncomingConfirm;

  /// No description provided for @settingsMatrixVerifyLabel.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get settingsMatrixVerifyLabel;

  /// No description provided for @settingsMeasurableAggregationHelper.
  ///
  /// In en, this message translates to:
  /// **'How a day\'s entries combine on charts'**
  String get settingsMeasurableAggregationHelper;

  /// No description provided for @settingsMeasurableAggregationLabel.
  ///
  /// In en, this message translates to:
  /// **'Default aggregation type'**
  String get settingsMeasurableAggregationLabel;

  /// No description provided for @settingsMeasurableDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete measurable type'**
  String get settingsMeasurableDeleteTooltip;

  /// No description provided for @settingsMeasurableDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get settingsMeasurableDescriptionLabel;

  /// No description provided for @settingsMeasurableDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit measurable'**
  String get settingsMeasurableDetailsLabel;

  /// No description provided for @settingsMeasurableNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Measurable name'**
  String get settingsMeasurableNameLabel;

  /// No description provided for @settingsMeasurablePrivateLabel.
  ///
  /// In en, this message translates to:
  /// **'Private: '**
  String get settingsMeasurablePrivateLabel;

  /// No description provided for @settingsMeasurableSaveLabel.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settingsMeasurableSaveLabel;

  /// No description provided for @settingsMeasurablesCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create measurable'**
  String get settingsMeasurablesCreateTitle;

  /// No description provided for @settingsMeasurablesEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No measurables yet'**
  String get settingsMeasurablesEmptyState;

  /// No description provided for @settingsMeasurablesEmptyStateHint.
  ///
  /// In en, this message translates to:
  /// **'Measurables are numbers you track over time — weight, water, steps.'**
  String get settingsMeasurablesEmptyStateHint;

  /// No description provided for @settingsMeasurablesErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading measurables'**
  String get settingsMeasurablesErrorLoading;

  /// No description provided for @settingsMeasurablesNoMatchQuery.
  ///
  /// In en, this message translates to:
  /// **'No measurables match \"{query}\"'**
  String settingsMeasurablesNoMatchQuery(String query);

  /// No description provided for @settingsMeasurablesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search measurables…'**
  String get settingsMeasurablesSearchHint;

  /// No description provided for @settingsMeasurablesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure measurable data types'**
  String get settingsMeasurablesSubtitle;

  /// No description provided for @settingsMeasurablesTitle.
  ///
  /// In en, this message translates to:
  /// **'Measurables'**
  String get settingsMeasurablesTitle;

  /// No description provided for @settingsMeasurableUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit abbreviation (optional)'**
  String get settingsMeasurableUnitLabel;

  /// No description provided for @settingsResetGeminiConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get settingsResetGeminiConfirm;

  /// No description provided for @settingsResetGeminiConfirmQuestion.
  ///
  /// In en, this message translates to:
  /// **'This will show the Gemini setup dialog again. Continue?'**
  String get settingsResetGeminiConfirmQuestion;

  /// No description provided for @settingsResetGeminiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show the Gemini AI setup dialog again'**
  String get settingsResetGeminiSubtitle;

  /// No description provided for @settingsResetGeminiTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Gemini Setup Dialog'**
  String get settingsResetGeminiTitle;

  /// No description provided for @settingsResetHintsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get settingsResetHintsConfirm;

  /// No description provided for @settingsResetHintsConfirmQuestion.
  ///
  /// In en, this message translates to:
  /// **'Reset in‑app hints shown across the app?'**
  String get settingsResetHintsConfirmQuestion;

  /// No description provided for @settingsResetHintsResult.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Reset zero hints} one{Reset one hint} other{Reset {count} hints}}'**
  String settingsResetHintsResult(int count);

  /// No description provided for @settingsResetHintsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clear one‑time tips and onboarding hints'**
  String get settingsResetHintsSubtitle;

  /// No description provided for @settingsResetHintsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset In‑App Hints'**
  String get settingsResetHintsTitle;

  /// No description provided for @settingsSpeechSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Voice and reading aloud'**
  String get settingsSpeechSubtitle;

  /// No description provided for @settingsSpeechTitle.
  ///
  /// In en, this message translates to:
  /// **'Speech'**
  String get settingsSpeechTitle;

  /// No description provided for @settingsSyncConflictsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Resolve synchronization conflicts to ensure data consistency'**
  String get settingsSyncConflictsSubtitle;

  /// No description provided for @settingsSyncNodeProfileCapabilitiesEmpty.
  ///
  /// In en, this message translates to:
  /// **'None detected — auto-trigger of synced audio inference will not target this device.'**
  String get settingsSyncNodeProfileCapabilitiesEmpty;

  /// No description provided for @settingsSyncNodeProfileCapabilitiesLabel.
  ///
  /// In en, this message translates to:
  /// **'Detected AI capabilities'**
  String get settingsSyncNodeProfileCapabilitiesLabel;

  /// No description provided for @settingsSyncNodeProfileCapabilityMlxAudio.
  ///
  /// In en, this message translates to:
  /// **'MLX Audio (local)'**
  String get settingsSyncNodeProfileCapabilityMlxAudio;

  /// No description provided for @settingsSyncNodeProfileCapabilityOllamaLlm.
  ///
  /// In en, this message translates to:
  /// **'Ollama LLM'**
  String get settingsSyncNodeProfileCapabilityOllamaLlm;

  /// No description provided for @settingsSyncNodeProfileCapabilityOmlxLlm.
  ///
  /// In en, this message translates to:
  /// **'oMLX LLM'**
  String get settingsSyncNodeProfileCapabilityOmlxLlm;

  /// No description provided for @settingsSyncNodeProfileCapabilityVoxtral.
  ///
  /// In en, this message translates to:
  /// **'Voxtral (local)'**
  String get settingsSyncNodeProfileCapabilityVoxtral;

  /// No description provided for @settingsSyncNodeProfileCapabilityWhisper.
  ///
  /// In en, this message translates to:
  /// **'Whisper (local)'**
  String get settingsSyncNodeProfileCapabilityWhisper;

  /// No description provided for @settingsSyncNodeProfileDisplayNameHelper.
  ///
  /// In en, this message translates to:
  /// **'Visible to your other devices when picking which one to pin a profile to.'**
  String get settingsSyncNodeProfileDisplayNameHelper;

  /// No description provided for @settingsSyncNodeProfileDisplayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Device display name'**
  String get settingsSyncNodeProfileDisplayNameLabel;

  /// No description provided for @settingsSyncNodeProfileKnownNodesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No other devices have published a profile yet.'**
  String get settingsSyncNodeProfileKnownNodesEmpty;

  /// No description provided for @settingsSyncNodeProfileKnownNodesTitle.
  ///
  /// In en, this message translates to:
  /// **'Known sync devices'**
  String get settingsSyncNodeProfileKnownNodesTitle;

  /// No description provided for @settingsSyncNodeProfileSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settingsSyncNodeProfileSaveButton;

  /// No description provided for @settingsSyncNodeProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Name this device and review capabilities visible to your other devices.'**
  String get settingsSyncNodeProfileSubtitle;

  /// No description provided for @settingsSyncNodeProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get settingsSyncNodeProfileTitle;

  /// No description provided for @settingsSyncOutboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Outbox'**
  String get settingsSyncOutboxTitle;

  /// No description provided for @settingsSyncStatsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Inspect sync pipeline metrics'**
  String get settingsSyncStatsSubtitle;

  /// No description provided for @settingsSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure sync and view stats'**
  String get settingsSyncSubtitle;

  /// No description provided for @settingsThemingAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get settingsThemingAutomatic;

  /// No description provided for @settingsThemingDark.
  ///
  /// In en, this message translates to:
  /// **'Dark Appearance'**
  String get settingsThemingDark;

  /// No description provided for @settingsThemingLight.
  ///
  /// In en, this message translates to:
  /// **'Light Appearance'**
  String get settingsThemingLight;

  /// No description provided for @settingsThemingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Customize app appearance and themes'**
  String get settingsThemingSubtitle;

  /// No description provided for @settingsThemingTitle.
  ///
  /// In en, this message translates to:
  /// **'Theming'**
  String get settingsThemingTitle;

  /// No description provided for @settingsV2CategoryEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Pick a sub-setting on the left.'**
  String get settingsV2CategoryEmptyBody;

  /// No description provided for @settingsV2DetailRootCrumb.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsV2DetailRootCrumb;

  /// No description provided for @settingsV2EmptyStateBody.
  ///
  /// In en, this message translates to:
  /// **'Pick a section on the left to begin.'**
  String get settingsV2EmptyStateBody;

  /// No description provided for @settingsV2ResizeHandleLabel.
  ///
  /// In en, this message translates to:
  /// **'Resize settings tree'**
  String get settingsV2ResizeHandleLabel;

  /// No description provided for @settingsV2UnimplementedTitle.
  ///
  /// In en, this message translates to:
  /// **'Panel not yet implemented'**
  String get settingsV2UnimplementedTitle;

  /// No description provided for @settingsWhatsNewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See the latest updates and features'**
  String get settingsWhatsNewSubtitle;

  /// No description provided for @settingsWhatsNewTitle.
  ///
  /// In en, this message translates to:
  /// **'What\'s New'**
  String get settingsWhatsNewTitle;

  /// No description provided for @settingThemingDark.
  ///
  /// In en, this message translates to:
  /// **'Dark Theme'**
  String get settingThemingDark;

  /// No description provided for @settingThemingLight.
  ///
  /// In en, this message translates to:
  /// **'Light Theme'**
  String get settingThemingLight;

  /// No description provided for @sidebarRunningTimerLabel.
  ///
  /// In en, this message translates to:
  /// **'Running timer'**
  String get sidebarRunningTimerLabel;

  /// No description provided for @sidebarRunningTimerStopTooltip.
  ///
  /// In en, this message translates to:
  /// **'Stop timer'**
  String get sidebarRunningTimerStopTooltip;

  /// No description provided for @sidebarToggleCollapseLabel.
  ///
  /// In en, this message translates to:
  /// **'Collapse sidebar'**
  String get sidebarToggleCollapseLabel;

  /// No description provided for @sidebarToggleExpandLabel.
  ///
  /// In en, this message translates to:
  /// **'Expand sidebar'**
  String get sidebarToggleExpandLabel;

  /// No description provided for @sidebarWakesCancelTooltip.
  ///
  /// In en, this message translates to:
  /// **'Cancel wake'**
  String get sidebarWakesCancelTooltip;

  /// No description provided for @sidebarWakesHeader.
  ///
  /// In en, this message translates to:
  /// **'Wakes'**
  String get sidebarWakesHeader;

  /// No description provided for @sidebarWakesNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get sidebarWakesNow;

  /// No description provided for @sidebarWakesOpenList.
  ///
  /// In en, this message translates to:
  /// **'Open list'**
  String get sidebarWakesOpenList;

  /// No description provided for @skillsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get skillsSectionTitle;

  /// No description provided for @speechDictionaryHelper.
  ///
  /// In en, this message translates to:
  /// **'Semicolon-separated terms (max 50 chars) for better speech recognition'**
  String get speechDictionaryHelper;

  /// No description provided for @speechDictionaryHint.
  ///
  /// In en, this message translates to:
  /// **'macOS; Kirkjubæjarklaustur; Claude Code'**
  String get speechDictionaryHint;

  /// No description provided for @speechDictionaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Speech Dictionary'**
  String get speechDictionaryLabel;

  /// No description provided for @speechDictionarySectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Add terms that are often misspelled by speech recognition (names, places, technical terms)'**
  String get speechDictionarySectionDescription;

  /// No description provided for @speechDictionarySectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition'**
  String get speechDictionarySectionTitle;

  /// No description provided for @speechDictionaryWarning.
  ///
  /// In en, this message translates to:
  /// **'Large dictionary ({count} terms) may increase API costs'**
  String speechDictionaryWarning(Object count);

  /// No description provided for @speechModalSelectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get speechModalSelectLanguage;

  /// No description provided for @speechModalTitle.
  ///
  /// In en, this message translates to:
  /// **'Speech Recognition'**
  String get speechModalTitle;

  /// No description provided for @speechSettingsModelDescription.
  ///
  /// In en, this message translates to:
  /// **'On-device speech model'**
  String get speechSettingsModelDescription;

  /// No description provided for @speechSettingsModelDownloadsOnce.
  ///
  /// In en, this message translates to:
  /// **'Downloads once'**
  String get speechSettingsModelDownloadsOnce;

  /// No description provided for @speechSettingsModelLabel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get speechSettingsModelLabel;

  /// No description provided for @speechSettingsRecommendedBadge.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get speechSettingsRecommendedBadge;

  /// No description provided for @speechSettingsSpeedDescription.
  ///
  /// In en, this message translates to:
  /// **'How fast summaries are read'**
  String get speechSettingsSpeedDescription;

  /// No description provided for @speechSettingsSpeedLabel.
  ///
  /// In en, this message translates to:
  /// **'Reading speed'**
  String get speechSettingsSpeedLabel;

  /// No description provided for @speechSettingsVoiceDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the voice that reads summaries aloud'**
  String get speechSettingsVoiceDescription;

  /// No description provided for @speechSettingsVoiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get speechSettingsVoiceLabel;

  /// No description provided for @speechVoiceGenderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get speechVoiceGenderFemale;

  /// No description provided for @speechVoiceGenderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get speechVoiceGenderMale;

  /// No description provided for @speechVoicePreviewTooltip.
  ///
  /// In en, this message translates to:
  /// **'Preview voice'**
  String get speechVoicePreviewTooltip;

  /// No description provided for @syncActivityIndicatorSemantics.
  ///
  /// In en, this message translates to:
  /// **'Sync activity. Outbox: {outbox}. Inbox: {inbox}. Open sync outbox.'**
  String syncActivityIndicatorSemantics(int outbox, int inbox);

  /// No description provided for @syncDeleteConfigConfirm.
  ///
  /// In en, this message translates to:
  /// **'YES, I\'M SURE'**
  String get syncDeleteConfigConfirm;

  /// No description provided for @syncDeleteConfigQuestion.
  ///
  /// In en, this message translates to:
  /// **'Do you want to delete the sync configuration?'**
  String get syncDeleteConfigQuestion;

  /// No description provided for @syncEntitiesConfirm.
  ///
  /// In en, this message translates to:
  /// **'START SYNC'**
  String get syncEntitiesConfirm;

  /// No description provided for @syncEntitiesMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose the entities you want to sync.'**
  String get syncEntitiesMessage;

  /// No description provided for @syncEntitiesSuccessDescription.
  ///
  /// In en, this message translates to:
  /// **'Everything is up to date.'**
  String get syncEntitiesSuccessDescription;

  /// No description provided for @syncEntitiesSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync complete'**
  String get syncEntitiesSuccessTitle;

  /// No description provided for @syncListCountSummary.
  ///
  /// In en, this message translates to:
  /// **'{label} · {itemCount, plural, =0{0 items} =1{1 item} other{{itemCount} items}}'**
  String syncListCountSummary(String label, int itemCount);

  /// No description provided for @syncListPayloadKindLabel.
  ///
  /// In en, this message translates to:
  /// **'Payload'**
  String get syncListPayloadKindLabel;

  /// No description provided for @syncListUnknownPayload.
  ///
  /// In en, this message translates to:
  /// **'Unknown payload'**
  String get syncListUnknownPayload;

  /// No description provided for @syncNotLoggedInToast.
  ///
  /// In en, this message translates to:
  /// **'Sync is not logged in'**
  String get syncNotLoggedInToast;

  /// No description provided for @syncPayloadAgentBundle.
  ///
  /// In en, this message translates to:
  /// **'Agent bundle'**
  String get syncPayloadAgentBundle;

  /// No description provided for @syncPayloadAgentEntity.
  ///
  /// In en, this message translates to:
  /// **'Agent entity'**
  String get syncPayloadAgentEntity;

  /// No description provided for @syncPayloadAgentLink.
  ///
  /// In en, this message translates to:
  /// **'Agent link'**
  String get syncPayloadAgentLink;

  /// No description provided for @syncPayloadAiConfig.
  ///
  /// In en, this message translates to:
  /// **'AI configuration'**
  String get syncPayloadAiConfig;

  /// No description provided for @syncPayloadAiConfigDelete.
  ///
  /// In en, this message translates to:
  /// **'AI configuration delete'**
  String get syncPayloadAiConfigDelete;

  /// No description provided for @syncPayloadBackfillRequest.
  ///
  /// In en, this message translates to:
  /// **'Backfill request'**
  String get syncPayloadBackfillRequest;

  /// No description provided for @syncPayloadBackfillResponse.
  ///
  /// In en, this message translates to:
  /// **'Backfill response'**
  String get syncPayloadBackfillResponse;

  /// No description provided for @syncPayloadConfigFlag.
  ///
  /// In en, this message translates to:
  /// **'Config flag'**
  String get syncPayloadConfigFlag;

  /// No description provided for @syncPayloadEntityDefinition.
  ///
  /// In en, this message translates to:
  /// **'Entity definition'**
  String get syncPayloadEntityDefinition;

  /// No description provided for @syncPayloadEntryLink.
  ///
  /// In en, this message translates to:
  /// **'Entry link'**
  String get syncPayloadEntryLink;

  /// No description provided for @syncPayloadJournalEntity.
  ///
  /// In en, this message translates to:
  /// **'Journal entry'**
  String get syncPayloadJournalEntity;

  /// No description provided for @syncPayloadNotification.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get syncPayloadNotification;

  /// No description provided for @syncPayloadNotificationStateUpdate.
  ///
  /// In en, this message translates to:
  /// **'Notification state update'**
  String get syncPayloadNotificationStateUpdate;

  /// No description provided for @syncPayloadOutboxBundle.
  ///
  /// In en, this message translates to:
  /// **'Outbox bundle'**
  String get syncPayloadOutboxBundle;

  /// No description provided for @syncPayloadSyncNodeProfile.
  ///
  /// In en, this message translates to:
  /// **'Sync node profile'**
  String get syncPayloadSyncNodeProfile;

  /// No description provided for @syncPayloadThemingSelection.
  ///
  /// In en, this message translates to:
  /// **'Theming selection'**
  String get syncPayloadThemingSelection;

  /// No description provided for @syncStepAgentEntities.
  ///
  /// In en, this message translates to:
  /// **'Agent entities'**
  String get syncStepAgentEntities;

  /// No description provided for @syncStepAgentLinks.
  ///
  /// In en, this message translates to:
  /// **'Agent links'**
  String get syncStepAgentLinks;

  /// No description provided for @syncStepAiSettings.
  ///
  /// In en, this message translates to:
  /// **'AI settings'**
  String get syncStepAiSettings;

  /// No description provided for @syncStepBackfillAgentEntityClocks.
  ///
  /// In en, this message translates to:
  /// **'Backfill agent entity clocks'**
  String get syncStepBackfillAgentEntityClocks;

  /// No description provided for @syncStepBackfillAgentLinkClocks.
  ///
  /// In en, this message translates to:
  /// **'Backfill agent link clocks'**
  String get syncStepBackfillAgentLinkClocks;

  /// No description provided for @syncStepCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get syncStepCategories;

  /// No description provided for @syncStepComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get syncStepComplete;

  /// No description provided for @syncStepDashboards.
  ///
  /// In en, this message translates to:
  /// **'Dashboards'**
  String get syncStepDashboards;

  /// No description provided for @syncStepHabits.
  ///
  /// In en, this message translates to:
  /// **'Habits'**
  String get syncStepHabits;

  /// No description provided for @syncStepLabels.
  ///
  /// In en, this message translates to:
  /// **'Labels'**
  String get syncStepLabels;

  /// No description provided for @syncStepMeasurables.
  ///
  /// In en, this message translates to:
  /// **'Measurables'**
  String get syncStepMeasurables;

  /// No description provided for @taskActionBarAudioRecordingActive.
  ///
  /// In en, this message translates to:
  /// **'Audio recording in progress'**
  String get taskActionBarAudioRecordingActive;

  /// No description provided for @taskActionBarMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get taskActionBarMoreActions;

  /// No description provided for @taskActionBarOpenRunningTimer.
  ///
  /// In en, this message translates to:
  /// **'Open running timer'**
  String get taskActionBarOpenRunningTimer;

  /// No description provided for @taskActionBarStopTracking.
  ///
  /// In en, this message translates to:
  /// **'Stop time tracking'**
  String get taskActionBarStopTracking;

  /// No description provided for @taskActionBarTrackTime.
  ///
  /// In en, this message translates to:
  /// **'Track time'**
  String get taskActionBarTrackTime;

  /// No description provided for @taskAgentCancelTimerTooltip.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get taskAgentCancelTimerTooltip;

  /// No description provided for @taskAgentCountdownTooltip.
  ///
  /// In en, this message translates to:
  /// **'Next auto-run in {countdown}'**
  String taskAgentCountdownTooltip(String countdown);

  /// No description provided for @taskAgentCreateChipLabel.
  ///
  /// In en, this message translates to:
  /// **'Assign Agent'**
  String get taskAgentCreateChipLabel;

  /// No description provided for @taskAgentCreateError.
  ///
  /// In en, this message translates to:
  /// **'Failed to create agent: {error}'**
  String taskAgentCreateError(String error);

  /// No description provided for @taskAgentRunNowTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get taskAgentRunNowTooltip;

  /// No description provided for @taskCategoryAllLabel.
  ///
  /// In en, this message translates to:
  /// **'all'**
  String get taskCategoryAllLabel;

  /// No description provided for @taskCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category:'**
  String get taskCategoryLabel;

  /// No description provided for @taskCategoryUnassignedLabel.
  ///
  /// In en, this message translates to:
  /// **'unassigned'**
  String get taskCategoryUnassignedLabel;

  /// No description provided for @taskDueDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Due Date'**
  String get taskDueDateLabel;

  /// No description provided for @taskDueDateWithDate.
  ///
  /// In en, this message translates to:
  /// **'Due: {date}'**
  String taskDueDateWithDate(String date);

  /// No description provided for @taskDueInDays.
  ///
  /// In en, this message translates to:
  /// **'Due in {days, plural, =1{1 day} other{{days} days}}'**
  String taskDueInDays(int days);

  /// No description provided for @taskDueToday.
  ///
  /// In en, this message translates to:
  /// **'Due Today'**
  String get taskDueToday;

  /// No description provided for @taskDueTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Due Tomorrow'**
  String get taskDueTomorrow;

  /// No description provided for @taskDueYesterday.
  ///
  /// In en, this message translates to:
  /// **'Due Yesterday'**
  String get taskDueYesterday;

  /// No description provided for @taskEditTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit task title'**
  String get taskEditTitleLabel;

  /// No description provided for @taskEstimateLabel.
  ///
  /// In en, this message translates to:
  /// **'Estimate:'**
  String get taskEstimateLabel;

  /// No description provided for @taskEstimateProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'{tracked} of {estimate}'**
  String taskEstimateProgressLabel(String tracked, String estimate);

  /// No description provided for @taskEstimateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Time tracked: {tracked} of {estimate} estimated'**
  String taskEstimateTooltip(String tracked, String estimate);

  /// No description provided for @taskLabelsMoreCount.
  ///
  /// In en, this message translates to:
  /// **'+{count}'**
  String taskLabelsMoreCount(int count);

  /// No description provided for @taskLabelsShowFewer.
  ///
  /// In en, this message translates to:
  /// **'Show fewer'**
  String get taskLabelsShowFewer;

  /// No description provided for @taskLanguageArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get taskLanguageArabic;

  /// No description provided for @taskLanguageBengali.
  ///
  /// In en, this message translates to:
  /// **'Bengali'**
  String get taskLanguageBengali;

  /// No description provided for @taskLanguageBulgarian.
  ///
  /// In en, this message translates to:
  /// **'Bulgarian'**
  String get taskLanguageBulgarian;

  /// No description provided for @taskLanguageChinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get taskLanguageChinese;

  /// No description provided for @taskLanguageCroatian.
  ///
  /// In en, this message translates to:
  /// **'Croatian'**
  String get taskLanguageCroatian;

  /// No description provided for @taskLanguageCzech.
  ///
  /// In en, this message translates to:
  /// **'Czech'**
  String get taskLanguageCzech;

  /// No description provided for @taskLanguageDanish.
  ///
  /// In en, this message translates to:
  /// **'Danish'**
  String get taskLanguageDanish;

  /// No description provided for @taskLanguageDutch.
  ///
  /// In en, this message translates to:
  /// **'Dutch'**
  String get taskLanguageDutch;

  /// No description provided for @taskLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get taskLanguageEnglish;

  /// No description provided for @taskLanguageEstonian.
  ///
  /// In en, this message translates to:
  /// **'Estonian'**
  String get taskLanguageEstonian;

  /// No description provided for @taskLanguageFinnish.
  ///
  /// In en, this message translates to:
  /// **'Finnish'**
  String get taskLanguageFinnish;

  /// No description provided for @taskLanguageFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get taskLanguageFrench;

  /// No description provided for @taskLanguageGerman.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get taskLanguageGerman;

  /// No description provided for @taskLanguageGreek.
  ///
  /// In en, this message translates to:
  /// **'Greek'**
  String get taskLanguageGreek;

  /// No description provided for @taskLanguageHebrew.
  ///
  /// In en, this message translates to:
  /// **'Hebrew'**
  String get taskLanguageHebrew;

  /// No description provided for @taskLanguageHindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get taskLanguageHindi;

  /// No description provided for @taskLanguageHungarian.
  ///
  /// In en, this message translates to:
  /// **'Hungarian'**
  String get taskLanguageHungarian;

  /// No description provided for @taskLanguageIgbo.
  ///
  /// In en, this message translates to:
  /// **'Igbo'**
  String get taskLanguageIgbo;

  /// No description provided for @taskLanguageIndonesian.
  ///
  /// In en, this message translates to:
  /// **'Indonesian'**
  String get taskLanguageIndonesian;

  /// No description provided for @taskLanguageItalian.
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get taskLanguageItalian;

  /// No description provided for @taskLanguageJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get taskLanguageJapanese;

  /// No description provided for @taskLanguageKorean.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get taskLanguageKorean;

  /// No description provided for @taskLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get taskLanguageLabel;

  /// No description provided for @taskLanguageLatvian.
  ///
  /// In en, this message translates to:
  /// **'Latvian'**
  String get taskLanguageLatvian;

  /// No description provided for @taskLanguageLithuanian.
  ///
  /// In en, this message translates to:
  /// **'Lithuanian'**
  String get taskLanguageLithuanian;

  /// No description provided for @taskLanguageNigerianPidgin.
  ///
  /// In en, this message translates to:
  /// **'Nigerian Pidgin'**
  String get taskLanguageNigerianPidgin;

  /// No description provided for @taskLanguageNorwegian.
  ///
  /// In en, this message translates to:
  /// **'Norwegian'**
  String get taskLanguageNorwegian;

  /// No description provided for @taskLanguagePolish.
  ///
  /// In en, this message translates to:
  /// **'Polish'**
  String get taskLanguagePolish;

  /// No description provided for @taskLanguagePortuguese.
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get taskLanguagePortuguese;

  /// No description provided for @taskLanguageRomanian.
  ///
  /// In en, this message translates to:
  /// **'Romanian'**
  String get taskLanguageRomanian;

  /// No description provided for @taskLanguageRussian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get taskLanguageRussian;

  /// No description provided for @taskLanguageSelectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Currently selected'**
  String get taskLanguageSelectedLabel;

  /// No description provided for @taskLanguageSerbian.
  ///
  /// In en, this message translates to:
  /// **'Serbian'**
  String get taskLanguageSerbian;

  /// No description provided for @taskLanguageSetAction.
  ///
  /// In en, this message translates to:
  /// **'Set language'**
  String get taskLanguageSetAction;

  /// No description provided for @taskLanguageSlovak.
  ///
  /// In en, this message translates to:
  /// **'Slovak'**
  String get taskLanguageSlovak;

  /// No description provided for @taskLanguageSlovenian.
  ///
  /// In en, this message translates to:
  /// **'Slovenian'**
  String get taskLanguageSlovenian;

  /// No description provided for @taskLanguageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get taskLanguageSpanish;

  /// No description provided for @taskLanguageSwahili.
  ///
  /// In en, this message translates to:
  /// **'Swahili'**
  String get taskLanguageSwahili;

  /// No description provided for @taskLanguageSwedish.
  ///
  /// In en, this message translates to:
  /// **'Swedish'**
  String get taskLanguageSwedish;

  /// No description provided for @taskLanguageThai.
  ///
  /// In en, this message translates to:
  /// **'Thai'**
  String get taskLanguageThai;

  /// No description provided for @taskLanguageTurkish.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get taskLanguageTurkish;

  /// The Twi language, spoken primarily in Ghana
  ///
  /// In en, this message translates to:
  /// **'Twi'**
  String get taskLanguageTwi;

  /// No description provided for @taskLanguageUkrainian.
  ///
  /// In en, this message translates to:
  /// **'Ukrainian'**
  String get taskLanguageUkrainian;

  /// No description provided for @taskLanguageVietnamese.
  ///
  /// In en, this message translates to:
  /// **'Vietnamese'**
  String get taskLanguageVietnamese;

  /// No description provided for @taskLanguageYoruba.
  ///
  /// In en, this message translates to:
  /// **'Yoruba'**
  String get taskLanguageYoruba;

  /// No description provided for @taskNoDueDateLabel.
  ///
  /// In en, this message translates to:
  /// **'No due date'**
  String get taskNoDueDateLabel;

  /// No description provided for @taskNoEstimateLabel.
  ///
  /// In en, this message translates to:
  /// **'No estimate'**
  String get taskNoEstimateLabel;

  /// No description provided for @taskOverdueByDays.
  ///
  /// In en, this message translates to:
  /// **'Overdue by {days, plural, =1{1 day} other{{days} days}}'**
  String taskOverdueByDays(int days);

  /// No description provided for @taskPriorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get taskPriorityHigh;

  /// No description provided for @taskPriorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get taskPriorityLow;

  /// No description provided for @taskPriorityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get taskPriorityMedium;

  /// No description provided for @taskPriorityUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get taskPriorityUrgent;

  /// No description provided for @tasksAddLabelButton.
  ///
  /// In en, this message translates to:
  /// **'Add Label'**
  String get tasksAddLabelButton;

  /// No description provided for @tasksAgentFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get tasksAgentFilterAll;

  /// No description provided for @tasksAgentFilterHasAgent.
  ///
  /// In en, this message translates to:
  /// **'Has Agent'**
  String get tasksAgentFilterHasAgent;

  /// No description provided for @tasksAgentFilterNoAgent.
  ///
  /// In en, this message translates to:
  /// **'No Agent'**
  String get tasksAgentFilterNoAgent;

  /// No description provided for @tasksAgentFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get tasksAgentFilterTitle;

  /// No description provided for @tasksFilterApplyTitle.
  ///
  /// In en, this message translates to:
  /// **'Apply filter'**
  String get tasksFilterApplyTitle;

  /// No description provided for @tasksFilterClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get tasksFilterClearAll;

  /// No description provided for @tasksFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'Tasks Filter'**
  String get tasksFilterTitle;

  /// No description provided for @taskShowcaseAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get taskShowcaseAudio;

  /// No description provided for @taskShowcaseCompletedCount.
  ///
  /// In en, this message translates to:
  /// **'{completed} / {total} done'**
  String taskShowcaseCompletedCount(int completed, int total);

  /// No description provided for @taskShowcaseDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due: {date}'**
  String taskShowcaseDueDate(String date);

  /// No description provided for @taskShowcaseJumpToSection.
  ///
  /// In en, this message translates to:
  /// **'Jump to section'**
  String get taskShowcaseJumpToSection;

  /// No description provided for @taskShowcaseLinked.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get taskShowcaseLinked;

  /// No description provided for @taskShowcaseNoResults.
  ///
  /// In en, this message translates to:
  /// **'No tasks match your search.'**
  String get taskShowcaseNoResults;

  /// No description provided for @taskShowcaseReadMore.
  ///
  /// In en, this message translates to:
  /// **'Read more'**
  String get taskShowcaseReadMore;

  /// No description provided for @taskShowcaseRecordingsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 recording} other{{count} recordings}}'**
  String taskShowcaseRecordingsCount(int count);

  /// No description provided for @taskShowcaseTaskCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 task} other{{count} tasks}}'**
  String taskShowcaseTaskCount(int count);

  /// No description provided for @taskShowcaseTaskDescription.
  ///
  /// In en, this message translates to:
  /// **'Task description'**
  String get taskShowcaseTaskDescription;

  /// No description provided for @taskShowcaseTimeTracker.
  ///
  /// In en, this message translates to:
  /// **'Time Tracker'**
  String get taskShowcaseTimeTracker;

  /// No description provided for @taskShowcaseTodo.
  ///
  /// In en, this message translates to:
  /// **'Todo'**
  String get taskShowcaseTodo;

  /// No description provided for @taskShowcaseTodos.
  ///
  /// In en, this message translates to:
  /// **'Todos'**
  String get taskShowcaseTodos;

  /// No description provided for @tasksLabelFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get tasksLabelFilterAll;

  /// No description provided for @tasksLabelFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get tasksLabelFilterTitle;

  /// No description provided for @tasksLabelFilterUnlabeled.
  ///
  /// In en, this message translates to:
  /// **'Unlabeled'**
  String get tasksLabelFilterUnlabeled;

  /// No description provided for @tasksLabelsDialogClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get tasksLabelsDialogClose;

  /// No description provided for @tasksLabelsSheetApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get tasksLabelsSheetApply;

  /// No description provided for @tasksLabelsSheetSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search labels…'**
  String get tasksLabelsSheetSearchHint;

  /// No description provided for @tasksLabelsUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update labels'**
  String get tasksLabelsUpdateFailed;

  /// No description provided for @tasksPriorityFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get tasksPriorityFilterAll;

  /// No description provided for @tasksPriorityFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get tasksPriorityFilterTitle;

  /// No description provided for @tasksPriorityP0.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get tasksPriorityP0;

  /// No description provided for @tasksPriorityP0Description.
  ///
  /// In en, this message translates to:
  /// **'Urgent (ASAP)'**
  String get tasksPriorityP0Description;

  /// No description provided for @tasksPriorityP1.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get tasksPriorityP1;

  /// No description provided for @tasksPriorityP1Description.
  ///
  /// In en, this message translates to:
  /// **'High (Soon)'**
  String get tasksPriorityP1Description;

  /// No description provided for @tasksPriorityP2.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get tasksPriorityP2;

  /// No description provided for @tasksPriorityP2Description.
  ///
  /// In en, this message translates to:
  /// **'Medium (Default)'**
  String get tasksPriorityP2Description;

  /// No description provided for @tasksPriorityP3.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get tasksPriorityP3;

  /// No description provided for @tasksPriorityP3Description.
  ///
  /// In en, this message translates to:
  /// **'Low (Whenever)'**
  String get tasksPriorityP3Description;

  /// No description provided for @tasksPriorityPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Select priority'**
  String get tasksPriorityPickerTitle;

  /// No description provided for @tasksQuickFilterClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get tasksQuickFilterClear;

  /// No description provided for @tasksQuickFilterLabelsActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Active label filters'**
  String get tasksQuickFilterLabelsActiveTitle;

  /// No description provided for @tasksQuickFilterUnassignedLabel.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get tasksQuickFilterUnassignedLabel;

  /// No description provided for @tasksSavedFilterDeleteConfirmTooltip.
  ///
  /// In en, this message translates to:
  /// **'Tap again to delete'**
  String get tasksSavedFilterDeleteConfirmTooltip;

  /// No description provided for @tasksSavedFilterDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete saved filter'**
  String get tasksSavedFilterDeleteTooltip;

  /// No description provided for @tasksSavedFilterDragHandleSemantics.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get tasksSavedFilterDragHandleSemantics;

  /// No description provided for @tasksSavedFilterRenameSemantics.
  ///
  /// In en, this message translates to:
  /// **'Rename saved filter'**
  String get tasksSavedFilterRenameSemantics;

  /// No description provided for @tasksSavedFiltersSaveButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get tasksSavedFiltersSaveButtonLabel;

  /// No description provided for @tasksSavedFiltersSavePopupCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get tasksSavedFiltersSavePopupCancel;

  /// No description provided for @tasksSavedFiltersSavePopupHelper.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 filter active. Saved to sidebar under Tasks.} other{{count} filters active. Saved to sidebar under Tasks.}}'**
  String tasksSavedFiltersSavePopupHelper(int count);

  /// No description provided for @tasksSavedFiltersSavePopupHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Blocked or on hold'**
  String get tasksSavedFiltersSavePopupHint;

  /// No description provided for @tasksSavedFiltersSavePopupSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get tasksSavedFiltersSavePopupSave;

  /// No description provided for @tasksSavedFiltersSavePopupTitle.
  ///
  /// In en, this message translates to:
  /// **'Name this filter'**
  String get tasksSavedFiltersSavePopupTitle;

  /// No description provided for @tasksSavedFilterToastDeleted.
  ///
  /// In en, this message translates to:
  /// **'Filter deleted'**
  String get tasksSavedFilterToastDeleted;

  /// No description provided for @tasksSavedFilterToastSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved \'{name}\''**
  String tasksSavedFilterToastSaved(String name);

  /// No description provided for @tasksSavedFilterToastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated \'{name}\''**
  String tasksSavedFilterToastUpdated(String name);

  /// No description provided for @tasksSearchModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Search mode'**
  String get tasksSearchModeLabel;

  /// No description provided for @tasksShowCreationDate.
  ///
  /// In en, this message translates to:
  /// **'Show creation date on cards'**
  String get tasksShowCreationDate;

  /// No description provided for @tasksShowDueDate.
  ///
  /// In en, this message translates to:
  /// **'Show due date on cards'**
  String get tasksShowDueDate;

  /// No description provided for @tasksSortByCreationDate.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get tasksSortByCreationDate;

  /// No description provided for @tasksSortByDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due Date'**
  String get tasksSortByDueDate;

  /// No description provided for @tasksSortByLabel.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get tasksSortByLabel;

  /// No description provided for @tasksSortByPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get tasksSortByPriority;

  /// No description provided for @taskStatusAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get taskStatusAll;

  /// No description provided for @taskStatusBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get taskStatusBlocked;

  /// No description provided for @taskStatusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get taskStatusDone;

  /// No description provided for @taskStatusGroomed.
  ///
  /// In en, this message translates to:
  /// **'Groomed'**
  String get taskStatusGroomed;

  /// No description provided for @taskStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get taskStatusInProgress;

  /// No description provided for @taskStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status:'**
  String get taskStatusLabel;

  /// No description provided for @taskStatusOnHold.
  ///
  /// In en, this message translates to:
  /// **'On Hold'**
  String get taskStatusOnHold;

  /// No description provided for @taskStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get taskStatusOpen;

  /// No description provided for @taskStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get taskStatusRejected;

  /// No description provided for @taskTitleEmpty.
  ///
  /// In en, this message translates to:
  /// **'No title'**
  String get taskTitleEmpty;

  /// No description provided for @taskUntitled.
  ///
  /// In en, this message translates to:
  /// **'(untitled)'**
  String get taskUntitled;

  /// No description provided for @thinkingDisclosureCopied.
  ///
  /// In en, this message translates to:
  /// **'Reasoning copied'**
  String get thinkingDisclosureCopied;

  /// No description provided for @thinkingDisclosureCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy reasoning'**
  String get thinkingDisclosureCopy;

  /// No description provided for @thinkingDisclosureHide.
  ///
  /// In en, this message translates to:
  /// **'Hide reasoning'**
  String get thinkingDisclosureHide;

  /// No description provided for @thinkingDisclosureShow.
  ///
  /// In en, this message translates to:
  /// **'Show reasoning'**
  String get thinkingDisclosureShow;

  /// No description provided for @thinkingDisclosureStateCollapsed.
  ///
  /// In en, this message translates to:
  /// **'collapsed'**
  String get thinkingDisclosureStateCollapsed;

  /// No description provided for @thinkingDisclosureStateExpanded.
  ///
  /// In en, this message translates to:
  /// **'expanded'**
  String get thinkingDisclosureStateExpanded;

  /// No description provided for @timeEntryItemEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get timeEntryItemEnd;

  /// No description provided for @timeEntryItemRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get timeEntryItemRunning;

  /// No description provided for @timeEntryItemStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get timeEntryItemStart;

  /// No description provided for @unlinkButton.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get unlinkButton;

  /// No description provided for @unlinkTaskConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to unlink this task?'**
  String get unlinkTaskConfirm;

  /// No description provided for @unlinkTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlink Task'**
  String get unlinkTaskTitle;

  /// No description provided for @vectorSearchTiming.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{elapsed}ms, {count} result} other{{elapsed}ms, {count} results}}'**
  String vectorSearchTiming(int elapsed, int count);

  /// No description provided for @viewMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get viewMenuTitle;

  /// No description provided for @viewMenuZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom In'**
  String get viewMenuZoomIn;

  /// No description provided for @viewMenuZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom Out'**
  String get viewMenuZoomOut;

  /// No description provided for @viewMenuZoomReset.
  ///
  /// In en, this message translates to:
  /// **'Actual Size'**
  String get viewMenuZoomReset;

  /// No description provided for @whatsNewDoneButton.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get whatsNewDoneButton;

  /// No description provided for @whatsNewSkipButton.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get whatsNewSkipButton;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'cs',
    'de',
    'en',
    'es',
    'fr',
    'ro',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'en':
      {
        switch (locale.countryCode) {
          case 'GB':
            return AppLocalizationsEnGb();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'cs':
      return AppLocalizationsCs();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ro':
      return AppLocalizationsRo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

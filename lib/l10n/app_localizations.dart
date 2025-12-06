import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

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
    Locale('de'),
    Locale('en', 'GB'),
    Locale('es'),
    Locale('fr'),
    Locale('ro')
  ];

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

  /// No description provided for @addActionAddPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photo(s)'**
  String get addActionAddPhotos;

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

  /// No description provided for @addActionImportImage.
  ///
  /// In en, this message translates to:
  /// **'Import Image'**
  String get addActionImportImage;

  /// No description provided for @addActionAddTimeRecording.
  ///
  /// In en, this message translates to:
  /// **'Timer Entry'**
  String get addActionAddTimeRecording;

  /// No description provided for @addAudioTitle.
  ///
  /// In en, this message translates to:
  /// **'Audio Recording'**
  String get addAudioTitle;

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

  /// No description provided for @addSurveyTitle.
  ///
  /// In en, this message translates to:
  /// **'Fill Survey'**
  String get addSurveyTitle;

  /// No description provided for @aiAssistantActionItemSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Action Item Suggestions'**
  String get aiAssistantActionItemSuggestions;

  /// No description provided for @aiAssistantAnalyzeImage.
  ///
  /// In en, this message translates to:
  /// **'Analyze image'**
  String get aiAssistantAnalyzeImage;

  /// No description provided for @aiAssistantSummarizeTask.
  ///
  /// In en, this message translates to:
  /// **'Summarize task'**
  String get aiAssistantSummarizeTask;

  /// No description provided for @aiAssistantThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking...'**
  String get aiAssistantThinking;

  /// No description provided for @aiAssistantTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get aiAssistantTitle;

  /// No description provided for @aiAssistantTranscribeAudio.
  ///
  /// In en, this message translates to:
  /// **'Transcribe audio'**
  String get aiAssistantTranscribeAudio;

  /// No description provided for @aiConfigApiKeyEmptyError.
  ///
  /// In en, this message translates to:
  /// **'API key cannot be empty'**
  String get aiConfigApiKeyEmptyError;

  /// No description provided for @aiConfigApiKeyFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get aiConfigApiKeyFieldLabel;

  /// No description provided for @aiConfigAssociatedModelsRemoved.
  ///
  /// In en, this message translates to:
  /// **'{count} associated model{count, plural, =1{} other{s}} removed'**
  String aiConfigAssociatedModelsRemoved(int count);

  /// No description provided for @aiConfigBaseUrlFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get aiConfigBaseUrlFieldLabel;

  /// No description provided for @aiConfigCommentFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Comment (Optional)'**
  String get aiConfigCommentFieldLabel;

  /// No description provided for @aiConfigCreateButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Create Prompt'**
  String get aiConfigCreateButtonLabel;

  /// No description provided for @aiConfigDescriptionFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (Optional)'**
  String get aiConfigDescriptionFieldLabel;

  /// No description provided for @aiConfigFailedToLoadModels.
  ///
  /// In en, this message translates to:
  /// **'Failed to load models: {error}'**
  String aiConfigFailedToLoadModels(String error);

  /// No description provided for @aiConfigFailedToLoadModelsGeneric.
  ///
  /// In en, this message translates to:
  /// **'Failed to load models. Please try again.'**
  String get aiConfigFailedToLoadModelsGeneric;

  /// No description provided for @loggingFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load logs. Please try again.'**
  String get loggingFailedToLoad;

  /// No description provided for @loggingSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed. Please try again.'**
  String get loggingSearchFailed;

  /// No description provided for @loggingFailedToLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Failed to load more results. Please try again.'**
  String get loggingFailedToLoadMore;

  /// No description provided for @aiConfigFailedToSaveMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to save configuration. Please try again.'**
  String get aiConfigFailedToSaveMessage;

  /// No description provided for @aiConfigInputDataTypesTitle.
  ///
  /// In en, this message translates to:
  /// **'Required Input Data Types'**
  String get aiConfigInputDataTypesTitle;

  /// No description provided for @aiConfigInputModalitiesFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Input Modalities'**
  String get aiConfigInputModalitiesFieldLabel;

  /// No description provided for @aiConfigInputModalitiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Input Modalities'**
  String get aiConfigInputModalitiesTitle;

  /// No description provided for @aiConfigInvalidUrlError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid URL'**
  String get aiConfigInvalidUrlError;

  /// No description provided for @aiConfigListCascadeDeleteWarning.
  ///
  /// In en, this message translates to:
  /// **'This will also delete all models associated with this provider.'**
  String get aiConfigListCascadeDeleteWarning;

  /// No description provided for @aiConfigListDeleteConfirmCancel.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get aiConfigListDeleteConfirmCancel;

  /// No description provided for @aiConfigListDeleteConfirmDelete.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get aiConfigListDeleteConfirmDelete;

  /// No description provided for @aiConfigListDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{configName}\"?'**
  String aiConfigListDeleteConfirmMessage(String configName);

  /// No description provided for @aiConfigListDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Deletion'**
  String get aiConfigListDeleteConfirmTitle;

  /// No description provided for @aiConfigListEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No configurations found. Add one to get started.'**
  String get aiConfigListEmptyState;

  /// No description provided for @aiConfigListErrorDeleting.
  ///
  /// In en, this message translates to:
  /// **'Error deleting {configName}: {error}'**
  String aiConfigListErrorDeleting(String configName, String error);

  /// No description provided for @aiConfigListErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading configurations'**
  String get aiConfigListErrorLoading;

  /// No description provided for @aiConfigListItemDeleted.
  ///
  /// In en, this message translates to:
  /// **'{configName} deleted'**
  String aiConfigListItemDeleted(String configName);

  /// No description provided for @aiConfigListUndoDelete.
  ///
  /// In en, this message translates to:
  /// **'UNDO'**
  String get aiConfigListUndoDelete;

  /// No description provided for @aiConfigManageModelsButton.
  ///
  /// In en, this message translates to:
  /// **'Manage Models'**
  String get aiConfigManageModelsButton;

  /// No description provided for @aiConfigModelRemovedMessage.
  ///
  /// In en, this message translates to:
  /// **'{modelName} removed from prompt'**
  String aiConfigModelRemovedMessage(String modelName);

  /// No description provided for @aiConfigModelsTitle.
  ///
  /// In en, this message translates to:
  /// **'Available Models'**
  String get aiConfigModelsTitle;

  /// No description provided for @aiConfigNameFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get aiConfigNameFieldLabel;

  /// No description provided for @aiConfigNameTooShortError.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 3 characters'**
  String get aiConfigNameTooShortError;

  /// No description provided for @aiConfigNoModelsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No AI models are configured yet. Please add one in settings.'**
  String get aiConfigNoModelsAvailable;

  /// No description provided for @aiConfigNoModelsSelected.
  ///
  /// In en, this message translates to:
  /// **'No models selected. At least one model is required.'**
  String get aiConfigNoModelsSelected;

  /// No description provided for @aiConfigNoProvidersAvailable.
  ///
  /// In en, this message translates to:
  /// **'No API providers available. Please add an API provider first.'**
  String get aiConfigNoProvidersAvailable;

  /// No description provided for @aiConfigNoSuitableModelsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No models meet the requirements for this prompt. Please configure models that support the required capabilities.'**
  String get aiConfigNoSuitableModelsAvailable;

  /// No description provided for @aiConfigOutputModalitiesFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Output Modalities'**
  String get aiConfigOutputModalitiesFieldLabel;

  /// No description provided for @aiConfigOutputModalitiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Output Modalities'**
  String get aiConfigOutputModalitiesTitle;

  /// No description provided for @aiConfigProviderDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Provider deleted successfully'**
  String get aiConfigProviderDeletedSuccessfully;

  /// No description provided for @aiConfigProviderFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Inference Provider'**
  String get aiConfigProviderFieldLabel;

  /// No description provided for @aiConfigProviderModelIdFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Provider Model ID'**
  String get aiConfigProviderModelIdFieldLabel;

  /// No description provided for @aiConfigProviderModelIdTooShortError.
  ///
  /// In en, this message translates to:
  /// **'ProviderModelId must be at least 3 characters'**
  String get aiConfigProviderModelIdTooShortError;

  /// No description provided for @aiConfigProviderTypeFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Provider Type'**
  String get aiConfigProviderTypeFieldLabel;

  /// No description provided for @aiConfigReasoningCapabilityDescription.
  ///
  /// In en, this message translates to:
  /// **'Model can perform step-by-step reasoning'**
  String get aiConfigReasoningCapabilityDescription;

  /// No description provided for @aiConfigReasoningCapabilityFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Reasoning Capability'**
  String get aiConfigReasoningCapabilityFieldLabel;

  /// No description provided for @aiConfigRequiredInputDataFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Required Input Data'**
  String get aiConfigRequiredInputDataFieldLabel;

  /// No description provided for @aiConfigResponseTypeFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'AI Response Type'**
  String get aiConfigResponseTypeFieldLabel;

  /// No description provided for @aiConfigResponseTypeNotSelectedError.
  ///
  /// In en, this message translates to:
  /// **'Please select a response type'**
  String get aiConfigResponseTypeNotSelectedError;

  /// No description provided for @aiConfigResponseTypeSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Select response type'**
  String get aiConfigResponseTypeSelectHint;

  /// No description provided for @aiConfigSelectInputDataTypesPrompt.
  ///
  /// In en, this message translates to:
  /// **'Select required data types...'**
  String get aiConfigSelectInputDataTypesPrompt;

  /// No description provided for @aiConfigSelectModalitiesPrompt.
  ///
  /// In en, this message translates to:
  /// **'Select modalities'**
  String get aiConfigSelectModalitiesPrompt;

  /// No description provided for @aiConfigSelectProviderModalTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Inference Provider'**
  String get aiConfigSelectProviderModalTitle;

  /// No description provided for @aiConfigSelectProviderNotFound.
  ///
  /// In en, this message translates to:
  /// **'Inference Provider not found'**
  String get aiConfigSelectProviderNotFound;

  /// No description provided for @aiConfigSelectProviderTypeModalTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Provider Type'**
  String get aiConfigSelectProviderTypeModalTitle;

  /// No description provided for @aiConfigSelectResponseTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Select AI Response Type'**
  String get aiConfigSelectResponseTypeTitle;

  /// No description provided for @aiConfigSystemMessageFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'System Message'**
  String get aiConfigSystemMessageFieldLabel;

  /// No description provided for @aiConfigUpdateButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Update Prompt'**
  String get aiConfigUpdateButtonLabel;

  /// No description provided for @aiConfigUseReasoningDescription.
  ///
  /// In en, this message translates to:
  /// **'If enabled, the model will use its reasoning capabilities for this prompt.'**
  String get aiConfigUseReasoningDescription;

  /// No description provided for @aiConfigUseReasoningFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Use Reasoning'**
  String get aiConfigUseReasoningFieldLabel;

  /// No description provided for @aiConfigUserMessageEmptyError.
  ///
  /// In en, this message translates to:
  /// **'User message cannot be empty'**
  String get aiConfigUserMessageEmptyError;

  /// No description provided for @aiConfigUserMessageFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'User Message'**
  String get aiConfigUserMessageFieldLabel;

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

  /// No description provided for @aiInferenceErrorAuthenticationMessage.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Please check your API key and ensure it is valid.'**
  String get aiInferenceErrorAuthenticationMessage;

  /// No description provided for @aiInferenceErrorAuthenticationTitle.
  ///
  /// In en, this message translates to:
  /// **'Authentication Failed'**
  String get aiInferenceErrorAuthenticationTitle;

  /// No description provided for @aiInferenceErrorConnectionFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Unable to connect to the AI service. Please check your internet connection and ensure the service is accessible.'**
  String get aiInferenceErrorConnectionFailedMessage;

  /// No description provided for @aiInferenceErrorConnectionFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection Failed'**
  String get aiInferenceErrorConnectionFailedTitle;

  /// No description provided for @aiInferenceErrorInvalidRequestMessage.
  ///
  /// In en, this message translates to:
  /// **'The request was invalid. Please check your configuration and try again.'**
  String get aiInferenceErrorInvalidRequestMessage;

  /// No description provided for @aiInferenceErrorInvalidRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Invalid Request'**
  String get aiInferenceErrorInvalidRequestTitle;

  /// No description provided for @aiInferenceErrorRateLimitMessage.
  ///
  /// In en, this message translates to:
  /// **'You have exceeded the rate limit. Please wait a moment before trying again.'**
  String get aiInferenceErrorRateLimitMessage;

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

  /// No description provided for @aiInferenceErrorServerMessage.
  ///
  /// In en, this message translates to:
  /// **'The AI service encountered an error. Please try again later.'**
  String get aiInferenceErrorServerMessage;

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

  /// No description provided for @aiInferenceErrorViewLogButton.
  ///
  /// In en, this message translates to:
  /// **'View Log'**
  String get aiInferenceErrorViewLogButton;

  /// No description provided for @aiInferenceErrorTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'The request took too long to complete. Please try again or check if the service is responding.'**
  String get aiInferenceErrorTimeoutMessage;

  /// No description provided for @aiInferenceErrorTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Request Timed Out'**
  String get aiInferenceErrorTimeoutTitle;

  /// No description provided for @aiInferenceErrorUnknownMessage.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try again.'**
  String get aiInferenceErrorUnknownMessage;

  /// No description provided for @aiInferenceErrorUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get aiInferenceErrorUnknownTitle;

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

  /// No description provided for @aiProviderGemma3nDescription.
  ///
  /// In en, this message translates to:
  /// **'Local Gemma 3n model with audio transcription capabilities'**
  String get aiProviderGemma3nDescription;

  /// No description provided for @aiProviderGemma3nName.
  ///
  /// In en, this message translates to:
  /// **'Gemma 3n (local)'**
  String get aiProviderGemma3nName;

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

  /// No description provided for @aiResponseTypeActionItemSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Action Item Suggestions'**
  String get aiResponseTypeActionItemSuggestions;

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

  /// No description provided for @aiResponseTypeTaskSummary.
  ///
  /// In en, this message translates to:
  /// **'Task Summary'**
  String get aiResponseTypeTaskSummary;

  /// No description provided for @aiSettingsAddModelButton.
  ///
  /// In en, this message translates to:
  /// **'Add Model'**
  String get aiSettingsAddModelButton;

  /// No description provided for @aiSettingsAddPromptButton.
  ///
  /// In en, this message translates to:
  /// **'Add Prompt'**
  String get aiSettingsAddPromptButton;

  /// No description provided for @aiSettingsAddProviderButton.
  ///
  /// In en, this message translates to:
  /// **'Add Provider'**
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

  /// No description provided for @aiSettingsNoPromptsConfigured.
  ///
  /// In en, this message translates to:
  /// **'No AI prompts configured'**
  String get aiSettingsNoPromptsConfigured;

  /// No description provided for @aiSettingsNoProvidersConfigured.
  ///
  /// In en, this message translates to:
  /// **'No AI providers configured'**
  String get aiSettingsNoProvidersConfigured;

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

  /// No description provided for @aiSettingsTabModels.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get aiSettingsTabModels;

  /// No description provided for @aiSettingsTabPrompts.
  ///
  /// In en, this message translates to:
  /// **'Prompts'**
  String get aiSettingsTabPrompts;

  /// No description provided for @aiSettingsTabProviders.
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get aiSettingsTabProviders;

  /// No description provided for @aiTaskSummaryRunning.
  ///
  /// In en, this message translates to:
  /// **'Thinking about summarizing task...'**
  String get aiTaskSummaryRunning;

  /// No description provided for @aiTaskSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Task Summary'**
  String get aiTaskSummaryTitle;

  /// No description provided for @aiTaskSummaryScheduled.
  ///
  /// In en, this message translates to:
  /// **'Summary in {time}'**
  String aiTaskSummaryScheduled(String time);

  /// No description provided for @aiTaskSummaryCancelScheduled.
  ///
  /// In en, this message translates to:
  /// **'Cancel scheduled summary'**
  String get aiTaskSummaryCancelScheduled;

  /// No description provided for @aiTaskSummaryTriggerNow.
  ///
  /// In en, this message translates to:
  /// **'Generate summary now'**
  String get aiTaskSummaryTriggerNow;

  /// No description provided for @apiKeyAddPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Provider'**
  String get apiKeyAddPageTitle;

  /// No description provided for @apiKeyEditLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load API key configuration'**
  String get apiKeyEditLoadError;

  /// No description provided for @apiKeyEditPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Provider'**
  String get apiKeyEditPageTitle;

  /// No description provided for @apiKeyFormCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get apiKeyFormCreateButton;

  /// No description provided for @apiKeyFormUpdateButton.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get apiKeyFormUpdateButton;

  /// No description provided for @apiKeysSettingsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Inference Providers'**
  String get apiKeysSettingsPageTitle;

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @categoryDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'YES, DELETE THIS CATEGORY'**
  String get categoryDeleteConfirm;

  /// No description provided for @categoryDeleteQuestion.
  ///
  /// In en, this message translates to:
  /// **'Do you want to delete this category?'**
  String get categoryDeleteQuestion;

  /// No description provided for @categorySearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search categories...'**
  String get categorySearchPlaceholder;

  /// No description provided for @checklistAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add a new item'**
  String get checklistAddItem;

  /// No description provided for @checklistDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete checklist?'**
  String get checklistDelete;

  /// No description provided for @checklistItemDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete checklist item?'**
  String get checklistItemDelete;

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

  /// No description provided for @checklistItemDeleteWarning.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get checklistItemDeleteWarning;

  /// No description provided for @checklistItemDrag.
  ///
  /// In en, this message translates to:
  /// **'Drag suggestions into checklist'**
  String get checklistItemDrag;

  /// No description provided for @checklistNoSuggestionsTitle.
  ///
  /// In en, this message translates to:
  /// **'No suggested Action Items'**
  String get checklistNoSuggestionsTitle;

  /// No description provided for @checklistSuggestionsOutdated.
  ///
  /// In en, this message translates to:
  /// **'Outdated'**
  String get checklistSuggestionsOutdated;

  /// No description provided for @checklistSuggestionsRunning.
  ///
  /// In en, this message translates to:
  /// **'Thinking about untracked suggestions...'**
  String get checklistSuggestionsRunning;

  /// No description provided for @checklistSuggestionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Suggested Action Items'**
  String get checklistSuggestionsTitle;

  /// No description provided for @checklistExportAsMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Export checklist as Markdown'**
  String get checklistExportAsMarkdown;

  /// No description provided for @checklistMarkdownCopied.
  ///
  /// In en, this message translates to:
  /// **'Checklist copied as Markdown'**
  String get checklistMarkdownCopied;

  /// No description provided for @checklistShareHint.
  ///
  /// In en, this message translates to:
  /// **'Long press to share'**
  String get checklistShareHint;

  /// No description provided for @checklistNothingToExport.
  ///
  /// In en, this message translates to:
  /// **'No items to export'**
  String get checklistNothingToExport;

  /// No description provided for @checklistExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get checklistExportFailed;

  /// No description provided for @checklistsTitle.
  ///
  /// In en, this message translates to:
  /// **'Checklists'**
  String get checklistsTitle;

  /// No description provided for @checklistsReorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get checklistsReorder;

  /// No description provided for @settingsResetHintsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset In‑App Hints'**
  String get settingsResetHintsTitle;

  /// No description provided for @settingsResetHintsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clear one‑time tips and onboarding hints'**
  String get settingsResetHintsSubtitle;

  /// No description provided for @settingsResetHintsConfirmQuestion.
  ///
  /// In en, this message translates to:
  /// **'Reset in‑app hints shown across the app?'**
  String get settingsResetHintsConfirmQuestion;

  /// No description provided for @settingsResetHintsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get settingsResetHintsConfirm;

  /// No description provided for @settingsResetHintsResult.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Reset zero hints} one{Reset one hint} other{Reset {count} hints}}'**
  String settingsResetHintsResult(int count);

  /// No description provided for @colorLabel.
  ///
  /// In en, this message translates to:
  /// **'Color:'**
  String get colorLabel;

  /// No description provided for @colorPickerError.
  ///
  /// In en, this message translates to:
  /// **'Invalid Hex color'**
  String get colorPickerError;

  /// No description provided for @colorPickerHint.
  ///
  /// In en, this message translates to:
  /// **'Enter Hex color or pick'**
  String get colorPickerHint;

  /// No description provided for @completeHabitFailButton.
  ///
  /// In en, this message translates to:
  /// **'Fail'**
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

  /// No description provided for @configFlagAutoTranscribeDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatically transcribe audio recordings in your entries. This requires an internet connection.'**
  String get configFlagAutoTranscribeDescription;

  /// No description provided for @configFlagEnableAutoTaskTldrDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatically generate summaries for your tasks to help you quickly understand their status.'**
  String get configFlagEnableAutoTaskTldrDescription;

  /// No description provided for @configFlagEnableCalendarPageDescription.
  ///
  /// In en, this message translates to:
  /// **'Show the Calendar page in the main navigation. View and manage your entries in a calendar view.'**
  String get configFlagEnableCalendarPageDescription;

  /// No description provided for @configFlagEnableDashboardsPageDescription.
  ///
  /// In en, this message translates to:
  /// **'Show the Dashboards page in the main navigation. View your data and insights in customizable dashboards.'**
  String get configFlagEnableDashboardsPageDescription;

  /// No description provided for @configFlagEnableEventsDescription.
  ///
  /// In en, this message translates to:
  /// **'Show the Events feature to create, track, and manage events in your journal.'**
  String get configFlagEnableEventsDescription;

  /// No description provided for @configFlagEnableHabitsPageDescription.
  ///
  /// In en, this message translates to:
  /// **'Show the Habits page in the main navigation. Track and manage your daily habits here.'**
  String get configFlagEnableHabitsPageDescription;

  /// No description provided for @configFlagEnableLoggingDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable detailed logging for debugging purposes. This may impact performance.'**
  String get configFlagEnableLoggingDescription;

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

  /// No description provided for @configFlagEnableLogging.
  ///
  /// In en, this message translates to:
  /// **'Enable logging'**
  String get configFlagEnableLogging;

  /// No description provided for @configFlagEnableMatrix.
  ///
  /// In en, this message translates to:
  /// **'Enable Matrix sync'**
  String get configFlagEnableMatrix;

  /// No description provided for @configFlagEnableHabitsPage.
  ///
  /// In en, this message translates to:
  /// **'Enable Habits page'**
  String get configFlagEnableHabitsPage;

  /// No description provided for @configFlagEnableDashboardsPage.
  ///
  /// In en, this message translates to:
  /// **'Enable Dashboards page'**
  String get configFlagEnableDashboardsPage;

  /// No description provided for @configFlagEnableCalendarPage.
  ///
  /// In en, this message translates to:
  /// **'Enable Calendar page'**
  String get configFlagEnableCalendarPage;

  /// No description provided for @configFlagEnableEvents.
  ///
  /// In en, this message translates to:
  /// **'Enable Events'**
  String get configFlagEnableEvents;

  /// No description provided for @configFlagUseCloudInferenceDescription.
  ///
  /// In en, this message translates to:
  /// **'Use cloud-based AI services for enhanced features. This requires an internet connection.'**
  String get configFlagUseCloudInferenceDescription;

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

  /// No description provided for @conflictsResolveLocalVersion.
  ///
  /// In en, this message translates to:
  /// **'Resolve with local version'**
  String get conflictsResolveLocalVersion;

  /// No description provided for @conflictsResolveRemoteVersion.
  ///
  /// In en, this message translates to:
  /// **'Resolve with remote version'**
  String get conflictsResolveRemoteVersion;

  /// No description provided for @conflictsCopyTextFromSync.
  ///
  /// In en, this message translates to:
  /// **'Copy Text from Sync'**
  String get conflictsCopyTextFromSync;

  /// No description provided for @createCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Category:'**
  String get createCategoryTitle;

  /// No description provided for @categoryCreationError.
  ///
  /// In en, this message translates to:
  /// **'Failed to create category. Please try again.'**
  String get categoryCreationError;

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

  /// No description provided for @customColor.
  ///
  /// In en, this message translates to:
  /// **'Custom Color'**
  String get customColor;

  /// No description provided for @dashboardActiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Active:'**
  String get dashboardActiveLabel;

  /// No description provided for @dashboardAddChartsTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Charts:'**
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

  /// No description provided for @dashboardAggregationLabel.
  ///
  /// In en, this message translates to:
  /// **'Aggregation Type:'**
  String get dashboardAggregationLabel;

  /// No description provided for @dashboardCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category:'**
  String get dashboardCategoryLabel;

  /// No description provided for @dashboardCopyHint.
  ///
  /// In en, this message translates to:
  /// **'Save & Copy dashboard config'**
  String get dashboardCopyHint;

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
  /// **'Description (optional):'**
  String get dashboardDescriptionLabel;

  /// No description provided for @dashboardNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Dashboard name:'**
  String get dashboardNameLabel;

  /// No description provided for @dashboardNotFound.
  ///
  /// In en, this message translates to:
  /// **'Dashboard not found'**
  String get dashboardNotFound;

  /// No description provided for @dashboardPrivateLabel.
  ///
  /// In en, this message translates to:
  /// **'Private:'**
  String get dashboardPrivateLabel;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

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

  /// No description provided for @editorPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter notes...'**
  String get editorPlaceholder;

  /// No description provided for @enhancedPromptFormAdditionalDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Additional Details'**
  String get enhancedPromptFormAdditionalDetailsTitle;

  /// No description provided for @enhancedPromptFormAiResponseTypeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Format of the expected response'**
  String get enhancedPromptFormAiResponseTypeSubtitle;

  /// No description provided for @enhancedPromptFormBasicConfigurationTitle.
  ///
  /// In en, this message translates to:
  /// **'Basic Configuration'**
  String get enhancedPromptFormBasicConfigurationTitle;

  /// No description provided for @enhancedPromptFormConfigurationOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Configuration Options'**
  String get enhancedPromptFormConfigurationOptionsTitle;

  /// No description provided for @enhancedPromptFormDescription.
  ///
  /// In en, this message translates to:
  /// **'Create custom prompts that can be used with your AI models to generate specific types of responses'**
  String get enhancedPromptFormDescription;

  /// No description provided for @enhancedPromptFormDescriptionHelperText.
  ///
  /// In en, this message translates to:
  /// **'Optional notes about this prompt\'s purpose and usage'**
  String get enhancedPromptFormDescriptionHelperText;

  /// No description provided for @enhancedPromptFormDisplayNameHelperText.
  ///
  /// In en, this message translates to:
  /// **'A descriptive name for this prompt template'**
  String get enhancedPromptFormDisplayNameHelperText;

  /// No description provided for @enhancedPromptFormPreconfiguredPromptDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose from ready-made prompt templates'**
  String get enhancedPromptFormPreconfiguredPromptDescription;

  /// No description provided for @enhancedPromptFormPromptConfigurationTitle.
  ///
  /// In en, this message translates to:
  /// **'Prompt Configuration'**
  String get enhancedPromptFormPromptConfigurationTitle;

  /// No description provided for @enhancedPromptFormQuickStartDescription.
  ///
  /// In en, this message translates to:
  /// **'Start with a pre-built template to save time'**
  String get enhancedPromptFormQuickStartDescription;

  /// No description provided for @enhancedPromptFormQuickStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Start'**
  String get enhancedPromptFormQuickStartTitle;

  /// No description provided for @enhancedPromptFormRequiredInputDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Type of data this prompt expects'**
  String get enhancedPromptFormRequiredInputDataSubtitle;

  /// No description provided for @enhancedPromptFormSystemMessageHelperText.
  ///
  /// In en, this message translates to:
  /// **'Instructions that define the AI\'s behavior and response style'**
  String get enhancedPromptFormSystemMessageHelperText;

  /// No description provided for @enhancedPromptFormUserMessageHelperText.
  ///
  /// In en, this message translates to:
  /// **'The main prompt text.'**
  String get enhancedPromptFormUserMessageHelperText;

  /// No description provided for @entryActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get entryActions;

  /// No description provided for @eventNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Event:'**
  String get eventNameLabel;

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

  /// No description provided for @habitActiveFromLabel.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get habitActiveFromLabel;

  /// No description provided for @habitArchivedLabel.
  ///
  /// In en, this message translates to:
  /// **'Archived:'**
  String get habitArchivedLabel;

  /// No description provided for @habitCategoryHint.
  ///
  /// In en, this message translates to:
  /// **'Select Category...'**
  String get habitCategoryHint;

  /// No description provided for @habitCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category:'**
  String get habitCategoryLabel;

  /// No description provided for @habitDashboardHint.
  ///
  /// In en, this message translates to:
  /// **'Select Dashboard...'**
  String get habitDashboardHint;

  /// No description provided for @habitDashboardLabel.
  ///
  /// In en, this message translates to:
  /// **'Dashboard:'**
  String get habitDashboardLabel;

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

  /// No description provided for @habitPriorityLabel.
  ///
  /// In en, this message translates to:
  /// **'Priority:'**
  String get habitPriorityLabel;

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

  /// No description provided for @habitsCompletedHeader.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get habitsCompletedHeader;

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
  /// **'Duration:'**
  String get journalDurationLabel;

  /// No description provided for @journalFavoriteTooltip.
  ///
  /// In en, this message translates to:
  /// **'starred only'**
  String get journalFavoriteTooltip;

  /// No description provided for @journalFlaggedTooltip.
  ///
  /// In en, this message translates to:
  /// **'flagged only'**
  String get journalFlaggedTooltip;

  /// No description provided for @journalHideMapHint.
  ///
  /// In en, this message translates to:
  /// **'Hide map'**
  String get journalHideMapHint;

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

  /// No description provided for @journalLinkedEntriesAiLabel.
  ///
  /// In en, this message translates to:
  /// **'Show AI-generated entries:'**
  String get journalLinkedEntriesAiLabel;

  /// No description provided for @journalLinkedEntriesHiddenLabel.
  ///
  /// In en, this message translates to:
  /// **'Show hidden entries:'**
  String get journalLinkedEntriesHiddenLabel;

  /// No description provided for @journalLinkedEntriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Linked Entries'**
  String get journalLinkedEntriesLabel;

  /// No description provided for @journalLinkedFromLabel.
  ///
  /// In en, this message translates to:
  /// **'Linked from:'**
  String get journalLinkedFromLabel;

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

  /// No description provided for @journalShareAudioHint.
  ///
  /// In en, this message translates to:
  /// **'Share audio'**
  String get journalShareAudioHint;

  /// No description provided for @journalSharePhotoHint.
  ///
  /// In en, this message translates to:
  /// **'Share photo'**
  String get journalSharePhotoHint;

  /// No description provided for @journalShowMapHint.
  ///
  /// In en, this message translates to:
  /// **'Show map'**
  String get journalShowMapHint;

  /// No description provided for @journalTagPlusHint.
  ///
  /// In en, this message translates to:
  /// **'Manage entry tags'**
  String get journalTagPlusHint;

  /// No description provided for @journalTagsCopyHint.
  ///
  /// In en, this message translates to:
  /// **'Copy tags'**
  String get journalTagsCopyHint;

  /// No description provided for @journalTagsLabel.
  ///
  /// In en, this message translates to:
  /// **'Tags:'**
  String get journalTagsLabel;

  /// No description provided for @journalTagsPasteHint.
  ///
  /// In en, this message translates to:
  /// **'Paste tags'**
  String get journalTagsPasteHint;

  /// No description provided for @journalTagsRemoveHint.
  ///
  /// In en, this message translates to:
  /// **'Remove tag'**
  String get journalTagsRemoveHint;

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

  /// No description provided for @maintenanceDeleteLoggingDb.
  ///
  /// In en, this message translates to:
  /// **'Delete Logging Database'**
  String get maintenanceDeleteLoggingDb;

  /// No description provided for @maintenanceDeleteLoggingDbDescription.
  ///
  /// In en, this message translates to:
  /// **'Delete logging database'**
  String get maintenanceDeleteLoggingDbDescription;

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

  /// No description provided for @maintenanceRemoveActionItemSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Remove deprecated AI suggestions'**
  String get maintenanceRemoveActionItemSuggestions;

  /// No description provided for @maintenanceRemoveActionItemSuggestionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Remove old action item suggestions'**
  String get maintenanceRemoveActionItemSuggestionsDescription;

  /// No description provided for @maintenanceRemoveActionItemSuggestionsMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove all deprecated action item suggestions? This will permanently delete these entries.'**
  String get maintenanceRemoveActionItemSuggestionsMessage;

  /// No description provided for @maintenanceRemoveActionItemSuggestionsConfirm.
  ///
  /// In en, this message translates to:
  /// **'YES, REMOVE'**
  String get maintenanceRemoveActionItemSuggestionsConfirm;

  /// No description provided for @maintenanceReSync.
  ///
  /// In en, this message translates to:
  /// **'Re-sync messages'**
  String get maintenanceReSync;

  /// No description provided for @maintenanceReSyncDescription.
  ///
  /// In en, this message translates to:
  /// **'Re-sync messages from server'**
  String get maintenanceReSyncDescription;

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

  /// No description provided for @maintenancePopulateSequenceLog.
  ///
  /// In en, this message translates to:
  /// **'Populate sync sequence log'**
  String get maintenancePopulateSequenceLog;

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

  /// No description provided for @maintenancePopulateSequenceLogComplete.
  ///
  /// In en, this message translates to:
  /// **'{count} entries indexed'**
  String maintenancePopulateSequenceLogComplete(int count);

  /// No description provided for @maintenanceSyncDefinitions.
  ///
  /// In en, this message translates to:
  /// **'Sync tags, measurables, dashboards, habits, categories, AI settings'**
  String get maintenanceSyncDefinitions;

  /// No description provided for @maintenanceSyncDefinitionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Sync tags, measurables, dashboards, habits, categories, and AI settings'**
  String get maintenanceSyncDefinitionsDescription;

  /// No description provided for @backfillSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Backfill Sync'**
  String get backfillSettingsTitle;

  /// No description provided for @backfillSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage sync gap recovery'**
  String get backfillSettingsSubtitle;

  /// No description provided for @backfillSettingsInfo.
  ///
  /// In en, this message translates to:
  /// **'Automatic backfill requests missing entries from the last 24 hours. Use manual backfill for older entries.'**
  String get backfillSettingsInfo;

  /// No description provided for @backfillToggleTitle.
  ///
  /// In en, this message translates to:
  /// **'Automatic Backfill'**
  String get backfillToggleTitle;

  /// No description provided for @backfillToggleEnabledDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatically request missing sync entries'**
  String get backfillToggleEnabledDescription;

  /// No description provided for @backfillToggleDisabledDescription.
  ///
  /// In en, this message translates to:
  /// **'Backfill disabled - useful on metered networks'**
  String get backfillToggleDisabledDescription;

  /// No description provided for @backfillStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Statistics'**
  String get backfillStatsTitle;

  /// No description provided for @backfillStatsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh stats'**
  String get backfillStatsRefresh;

  /// No description provided for @backfillStatsNoData.
  ///
  /// In en, this message translates to:
  /// **'No sync data available'**
  String get backfillStatsNoData;

  /// No description provided for @backfillStatsTotalEntries.
  ///
  /// In en, this message translates to:
  /// **'Total entries'**
  String get backfillStatsTotalEntries;

  /// No description provided for @backfillStatsReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get backfillStatsReceived;

  /// No description provided for @backfillStatsMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get backfillStatsMissing;

  /// No description provided for @backfillStatsRequested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get backfillStatsRequested;

  /// No description provided for @backfillStatsBackfilled.
  ///
  /// In en, this message translates to:
  /// **'Backfilled'**
  String get backfillStatsBackfilled;

  /// No description provided for @backfillStatsDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get backfillStatsDeleted;

  /// No description provided for @backfillStatsHostsTitle.
  ///
  /// In en, this message translates to:
  /// **'{count} connected device{count, plural, =1{} other{s}}'**
  String backfillStatsHostsTitle(int count);

  /// No description provided for @backfillManualTitle.
  ///
  /// In en, this message translates to:
  /// **'Manual Backfill'**
  String get backfillManualTitle;

  /// No description provided for @backfillManualDescription.
  ///
  /// In en, this message translates to:
  /// **'Request all missing entries regardless of age. Use this to recover older sync gaps.'**
  String get backfillManualDescription;

  /// No description provided for @backfillManualTrigger.
  ///
  /// In en, this message translates to:
  /// **'Request Missing Entries'**
  String get backfillManualTrigger;

  /// No description provided for @backfillManualProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get backfillManualProcessing;

  /// No description provided for @backfillManualSuccess.
  ///
  /// In en, this message translates to:
  /// **'{count} entries requested'**
  String backfillManualSuccess(int count);

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

  /// No description provided for @modelEditLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load model configuration'**
  String get modelEditLoadError;

  /// No description provided for @modelEditPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Model'**
  String get modelEditPageTitle;

  /// No description provided for @modelManagementSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} model{count, plural, =1{} other{s}} selected'**
  String modelManagementSelectedCount(int count);

  /// No description provided for @modelsSettingsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Models'**
  String get modelsSettingsPageTitle;

  /// No description provided for @navTabTitleCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get navTabTitleCalendar;

  /// No description provided for @navTabTitleHabits.
  ///
  /// In en, this message translates to:
  /// **'Habits'**
  String get navTabTitleHabits;

  /// No description provided for @navTabTitleInsights.
  ///
  /// In en, this message translates to:
  /// **'Dashboards'**
  String get navTabTitleInsights;

  /// No description provided for @navTabTitleJournal.
  ///
  /// In en, this message translates to:
  /// **'Logbook'**
  String get navTabTitleJournal;

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

  /// No description provided for @outboxMonitorLabelAll.
  ///
  /// In en, this message translates to:
  /// **'all'**
  String get outboxMonitorLabelAll;

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

  /// No description provided for @outboxMonitorRetriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Retries'**
  String get outboxMonitorRetriesLabel;

  /// No description provided for @outboxMonitorRetries.
  ///
  /// In en, this message translates to:
  /// **'retries'**
  String get outboxMonitorRetries;

  /// No description provided for @outboxMonitorRetry.
  ///
  /// In en, this message translates to:
  /// **'retry'**
  String get outboxMonitorRetry;

  /// No description provided for @outboxMonitorSubjectLabel.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get outboxMonitorSubjectLabel;

  /// No description provided for @outboxMonitorAttachmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get outboxMonitorAttachmentLabel;

  /// No description provided for @outboxMonitorRetryConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Retry this sync item now?'**
  String get outboxMonitorRetryConfirmMessage;

  /// No description provided for @outboxMonitorRetryConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Retry Now'**
  String get outboxMonitorRetryConfirmLabel;

  /// No description provided for @outboxMonitorRetryQueued.
  ///
  /// In en, this message translates to:
  /// **'Retry scheduled'**
  String get outboxMonitorRetryQueued;

  /// No description provided for @outboxMonitorRetryFailed.
  ///
  /// In en, this message translates to:
  /// **'Retry failed. Please try again.'**
  String get outboxMonitorRetryFailed;

  /// No description provided for @outboxMonitorEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Outbox is clear'**
  String get outboxMonitorEmptyTitle;

  /// No description provided for @outboxMonitorEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'There are no sync items in this view.'**
  String get outboxMonitorEmptyDescription;

  /// No description provided for @outboxMonitorSwitchLabel.
  ///
  /// In en, this message translates to:
  /// **'enabled'**
  String get outboxMonitorSwitchLabel;

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

  /// No description provided for @syncPayloadJournalEntity.
  ///
  /// In en, this message translates to:
  /// **'Journal entry'**
  String get syncPayloadJournalEntity;

  /// No description provided for @syncPayloadEntityDefinition.
  ///
  /// In en, this message translates to:
  /// **'Entity definition'**
  String get syncPayloadEntityDefinition;

  /// No description provided for @syncPayloadTagEntity.
  ///
  /// In en, this message translates to:
  /// **'Tag entity'**
  String get syncPayloadTagEntity;

  /// No description provided for @syncPayloadEntryLink.
  ///
  /// In en, this message translates to:
  /// **'Entry link'**
  String get syncPayloadEntryLink;

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

  /// No description provided for @syncPayloadThemingSelection.
  ///
  /// In en, this message translates to:
  /// **'Theming selection'**
  String get syncPayloadThemingSelection;

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

  /// No description provided for @syncListCountSummary.
  ///
  /// In en, this message translates to:
  /// **'{label} · {itemCount, plural, =0{0 items} =1{1 item} other{{itemCount} items}}'**
  String syncListCountSummary(String label, int itemCount);

  /// No description provided for @conflictsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No conflicts detected'**
  String get conflictsEmptyTitle;

  /// No description provided for @conflictsEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Everything is in sync right now. Resolved items stay available in the other filter.'**
  String get conflictsEmptyDescription;

  /// No description provided for @conflictEntityLabel.
  ///
  /// In en, this message translates to:
  /// **'Entity'**
  String get conflictEntityLabel;

  /// No description provided for @conflictIdLabel.
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get conflictIdLabel;

  /// No description provided for @promptAddOrRemoveModelsButton.
  ///
  /// In en, this message translates to:
  /// **'Add or Remove Models'**
  String get promptAddOrRemoveModelsButton;

  /// No description provided for @promptAddPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Prompt'**
  String get promptAddPageTitle;

  /// No description provided for @promptAiResponseTypeDescription.
  ///
  /// In en, this message translates to:
  /// **'Format of the expected response'**
  String get promptAiResponseTypeDescription;

  /// No description provided for @promptAiResponseTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'AI Response Type'**
  String get promptAiResponseTypeLabel;

  /// No description provided for @promptBehaviorDescription.
  ///
  /// In en, this message translates to:
  /// **'Configure how the prompt processes and responds'**
  String get promptBehaviorDescription;

  /// No description provided for @promptBehaviorTitle.
  ///
  /// In en, this message translates to:
  /// **'Prompt Behavior'**
  String get promptBehaviorTitle;

  /// No description provided for @promptCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get promptCancelButton;

  /// No description provided for @promptContentDescription.
  ///
  /// In en, this message translates to:
  /// **'Define the system and user prompts'**
  String get promptContentDescription;

  /// No description provided for @promptContentTitle.
  ///
  /// In en, this message translates to:
  /// **'Prompt Content'**
  String get promptContentTitle;

  /// No description provided for @promptDefaultModelBadge.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get promptDefaultModelBadge;

  /// No description provided for @promptDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe this prompt'**
  String get promptDescriptionHint;

  /// No description provided for @promptDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get promptDescriptionLabel;

  /// No description provided for @promptDetailsDescription.
  ///
  /// In en, this message translates to:
  /// **'Basic information about this prompt'**
  String get promptDetailsDescription;

  /// No description provided for @promptDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Prompt Details'**
  String get promptDetailsTitle;

  /// No description provided for @promptDisplayNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a friendly name'**
  String get promptDisplayNameHint;

  /// No description provided for @promptDisplayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get promptDisplayNameLabel;

  /// No description provided for @promptEditLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load prompt'**
  String get promptEditLoadError;

  /// No description provided for @promptEditPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Prompt'**
  String get promptEditPageTitle;

  /// No description provided for @promptErrorLoadingModel.
  ///
  /// In en, this message translates to:
  /// **'Error loading model'**
  String get promptErrorLoadingModel;

  /// No description provided for @promptGoBackButton.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get promptGoBackButton;

  /// No description provided for @promptLoadingModel.
  ///
  /// In en, this message translates to:
  /// **'Loading model...'**
  String get promptLoadingModel;

  /// No description provided for @promptModelSelectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose compatible models for this prompt'**
  String get promptModelSelectionDescription;

  /// No description provided for @promptModelSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Model Selection'**
  String get promptModelSelectionTitle;

  /// No description provided for @promptNoModelsSelectedError.
  ///
  /// In en, this message translates to:
  /// **'No models selected. Select at least one model.'**
  String get promptNoModelsSelectedError;

  /// No description provided for @promptReasoningModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable for prompts requiring deep thinking'**
  String get promptReasoningModeDescription;

  /// No description provided for @promptReasoningModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Reasoning Mode'**
  String get promptReasoningModeLabel;

  /// No description provided for @promptRequiredInputDataDescription.
  ///
  /// In en, this message translates to:
  /// **'Type of data this prompt expects'**
  String get promptRequiredInputDataDescription;

  /// No description provided for @promptRequiredInputDataLabel.
  ///
  /// In en, this message translates to:
  /// **'Required Input Data'**
  String get promptRequiredInputDataLabel;

  /// No description provided for @promptSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save Prompt'**
  String get promptSaveButton;

  /// No description provided for @promptSelectInputTypeHint.
  ///
  /// In en, this message translates to:
  /// **'Select input type'**
  String get promptSelectInputTypeHint;

  /// No description provided for @promptSelectModelsButton.
  ///
  /// In en, this message translates to:
  /// **'Select Models'**
  String get promptSelectModelsButton;

  /// No description provided for @promptSelectResponseTypeHint.
  ///
  /// In en, this message translates to:
  /// **'Select response type'**
  String get promptSelectResponseTypeHint;

  /// No description provided for @promptSelectionModalTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Preconfigured Prompt'**
  String get promptSelectionModalTitle;

  /// No description provided for @promptSetDefaultButton.
  ///
  /// In en, this message translates to:
  /// **'Set Default'**
  String get promptSetDefaultButton;

  /// No description provided for @promptSettingsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Prompts'**
  String get promptSettingsPageTitle;

  /// No description provided for @promptSystemPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the system prompt...'**
  String get promptSystemPromptHint;

  /// No description provided for @promptSystemPromptLabel.
  ///
  /// In en, this message translates to:
  /// **'System Prompt'**
  String get promptSystemPromptLabel;

  /// No description provided for @promptTryAgainMessage.
  ///
  /// In en, this message translates to:
  /// **'Please try again or contact support'**
  String get promptTryAgainMessage;

  /// No description provided for @promptUsePreconfiguredButton.
  ///
  /// In en, this message translates to:
  /// **'Use Preconfigured Prompt'**
  String get promptUsePreconfiguredButton;

  /// No description provided for @promptUserPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the user prompt...'**
  String get promptUserPromptHint;

  /// No description provided for @promptUserPromptLabel.
  ///
  /// In en, this message translates to:
  /// **'User Prompt'**
  String get promptUserPromptLabel;

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

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get searchHint;

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

  /// No description provided for @settingsAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About Lotti'**
  String get settingsAboutTitle;

  /// No description provided for @settingsAboutAppTagline.
  ///
  /// In en, this message translates to:
  /// **'Your Personal Journal'**
  String get settingsAboutAppTagline;

  /// No description provided for @settingsAboutAppInformation.
  ///
  /// In en, this message translates to:
  /// **'App Information'**
  String get settingsAboutAppInformation;

  /// No description provided for @settingsAboutYourData.
  ///
  /// In en, this message translates to:
  /// **'Your Data'**
  String get settingsAboutYourData;

  /// No description provided for @settingsAboutCredits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get settingsAboutCredits;

  /// No description provided for @settingsAboutBuiltWithFlutter.
  ///
  /// In en, this message translates to:
  /// **'Built with Flutter and love for personal journaling.'**
  String get settingsAboutBuiltWithFlutter;

  /// No description provided for @settingsAboutThankYou.
  ///
  /// In en, this message translates to:
  /// **'Thank you for using Lotti!'**
  String get settingsAboutThankYou;

  /// No description provided for @settingsAboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsAboutVersion;

  /// No description provided for @settingsAboutPlatform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get settingsAboutPlatform;

  /// No description provided for @settingsAboutBuildType.
  ///
  /// In en, this message translates to:
  /// **'Build Type'**
  String get settingsAboutBuildType;

  /// No description provided for @settingsAboutJournalEntries.
  ///
  /// In en, this message translates to:
  /// **'Journal Entries'**
  String get settingsAboutJournalEntries;

  /// No description provided for @settingsAdvancedTitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced Settings'**
  String get settingsAdvancedTitle;

  /// No description provided for @settingsAdvancedMatrixSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure and manage Matrix synchronization settings'**
  String get settingsAdvancedMatrixSyncSubtitle;

  /// No description provided for @settingsAdvancedOutboxSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View and manage items waiting to be synchronized'**
  String get settingsAdvancedOutboxSubtitle;

  /// No description provided for @settingsAdvancedConflictsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Resolve synchronization conflicts to ensure data consistency'**
  String get settingsAdvancedConflictsSubtitle;

  /// No description provided for @settingsAdvancedLogsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Access and review application logs for debugging'**
  String get settingsAdvancedLogsSubtitle;

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

  /// No description provided for @settingsAdvancedAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Learn more about the Lotti application'**
  String get settingsAdvancedAboutSubtitle;

  /// No description provided for @settingsAiApiKeys.
  ///
  /// In en, this message translates to:
  /// **'AI Inference Providers'**
  String get settingsAiApiKeys;

  /// No description provided for @settingsAiModels.
  ///
  /// In en, this message translates to:
  /// **'AI Models'**
  String get settingsAiModels;

  /// No description provided for @settingsCategoriesDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Category Details'**
  String get settingsCategoriesDetailsLabel;

  /// No description provided for @settingsCategoriesDuplicateError.
  ///
  /// In en, this message translates to:
  /// **'Category exists already'**
  String get settingsCategoriesDuplicateError;

  /// No description provided for @settingsCategoriesNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Category name:'**
  String get settingsCategoriesNameLabel;

  /// No description provided for @settingsCategoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get settingsCategoriesTitle;

  /// No description provided for @settingsLabelsTitle.
  ///
  /// In en, this message translates to:
  /// **'Labels'**
  String get settingsLabelsTitle;

  /// No description provided for @settingsLabelsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Organize tasks with colored labels'**
  String get settingsLabelsSubtitle;

  /// No description provided for @settingsCategoriesAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add Category'**
  String get settingsCategoriesAddTooltip;

  /// No description provided for @settingsLabelsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search labels…'**
  String get settingsLabelsSearchHint;

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

  /// No description provided for @settingsCategoriesEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No categories found'**
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

  /// No description provided for @settingsCategoriesHasDefaultLanguage.
  ///
  /// In en, this message translates to:
  /// **'Default language'**
  String get settingsCategoriesHasDefaultLanguage;

  /// No description provided for @settingsCategoriesHasAiSettings.
  ///
  /// In en, this message translates to:
  /// **'AI settings'**
  String get settingsCategoriesHasAiSettings;

  /// No description provided for @settingsCategoriesHasAutomaticPrompts.
  ///
  /// In en, this message translates to:
  /// **'Automatic AI'**
  String get settingsCategoriesHasAutomaticPrompts;

  /// No description provided for @categoryNotFound.
  ///
  /// In en, this message translates to:
  /// **'Category not found'**
  String get categoryNotFound;

  /// No description provided for @saveSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Saved successfully'**
  String get saveSuccessful;

  /// No description provided for @basicSettings.
  ///
  /// In en, this message translates to:
  /// **'Basic Settings'**
  String get basicSettings;

  /// No description provided for @categoryDefaultLanguageDescription.
  ///
  /// In en, this message translates to:
  /// **'Set a default language for tasks in this category'**
  String get categoryDefaultLanguageDescription;

  /// No description provided for @aiModelSettings.
  ///
  /// In en, this message translates to:
  /// **'AI Model Settings'**
  String get aiModelSettings;

  /// No description provided for @categoryAiModelDescription.
  ///
  /// In en, this message translates to:
  /// **'Control which AI prompts can be used with this category'**
  String get categoryAiModelDescription;

  /// No description provided for @automaticPrompts.
  ///
  /// In en, this message translates to:
  /// **'Automatic Prompts'**
  String get automaticPrompts;

  /// No description provided for @categoryAutomaticPromptsDescription.
  ///
  /// In en, this message translates to:
  /// **'Configure prompts that run automatically for different content types'**
  String get categoryAutomaticPromptsDescription;

  /// No description provided for @enterCategoryName.
  ///
  /// In en, this message translates to:
  /// **'Enter category name'**
  String get enterCategoryName;

  /// No description provided for @categoryNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Category name is required'**
  String get categoryNameRequired;

  /// No description provided for @settingsLabelsCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create label'**
  String get settingsLabelsCreateTitle;

  /// No description provided for @settingsLabelsEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit label'**
  String get settingsLabelsEditTitle;

  /// No description provided for @settingsLabelsNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Label name'**
  String get settingsLabelsNameLabel;

  /// No description provided for @settingsLabelsNameHint.
  ///
  /// In en, this message translates to:
  /// **'Bug, Release blocker, Sync…'**
  String get settingsLabelsNameHint;

  /// No description provided for @settingsLabelsNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Label name must not be empty.'**
  String get settingsLabelsNameRequired;

  /// No description provided for @settingsLabelsDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get settingsLabelsDescriptionLabel;

  /// No description provided for @settingsLabelsDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Explain when to apply this label'**
  String get settingsLabelsDescriptionHint;

  /// No description provided for @settingsLabelsColorHeading.
  ///
  /// In en, this message translates to:
  /// **'Select a color'**
  String get settingsLabelsColorHeading;

  /// No description provided for @settingsLabelsColorSubheading.
  ///
  /// In en, this message translates to:
  /// **'Quick presets'**
  String get settingsLabelsColorSubheading;

  /// No description provided for @settingsLabelsCategoriesHeading.
  ///
  /// In en, this message translates to:
  /// **'Applicable categories'**
  String get settingsLabelsCategoriesHeading;

  /// No description provided for @settingsLabelsCategoriesAdd.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get settingsLabelsCategoriesAdd;

  /// No description provided for @settingsLabelsCategoriesRemoveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get settingsLabelsCategoriesRemoveTooltip;

  /// No description provided for @settingsLabelsCategoriesNone.
  ///
  /// In en, this message translates to:
  /// **'Applies to all categories'**
  String get settingsLabelsCategoriesNone;

  /// No description provided for @settingsLabelsPrivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Private label'**
  String get settingsLabelsPrivateTitle;

  /// No description provided for @settingsLabelsPrivateDescription.
  ///
  /// In en, this message translates to:
  /// **'Private labels only appear when “Show private entries” is enabled.'**
  String get settingsLabelsPrivateDescription;

  /// No description provided for @settingsLabelsCreateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Label created successfully'**
  String get settingsLabelsCreateSuccess;

  /// No description provided for @settingsLabelsUpdateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Label updated'**
  String get settingsLabelsUpdateSuccess;

  /// No description provided for @settingsLabelsDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete label'**
  String get settingsLabelsDeleteConfirmTitle;

  /// No description provided for @settingsLabelsDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{labelName}\"? Tasks with this label will lose the assignment.'**
  String settingsLabelsDeleteConfirmMessage(Object labelName);

  /// No description provided for @settingsLabelsDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Label \"{labelName}\" deleted'**
  String settingsLabelsDeleteSuccess(Object labelName);

  /// No description provided for @settingsLabelsDeleteCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsLabelsDeleteCancel;

  /// No description provided for @settingsLabelsDeleteConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get settingsLabelsDeleteConfirmAction;

  /// No description provided for @settingsLabelsActionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Label actions'**
  String get settingsLabelsActionsTooltip;

  /// No description provided for @settingsLabelsUsageCount.
  ///
  /// In en, this message translates to:
  /// **'Used on {count, plural, =1{1 task} other{{count} tasks}}'**
  String settingsLabelsUsageCount(int count);

  /// No description provided for @selectColor.
  ///
  /// In en, this message translates to:
  /// **'Select Color'**
  String get selectColor;

  /// No description provided for @selectButton.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get selectButton;

  /// No description provided for @privateLabel.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get privateLabel;

  /// No description provided for @categoryPrivateDescription.
  ///
  /// In en, this message translates to:
  /// **'Hide this category when private mode is enabled'**
  String get categoryPrivateDescription;

  /// No description provided for @activeLabel.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeLabel;

  /// No description provided for @categoryActiveDescription.
  ///
  /// In en, this message translates to:
  /// **'Inactive categories won\'t appear in selection lists'**
  String get categoryActiveDescription;

  /// No description provided for @favoriteLabel.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get favoriteLabel;

  /// No description provided for @categoryFavoriteDescription.
  ///
  /// In en, this message translates to:
  /// **'Mark this category as a favorite'**
  String get categoryFavoriteDescription;

  /// No description provided for @defaultLanguage.
  ///
  /// In en, this message translates to:
  /// **'Default Language'**
  String get defaultLanguage;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @noDefaultLanguage.
  ///
  /// In en, this message translates to:
  /// **'No default language'**
  String get noDefaultLanguage;

  /// No description provided for @noPromptsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No prompts available'**
  String get noPromptsAvailable;

  /// No description provided for @createPromptsFirst.
  ///
  /// In en, this message translates to:
  /// **'Create AI prompts first to configure them here'**
  String get createPromptsFirst;

  /// No description provided for @selectAllowedPrompts.
  ///
  /// In en, this message translates to:
  /// **'Select which prompts are allowed for this category'**
  String get selectAllowedPrompts;

  /// No description provided for @audioRecordings.
  ///
  /// In en, this message translates to:
  /// **'Audio Recordings'**
  String get audioRecordings;

  /// No description provided for @checklistUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checklist Updates'**
  String get checklistUpdates;

  /// No description provided for @images.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get images;

  /// No description provided for @entryTypeLabelTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get entryTypeLabelTask;

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

  /// No description provided for @entryTypeLabelJournalAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get entryTypeLabelJournalAudio;

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

  /// No description provided for @entryTypeLabelSurveyEntry.
  ///
  /// In en, this message translates to:
  /// **'Survey'**
  String get entryTypeLabelSurveyEntry;

  /// No description provided for @entryTypeLabelWorkoutEntry.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get entryTypeLabelWorkoutEntry;

  /// No description provided for @entryTypeLabelHabitCompletionEntry.
  ///
  /// In en, this message translates to:
  /// **'Habit'**
  String get entryTypeLabelHabitCompletionEntry;

  /// No description provided for @entryTypeLabelQuantitativeEntry.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get entryTypeLabelQuantitativeEntry;

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

  /// No description provided for @entryTypeLabelAiResponse.
  ///
  /// In en, this message translates to:
  /// **'AI Response'**
  String get entryTypeLabelAiResponse;

  /// No description provided for @taskSummaries.
  ///
  /// In en, this message translates to:
  /// **'Task Summaries'**
  String get taskSummaries;

  /// No description provided for @noPromptsForType.
  ///
  /// In en, this message translates to:
  /// **'No prompts available for this type'**
  String get noPromptsForType;

  /// No description provided for @errorLoadingPrompts.
  ///
  /// In en, this message translates to:
  /// **'Error loading prompts'**
  String get errorLoadingPrompts;

  /// No description provided for @categoryDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Category?'**
  String get categoryDeleteTitle;

  /// No description provided for @categoryDeleteConfirmation.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone. All entries in this category will remain but will no longer be categorized.'**
  String get categoryDeleteConfirmation;

  /// No description provided for @speechDictionaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Speech Dictionary'**
  String get speechDictionaryLabel;

  /// No description provided for @speechDictionaryHint.
  ///
  /// In en, this message translates to:
  /// **'macOS; Kirkjubæjarklaustur; Claude Code'**
  String get speechDictionaryHint;

  /// No description provided for @speechDictionaryHelper.
  ///
  /// In en, this message translates to:
  /// **'Semicolon-separated terms (max 50 chars) for better speech recognition'**
  String get speechDictionaryHelper;

  /// No description provided for @speechDictionaryWarning.
  ///
  /// In en, this message translates to:
  /// **'Large dictionary ({count} terms) may increase API costs'**
  String speechDictionaryWarning(Object count);

  /// No description provided for @speechDictionarySectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Speech Recognition'**
  String get speechDictionarySectionTitle;

  /// No description provided for @speechDictionarySectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Add terms that are often misspelled by speech recognition (names, places, technical terms)'**
  String get speechDictionarySectionDescription;

  /// No description provided for @addToDictionary.
  ///
  /// In en, this message translates to:
  /// **'Add to Dictionary'**
  String get addToDictionary;

  /// No description provided for @addToDictionarySuccess.
  ///
  /// In en, this message translates to:
  /// **'Term added to dictionary'**
  String get addToDictionarySuccess;

  /// No description provided for @addToDictionaryNoCategory.
  ///
  /// In en, this message translates to:
  /// **'Cannot add to dictionary: task has no category'**
  String get addToDictionaryNoCategory;

  /// No description provided for @addToDictionaryDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Term already exists in dictionary'**
  String get addToDictionaryDuplicate;

  /// No description provided for @addToDictionaryTooLong.
  ///
  /// In en, this message translates to:
  /// **'Term too long (max 50 characters)'**
  String get addToDictionaryTooLong;

  /// No description provided for @addToDictionarySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save dictionary'**
  String get addToDictionarySaveFailed;

  /// No description provided for @deleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButton;

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @createButton.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createButton;

  /// No description provided for @settingsConflictsResolutionTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Conflict Resolution'**
  String get settingsConflictsResolutionTitle;

  /// No description provided for @settingsConflictsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Conflicts'**
  String get settingsConflictsTitle;

  /// No description provided for @settingsDashboardDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Dashboard Details'**
  String get settingsDashboardDetailsLabel;

  /// No description provided for @settingsDashboardSaveLabel.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settingsDashboardSaveLabel;

  /// No description provided for @settingsDashboardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboards'**
  String get settingsDashboardsTitle;

  /// No description provided for @settingsFlagsTitle.
  ///
  /// In en, this message translates to:
  /// **'Config Flags'**
  String get settingsFlagsTitle;

  /// No description provided for @settingsHabitsDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete Habit'**
  String get settingsHabitsDeleteTooltip;

  /// No description provided for @settingsHabitsDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional):'**
  String get settingsHabitsDescriptionLabel;

  /// No description provided for @settingsHabitsDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Habit Details'**
  String get settingsHabitsDetailsLabel;

  /// No description provided for @settingsHabitsNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Habit name:'**
  String get settingsHabitsNameLabel;

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

  /// No description provided for @settingsHabitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Habits'**
  String get settingsHabitsTitle;

  /// No description provided for @settingsHealthImportFromDate.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get settingsHealthImportFromDate;

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

  /// No description provided for @settingsLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get settingsLogsTitle;

  /// No description provided for @settingsMaintenanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get settingsMaintenanceTitle;

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

  /// No description provided for @settingsMatrixCancelVerificationLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancel Verification'**
  String get settingsMatrixCancelVerificationLabel;

  /// No description provided for @settingsMatrixContinueVerificationLabel.
  ///
  /// In en, this message translates to:
  /// **'Accept on other device to continue'**
  String get settingsMatrixContinueVerificationLabel;

  /// No description provided for @settingsMatrixDeleteLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get settingsMatrixDeleteLabel;

  /// No description provided for @settingsMatrixDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get settingsMatrixDone;

  /// No description provided for @settingsMatrixEnterValidUrl.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid URL'**
  String get settingsMatrixEnterValidUrl;

  /// No description provided for @settingsMatrixHomeServerLabel.
  ///
  /// In en, this message translates to:
  /// **'Homeserver'**
  String get settingsMatrixHomeServerLabel;

  /// No description provided for @settingsMatrixHomeserverConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Matrix Homeserver Setup'**
  String get settingsMatrixHomeserverConfigTitle;

  /// No description provided for @settingsMatrixListUnverifiedLabel.
  ///
  /// In en, this message translates to:
  /// **'Unverified devices'**
  String get settingsMatrixListUnverifiedLabel;

  /// No description provided for @settingsMatrixLoginButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get settingsMatrixLoginButtonLabel;

  /// No description provided for @settingsMatrixLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get settingsMatrixLoginFailed;

  /// No description provided for @settingsMatrixLogoutButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get settingsMatrixLogoutButtonLabel;

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

  /// No description provided for @settingsMatrixPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get settingsMatrixPasswordLabel;

  /// No description provided for @settingsMatrixPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password too short'**
  String get settingsMatrixPasswordTooShort;

  /// No description provided for @settingsMatrixPreviousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous Page'**
  String get settingsMatrixPreviousPage;

  /// No description provided for @settingsMatrixQrTextPage.
  ///
  /// In en, this message translates to:
  /// **'Scan this QR code to invite device to a sync room.'**
  String get settingsMatrixQrTextPage;

  /// No description provided for @settingsMatrixRoomInviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Room invite'**
  String get settingsMatrixRoomInviteTitle;

  /// No description provided for @settingsMatrixRoomInviteMessage.
  ///
  /// In en, this message translates to:
  /// **'Invite to room {roomId} from {senderId}. Accept?'**
  String settingsMatrixRoomInviteMessage(String roomId, String senderId);

  /// No description provided for @settingsMatrixAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get settingsMatrixAccept;

  /// No description provided for @settingsMatrixRoomConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Matrix Sync Room Setup'**
  String get settingsMatrixRoomConfigTitle;

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

  /// No description provided for @settingsMatrixSentMessagesLabel.
  ///
  /// In en, this message translates to:
  /// **'Sent messages:'**
  String get settingsMatrixSentMessagesLabel;

  /// No description provided for @settingsMatrixMessageType.
  ///
  /// In en, this message translates to:
  /// **'Message Type'**
  String get settingsMatrixMessageType;

  /// No description provided for @settingsMatrixCount.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get settingsMatrixCount;

  /// No description provided for @settingsMatrixMetric.
  ///
  /// In en, this message translates to:
  /// **'Metric'**
  String get settingsMatrixMetric;

  /// No description provided for @settingsMatrixValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get settingsMatrixValue;

  /// No description provided for @settingsMatrixMetrics.
  ///
  /// In en, this message translates to:
  /// **'Sync Metrics'**
  String get settingsMatrixMetrics;

  /// No description provided for @settingsMatrixMetricsNoData.
  ///
  /// In en, this message translates to:
  /// **'Sync Metrics: no data'**
  String get settingsMatrixMetricsNoData;

  /// No description provided for @settingsMatrixLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated:'**
  String get settingsMatrixLastUpdated;

  /// No description provided for @settingsMatrixRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get settingsMatrixRefresh;

  /// No description provided for @settingsMatrixTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Settings'**
  String get settingsMatrixTitle;

  /// No description provided for @settingsMatrixMaintenanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get settingsMatrixMaintenanceTitle;

  /// No description provided for @settingsMatrixMaintenanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Run Matrix maintenance tasks and recovery tools'**
  String get settingsMatrixMaintenanceSubtitle;

  /// No description provided for @settingsMatrixSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure end-to-end encrypted sync'**
  String get settingsMatrixSubtitle;

  /// No description provided for @settingsMatrixUnverifiedDevicesPage.
  ///
  /// In en, this message translates to:
  /// **'Unverified Devices'**
  String get settingsMatrixUnverifiedDevicesPage;

  /// No description provided for @settingsMatrixUserLabel.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get settingsMatrixUserLabel;

  /// No description provided for @settingsMatrixUserNameTooShort.
  ///
  /// In en, this message translates to:
  /// **'User name too short'**
  String get settingsMatrixUserNameTooShort;

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
      String deviceName, String deviceID);

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

  /// No description provided for @settingsMeasurableAggregationLabel.
  ///
  /// In en, this message translates to:
  /// **'Default Aggregation Type (optional):'**
  String get settingsMeasurableAggregationLabel;

  /// No description provided for @settingsMeasurableDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete measurable type'**
  String get settingsMeasurableDeleteTooltip;

  /// No description provided for @settingsMeasurableDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional):'**
  String get settingsMeasurableDescriptionLabel;

  /// No description provided for @settingsMeasurableDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Measurable Details'**
  String get settingsMeasurableDetailsLabel;

  /// No description provided for @settingsMeasurableFavoriteLabel.
  ///
  /// In en, this message translates to:
  /// **'Favorite: '**
  String get settingsMeasurableFavoriteLabel;

  /// No description provided for @settingsMeasurableNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Measurable name:'**
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

  /// No description provided for @settingsMeasurableUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit abbreviation (optional):'**
  String get settingsMeasurableUnitLabel;

  /// No description provided for @settingsMeasurablesTitle.
  ///
  /// In en, this message translates to:
  /// **'Measurable Types'**
  String get settingsMeasurablesTitle;

  /// No description provided for @settingsSpeechAudioWithoutTranscript.
  ///
  /// In en, this message translates to:
  /// **'Audio entries without transcript:'**
  String get settingsSpeechAudioWithoutTranscript;

  /// No description provided for @settingsSpeechAudioWithoutTranscriptButton.
  ///
  /// In en, this message translates to:
  /// **'Find & transcribe'**
  String get settingsSpeechAudioWithoutTranscriptButton;

  /// No description provided for @settingsSpeechLastActivity.
  ///
  /// In en, this message translates to:
  /// **'Last transcription activity:'**
  String get settingsSpeechLastActivity;

  /// No description provided for @settingsSpeechModelSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Whisper speech recognition model:'**
  String get settingsSpeechModelSelectionTitle;

  /// No description provided for @settingsSyncOutboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Outbox'**
  String get settingsSyncOutboxTitle;

  /// No description provided for @syncNotLoggedInToast.
  ///
  /// In en, this message translates to:
  /// **'Sync is not logged in'**
  String get syncNotLoggedInToast;

  /// No description provided for @settingsSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure sync and view stats'**
  String get settingsSyncSubtitle;

  /// No description provided for @settingsSyncStatsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Inspect sync pipeline metrics'**
  String get settingsSyncStatsSubtitle;

  /// No description provided for @matrixStatsError.
  ///
  /// In en, this message translates to:
  /// **'Error loading Matrix stats'**
  String get matrixStatsError;

  /// No description provided for @settingsTagsDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete tag'**
  String get settingsTagsDeleteTooltip;

  /// No description provided for @settingsTagsDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Tags Details'**
  String get settingsTagsDetailsLabel;

  /// No description provided for @settingsTagsHideLabel.
  ///
  /// In en, this message translates to:
  /// **'Hide from suggestions:'**
  String get settingsTagsHideLabel;

  /// No description provided for @settingsTagsPrivateLabel.
  ///
  /// In en, this message translates to:
  /// **'Private:'**
  String get settingsTagsPrivateLabel;

  /// No description provided for @settingsTagsSaveLabel.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settingsTagsSaveLabel;

  /// No description provided for @settingsTagsTagName.
  ///
  /// In en, this message translates to:
  /// **'Tag:'**
  String get settingsTagsTagName;

  /// No description provided for @settingsTagsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get settingsTagsTitle;

  /// No description provided for @settingsTagsTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Tag type:'**
  String get settingsTagsTypeLabel;

  /// No description provided for @settingsTagsTypePerson.
  ///
  /// In en, this message translates to:
  /// **'PERSON'**
  String get settingsTagsTypePerson;

  /// No description provided for @settingsTagsTypeStory.
  ///
  /// In en, this message translates to:
  /// **'STORY'**
  String get settingsTagsTypeStory;

  /// No description provided for @settingsTagsTypeTag.
  ///
  /// In en, this message translates to:
  /// **'TAG'**
  String get settingsTagsTypeTag;

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

  /// No description provided for @settingsThemingTitle.
  ///
  /// In en, this message translates to:
  /// **'Theming'**
  String get settingsThemingTitle;

  /// No description provided for @speechModalAddTranscription.
  ///
  /// In en, this message translates to:
  /// **'Add Transcription'**
  String get speechModalAddTranscription;

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

  /// No description provided for @speechModalTranscriptionProgress.
  ///
  /// In en, this message translates to:
  /// **'Transcription Progress'**
  String get speechModalTranscriptionProgress;

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

  /// No description provided for @syncStepAiSettings.
  ///
  /// In en, this message translates to:
  /// **'AI settings'**
  String get syncStepAiSettings;

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

  /// No description provided for @syncStepMeasurables.
  ///
  /// In en, this message translates to:
  /// **'Measurables'**
  String get syncStepMeasurables;

  /// No description provided for @syncStepLabels.
  ///
  /// In en, this message translates to:
  /// **'Labels'**
  String get syncStepLabels;

  /// No description provided for @syncStepTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get syncStepTags;

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

  /// No description provided for @taskEstimateLabel.
  ///
  /// In en, this message translates to:
  /// **'Estimate:'**
  String get taskEstimateLabel;

  /// No description provided for @taskNoEstimateLabel.
  ///
  /// In en, this message translates to:
  /// **'No estimate'**
  String get taskNoEstimateLabel;

  /// No description provided for @taskNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a name for the task'**
  String get taskNameHint;

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

  /// No description provided for @taskLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language:'**
  String get taskLanguageLabel;

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

  /// No description provided for @taskLanguageSerbian.
  ///
  /// In en, this message translates to:
  /// **'Serbian'**
  String get taskLanguageSerbian;

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

  /// No description provided for @taskLanguageUkrainian.
  ///
  /// In en, this message translates to:
  /// **'Ukrainian'**
  String get taskLanguageUkrainian;

  /// No description provided for @taskLanguageIgbo.
  ///
  /// In en, this message translates to:
  /// **'Igbo'**
  String get taskLanguageIgbo;

  /// No description provided for @taskLanguageNigerianPidgin.
  ///
  /// In en, this message translates to:
  /// **'Nigerian Pidgin'**
  String get taskLanguageNigerianPidgin;

  /// No description provided for @taskLanguageYoruba.
  ///
  /// In en, this message translates to:
  /// **'Yoruba'**
  String get taskLanguageYoruba;

  /// No description provided for @taskLanguageSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search languages...'**
  String get taskLanguageSearchPlaceholder;

  /// No description provided for @taskLanguageSelectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Currently selected'**
  String get taskLanguageSelectedLabel;

  /// No description provided for @taskLanguageVietnamese.
  ///
  /// In en, this message translates to:
  /// **'Vietnamese'**
  String get taskLanguageVietnamese;

  /// No description provided for @tasksFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'Tasks Filter'**
  String get tasksFilterTitle;

  /// No description provided for @timeByCategoryChartTitle.
  ///
  /// In en, this message translates to:
  /// **'Time by Category'**
  String get timeByCategoryChartTitle;

  /// No description provided for @timeByCategoryChartTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get timeByCategoryChartTotalLabel;

  /// No description provided for @viewMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get viewMenuTitle;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @commonUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get commonUnknown;

  /// No description provided for @aiTranscribingAudio.
  ///
  /// In en, this message translates to:
  /// **'Transcribing audio...'**
  String get aiTranscribingAudio;

  /// No description provided for @copyAsText.
  ///
  /// In en, this message translates to:
  /// **'Copy as text'**
  String get copyAsText;

  /// No description provided for @copyAsMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Copy as Markdown'**
  String get copyAsMarkdown;

  /// No description provided for @editorInsertDivider.
  ///
  /// In en, this message translates to:
  /// **'Insert divider'**
  String get editorInsertDivider;

  /// No description provided for @tasksLabelsHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Labels'**
  String get tasksLabelsHeaderTitle;

  /// No description provided for @tasksLabelsHeaderEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit labels'**
  String get tasksLabelsHeaderEditTooltip;

  /// No description provided for @tasksLabelsNoLabels.
  ///
  /// In en, this message translates to:
  /// **'No labels'**
  String get tasksLabelsNoLabels;

  /// No description provided for @tasksLabelsDialogClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get tasksLabelsDialogClose;

  /// No description provided for @tasksLabelsSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Select labels'**
  String get tasksLabelsSheetTitle;

  /// No description provided for @tasksLabelsSheetSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search labels…'**
  String get tasksLabelsSheetSearchHint;

  /// No description provided for @tasksLabelsSheetApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get tasksLabelsSheetApply;

  /// No description provided for @tasksLabelsUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update labels'**
  String get tasksLabelsUpdateFailed;

  /// No description provided for @tasksLabelFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'Labels'**
  String get tasksLabelFilterTitle;

  /// No description provided for @tasksLabelFilterUnlabeled.
  ///
  /// In en, this message translates to:
  /// **'Unlabeled'**
  String get tasksLabelFilterUnlabeled;

  /// No description provided for @tasksLabelFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get tasksLabelFilterAll;

  /// No description provided for @tasksQuickFilterLabelsActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Active label filters'**
  String get tasksQuickFilterLabelsActiveTitle;

  /// No description provided for @tasksQuickFilterClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get tasksQuickFilterClear;

  /// No description provided for @tasksQuickFilterUnassignedLabel.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get tasksQuickFilterUnassignedLabel;

  /// No description provided for @taskLabelUnassignedLabel.
  ///
  /// In en, this message translates to:
  /// **'unassigned'**
  String get taskLabelUnassignedLabel;

  /// No description provided for @tasksPriorityTitle.
  ///
  /// In en, this message translates to:
  /// **'Priority:'**
  String get tasksPriorityTitle;

  /// No description provided for @tasksPriorityP0.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get tasksPriorityP0;

  /// No description provided for @tasksPriorityP1.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get tasksPriorityP1;

  /// No description provided for @tasksPriorityP2.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get tasksPriorityP2;

  /// No description provided for @tasksPriorityP3.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get tasksPriorityP3;

  /// No description provided for @tasksPriorityPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Select priority'**
  String get tasksPriorityPickerTitle;

  /// No description provided for @tasksPriorityFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get tasksPriorityFilterTitle;

  /// No description provided for @tasksPriorityFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get tasksPriorityFilterAll;

  /// No description provided for @tasksPriorityP0Description.
  ///
  /// In en, this message translates to:
  /// **'Urgent (ASAP)'**
  String get tasksPriorityP0Description;

  /// No description provided for @tasksPriorityP1Description.
  ///
  /// In en, this message translates to:
  /// **'High (Soon)'**
  String get tasksPriorityP1Description;

  /// No description provided for @tasksPriorityP2Description.
  ///
  /// In en, this message translates to:
  /// **'Medium (Default)'**
  String get tasksPriorityP2Description;

  /// No description provided for @tasksPriorityP3Description.
  ///
  /// In en, this message translates to:
  /// **'Low (Whenever)'**
  String get tasksPriorityP3Description;

  /// No description provided for @checklistFilterShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all items'**
  String get checklistFilterShowAll;

  /// No description provided for @checklistFilterShowOpen.
  ///
  /// In en, this message translates to:
  /// **'Show open items'**
  String get checklistFilterShowOpen;

  /// No description provided for @checklistFilterStateOpenOnly.
  ///
  /// In en, this message translates to:
  /// **'Showing open items'**
  String get checklistFilterStateOpenOnly;

  /// No description provided for @checklistFilterStateAll.
  ///
  /// In en, this message translates to:
  /// **'Showing all items'**
  String get checklistFilterStateAll;

  /// No description provided for @checklistFilterToggleSemantics.
  ///
  /// In en, this message translates to:
  /// **'Toggle checklist filter (current: {state})'**
  String checklistFilterToggleSemantics(String state);

  /// No description provided for @checklistCompletedShort.
  ///
  /// In en, this message translates to:
  /// **'{completed}/{total} done'**
  String checklistCompletedShort(int completed, int total);

  /// No description provided for @checklistAllDone.
  ///
  /// In en, this message translates to:
  /// **'All items completed!'**
  String get checklistAllDone;

  /// No description provided for @correctionExamplesSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Checklist Correction Examples'**
  String get correctionExamplesSectionTitle;

  /// No description provided for @correctionExamplesSectionDescription.
  ///
  /// In en, this message translates to:
  /// **'When you manually correct checklist items, those corrections are saved here and used to improve AI suggestions.'**
  String get correctionExamplesSectionDescription;

  /// No description provided for @correctionExamplesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No corrections captured yet. Edit a checklist item to add your first example.'**
  String get correctionExamplesEmpty;

  /// No description provided for @correctionExamplesWarning.
  ///
  /// In en, this message translates to:
  /// **'You have {count} corrections. Only the most recent {max} will be used in AI prompts. Consider deleting old or redundant examples.'**
  String correctionExamplesWarning(int count, int max);

  /// No description provided for @correctionExampleCaptured.
  ///
  /// In en, this message translates to:
  /// **'Correction saved for AI learning'**
  String get correctionExampleCaptured;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr', 'ro'].contains(locale.languageCode);

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
      'that was used.');
}

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

  /// No description provided for @aiConfigListCascadeDeleteWarning.
  ///
  /// In en, this message translates to:
  /// **'This will also delete all models associated with this provider.'**
  String get aiConfigListCascadeDeleteWarning;

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

  /// No description provided for @aiConfigProviderDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Provider deleted successfully'**
  String get aiConfigProviderDeletedSuccessfully;

  /// No description provided for @aiConfigAssociatedModelsRemoved.
  ///
  /// In en, this message translates to:
  /// **'{count} associated model{count, plural, =1{} other{s}} removed'**
  String aiConfigAssociatedModelsRemoved(int count);

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

  /// No description provided for @checklistsTitle.
  ///
  /// In en, this message translates to:
  /// **'Checklists'**
  String get checklistsTitle;

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

  /// No description provided for @configFlagRecordLocationDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatically record your location with new entries. This helps with location-based organization and search.'**
  String get configFlagRecordLocationDescription;

  /// No description provided for @configFlagResendAttachmentsDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable this to automatically resend failed attachment uploads when the connection is restored.'**
  String get configFlagResendAttachmentsDescription;

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

  /// No description provided for @createCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Category:'**
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

  /// No description provided for @maintenanceDeleteLoggingDb.
  ///
  /// In en, this message translates to:
  /// **'Delete Logging Database'**
  String get maintenanceDeleteLoggingDb;

  /// No description provided for @maintenanceDeleteSyncDb.
  ///
  /// In en, this message translates to:
  /// **'Delete Sync Database'**
  String get maintenanceDeleteSyncDb;

  /// No description provided for @maintenancePurgeAudioModels.
  ///
  /// In en, this message translates to:
  /// **'Purge audio models'**
  String get maintenancePurgeAudioModels;

  /// No description provided for @maintenancePurgeAudioModelsMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to purge all audio models? This action cannot be undone.'**
  String get maintenancePurgeAudioModelsMessage;

  /// No description provided for @maintenancePurgeAudioModelsConfirm.
  ///
  /// In en, this message translates to:
  /// **'YES, PURGE MODELS'**
  String get maintenancePurgeAudioModelsConfirm;

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

  /// No description provided for @maintenancePurgeDeletedMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to purge all deleted items? This action cannot be undone.'**
  String get maintenancePurgeDeletedMessage;

  /// No description provided for @maintenanceRecreateFts5.
  ///
  /// In en, this message translates to:
  /// **'Recreate full-text index'**
  String get maintenanceRecreateFts5;

  /// No description provided for @maintenanceRecreateFts5Message.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to recreate the full-text index? This may take some time.'**
  String get maintenanceRecreateFts5Message;

  /// No description provided for @maintenanceRecreateFts5Confirm.
  ///
  /// In en, this message translates to:
  /// **'YES, RECREATE INDEX'**
  String get maintenanceRecreateFts5Confirm;

  /// No description provided for @maintenanceReSync.
  ///
  /// In en, this message translates to:
  /// **'Re-sync messages'**
  String get maintenanceReSync;

  /// No description provided for @maintenanceSyncDefinitions.
  ///
  /// In en, this message translates to:
  /// **'Sync tags, measurables, dashboards, habits, categories'**
  String get maintenanceSyncDefinitions;

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

  /// No description provided for @outboxMonitorNoAttachment.
  ///
  /// In en, this message translates to:
  /// **'no attachment'**
  String get outboxMonitorNoAttachment;

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

  /// No description provided for @outboxMonitorSwitchLabel.
  ///
  /// In en, this message translates to:
  /// **'enabled'**
  String get outboxMonitorSwitchLabel;

  /// No description provided for @promptAddPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Prompt'**
  String get promptAddPageTitle;

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

  /// No description provided for @promptSettingsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Prompts'**
  String get promptSettingsPageTitle;

  /// No description provided for @promptSelectionModalTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Preconfigured Prompt'**
  String get promptSelectionModalTitle;

  /// No description provided for @promptUsePreconfiguredButton.
  ///
  /// In en, this message translates to:
  /// **'Use Preconfigured Prompt'**
  String get promptUsePreconfiguredButton;

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

  /// No description provided for @settingsAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About Lotti'**
  String get settingsAboutTitle;

  /// No description provided for @settingsAdvancedShowCaseAboutLottiTooltip.
  ///
  /// In en, this message translates to:
  /// **'Learn more about the Lotti application, including version and credits.'**
  String get settingsAdvancedShowCaseAboutLottiTooltip;

  /// No description provided for @settingsAdvancedShowCaseApiKeyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Manage your AI inference providers for various AI services. Add, edit, or delete providers to configure integrations with supported services like OpenAI, Gemini, Nebius, Ollama, and more. Ensure secure handling of sensitive information.'**
  String get settingsAdvancedShowCaseApiKeyTooltip;

  /// No description provided for @settingsAdvancedShowCaseConflictsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Resolve synchronization conflicts to ensure data consistency.'**
  String get settingsAdvancedShowCaseConflictsTooltip;

  /// No description provided for @settingsAdvancedShowCaseHealthImportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Import health-related data from external sources.'**
  String get settingsAdvancedShowCaseHealthImportTooltip;

  /// No description provided for @settingsAdvancedShowCaseLogsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Access and review application logs for debugging and monitoring.'**
  String get settingsAdvancedShowCaseLogsTooltip;

  /// No description provided for @settingsAdvancedShowCaseMaintenanceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Perform maintenance tasks to optimize application performance.'**
  String get settingsAdvancedShowCaseMaintenanceTooltip;

  /// No description provided for @settingsAdvancedShowCaseMatrixSyncTooltip.
  ///
  /// In en, this message translates to:
  /// **'Configure and manage Matrix synchronization settings for seamless data integration.'**
  String get settingsAdvancedShowCaseMatrixSyncTooltip;

  /// No description provided for @settingsAdvancedShowCaseModelsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Define AI models that use inference providers'**
  String get settingsAdvancedShowCaseModelsTooltip;

  /// No description provided for @settingsAdvancedShowCaseSyncOutboxTooltip.
  ///
  /// In en, this message translates to:
  /// **'View and manage items waiting to be synchronized in the outbox.'**
  String get settingsAdvancedShowCaseSyncOutboxTooltip;

  /// No description provided for @settingsAdvancedTitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced Settings'**
  String get settingsAdvancedTitle;

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

  /// No description provided for @settingsCategoryShowCaseActiveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Toggle this option to mark the category as active. Active categories are currently in use and will be prominently displayed for easier accessibility.'**
  String get settingsCategoryShowCaseActiveTooltip;

  /// No description provided for @settingsCategoryShowCaseColorTooltip.
  ///
  /// In en, this message translates to:
  /// **'Select a color to represent this category. You can either enter a valid HEX color code (e.g., #FF5733) or use the color picker on the right to choose a color visually.'**
  String get settingsCategoryShowCaseColorTooltip;

  /// No description provided for @settingsCategoryShowCaseDelTooltip.
  ///
  /// In en, this message translates to:
  /// **'Click this button to delete the category. Please note that this action is irreversible, so ensure you want to remove the category before proceeding.'**
  String get settingsCategoryShowCaseDelTooltip;

  /// No description provided for @settingsCategoryShowCaseFavTooltip.
  ///
  /// In en, this message translates to:
  /// **'\'Enable this option to mark the category as a favorite. Favorite categories are easier to access and are highlighted for quick reference.\''**
  String get settingsCategoryShowCaseFavTooltip;

  /// No description provided for @settingsCategoryShowCaseNameTooltip.
  ///
  /// In en, this message translates to:
  /// **'Enter a clear and relevant name for the category. Keep it short and descriptive so you can easily identify its purpose.'**
  String get settingsCategoryShowCaseNameTooltip;

  /// No description provided for @settingsCategoryShowCasePrivateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Toggle this option to mark the category as private. Private categories are only visible to you and help in organizing sensitive or personal habits and tasks securely.'**
  String get settingsCategoryShowCasePrivateTooltip;

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

  /// No description provided for @settingsDashboardsShowCaseActiveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Toggle this switch to mark the dashboard as active. Active dashboards are currently in use and will be prominently displayed for easier accessibility.'**
  String get settingsDashboardsShowCaseActiveTooltip;

  /// No description provided for @settingsDashboardsShowCaseCatTooltip.
  ///
  /// In en, this message translates to:
  /// **'Select a category that best describes the dashboard. This helps in organizing and categorizing your dashboards effectively. Examples: \'Health\', \'Productivity\', \'Work\'.'**
  String get settingsDashboardsShowCaseCatTooltip;

  /// No description provided for @settingsDashboardsShowCaseCopyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Tap to copy this dashboard. This will allow you to duplicate the dashboard and use them elsewhere.'**
  String get settingsDashboardsShowCaseCopyTooltip;

  /// No description provided for @settingsDashboardsShowCaseDelTooltip.
  ///
  /// In en, this message translates to:
  /// **'Tap this button to permanently delete the dashboard. Be cautious, as this action cannot be undone and all related data will be removed.'**
  String get settingsDashboardsShowCaseDelTooltip;

  /// No description provided for @settingsDashboardsShowCaseDescrTooltip.
  ///
  /// In en, this message translates to:
  /// **'Provide a detailed description for the dashboard. This helps in understanding the purpose and contents of the dashboard. Examples: \'Tracks daily wellness activities\', \'Monitors work-related tasks and goals\'.'**
  String get settingsDashboardsShowCaseDescrTooltip;

  /// No description provided for @settingsDashboardsShowCaseHealthChartsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Select the health charts you want to include in your dashboard. Examples: \'Weight\', \'Body Fat Percentage\'.'**
  String get settingsDashboardsShowCaseHealthChartsTooltip;

  /// No description provided for @settingsDashboardsShowCaseNameTooltip.
  ///
  /// In en, this message translates to:
  /// **'Enter a clear and relevant name for the dashboard. Keep it short and descriptive so you can easily identify its purpose. Examples: \'Wellness Track\', \'Daily Goals\', \'Work Schedule\'.'**
  String get settingsDashboardsShowCaseNameTooltip;

  /// No description provided for @settingsDashboardsShowCasePrivateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Toggle this switch to make the dashboard private. Private dashboards are only visible to you and won\'t be shared with others.'**
  String get settingsDashboardsShowCasePrivateTooltip;

  /// No description provided for @settingsDashboardsShowCaseSurveyChartsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Select the survey charts you want to include in your dashboard. Examples: \'Customer Satisfaction\', \'Employee Feedback\'.'**
  String get settingsDashboardsShowCaseSurveyChartsTooltip;

  /// No description provided for @settingsDashboardsShowCaseWorkoutChartsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Select the workout charts you want to include in your dashboard. Examples: \'Walking\', \'Running\', \'Swimming\'.'**
  String get settingsDashboardsShowCaseWorkoutChartsTooltip;

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

  /// No description provided for @settingsHabitsShowCaseAlertTimeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Set the specific time you want to receive a reminder or alert for this habit. This ensures you never miss completing it. Example: \'8:00 PM\'.'**
  String get settingsHabitsShowCaseAlertTimeTooltip;

  /// No description provided for @settingsHabitsShowCaseArchivedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Toggle this switch to archive the habit. Archived habits are no longer active but remain saved for future reference or review. Examples: \'Learn Guitar\', \'Completed Course\'.'**
  String get settingsHabitsShowCaseArchivedTooltip;

  /// No description provided for @settingsHabitsShowCaseCatTooltip.
  ///
  /// In en, this message translates to:
  /// **'Choose a category that best describes your habit or create a new one by selecting the [+] button.\nExamples: \'Health\', \'Productivity\', \'Exercise\'.'**
  String get settingsHabitsShowCaseCatTooltip;

  /// No description provided for @settingsHabitsShowCaseDashTooltip.
  ///
  /// In en, this message translates to:
  /// **'Select a dashboard to organize and track your habit, or create a new dashboard using the [+] button.\nExamples: \'Wellness Tracker\', \'Daily Goals\', \'Work Schedule\'.'**
  String get settingsHabitsShowCaseDashTooltip;

  /// No description provided for @settingsHabitsShowCaseDelHabitTooltip.
  ///
  /// In en, this message translates to:
  /// **'Tap this button to permanently delete the habit. Be cautious, as this action cannot be undone and all related data will be removed.'**
  String get settingsHabitsShowCaseDelHabitTooltip;

  /// No description provided for @settingsHabitsShowCaseDescrTooltip.
  ///
  /// In en, this message translates to:
  /// **'Provide a brief and meaningful description of the habit. Include any relevant details or \ncontext to clearly define the habit\'s purpose and importance. \nExamples: \'Jog for 30 minutes every morning to boost fitness\' or \'Read one chapter daily to improve knowledge and focus\''**
  String get settingsHabitsShowCaseDescrTooltip;

  /// No description provided for @settingsHabitsShowCaseNameTooltip.
  ///
  /// In en, this message translates to:
  /// **'Enter a clear and descriptive name for the habit.\nAvoid overly long names, and make it concise enough to identify the habit easily. \nExamples: \'Morning Jogs\', \'Read Daily\'.'**
  String get settingsHabitsShowCaseNameTooltip;

  /// No description provided for @settingsHabitsShowCasePriorTooltip.
  ///
  /// In en, this message translates to:
  /// **'Toggle the switch to assign priority to the habit. High-priority habits often represent essential or urgent tasks you want to focus on. Examples: \'Exercise Daily\', \'Work on Project\'.'**
  String get settingsHabitsShowCasePriorTooltip;

  /// No description provided for @settingsHabitsShowCasePrivateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Use this switch to mark the habit as private. Private habits are only visible to you and will not be shared with others. Examples: \'Personal Journal\', \'Meditation\'.'**
  String get settingsHabitsShowCasePrivateTooltip;

  /// No description provided for @settingsHabitsShowCaseStarDateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Select the date you want to start tracking this habit. This helps to define when the habit begins and allows for accurate progress monitoring. Example: \'July 1, 2025\'.'**
  String get settingsHabitsShowCaseStarDateTooltip;

  /// No description provided for @settingsHabitsShowCaseStartTimeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Set the time from which this habit should be visible or start appearing in your schedule. This helps organize your day effectively. Example: \'7:00 AM\'.'**
  String get settingsHabitsShowCaseStartTimeTooltip;

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

  /// No description provided for @settingsMatrixHomeserverConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Matrix Homeserver Setup'**
  String get settingsMatrixHomeserverConfigTitle;

  /// No description provided for @settingsMatrixHomeServerLabel.
  ///
  /// In en, this message translates to:
  /// **'Homeserver'**
  String get settingsMatrixHomeServerLabel;

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

  /// No description provided for @settingsMatrixTitle.
  ///
  /// In en, this message translates to:
  /// **'Matrix Sync Settings'**
  String get settingsMatrixTitle;

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

  /// No description provided for @settingsMeasurableShowCaseAggreTypeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Select the default aggregation type for the measurable data. This determines how the data will be summarized over time. \nOptions: \'dailySum\', \'dailyMax\', \'dailyAvg\', \'hourlySum\'.'**
  String get settingsMeasurableShowCaseAggreTypeTooltip;

  /// No description provided for @settingsMeasurableShowCaseDelTooltip.
  ///
  /// In en, this message translates to:
  /// **'Click this button to delete the measurable type. Please note that this action is irreversible, so ensure you want to remove the measurable type before proceeding.'**
  String get settingsMeasurableShowCaseDelTooltip;

  /// No description provided for @settingsMeasurableShowCaseDescrTooltip.
  ///
  /// In en, this message translates to:
  /// **'Provide a brief and meaningful description of the measurable type. Include any relevant details or context to clearly define its purpose and importance. \nExamples: \'Body weight measured in kilograms\''**
  String get settingsMeasurableShowCaseDescrTooltip;

  /// No description provided for @settingsMeasurableShowCaseNameTooltip.
  ///
  /// In en, this message translates to:
  /// **'Enter a clear and descriptive name for the measurable type.\nAvoid overly long names, and make it concise enough to identify the measurable type easily. \nExamples: \'Weight\', \'Blood Pressure\'.'**
  String get settingsMeasurableShowCaseNameTooltip;

  /// No description provided for @settingsMeasurableShowCasePrivateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Toggle this option to mark the measurable type as private. Private measurable types are only visible to you and help in organizing sensitive or personal data securely.'**
  String get settingsMeasurableShowCasePrivateTooltip;

  /// No description provided for @settingsMeasurableShowCaseUnitTooltip.
  ///
  /// In en, this message translates to:
  /// **'Enter a clear and concise unit abbreviation for the measurable type. This helps in identifying the unit of measurement easily.'**
  String get settingsMeasurableShowCaseUnitTooltip;

  /// No description provided for @settingsMeasurablesTitle.
  ///
  /// In en, this message translates to:
  /// **'Measurable Types'**
  String get settingsMeasurablesTitle;

  /// No description provided for @settingsMeasurableUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit abbreviation (optional):'**
  String get settingsMeasurableUnitLabel;

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

  /// No description provided for @settingsSpeechTitle.
  ///
  /// In en, this message translates to:
  /// **'Speech Settings'**
  String get settingsSpeechTitle;

  /// No description provided for @settingsSyncOutboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Outbox'**
  String get settingsSyncOutboxTitle;

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

  /// No description provided for @settingsTagsShowCaseDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove this tag permanently. This action cannot be undone.'**
  String get settingsTagsShowCaseDeleteTooltip;

  /// No description provided for @settingsTagsShowCaseHideTooltip.
  ///
  /// In en, this message translates to:
  /// **'Enable this option to hide this tag from suggestions. Use it for tags that are personal or not commonly needed.'**
  String get settingsTagsShowCaseHideTooltip;

  /// No description provided for @settingsTagsShowCaseNameTooltip.
  ///
  /// In en, this message translates to:
  /// **'Enter a clear and relevant name for the tag. Keep it short and descriptive so you can easily categorize your habits Examples: \"Health\", \"Productivity\", \"Mindfulness\".'**
  String get settingsTagsShowCaseNameTooltip;

  /// No description provided for @settingsTagsShowCasePrivateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Enable this option to make the tag private. Private tags are only visible to you and won\'t be shared with others.'**
  String get settingsTagsShowCasePrivateTooltip;

  /// No description provided for @settingsTagsShowCaseTypeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Select the type of tag to categorize it properly: \n[Tag]-> General categories like \'Health\' or \'Productivity\'. \n[Person]-> Use for tagging specific individuals. \n[Story]-> Attach tags to stories for better organization.'**
  String get settingsTagsShowCaseTypeTooltip;

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

  /// No description provided for @settingsThemingShowCaseDarkTooltip.
  ///
  /// In en, this message translates to:
  /// **'Choose the dark theme for a darker appearance.'**
  String get settingsThemingShowCaseDarkTooltip;

  /// No description provided for @settingsThemingShowCaseLightTooltip.
  ///
  /// In en, this message translates to:
  /// **'Choose the light theme for a brighter appearance.'**
  String get settingsThemingShowCaseLightTooltip;

  /// No description provided for @settingsThemingShowCaseModeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Select your preferred theme mode: Light, Dark, or Automatic.'**
  String get settingsThemingShowCaseModeTooltip;

  /// No description provided for @settingsThemingTitle.
  ///
  /// In en, this message translates to:
  /// **'Theming'**
  String get settingsThemingTitle;

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

  /// No description provided for @showcaseCloseButton.
  ///
  /// In en, this message translates to:
  /// **'close'**
  String get showcaseCloseButton;

  /// No description provided for @showcaseNextButton.
  ///
  /// In en, this message translates to:
  /// **'next'**
  String get showcaseNextButton;

  /// No description provided for @showcasePreviousButton.
  ///
  /// In en, this message translates to:
  /// **'previous'**
  String get showcasePreviousButton;

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
  /// **'YES, SYNC ALL'**
  String get syncEntitiesConfirm;

  /// No description provided for @syncEntitiesMessage.
  ///
  /// In en, this message translates to:
  /// **'This will sync all tags, measurables, and categories. Do you want to continue?'**
  String get syncEntitiesMessage;

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

  /// No description provided for @taskNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a name for the task'**
  String get taskNameHint;

  /// No description provided for @tasksFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'Tasks Filter'**
  String get tasksFilterTitle;

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

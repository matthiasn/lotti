// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get addActionAddAudioRecording => 'Grabación de audio';

  @override
  String get addActionAddChecklist => 'Lista de verificación';

  @override
  String get addActionAddEvent => 'Evento';

  @override
  String get addActionAddImageFromClipboard => 'Pegar imagen';

  @override
  String get addActionAddPhotos => 'Foto(s)';

  @override
  String get addActionAddScreenshot => 'Captura de pantalla';

  @override
  String get addActionAddTask => 'Tarea';

  @override
  String get addActionAddText => 'Entrada de texto';

  @override
  String get addActionAddTimer => 'Timer';

  @override
  String get addActionImportImage => 'Import Image';

  @override
  String get addActionAddTimeRecording => 'Entrada de temporizador';

  @override
  String get addAudioTitle => 'Grabación de audio';

  @override
  String get addHabitCommentLabel => 'Comentario';

  @override
  String get addHabitDateLabel => 'Completado a las';

  @override
  String get addMeasurementCommentLabel => 'Comentario';

  @override
  String get addMeasurementDateLabel => 'Observado a las';

  @override
  String get addMeasurementSaveButton => 'Guardar';

  @override
  String get addSurveyTitle => 'Llenar encuesta';

  @override
  String get aiAssistantActionItemSuggestions =>
      'Sugerencias de elementos de acción';

  @override
  String get aiAssistantAnalyzeImage => 'Analizar imagen';

  @override
  String get aiAssistantSummarizeTask => 'Resumir tarea';

  @override
  String get aiAssistantThinking => 'Pensando...';

  @override
  String get aiAssistantTitle => 'Asistente de IA';

  @override
  String get aiAssistantTranscribeAudio => 'Transcribir audio';

  @override
  String get aiConfigApiKeyEmptyError => 'API key cannot be empty';

  @override
  String get aiConfigApiKeyFieldLabel => 'API Key';

  @override
  String aiConfigAssociatedModelsRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count associated model$_temp0 removed';
  }

  @override
  String get aiConfigBaseUrlFieldLabel => 'Base URL';

  @override
  String get aiConfigCommentFieldLabel => 'Comment (Optional)';

  @override
  String get aiConfigCreateButtonLabel => 'Create Prompt';

  @override
  String get aiConfigDescriptionFieldLabel => 'Description (Optional)';

  @override
  String aiConfigFailedToLoadModels(String error) {
    return 'Failed to load models: $error';
  }

  @override
  String get aiConfigFailedToLoadModelsGeneric =>
      'Error al cargar modelos. Por favor, inténtalo de nuevo.';

  @override
  String get loggingFailedToLoad =>
      'Error al cargar registros. Por favor, inténtalo de nuevo.';

  @override
  String get loggingSearchFailed =>
      'Error en la búsqueda. Por favor, inténtalo de nuevo.';

  @override
  String get loggingFailedToLoadMore =>
      'Error al cargar más resultados. Por favor, inténtalo de nuevo.';

  @override
  String get aiConfigFailedToSaveMessage =>
      'Failed to save configuration. Please try again.';

  @override
  String get aiConfigInputDataTypesTitle => 'Required Input Data Types';

  @override
  String get aiConfigInputModalitiesFieldLabel => 'Input Modalities';

  @override
  String get aiConfigInputModalitiesTitle => 'Input Modalities';

  @override
  String get aiConfigInvalidUrlError => 'Please enter a valid URL';

  @override
  String get aiConfigListCascadeDeleteWarning =>
      'This will also delete all models associated with this provider.';

  @override
  String get aiConfigListDeleteConfirmCancel => 'CANCEL';

  @override
  String get aiConfigListDeleteConfirmDelete => 'DELETE';

  @override
  String aiConfigListDeleteConfirmMessage(String configName) {
    return 'Are you sure you want to delete \"$configName\"?';
  }

  @override
  String get aiConfigListDeleteConfirmTitle => 'Confirm Deletion';

  @override
  String get aiConfigListEmptyState =>
      'No configurations found. Add one to get started.';

  @override
  String aiConfigListErrorDeleting(String configName, String error) {
    return 'Error deleting $configName: $error';
  }

  @override
  String get aiConfigListErrorLoading => 'Error loading configurations';

  @override
  String aiConfigListItemDeleted(String configName) {
    return '$configName deleted';
  }

  @override
  String get aiConfigListUndoDelete => 'UNDO';

  @override
  String get aiConfigManageModelsButton => 'Manage Models';

  @override
  String aiConfigModelRemovedMessage(String modelName) {
    return '$modelName removed from prompt';
  }

  @override
  String get aiConfigModelsTitle => 'Available Models';

  @override
  String get aiConfigNameFieldLabel => 'Display Name';

  @override
  String get aiConfigNameTooShortError => 'Name must be at least 3 characters';

  @override
  String get aiConfigNoModelsAvailable =>
      'No AI models are configured yet. Please add one in settings.';

  @override
  String get aiConfigNoModelsSelected =>
      'No models selected. At least one model is required.';

  @override
  String get aiConfigNoProvidersAvailable =>
      'No API providers available. Please add an API provider first.';

  @override
  String get aiConfigNoSuitableModelsAvailable =>
      'No models meet the requirements for this prompt. Please configure models that support the required capabilities.';

  @override
  String get aiConfigOutputModalitiesFieldLabel => 'Output Modalities';

  @override
  String get aiConfigOutputModalitiesTitle => 'Output Modalities';

  @override
  String get aiConfigProviderDeletedSuccessfully =>
      'Provider deleted successfully';

  @override
  String get aiConfigProviderFieldLabel => 'Inference Provider';

  @override
  String get aiConfigProviderModelIdFieldLabel => 'Provider Model ID';

  @override
  String get aiConfigProviderModelIdTooShortError =>
      'ProviderModelId must be at least 3 characters';

  @override
  String get aiConfigProviderTypeFieldLabel => 'Provider Type';

  @override
  String get aiConfigReasoningCapabilityDescription =>
      'Model can perform step-by-step reasoning';

  @override
  String get aiConfigReasoningCapabilityFieldLabel => 'Reasoning Capability';

  @override
  String get aiConfigRequiredInputDataFieldLabel => 'Required Input Data';

  @override
  String get aiConfigResponseTypeFieldLabel => 'AI Response Type';

  @override
  String get aiConfigResponseTypeNotSelectedError =>
      'Please select a response type';

  @override
  String get aiConfigResponseTypeSelectHint => 'Select response type';

  @override
  String get aiConfigSelectInputDataTypesPrompt =>
      'Select required data types...';

  @override
  String get aiConfigSelectModalitiesPrompt => 'Select modalities';

  @override
  String get aiConfigSelectProviderModalTitle => 'Select Inference Provider';

  @override
  String get aiConfigSelectProviderNotFound => 'Inference Provider not found';

  @override
  String get aiConfigSelectProviderTypeModalTitle => 'Select Provider Type';

  @override
  String get aiConfigSelectResponseTypeTitle => 'Select AI Response Type';

  @override
  String get aiConfigSystemMessageFieldLabel => 'System Message';

  @override
  String get aiConfigUpdateButtonLabel => 'Update Prompt';

  @override
  String get aiConfigUseReasoningDescription =>
      'If enabled, the model will use its reasoning capabilities for this prompt.';

  @override
  String get aiConfigUseReasoningFieldLabel => 'Use Reasoning';

  @override
  String get aiConfigUserMessageEmptyError => 'User message cannot be empty';

  @override
  String get aiConfigUserMessageFieldLabel => 'User Message';

  @override
  String get aiFormCancel => 'Cancel';

  @override
  String get aiFormFixErrors => 'Please fix errors before saving';

  @override
  String get aiFormNoChanges => 'No unsaved changes';

  @override
  String get aiInferenceErrorAuthenticationMessage =>
      'Authentication failed. Please check your API key and ensure it is valid.';

  @override
  String get aiInferenceErrorAuthenticationTitle => 'Authentication Failed';

  @override
  String get aiInferenceErrorConnectionFailedMessage =>
      'Unable to connect to the AI service. Please check your internet connection and ensure the service is accessible.';

  @override
  String get aiInferenceErrorConnectionFailedTitle => 'Connection Failed';

  @override
  String get aiInferenceErrorInvalidRequestMessage =>
      'The request was invalid. Please check your configuration and try again.';

  @override
  String get aiInferenceErrorInvalidRequestTitle => 'Invalid Request';

  @override
  String get aiInferenceErrorRateLimitMessage =>
      'You have exceeded the rate limit. Please wait a moment before trying again.';

  @override
  String get aiInferenceErrorRateLimitTitle => 'Rate Limit Exceeded';

  @override
  String get aiInferenceErrorRetryButton => 'Try Again';

  @override
  String get aiInferenceErrorServerMessage =>
      'The AI service encountered an error. Please try again later.';

  @override
  String get aiInferenceErrorServerTitle => 'Server Error';

  @override
  String get aiInferenceErrorSuggestionsTitle => 'Suggestions:';

  @override
  String get aiInferenceErrorViewLogButton => 'View Log';

  @override
  String get aiInferenceErrorTimeoutMessage =>
      'The request took too long to complete. Please try again or check if the service is responding.';

  @override
  String get aiInferenceErrorTimeoutTitle => 'Request Timed Out';

  @override
  String get aiInferenceErrorUnknownMessage =>
      'An unexpected error occurred. Please try again.';

  @override
  String get aiInferenceErrorUnknownTitle => 'Error';

  @override
  String get aiProviderAnthropicDescription =>
      'Anthropic\'s Claude family of AI assistants';

  @override
  String get aiProviderAnthropicName => 'Anthropic Claude';

  @override
  String get aiProviderGeminiDescription => 'Google\'s Gemini AI models';

  @override
  String get aiProviderGeminiName => 'Google Gemini';

  @override
  String get aiProviderGemma3nDescription =>
      'Local Gemma 3n model with audio transcription capabilities';

  @override
  String get aiProviderGemma3nName => 'Gemma 3n (local)';

  @override
  String get aiProviderGenericOpenAiDescription =>
      'API compatible with OpenAI format';

  @override
  String get aiProviderGenericOpenAiName => 'OpenAI Compatible';

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
  String get aiProviderWhisperDescription =>
      'Local Whisper transcription with OpenAI-compatible API';

  @override
  String get aiProviderWhisperName => 'Whisper (local)';

  @override
  String get aiResponseTypeAudioTranscription => 'Audio Transcription';

  @override
  String get aiResponseTypeChecklistUpdates => 'Checklist Updates';

  @override
  String get aiResponseTypeImageAnalysis => 'Image Analysis';

  @override
  String get aiResponseTypePromptGeneration => 'Generated Prompt';

  @override
  String get aiResponseTypeTaskSummary => 'Task Summary';

  @override
  String get aiSettingsAddModelButton => 'Add Model';

  @override
  String get aiSettingsAddPromptButton => 'Add Prompt';

  @override
  String get aiSettingsAddProviderButton => 'Add Provider';

  @override
  String get aiSettingsClearAllFiltersTooltip => 'Clear all filters';

  @override
  String get aiSettingsClearFiltersButton => 'Limpiar';

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
  String get aiSettingsModalityAudio => 'Audio';

  @override
  String get aiSettingsModalityText => 'Text';

  @override
  String get aiSettingsModalityVision => 'Vision';

  @override
  String get aiSettingsNoModelsConfigured => 'No AI models configured';

  @override
  String get aiSettingsNoPromptsConfigured => 'No AI prompts configured';

  @override
  String get aiSettingsNoProvidersConfigured => 'No AI providers configured';

  @override
  String get aiSettingsPageTitle => 'AI Settings';

  @override
  String get aiSettingsReasoningLabel => 'Reasoning';

  @override
  String get aiSettingsSearchHint => 'Search AI configurations...';

  @override
  String get aiSettingsTabModels => 'Models';

  @override
  String get aiSettingsTabPrompts => 'Prompts';

  @override
  String get aiSettingsTabProviders => 'Providers';

  @override
  String get aiTaskSummaryRunning => 'Pensando en resumir la tarea...';

  @override
  String get aiTaskSummaryTitle => 'Resumen de tareas de IA';

  @override
  String aiTaskSummaryScheduled(String time) {
    return 'Summary in $time';
  }

  @override
  String get aiTaskSummaryCancelScheduled => 'Cancel scheduled summary';

  @override
  String get aiTaskSummaryTriggerNow => 'Generate summary now';

  @override
  String get apiKeyAddPageTitle => 'Add Provider';

  @override
  String get apiKeyEditLoadError => 'Failed to load API key configuration';

  @override
  String get apiKeyEditPageTitle => 'Edit Provider';

  @override
  String get apiKeyFormCreateButton => 'Create';

  @override
  String get apiKeyFormUpdateButton => 'Update';

  @override
  String get apiKeysSettingsPageTitle => 'AI Inference Providers';

  @override
  String get cancelButton => 'Cancelar';

  @override
  String get categoryDeleteConfirm => 'SÍ, ELIMINAR ESTA CATEGORÍA';

  @override
  String get categoryDeleteQuestion => '¿Desea eliminar esta categoría?';

  @override
  String get categorySearchPlaceholder => 'Buscar categorías...';

  @override
  String get checklistAddItem => 'Agregar un nuevo elemento';

  @override
  String get checklistDelete => '¿Eliminar lista de verificación?';

  @override
  String get checklistItemDelete =>
      '¿Eliminar elemento de la lista de verificación?';

  @override
  String get checklistItemDeleteCancel => 'Cancelar';

  @override
  String get checklistItemDeleteConfirm => 'Confirmar';

  @override
  String get checklistItemDeleteWarning => 'Esta acción no se puede deshacer.';

  @override
  String get checklistItemDrag =>
      'Arrastre las sugerencias a la lista de verificación';

  @override
  String get checklistNoSuggestionsTitle =>
      'No hay elementos de acción sugeridos';

  @override
  String get checklistSuggestionsOutdated => 'Obsoleto';

  @override
  String get checklistSuggestionsRunning =>
      'Pensando en sugerencias sin seguimiento...';

  @override
  String get checklistSuggestionsTitle => 'Elementos de acción sugeridos';

  @override
  String get checklistExportAsMarkdown => 'Export checklist as Markdown';

  @override
  String get checklistMarkdownCopied => 'Checklist copied as Markdown';

  @override
  String get checklistShareHint => 'Long press to share';

  @override
  String get checklistNothingToExport => 'No items to export';

  @override
  String get checklistExportFailed => 'Export failed';

  @override
  String get checklistsTitle => 'Listas de verificación';

  @override
  String get checklistsReorder => 'Reorder';

  @override
  String get settingsResetHintsTitle => 'Reset In‑App Hints';

  @override
  String get settingsResetHintsSubtitle =>
      'Clear one‑time tips and onboarding hints';

  @override
  String get settingsResetHintsConfirmQuestion =>
      'Reset in‑app hints shown across the app?';

  @override
  String get settingsResetHintsConfirm => 'Confirm';

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
  String get colorLabel => 'Color:';

  @override
  String get colorPickerError => 'Color hexadecimal no válido';

  @override
  String get colorPickerHint => 'Ingrese el color hexadecimal o elija';

  @override
  String get completeHabitFailButton => 'Fallar';

  @override
  String get completeHabitSkipButton => 'Omitir';

  @override
  String get completeHabitSuccessButton => 'Éxito';

  @override
  String get configFlagAttemptEmbeddingDescription =>
      'Cuando está habilitado, la aplicación intentará generar incrustaciones para sus entradas para mejorar la búsqueda y las sugerencias de contenido relacionado.';

  @override
  String get configFlagAutoTranscribeDescription =>
      'Transcribir automáticamente grabaciones de audio en sus entradas. Esto requiere una conexión a Internet.';

  @override
  String get configFlagEnableAutoTaskTldrDescription =>
      'Generar automáticamente resúmenes para sus tareas para ayudarlo a comprender rápidamente su estado.';

  @override
  String get configFlagEnableCalendarPageDescription =>
      'Mostrar la página Calendario en la navegación principal. Vea y administre sus entradas en una vista de calendario.';

  @override
  String get configFlagEnableDashboardsPageDescription =>
      'Mostrar la página Paneles en la navegación principal. Vea sus datos e información en paneles personalizables.';

  @override
  String get configFlagEnableEventsDescription =>
      'Show the Events feature to create, track, and manage events in your journal.';

  @override
  String get configFlagEnableHabitsPageDescription =>
      'Mostrar la página Hábitos en la navegación principal. Rastree y administre sus hábitos diarios aquí.';

  @override
  String get configFlagEnableLoggingDescription =>
      'Habilitar el registro detallado para fines de depuración. Esto puede afectar el rendimiento.';

  @override
  String get configFlagEnableMatrixDescription =>
      'Habilitar la integración de Matrix para sincronizar sus entradas entre dispositivos y con otros usuarios de Matrix.';

  @override
  String get configFlagEnableNotifications => '¿Habilitar notificaciones?';

  @override
  String get configFlagEnableNotificationsDescription =>
      'Recibir notificaciones de recordatorios, actualizaciones y eventos importantes.';

  @override
  String get configFlagEnableTooltip =>
      'Habilitar información sobre herramientas';

  @override
  String get configFlagEnableTooltipDescription =>
      'Mostrar información sobre herramientas útil en toda la aplicación para guiarlo a través de las funciones.';

  @override
  String get configFlagPrivate => '¿Mostrar entradas privadas?';

  @override
  String get configFlagPrivateDescription =>
      'Habilite esto para que sus entradas sean privadas de forma predeterminada. Las entradas privadas solo son visibles para usted.';

  @override
  String get configFlagRecordLocation => 'Registrar ubicación';

  @override
  String get configFlagRecordLocationDescription =>
      'Registrar automáticamente su ubicación con las nuevas entradas. Esto ayuda con la organización y la búsqueda basadas en la ubicación.';

  @override
  String get configFlagResendAttachments => 'Reenviar archivos adjuntos';

  @override
  String get configFlagResendAttachmentsDescription =>
      'Activar para reenviar automáticamente las cargas de archivos adjuntos fallidas cuando se restablezca la conexión.';

  @override
  String get configFlagEnableAiStreaming =>
      'Habilitar streaming de IA para acciones de tareas';

  @override
  String get configFlagEnableAiStreamingDescription =>
      'Transmitir respuestas de IA para acciones relacionadas con tareas. Desactívelo para almacenar respuestas en búfer y mantener la interfaz más fluida.';

  @override
  String get configFlagEnableLogging => 'Habilitar registro';

  @override
  String get configFlagEnableMatrix => 'Habilitar sincronización Matrix';

  @override
  String get configFlagEnableHabitsPage => 'Habilitar página Hábitos';

  @override
  String get configFlagEnableDashboardsPage => 'Habilitar página Paneles';

  @override
  String get configFlagEnableCalendarPage => 'Habilitar página Calendario';

  @override
  String get configFlagEnableEvents => 'Enable Events';

  @override
  String get configFlagUseCloudInferenceDescription =>
      'Utiliza servicios de IA basados en la nube para funciones mejoradas. Esto requiere una conexión a Internet.';

  @override
  String get conflictsResolved => 'resueltos';

  @override
  String get conflictsUnresolved => 'sin resolver';

  @override
  String get conflictsResolveLocalVersion => 'Resolve with local version';

  @override
  String get conflictsResolveRemoteVersion => 'Resolve with remote version';

  @override
  String get conflictsCopyTextFromSync => 'Copy Text from Sync';

  @override
  String get createCategoryTitle => 'Crear categoría:';

  @override
  String get categoryCreationError =>
      'No se pudo crear la categoría. Por favor, inténtelo de nuevo.';

  @override
  String get createEntryLabel => 'Crear nueva entrada';

  @override
  String get createEntryTitle => 'Añadir';

  @override
  String get customColor => 'Custom Color';

  @override
  String get dashboardActiveLabel => 'Activo:';

  @override
  String get dashboardAddChartsTitle => 'Añadir gráficos:';

  @override
  String get dashboardAddHabitButton => 'Gráficos de hábitos';

  @override
  String get dashboardAddHabitTitle => 'Gráficos de hábitos';

  @override
  String get dashboardAddHealthButton => 'Gráficos de salud';

  @override
  String get dashboardAddHealthTitle => 'Gráficos de salud';

  @override
  String get dashboardAddMeasurementButton => 'Gráficos de medición';

  @override
  String get dashboardAddMeasurementTitle => 'Gráficos de medición';

  @override
  String get dashboardAddSurveyButton => 'Gráficos de encuesta';

  @override
  String get dashboardAddSurveyTitle => 'Gráficos de encuesta';

  @override
  String get dashboardAddWorkoutButton => 'Gráficos de entrenamiento';

  @override
  String get dashboardAddWorkoutTitle => 'Gráficos de entrenamiento';

  @override
  String get dashboardAggregationLabel => 'Tipo de agregación:';

  @override
  String get dashboardCategoryLabel => 'Categoría:';

  @override
  String get dashboardCopyHint => 'Guardar y copiar la configuración del panel';

  @override
  String get dashboardDeleteConfirm => 'SÍ, BORRAR ESTE PANEL';

  @override
  String get dashboardDeleteHint => 'Borrar panel';

  @override
  String get dashboardDeleteQuestion => '¿Quieres borrar este panel?';

  @override
  String get dashboardDescriptionLabel => 'Descripción (opcional):';

  @override
  String get dashboardNameLabel => 'Nombre del panel:';

  @override
  String get dashboardNotFound => 'Panel no encontrado';

  @override
  String get dashboardPrivateLabel => 'Privado:';

  @override
  String get done => 'Done';

  @override
  String get doneButton => 'Listo';

  @override
  String get editMenuTitle => 'Editar';

  @override
  String get editorPlaceholder => 'Introducir notas...';

  @override
  String get enhancedPromptFormAdditionalDetailsTitle => 'Additional Details';

  @override
  String get enhancedPromptFormAiResponseTypeSubtitle =>
      'Format of the expected response';

  @override
  String get enhancedPromptFormBasicConfigurationTitle => 'Basic Configuration';

  @override
  String get enhancedPromptFormConfigurationOptionsTitle =>
      'Configuration Options';

  @override
  String get enhancedPromptFormDescription =>
      'Create custom prompts that can be used with your AI models to generate specific types of responses';

  @override
  String get enhancedPromptFormDescriptionHelperText =>
      'Optional notes about this prompt\'s purpose and usage';

  @override
  String get enhancedPromptFormDisplayNameHelperText =>
      'A descriptive name for this prompt template';

  @override
  String get enhancedPromptFormPreconfiguredPromptDescription =>
      'Choose from ready-made prompt templates';

  @override
  String get enhancedPromptFormPromptConfigurationTitle =>
      'Prompt Configuration';

  @override
  String get enhancedPromptFormQuickStartDescription =>
      'Start with a pre-built template to save time';

  @override
  String get enhancedPromptFormQuickStartTitle => 'Quick Start';

  @override
  String get enhancedPromptFormRequiredInputDataSubtitle =>
      'Type of data this prompt expects';

  @override
  String get enhancedPromptFormSystemMessageHelperText =>
      'Instructions that define the AI\'s behavior and response style';

  @override
  String get enhancedPromptFormUserMessageHelperText => 'The main prompt text.';

  @override
  String get entryActions => 'Acciones';

  @override
  String get eventNameLabel => 'Evento:';

  @override
  String get fileMenuNewEllipsis => 'Nuevo ...';

  @override
  String get fileMenuNewEntry => 'Nueva entrada';

  @override
  String get fileMenuNewScreenshot => 'Captura de pantalla';

  @override
  String get fileMenuNewTask => 'Tarea';

  @override
  String get fileMenuTitle => 'Archivo';

  @override
  String get habitActiveFromLabel => 'Fecha de inicio';

  @override
  String get habitArchivedLabel => 'Archivado:';

  @override
  String get habitCategoryHint => 'Seleccionar categoría...';

  @override
  String get habitCategoryLabel => 'Categoría:';

  @override
  String get habitDashboardHint => 'Seleccionar panel...';

  @override
  String get habitDashboardLabel => 'Panel:';

  @override
  String get habitDeleteConfirm => 'SÍ, BORRAR ESTE HÁBITO';

  @override
  String get habitDeleteQuestion => '¿Quieres borrar este hábito?';

  @override
  String get habitPriorityLabel => 'Prioridad:';

  @override
  String get habitShowAlertAtLabel => 'Mostrar alerta a las';

  @override
  String get habitShowFromLabel => 'Mostrar desde';

  @override
  String get habitsCompletedHeader => 'Completado';

  @override
  String get habitsFilterAll => 'todos';

  @override
  String get habitsFilterCompleted => 'hecho';

  @override
  String get habitsFilterOpenNow => 'vencido';

  @override
  String get habitsFilterPendingLater => 'más tarde';

  @override
  String get habitsOpenHeader => 'Vencido ahora';

  @override
  String get habitsPendingLaterHeader => 'Más tarde hoy';

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
  String get journalCopyImageLabel => 'Copiar imagen';

  @override
  String get journalDateFromLabel => 'Fecha desde:';

  @override
  String get journalDateInvalid => 'Intervalo de fechas no válido';

  @override
  String get journalDateNowButton => 'Ahora';

  @override
  String get journalDateSaveButton => 'GUARDAR';

  @override
  String get journalDateToLabel => 'Fecha hasta:';

  @override
  String get journalDeleteConfirm => 'SÍ, BORRAR ESTA ENTRADA';

  @override
  String get journalDeleteHint => 'Borrar entrada';

  @override
  String get journalDeleteQuestion =>
      '¿Quieres borrar esta entrada del diario?';

  @override
  String get journalDurationLabel => 'Duración:';

  @override
  String get journalFavoriteTooltip => 'solo destacados';

  @override
  String get journalFlaggedTooltip => 'solo marcados';

  @override
  String get journalHideMapHint => 'Ocultar mapa';

  @override
  String get journalLinkFromHint => 'Vincular desde';

  @override
  String get journalLinkToHint => 'Vincular a';

  @override
  String get journalLinkedEntriesAiLabel =>
      'Mostrar entradas generadas por IA:';

  @override
  String get journalLinkedEntriesHiddenLabel => 'Mostrar entradas ocultas:';

  @override
  String get journalLinkedEntriesLabel => 'Entradas vinculadas';

  @override
  String get journalLinkedFromLabel => 'Vinculado de:';

  @override
  String get journalPrivateTooltip => 'solo privado';

  @override
  String get journalSearchHint => 'Buscar en el diario...';

  @override
  String get journalShareAudioHint => 'Compartir audio';

  @override
  String get journalSharePhotoHint => 'Compartir foto';

  @override
  String get journalShowMapHint => 'Mostrar mapa';

  @override
  String get journalTagPlusHint => 'Administrar etiquetas de entrada';

  @override
  String get journalTagsCopyHint => 'Copiar etiquetas';

  @override
  String get journalTagsLabel => 'Etiquetas:';

  @override
  String get journalTagsPasteHint => 'Pegar etiquetas';

  @override
  String get journalTagsRemoveHint => 'Eliminar etiqueta';

  @override
  String get journalToggleFlaggedTitle => 'Marcado';

  @override
  String get journalTogglePrivateTitle => 'Privado';

  @override
  String get journalToggleStarredTitle => 'Favorito';

  @override
  String get journalUnlinkConfirm => 'SÍ, DESVINCULAR ENTRADA';

  @override
  String get journalUnlinkHint => 'Desvincular';

  @override
  String get journalUnlinkQuestion =>
      '¿Está seguro de que desea desvincular esta entrada?';

  @override
  String get maintenanceDeleteDatabaseConfirm => 'YES, DELETE DATABASE';

  @override
  String maintenanceDeleteDatabaseQuestion(String databaseName) {
    return 'Are you sure you want to delete $databaseName Database?';
  }

  @override
  String get maintenanceDeleteEditorDb =>
      'Eliminar la base de datos de borradores del editor';

  @override
  String get maintenanceDeleteEditorDbDescription =>
      'Delete editor drafts database';

  @override
  String get maintenanceDeleteLoggingDb =>
      'Eliminar la base de datos de registro';

  @override
  String get maintenanceDeleteLoggingDbDescription => 'Delete logging database';

  @override
  String get maintenanceDeleteSyncDb =>
      'Eliminar la base de datos de sincronización';

  @override
  String get maintenanceDeleteSyncDbDescription => 'Delete sync database';

  @override
  String get maintenancePurgeDeleted => 'Purgar elementos eliminados';

  @override
  String get maintenancePurgeDeletedConfirm => 'Yes, purge all';

  @override
  String get maintenancePurgeDeletedDescription =>
      'Purge all deleted items permanently';

  @override
  String get maintenancePurgeDeletedMessage =>
      'Are you sure you want to purge all deleted items? This action cannot be undone.';

  @override
  String get maintenanceReSync => 'Volver a sincronizar mensajes';

  @override
  String get maintenanceReSyncDescription => 'Re-sync messages from server';

  @override
  String get maintenanceRecreateFts5 => 'Recrear el índice de texto completo';

  @override
  String get maintenanceRecreateFts5Confirm => 'YES, RECREATE INDEX';

  @override
  String get maintenanceRecreateFts5Description =>
      'Recreate full-text search index';

  @override
  String get maintenanceRecreateFts5Message =>
      'Are you sure you want to recreate the full-text index? This may take some time.';

  @override
  String get maintenancePopulateSequenceLog => 'Populate sync sequence log';

  @override
  String get maintenancePopulateSequenceLogConfirm => 'YES, POPULATE';

  @override
  String get maintenancePopulateSequenceLogDescription =>
      'Index existing entries for backfill support';

  @override
  String get maintenancePopulateSequenceLogMessage =>
      'This will scan all journal entries and add them to the sync sequence log. This enables backfill responses for entries created before this feature was added.';

  @override
  String maintenancePopulateSequenceLogComplete(int count) {
    return '$count entries indexed';
  }

  @override
  String get maintenanceSyncDefinitions =>
      'Sync tags, measurables, dashboards, habits, categories, AI settings';

  @override
  String get maintenanceSyncDefinitionsDescription =>
      'Sync tags, measurables, dashboards, habits, categories, and AI settings';

  @override
  String get backfillSettingsTitle => 'Backfill Sync';

  @override
  String get backfillSettingsSubtitle => 'Manage sync gap recovery';

  @override
  String get backfillSettingsInfo =>
      'Automatic backfill requests missing entries from the last 24 hours. Use manual backfill for older entries.';

  @override
  String get backfillToggleTitle => 'Automatic Backfill';

  @override
  String get backfillToggleEnabledDescription =>
      'Automatically request missing sync entries';

  @override
  String get backfillToggleDisabledDescription =>
      'Backfill disabled - useful on metered networks';

  @override
  String get backfillStatsTitle => 'Sync Statistics';

  @override
  String get backfillStatsRefresh => 'Refresh stats';

  @override
  String get backfillStatsNoData => 'No sync data available';

  @override
  String get backfillStatsTotalEntries => 'Total entries';

  @override
  String get backfillStatsReceived => 'Received';

  @override
  String get backfillStatsMissing => 'Missing';

  @override
  String get backfillStatsRequested => 'Requested';

  @override
  String get backfillStatsBackfilled => 'Backfilled';

  @override
  String get backfillStatsDeleted => 'Deleted';

  @override
  String get backfillStatsUnresolvable => 'Unresolvable';

  @override
  String backfillStatsHostsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count connected device$_temp0';
  }

  @override
  String get backfillManualTitle => 'Manual Backfill';

  @override
  String get backfillManualDescription =>
      'Request all missing entries regardless of age. Use this to recover older sync gaps.';

  @override
  String get backfillManualTrigger => 'Request Missing Entries';

  @override
  String get backfillManualProcessing => 'Processing...';

  @override
  String backfillManualSuccess(int count) {
    return '$count entries requested';
  }

  @override
  String get backfillReRequestTitle => 'Re-Request Pending';

  @override
  String get backfillReRequestDescription =>
      'Re-request entries that were requested but never received. Use this when responses are stuck.';

  @override
  String get backfillReRequestTrigger => 'Re-Request Pending Entries';

  @override
  String get backfillReRequestProcessing => 'Re-requesting...';

  @override
  String backfillReRequestSuccess(int count) {
    return '$count entries re-requested';
  }

  @override
  String get measurableDeleteConfirm => 'SÍ, ELIMINAR ESTE MEDIBLE';

  @override
  String get measurableDeleteQuestion =>
      '¿Desea eliminar este tipo de datos medibles?';

  @override
  String get measurableNotFound => 'Medible no encontrado';

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
  String get modelEditLoadError => 'Failed to load model configuration';

  @override
  String get modelEditPageTitle => 'Edit Model';

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
  String get modelsSettingsPageTitle => 'AI Models';

  @override
  String get navTabTitleCalendar => 'Calendario';

  @override
  String get navTabTitleHabits => 'Hábitos';

  @override
  String get navTabTitleInsights => 'Paneles';

  @override
  String get navTabTitleJournal => 'Diario';

  @override
  String get navTabTitleSettings => 'Ajustes';

  @override
  String get navTabTitleTasks => 'Tareas';

  @override
  String get outboxMonitorLabelAll => 'todos';

  @override
  String get outboxMonitorLabelError => 'error';

  @override
  String get outboxMonitorLabelPending => 'pendiente';

  @override
  String get outboxMonitorLabelSent => 'enviado';

  @override
  String get outboxMonitorLabelSuccess => 'success';

  @override
  String get outboxMonitorNoAttachment => 'sin archivo adjunto';

  @override
  String get outboxMonitorRetriesLabel => 'Retries';

  @override
  String get outboxMonitorRetries => 'reintentos';

  @override
  String get outboxMonitorRetry => 'reintentar';

  @override
  String get outboxMonitorSubjectLabel => 'Subject';

  @override
  String get outboxMonitorAttachmentLabel => 'Attachment';

  @override
  String get outboxMonitorRetryConfirmMessage => 'Retry this sync item now?';

  @override
  String get outboxMonitorRetryConfirmLabel => 'Retry Now';

  @override
  String get outboxMonitorRetryQueued => 'Retry scheduled';

  @override
  String get outboxMonitorRetryFailed => 'Retry failed. Please try again.';

  @override
  String get outboxMonitorDelete => 'delete';

  @override
  String get outboxMonitorDeleteConfirmMessage =>
      'Are you sure you want to delete this sync item? This action cannot be undone.';

  @override
  String get outboxMonitorDeleteConfirmLabel => 'Delete';

  @override
  String get outboxMonitorDeleteSuccess => 'Item deleted';

  @override
  String get outboxMonitorDeleteFailed => 'Delete failed. Please try again.';

  @override
  String get outboxMonitorEmptyTitle => 'Outbox is clear';

  @override
  String get outboxMonitorEmptyDescription =>
      'There are no sync items in this view.';

  @override
  String get outboxMonitorSwitchLabel => 'habilitado';

  @override
  String get syncListPayloadKindLabel => 'Payload';

  @override
  String get syncListUnknownPayload => 'Unknown payload';

  @override
  String get syncPayloadJournalEntity => 'Journal entry';

  @override
  String get syncPayloadEntityDefinition => 'Entity definition';

  @override
  String get syncPayloadTagEntity => 'Tag entity';

  @override
  String get syncPayloadEntryLink => 'Entry link';

  @override
  String get syncPayloadAiConfig => 'AI configuration';

  @override
  String get syncPayloadAiConfigDelete => 'AI configuration delete';

  @override
  String get syncPayloadThemingSelection => 'Theming selection';

  @override
  String get syncPayloadBackfillRequest => 'Backfill request';

  @override
  String get syncPayloadBackfillResponse => 'Backfill response';

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
  String get conflictsEmptyTitle => 'No conflicts detected';

  @override
  String get conflictsEmptyDescription =>
      'Everything is in sync right now. Resolved items stay available in the other filter.';

  @override
  String get conflictEntityLabel => 'Entity';

  @override
  String get conflictIdLabel => 'ID';

  @override
  String get promptAddOrRemoveModelsButton => 'Add or Remove Models';

  @override
  String get promptAddPageTitle => 'Add Prompt';

  @override
  String get promptAiResponseTypeDescription =>
      'Format of the expected response';

  @override
  String get promptAiResponseTypeLabel => 'AI Response Type';

  @override
  String get promptBehaviorDescription =>
      'Configure how the prompt processes and responds';

  @override
  String get promptBehaviorTitle => 'Prompt Behavior';

  @override
  String get promptCancelButton => 'Cancel';

  @override
  String get promptContentDescription => 'Define the system and user prompts';

  @override
  String get promptContentTitle => 'Prompt Content';

  @override
  String get promptDefaultModelBadge => 'Default';

  @override
  String get promptDescriptionHint => 'Describe this prompt';

  @override
  String get promptDescriptionLabel => 'Description';

  @override
  String get promptDetailsDescription => 'Basic information about this prompt';

  @override
  String get promptDetailsTitle => 'Prompt Details';

  @override
  String get promptDisplayNameHint => 'Enter a friendly name';

  @override
  String get promptDisplayNameLabel => 'Display Name';

  @override
  String get promptEditLoadError => 'Failed to load prompt';

  @override
  String get promptEditPageTitle => 'Edit Prompt';

  @override
  String get promptErrorLoadingModel => 'Error loading model';

  @override
  String get promptGoBackButton => 'Go Back';

  @override
  String get promptLoadingModel => 'Loading model...';

  @override
  String get promptModelSelectionDescription =>
      'Choose compatible models for this prompt';

  @override
  String get promptModelSelectionTitle => 'Model Selection';

  @override
  String get promptNoModelsSelectedError =>
      'No models selected. Select at least one model.';

  @override
  String get promptReasoningModeDescription =>
      'Enable for prompts requiring deep thinking';

  @override
  String get promptReasoningModeLabel => 'Reasoning Mode';

  @override
  String get promptRequiredInputDataDescription =>
      'Type of data this prompt expects';

  @override
  String get promptRequiredInputDataLabel => 'Required Input Data';

  @override
  String get promptSaveButton => 'Save Prompt';

  @override
  String get promptSelectInputTypeHint => 'Select input type';

  @override
  String get promptSelectModelsButton => 'Select Models';

  @override
  String get promptSelectResponseTypeHint => 'Select response type';

  @override
  String get promptSelectionModalTitle => 'Select Preconfigured Prompt';

  @override
  String get promptSetDefaultButton => 'Set Default';

  @override
  String get promptSettingsPageTitle => 'AI Prompts';

  @override
  String get promptSystemPromptHint => 'Enter the system prompt...';

  @override
  String get promptSystemPromptLabel => 'System Prompt';

  @override
  String get promptTryAgainMessage => 'Please try again or contact support';

  @override
  String get promptUsePreconfiguredButton => 'Use Preconfigured Prompt';

  @override
  String get promptUserPromptHint => 'Enter the user prompt...';

  @override
  String get promptUserPromptLabel => 'User Prompt';

  @override
  String get promptGenerationCardTitle => 'AI Coding Prompt';

  @override
  String get promptGenerationCopyTooltip => 'Copy prompt to clipboard';

  @override
  String get promptGenerationCopyButton => 'Copy Prompt';

  @override
  String get promptGenerationCopiedSnackbar => 'Prompt copied to clipboard';

  @override
  String get promptGenerationExpandTooltip => 'Show full prompt';

  @override
  String get promptGenerationFullPromptLabel => 'Full Prompt:';

  @override
  String get aiResponseTypeImagePromptGeneration => 'Prompt de Imagen';

  @override
  String get imagePromptGenerationCardTitle => 'Prompt de Imagen AI';

  @override
  String get imagePromptGenerationCopyTooltip =>
      'Copiar prompt de imagen al portapapeles';

  @override
  String get imagePromptGenerationCopyButton => 'Copiar Prompt';

  @override
  String get imagePromptGenerationCopiedSnackbar =>
      'Prompt de imagen copiado al portapapeles';

  @override
  String get imagePromptGenerationExpandTooltip => 'Mostrar prompt completo';

  @override
  String get imagePromptGenerationFullPromptLabel =>
      'Prompt de Imagen Completo:';

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
  String get aiResponseDeleteTitle => 'Delete AI Response';

  @override
  String get aiResponseDeleteWarning =>
      'Are you sure you want to delete this AI response? This cannot be undone.';

  @override
  String get aiResponseDeleteCancel => 'Cancel';

  @override
  String get aiResponseDeleteConfirm => 'Delete';

  @override
  String get aiResponseDeleteError =>
      'Failed to delete AI response. Please try again.';

  @override
  String get saveButtonLabel => 'Save';

  @override
  String get saveLabel => 'Guardar';

  @override
  String get searchHint => 'Buscar...';

  @override
  String get settingThemingDark => 'Tema oscuro';

  @override
  String get settingThemingLight => 'Tema claro';

  @override
  String get settingsAboutTitle => 'Acerca de Lotti';

  @override
  String get settingsAboutAppTagline => 'Tu diario personal';

  @override
  String get settingsAboutAppInformation => 'Información de la aplicación';

  @override
  String get settingsAboutYourData => 'Tus datos';

  @override
  String get settingsAboutCredits => 'Créditos';

  @override
  String get settingsAboutBuiltWithFlutter =>
      'Desarrollado con Flutter y amor por el diario personal.';

  @override
  String get settingsAboutThankYou => '¡Gracias por usar Lotti!';

  @override
  String get settingsAboutVersion => 'Versión';

  @override
  String get settingsAboutPlatform => 'Plataforma';

  @override
  String get settingsAboutBuildType => 'Tipo de compilación';

  @override
  String get settingsAboutJournalEntries => 'Entradas del diario';

  @override
  String get settingsAdvancedTitle => 'Configuración avanzada';

  @override
  String get settingsAdvancedMatrixSyncSubtitle =>
      'Configurar y gestionar ajustes de sincronización de Matrix';

  @override
  String get settingsAdvancedOutboxSubtitle =>
      'Ver y gestionar elementos esperando ser sincronizados';

  @override
  String get settingsAdvancedConflictsSubtitle =>
      'Resolver conflictos de sincronización para asegurar consistencia de datos';

  @override
  String get settingsAdvancedLogsSubtitle =>
      'Acceder y revisar registros de aplicación para depuración';

  @override
  String get settingsAdvancedHealthImportSubtitle =>
      'Importar datos relacionados con la salud desde fuentes externas';

  @override
  String get settingsAdvancedMaintenanceSubtitle =>
      'Realizar tareas de mantenimiento para optimizar el rendimiento de la aplicación';

  @override
  String get settingsAdvancedAboutSubtitle =>
      'Aprende más sobre la aplicación Lotti';

  @override
  String get settingsAiApiKeys => 'AI Inference Providers';

  @override
  String get settingsAiModels => 'AI Models';

  @override
  String get settingsCategoriesDetailsLabel => 'Category Details';

  @override
  String get settingsCategoriesDuplicateError => 'La categoría ya existe';

  @override
  String get settingsCategoriesNameLabel => 'Nombre de la categoría:';

  @override
  String get settingsCategoriesTitle => 'Categorías';

  @override
  String get settingsLabelsTitle => 'Labels';

  @override
  String get settingsLabelsSubtitle => 'Organize tasks with colored labels';

  @override
  String get settingsCategoriesAddTooltip => 'Add Category';

  @override
  String get settingsLabelsSearchHint => 'Search labels…';

  @override
  String get settingsLabelsEmptyState => 'No labels yet';

  @override
  String get settingsLabelsEmptyStateHint =>
      'Tap the + button to create your first label.';

  @override
  String get settingsLabelsErrorLoading => 'Failed to load labels';

  @override
  String get settingsCategoriesEmptyState => 'No categories found';

  @override
  String get settingsCategoriesEmptyStateHint =>
      'Create a category to organize your entries';

  @override
  String get settingsCategoriesErrorLoading => 'Error loading categories';

  @override
  String get settingsCategoriesHasDefaultLanguage => 'Default language';

  @override
  String get settingsCategoriesHasAiSettings => 'AI settings';

  @override
  String get settingsCategoriesHasAutomaticPrompts => 'Automatic AI';

  @override
  String get categoryNotFound => 'Category not found';

  @override
  String get saveSuccessful => 'Saved successfully';

  @override
  String get basicSettings => 'Basic Settings';

  @override
  String get categoryDefaultLanguageDescription =>
      'Set a default language for tasks in this category';

  @override
  String get aiModelSettings => 'AI Model Settings';

  @override
  String get categoryAiModelDescription =>
      'Control which AI prompts can be used with this category';

  @override
  String get automaticPrompts => 'Automatic Prompts';

  @override
  String get categoryAutomaticPromptsDescription =>
      'Configure prompts that run automatically for different content types';

  @override
  String get enterCategoryName => 'Enter category name';

  @override
  String get categoryNameRequired => 'Category name is required';

  @override
  String get settingsLabelsCreateTitle => 'Create label';

  @override
  String get settingsLabelsEditTitle => 'Edit label';

  @override
  String get settingsLabelsNameLabel => 'Label name';

  @override
  String get settingsLabelsNameHint => 'Bug, Release blocker, Sync…';

  @override
  String get settingsLabelsNameRequired => 'Label name must not be empty.';

  @override
  String get settingsLabelsDescriptionLabel => 'Description (optional)';

  @override
  String get settingsLabelsDescriptionHint =>
      'Explain when to apply this label';

  @override
  String get settingsLabelsColorHeading => 'Select a color';

  @override
  String get settingsLabelsColorSubheading => 'Quick presets';

  @override
  String get settingsLabelsCategoriesHeading => 'Applicable categories';

  @override
  String get settingsLabelsCategoriesAdd => 'Add category';

  @override
  String get settingsLabelsCategoriesRemoveTooltip => 'Remove';

  @override
  String get settingsLabelsCategoriesNone => 'Applies to all categories';

  @override
  String get settingsLabelsPrivateTitle => 'Private label';

  @override
  String get settingsLabelsPrivateDescription =>
      'Private labels only appear when “Show private entries” is enabled.';

  @override
  String get settingsLabelsCreateSuccess => 'Label created successfully';

  @override
  String get settingsLabelsUpdateSuccess => 'Label updated';

  @override
  String get settingsLabelsDeleteConfirmTitle => 'Delete label';

  @override
  String settingsLabelsDeleteConfirmMessage(Object labelName) {
    return 'Are you sure you want to delete \"$labelName\"? Tasks with this label will lose the assignment.';
  }

  @override
  String settingsLabelsDeleteSuccess(Object labelName) {
    return 'Label \"$labelName\" deleted';
  }

  @override
  String get settingsLabelsDeleteCancel => 'Cancel';

  @override
  String get settingsLabelsDeleteConfirmAction => 'Delete';

  @override
  String get settingsLabelsActionsTooltip => 'Label actions';

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
  String get selectColor => 'Select Color';

  @override
  String get selectButton => 'Select';

  @override
  String get privateLabel => 'Private';

  @override
  String get categoryPrivateDescription =>
      'Hide this category when private mode is enabled';

  @override
  String get activeLabel => 'Active';

  @override
  String get categoryActiveDescription =>
      'Inactive categories won\'t appear in selection lists';

  @override
  String get favoriteLabel => 'Favorite';

  @override
  String get categoryFavoriteDescription => 'Mark this category as a favorite';

  @override
  String get defaultLanguage => 'Default Language';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get noDefaultLanguage => 'No default language';

  @override
  String get noPromptsAvailable => 'No prompts available';

  @override
  String get createPromptsFirst =>
      'Create AI prompts first to configure them here';

  @override
  String get selectAllowedPrompts =>
      'Select which prompts are allowed for this category';

  @override
  String get audioRecordings => 'Audio Recordings';

  @override
  String get checklistUpdates => 'Checklist Updates';

  @override
  String get images => 'Images';

  @override
  String get entryTypeLabelTask => 'Task';

  @override
  String get entryTypeLabelJournalEntry => 'Text';

  @override
  String get entryTypeLabelJournalEvent => 'Event';

  @override
  String get entryTypeLabelJournalAudio => 'Audio';

  @override
  String get entryTypeLabelJournalImage => 'Photo';

  @override
  String get entryTypeLabelMeasurementEntry => 'Measured';

  @override
  String get entryTypeLabelSurveyEntry => 'Survey';

  @override
  String get entryTypeLabelWorkoutEntry => 'Workout';

  @override
  String get entryTypeLabelHabitCompletionEntry => 'Habit';

  @override
  String get entryTypeLabelQuantitativeEntry => 'Health';

  @override
  String get entryTypeLabelChecklist => 'Checklist';

  @override
  String get entryTypeLabelChecklistItem => 'To Do';

  @override
  String get entryTypeLabelAiResponse => 'AI Response';

  @override
  String get taskSummaries => 'Task Summaries';

  @override
  String get noPromptsForType => 'No prompts available for this type';

  @override
  String get errorLoadingPrompts => 'Error loading prompts';

  @override
  String get categoryDeleteTitle => 'Delete Category?';

  @override
  String get categoryDeleteConfirmation =>
      'This action cannot be undone. All entries in this category will remain but will no longer be categorized.';

  @override
  String get speechDictionaryLabel => 'Speech Dictionary';

  @override
  String get speechDictionaryHint => 'macOS; Kirkjubæjarklaustur; Claude Code';

  @override
  String get speechDictionaryHelper =>
      'Semicolon-separated terms (max 50 chars) for better speech recognition';

  @override
  String speechDictionaryWarning(Object count) {
    return 'Large dictionary ($count terms) may increase API costs';
  }

  @override
  String get speechDictionarySectionTitle => 'Speech Recognition';

  @override
  String get speechDictionarySectionDescription =>
      'Add terms that are often misspelled by speech recognition (names, places, technical terms)';

  @override
  String get addToDictionary => 'Add to Dictionary';

  @override
  String get addToDictionarySuccess => 'Term added to dictionary';

  @override
  String get addToDictionaryNoCategory =>
      'Cannot add to dictionary: task has no category';

  @override
  String get addToDictionaryDuplicate => 'Term already exists in dictionary';

  @override
  String get addToDictionaryTooLong => 'Term too long (max 50 characters)';

  @override
  String get addToDictionarySaveFailed => 'Failed to save dictionary';

  @override
  String get deleteButton => 'Delete';

  @override
  String get saveButton => 'Save';

  @override
  String get createButton => 'Create';

  @override
  String get settingsConflictsResolutionTitle =>
      'Resolución de Conflictos de Sincronización';

  @override
  String get settingsConflictsTitle => 'Conflictos de Sincronización';

  @override
  String get settingsDashboardDetailsLabel => 'Dashboard Details';

  @override
  String get settingsDashboardSaveLabel => 'Save';

  @override
  String get settingsDashboardsTitle => 'Paneles';

  @override
  String get settingsFlagsTitle => 'Configuración de indicadores';

  @override
  String get settingsHabitsDeleteTooltip => 'Eliminar hábito';

  @override
  String get settingsHabitsDescriptionLabel => 'Descripción (opcional):';

  @override
  String get settingsHabitsDetailsLabel => 'Habit Details';

  @override
  String get settingsHabitsNameLabel => 'Nombre del hábito:';

  @override
  String get settingsHabitsPrivateLabel => 'Privado:';

  @override
  String get settingsHabitsSaveLabel => 'Guardar';

  @override
  String get settingsHabitsTitle => 'Hábitos';

  @override
  String get settingsHealthImportFromDate => 'Inicio';

  @override
  String get settingsHealthImportTitle => 'Importación de salud';

  @override
  String get settingsHealthImportToDate => 'Fin';

  @override
  String get settingsLogsTitle => 'Registros';

  @override
  String get settingsMaintenanceTitle => 'Mantenimiento';

  @override
  String get settingsMatrixAcceptVerificationLabel =>
      'El otro dispositivo muestra emojis, continuar';

  @override
  String get settingsMatrixCancel => 'Cancelar';

  @override
  String get settingsMatrixCancelVerificationLabel => 'Cancelar verificación';

  @override
  String get settingsMatrixContinueVerificationLabel =>
      'Aceptar en el otro dispositivo para continuar';

  @override
  String get settingsMatrixDeleteLabel => 'Eliminar';

  @override
  String get settingsMatrixDone => 'Listo';

  @override
  String get settingsMatrixEnterValidUrl => 'Introduce una URL válida';

  @override
  String get settingsMatrixHomeServerLabel => 'Servidor doméstico';

  @override
  String get settingsMatrixHomeserverConfigTitle =>
      'Configuración del servidor doméstico Matrix';

  @override
  String get settingsMatrixListUnverifiedLabel => 'Dispositivos no verificados';

  @override
  String get settingsMatrixLoginButtonLabel => 'Iniciar sesión';

  @override
  String get settingsMatrixLoginFailed => 'Error al iniciar sesión';

  @override
  String get settingsMatrixLogoutButtonLabel => 'Cerrar sesión';

  @override
  String get settingsMatrixNextPage => 'Página siguiente';

  @override
  String get settingsMatrixNoUnverifiedLabel =>
      'No hay dispositivos sin verificar';

  @override
  String get settingsMatrixPasswordLabel => 'Contraseña';

  @override
  String get settingsMatrixPasswordTooShort => 'Contraseña demasiado corta';

  @override
  String get settingsMatrixPreviousPage => 'Página anterior';

  @override
  String get settingsMatrixQrTextPage =>
      'Escanea este código QR para invitar al dispositivo a una sala de sincronización.';

  @override
  String get settingsMatrixRoomInviteTitle => 'Room invite';

  @override
  String settingsMatrixRoomInviteMessage(String roomId, String senderId) {
    return 'Invite to room $roomId from $senderId. Accept?';
  }

  @override
  String get settingsMatrixAccept => 'Accept';

  @override
  String get settingsMatrixRoomConfigTitle =>
      'Configuración de la sala de sincronización Matrix';

  @override
  String get settingsMatrixStartVerificationLabel => 'Iniciar verificación';

  @override
  String get settingsMatrixStatsTitle => 'Estadísticas de Matrix';

  @override
  String get settingsMatrixSentMessagesLabel => 'Sent messages:';

  @override
  String get settingsMatrixMessageType => 'Message Type';

  @override
  String get settingsMatrixCount => 'Count';

  @override
  String get settingsMatrixMetric => 'Metric';

  @override
  String get settingsMatrixValue => 'Value';

  @override
  String get settingsMatrixMetrics => 'Sync Metrics';

  @override
  String get settingsMatrixMetricsNoData => 'Sync Metrics: no data';

  @override
  String get settingsMatrixLastUpdated => 'Last updated:';

  @override
  String get settingsMatrixRefresh => 'Refresh';

  @override
  String get settingsMatrixTitle => 'Ajustes de sincronización de Matrix';

  @override
  String get settingsMatrixMaintenanceTitle => 'Maintenance';

  @override
  String get settingsMatrixMaintenanceSubtitle =>
      'Run Matrix maintenance tasks and recovery tools';

  @override
  String get settingsMatrixSubtitle => 'Configure end-to-end encrypted sync';

  @override
  String get settingsMatrixUnverifiedDevicesPage =>
      'Dispositivos no verificados';

  @override
  String get settingsMatrixUserLabel => 'Usuario';

  @override
  String get settingsMatrixUserNameTooShort =>
      'Nombre de usuario demasiado corto';

  @override
  String get settingsMatrixVerificationCancelledLabel =>
      'Cancelado en el otro dispositivo...';

  @override
  String get settingsMatrixVerificationSuccessConfirm => 'Entendido';

  @override
  String settingsMatrixVerificationSuccessLabel(
      String deviceName, String deviceID) {
    return 'Has verificado correctamente $deviceName ($deviceID)';
  }

  @override
  String get settingsMatrixVerifyConfirm =>
      'Confirma en el otro dispositivo que los emojis a continuación se muestran en ambos dispositivos, en el mismo orden:';

  @override
  String get settingsMatrixVerifyIncomingConfirm =>
      'Confirma que los emojis a continuación se muestran en ambos dispositivos, en el mismo orden:';

  @override
  String get settingsMatrixVerifyLabel => 'Verificar';

  @override
  String get settingsMeasurableAggregationLabel =>
      'Tipo de agregación predeterminado (opcional):';

  @override
  String get settingsMeasurableDeleteTooltip => 'Eliminar tipo de medición';

  @override
  String get settingsMeasurableDescriptionLabel => 'Descripción (opcional):';

  @override
  String get settingsMeasurableDetailsLabel => 'Measurable Details';

  @override
  String get settingsMeasurableFavoriteLabel => 'Favorito: ';

  @override
  String get settingsMeasurableNameLabel => 'Nombre de la medición:';

  @override
  String get settingsMeasurablePrivateLabel => 'Privado: ';

  @override
  String get settingsMeasurableSaveLabel => 'Guardar';

  @override
  String get settingsMeasurableUnitLabel =>
      'Abreviatura de la unidad (opcional):';

  @override
  String get settingsMeasurablesTitle => 'Tipos de medición';

  @override
  String get settingsSpeechAudioWithoutTranscript =>
      'Entradas de audio sin transcripción:';

  @override
  String get settingsSpeechAudioWithoutTranscriptButton =>
      'Buscar y transcribir';

  @override
  String get settingsSpeechLastActivity => 'Última actividad de transcripción:';

  @override
  String get settingsSpeechModelSelectionTitle =>
      'Modelo de reconocimiento de voz Whisper:';

  @override
  String get settingsSyncOutboxTitle => 'Bandeja de salida de sincronización';

  @override
  String get syncNotLoggedInToast => 'Sync is not logged in';

  @override
  String get settingsSyncSubtitle => 'Configure sync and view stats';

  @override
  String get settingsSyncStatsSubtitle => 'Inspect sync pipeline metrics';

  @override
  String get matrixStatsError => 'Error loading Matrix stats';

  @override
  String get settingsTagsDeleteTooltip => 'Eliminar etiqueta';

  @override
  String get settingsTagsDetailsLabel => 'Tags Details';

  @override
  String get settingsTagsHideLabel => 'Ocultar de las sugerencias:';

  @override
  String get settingsTagsPrivateLabel => 'Privado:';

  @override
  String get settingsTagsSaveLabel => 'Guardar';

  @override
  String get settingsTagsTagName => 'Etiqueta:';

  @override
  String get settingsTagsTitle => 'Etiquetas';

  @override
  String get settingsTagsTypeLabel => 'Tipo de etiqueta:';

  @override
  String get settingsTagsTypePerson => 'PERSONA';

  @override
  String get settingsTagsTypeStory => 'HISTORIA';

  @override
  String get settingsTagsTypeTag => 'ETIQUETA';

  @override
  String get settingsThemingAutomatic => 'Automático';

  @override
  String get settingsThemingDark => 'Apariencia oscura';

  @override
  String get settingsThemingLight => 'Apariencia clara';

  @override
  String get settingsThemingTitle => 'Temas';

  @override
  String get speechModalAddTranscription => 'Añadir transcripción';

  @override
  String get speechModalSelectLanguage => 'Seleccionar idioma';

  @override
  String get speechModalTitle => 'Reconocimiento de voz';

  @override
  String get speechModalTranscriptionProgress => 'Progreso de la transcripción';

  @override
  String get syncDeleteConfigConfirm => 'SÍ, ESTOY SEGURO';

  @override
  String get syncDeleteConfigQuestion =>
      '¿Desea eliminar la configuración de sincronización?';

  @override
  String get syncEntitiesConfirm => 'START SYNC';

  @override
  String get syncEntitiesMessage => 'Elige los datos que quieres sincronizar.';

  @override
  String get syncEntitiesSuccessDescription => 'Todo está al día.';

  @override
  String get syncEntitiesSuccessTitle => 'Sincronización completada';

  @override
  String get syncStepAiSettings => 'Configuración de IA';

  @override
  String get syncStepCategories => 'Categories';

  @override
  String get syncStepComplete => 'Complete';

  @override
  String get syncStepDashboards => 'Dashboards';

  @override
  String get syncStepHabits => 'Habits';

  @override
  String get syncStepMeasurables => 'Measurables';

  @override
  String get syncStepLabels => 'Labels';

  @override
  String get syncStepTags => 'Tags';

  @override
  String get taskCategoryAllLabel => 'todos';

  @override
  String get taskCategoryLabel => 'Categoría:';

  @override
  String get taskCategoryUnassignedLabel => 'sin asignar';

  @override
  String get taskEstimateLabel => 'Estimación:';

  @override
  String get taskNoEstimateLabel => 'Sin estimación';

  @override
  String get taskNameHint => 'Introduzca un nombre para la tarea';

  @override
  String get taskStatusAll => 'Todos';

  @override
  String get taskStatusBlocked => 'Bloqueado';

  @override
  String get taskStatusDone => 'Completado';

  @override
  String get taskStatusGroomed => 'Preparado';

  @override
  String get taskStatusInProgress => 'En curso';

  @override
  String get taskStatusLabel => 'Estado:';

  @override
  String get taskStatusOnHold => 'En espera';

  @override
  String get taskStatusOpen => 'Abierto';

  @override
  String get taskStatusRejected => 'Rechazado';

  @override
  String get taskLanguageLabel => 'Idioma:';

  @override
  String get taskLanguageArabic => 'Árabe';

  @override
  String get taskLanguageBengali => 'Bengalí';

  @override
  String get taskLanguageBulgarian => 'Búlgaro';

  @override
  String get taskLanguageChinese => 'Chino';

  @override
  String get taskLanguageCroatian => 'Croata';

  @override
  String get taskLanguageCzech => 'Checo';

  @override
  String get taskLanguageDanish => 'Danés';

  @override
  String get taskLanguageDutch => 'Holandés';

  @override
  String get taskLanguageEnglish => 'Inglés';

  @override
  String get taskLanguageEstonian => 'Estonio';

  @override
  String get taskLanguageFinnish => 'Finlandés';

  @override
  String get taskLanguageFrench => 'Francés';

  @override
  String get taskLanguageGerman => 'Alemán';

  @override
  String get taskLanguageGreek => 'Griego';

  @override
  String get taskLanguageHebrew => 'Hebreo';

  @override
  String get taskLanguageHindi => 'Hindi';

  @override
  String get taskLanguageHungarian => 'Húngaro';

  @override
  String get taskLanguageIndonesian => 'Indonesio';

  @override
  String get taskLanguageItalian => 'Italiano';

  @override
  String get taskLanguageJapanese => 'Japonés';

  @override
  String get taskLanguageKorean => 'Coreano';

  @override
  String get taskLanguageLatvian => 'Letón';

  @override
  String get taskLanguageLithuanian => 'Lituano';

  @override
  String get taskLanguageNorwegian => 'Noruego';

  @override
  String get taskLanguagePolish => 'Polaco';

  @override
  String get taskLanguagePortuguese => 'Portugués';

  @override
  String get taskLanguageRomanian => 'Rumano';

  @override
  String get taskLanguageRussian => 'Ruso';

  @override
  String get taskLanguageSerbian => 'Serbio';

  @override
  String get taskLanguageSlovak => 'Eslovaco';

  @override
  String get taskLanguageSlovenian => 'Esloveno';

  @override
  String get taskLanguageSpanish => 'Español';

  @override
  String get taskLanguageSwahili => 'Suajili';

  @override
  String get taskLanguageSwedish => 'Sueco';

  @override
  String get taskLanguageThai => 'Tailandés';

  @override
  String get taskLanguageTwi => 'Twi';

  @override
  String get taskLanguageTurkish => 'Turco';

  @override
  String get taskLanguageUkrainian => 'Ucraniano';

  @override
  String get taskLanguageIgbo => 'Igbo';

  @override
  String get taskLanguageNigerianPidgin => 'Pidgin nigeriano';

  @override
  String get taskLanguageYoruba => 'Yoruba';

  @override
  String get taskLanguageSearchPlaceholder => 'Buscar idiomas...';

  @override
  String get taskLanguageSelectedLabel => 'Idioma actual';

  @override
  String get taskLanguageVietnamese => 'Vietnamita';

  @override
  String get tasksFilterTitle => 'Filtro de tareas';

  @override
  String get tasksSortByLabel => 'Ordenar por';

  @override
  String get tasksSortByPriority => 'Prioridad';

  @override
  String get tasksSortByDate => 'Fecha';

  @override
  String get tasksSortByDueDate => 'Vencimiento';

  @override
  String get tasksSortByCreationDate => 'Creación';

  @override
  String get tasksShowCreationDate => 'Mostrar fecha de creación en tarjetas';

  @override
  String get tasksShowDueDate => 'Mostrar fecha de vencimiento en tarjetas';

  @override
  String get taskDueToday => 'Vence hoy';

  @override
  String get taskDueTomorrow => 'Vence mañana';

  @override
  String get taskDueYesterday => 'Venció ayer';

  @override
  String taskDueInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días',
      one: '1 día',
    );
    return 'Vence en $_temp0';
  }

  @override
  String taskOverdueByDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días',
      one: '1 día',
    );
    return 'Atrasado $_temp0';
  }

  @override
  String get taskDueDateLabel => 'Fecha de vencimiento';

  @override
  String get taskNoDueDateLabel => 'Sin fecha de vencimiento';

  @override
  String taskDueDateWithDate(String date) {
    return 'Vence: $date';
  }

  @override
  String get clearButton => 'Borrar';

  @override
  String get timeByCategoryChartTitle => 'Tiempo por categoría';

  @override
  String get timeByCategoryChartTotalLabel => 'Total';

  @override
  String get viewMenuTitle => 'Vista';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonError => 'Error';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get aiTranscribingAudio => 'Transcribing audio...';

  @override
  String get copyAsText => 'Copy as text';

  @override
  String get copyAsMarkdown => 'Copy as Markdown';

  @override
  String get editorInsertDivider => 'Insert divider';

  @override
  String get tasksLabelsHeaderTitle => 'Labels';

  @override
  String get tasksLabelsHeaderEditTooltip => 'Edit labels';

  @override
  String get tasksAddLabelButton => 'Add Label';

  @override
  String get tasksLabelsNoLabels => 'No labels';

  @override
  String get tasksLabelsDialogClose => 'Close';

  @override
  String get tasksLabelsSheetTitle => 'Select labels';

  @override
  String get tasksLabelsSheetSearchHint => 'Search labels…';

  @override
  String get tasksLabelsSheetApply => 'Apply';

  @override
  String get tasksLabelsUpdateFailed => 'Failed to update labels';

  @override
  String get tasksLabelFilterTitle => 'Labels';

  @override
  String get tasksLabelFilterUnlabeled => 'Unlabeled';

  @override
  String get tasksLabelFilterAll => 'All';

  @override
  String get tasksQuickFilterLabelsActiveTitle => 'Active label filters';

  @override
  String get tasksQuickFilterClear => 'Clear';

  @override
  String get tasksQuickFilterUnassignedLabel => 'Unassigned';

  @override
  String get taskLabelUnassignedLabel => 'unassigned';

  @override
  String get entryLabelsHeaderTitle => 'Etiquetas';

  @override
  String get entryLabelsEditTooltip => 'Editar etiquetas';

  @override
  String get entryLabelsNoLabels => 'Sin etiquetas asignadas';

  @override
  String get entryLabelsActionTitle => 'Etiquetas';

  @override
  String get entryLabelsActionSubtitle =>
      'Asignar etiquetas para organizar esta entrada';

  @override
  String get tasksPriorityTitle => 'Priority:';

  @override
  String get tasksPriorityP0 => 'Urgent';

  @override
  String get tasksPriorityP1 => 'High';

  @override
  String get tasksPriorityP2 => 'Medium';

  @override
  String get tasksPriorityP3 => 'Low';

  @override
  String get tasksPriorityPickerTitle => 'Select priority';

  @override
  String get tasksPriorityFilterTitle => 'Priority';

  @override
  String get tasksPriorityFilterAll => 'All';

  @override
  String get tasksPriorityP0Description => 'Urgent (ASAP)';

  @override
  String get tasksPriorityP1Description => 'High (Soon)';

  @override
  String get tasksPriorityP2Description => 'Medium (Default)';

  @override
  String get tasksPriorityP3Description => 'Low (Whenever)';

  @override
  String get checklistFilterShowAll => 'Show all items';

  @override
  String get checklistFilterShowOpen => 'Show open items';

  @override
  String get checklistFilterStateOpenOnly => 'Showing open items';

  @override
  String get checklistFilterStateAll => 'Showing all items';

  @override
  String checklistFilterToggleSemantics(String state) {
    return 'Toggle checklist filter (current: $state)';
  }

  @override
  String checklistCompletedShort(int completed, int total) {
    return '$completed/$total done';
  }

  @override
  String get checklistAllDone => 'All items completed!';

  @override
  String get correctionExamplesSectionTitle =>
      'Ejemplos de Corrección de Lista';

  @override
  String get correctionExamplesSectionDescription =>
      'Cuando corriges manualmente elementos de la lista, esas correcciones se guardan aquí y se usan para mejorar las sugerencias de IA.';

  @override
  String get correctionExamplesEmpty =>
      'Aún no se han capturado correcciones. Edita un elemento de la lista para agregar tu primer ejemplo.';

  @override
  String correctionExamplesWarning(int count, int max) {
    return 'Tienes $count correcciones. Solo las $max más recientes se usarán en los prompts de IA. Considera eliminar ejemplos antiguos o redundantes.';
  }

  @override
  String get correctionExampleCaptured =>
      'Corrección guardada para aprendizaje de IA';

  @override
  String correctionExamplePending(int seconds) {
    return 'Guardando corrección en ${seconds}s...';
  }

  @override
  String get correctionExampleCancel => 'CANCELAR';

  @override
  String get syncRoomDiscoveryTitle =>
      'Buscar sala de sincronización existente';

  @override
  String get syncDiscoverRoomsButton => 'Descubrir salas existentes';

  @override
  String get syncDiscoveringRooms => 'Buscando salas de sincronización...';

  @override
  String get syncNoRoomsFound =>
      'No se encontraron salas de sincronización.\nPuede crear una nueva sala para comenzar a sincronizar.';

  @override
  String get syncCreateNewRoom => 'Crear nueva sala';

  @override
  String get syncSelectRoom => 'Seleccionar sala de sincronización';

  @override
  String get syncSelectRoomDescription =>
      'Encontramos salas de sincronización existentes. Seleccione una para unirse o cree una nueva sala.';

  @override
  String get syncCreateNewRoomInstead => 'Crear nueva sala en su lugar';

  @override
  String get syncDiscoveryError => 'Error al descubrir salas';

  @override
  String get syncRetry => 'Reintentar';

  @override
  String get syncSkip => 'Omitir';

  @override
  String get syncRoomUnnamed => 'Sala sin nombre';

  @override
  String get syncRoomCreatedUnknown => 'Desconocido';

  @override
  String get syncRoomVerified => 'Verificado';

  @override
  String get syncRoomHasContent => 'Tiene contenido';

  @override
  String get syncInviteErrorNetwork =>
      'Error de red. Por favor, compruebe su conexión e inténtelo de nuevo.';

  @override
  String get syncInviteErrorUserNotFound =>
      'Usuario no encontrado. Por favor, verifique que el código escaneado sea correcto.';

  @override
  String get syncInviteErrorForbidden =>
      'Permiso denegado. Es posible que no tenga acceso para invitar a este usuario.';

  @override
  String get syncInviteErrorRateLimited =>
      'Demasiadas solicitudes. Por favor, espere un momento e inténtelo de nuevo.';

  @override
  String get syncInviteErrorUnknown =>
      'No se pudo enviar la invitación. Por favor, inténtelo más tarde.';
}

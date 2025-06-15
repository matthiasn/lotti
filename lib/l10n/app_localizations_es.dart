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
  String get aiAssistantActionItemSuggestions => 'Sugerencias de elementos de acción';

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
  String get aiConfigFailedToSaveMessage => 'Failed to save configuration. Please try again.';

  @override
  String get aiConfigInputDataTypesTitle => 'Required Input Data Types';

  @override
  String get aiConfigInputModalitiesFieldLabel => 'Input Modalities';

  @override
  String get aiConfigInputModalitiesTitle => 'Input Modalities';

  @override
  String get aiConfigInvalidUrlError => 'Please enter a valid URL';

  @override
  String get aiConfigListCascadeDeleteWarning => 'This will also delete all models associated with this provider.';

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
  String get aiConfigListEmptyState => 'No configurations found. Add one to get started.';

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
  String get aiConfigNoModelsAvailable => 'No AI models are configured yet. Please add one in settings.';

  @override
  String get aiConfigNoModelsSelected => 'No models selected. At least one model is required.';

  @override
  String get aiConfigNoProvidersAvailable => 'No API providers available. Please add an API provider first.';

  @override
  String get aiConfigNoSuitableModelsAvailable => 'No models meet the requirements for this prompt. Please configure models that support the required capabilities.';

  @override
  String get aiConfigOutputModalitiesFieldLabel => 'Output Modalities';

  @override
  String get aiConfigOutputModalitiesTitle => 'Output Modalities';

  @override
  String get aiConfigProviderDeletedSuccessfully => 'Provider deleted successfully';

  @override
  String get aiConfigProviderFieldLabel => 'Inference Provider';

  @override
  String get aiConfigProviderModelIdFieldLabel => 'Provider Model ID';

  @override
  String get aiConfigProviderModelIdTooShortError => 'ProviderModelId must be at least 3 characters';

  @override
  String get aiConfigProviderTypeFieldLabel => 'Provider Type';

  @override
  String get aiConfigReasoningCapabilityDescription => 'Model can perform step-by-step reasoning';

  @override
  String get aiConfigReasoningCapabilityFieldLabel => 'Reasoning Capability';

  @override
  String get aiConfigRequiredInputDataFieldLabel => 'Required Input Data';

  @override
  String get aiConfigResponseTypeFieldLabel => 'AI Response Type';

  @override
  String get aiConfigResponseTypeNotSelectedError => 'Please select a response type';

  @override
  String get aiConfigResponseTypeSelectHint => 'Select response type';

  @override
  String get aiConfigSelectInputDataTypesPrompt => 'Select required data types...';

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
  String get aiConfigUseReasoningDescription => 'If enabled, the model will use its reasoning capabilities for this prompt.';

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
  String get aiInferenceErrorAuthenticationMessage => 'Authentication failed. Please check your API key and ensure it is valid.';

  @override
  String get aiInferenceErrorAuthenticationTitle => 'Authentication Failed';

  @override
  String get aiInferenceErrorConnectionFailedMessage => 'Unable to connect to the AI service. Please check your internet connection and ensure the service is accessible.';

  @override
  String get aiInferenceErrorConnectionFailedTitle => 'Connection Failed';

  @override
  String get aiInferenceErrorInvalidRequestMessage => 'The request was invalid. Please check your configuration and try again.';

  @override
  String get aiInferenceErrorInvalidRequestTitle => 'Invalid Request';

  @override
  String get aiInferenceErrorRateLimitMessage => 'You have exceeded the rate limit. Please wait a moment before trying again.';

  @override
  String get aiInferenceErrorRateLimitTitle => 'Rate Limit Exceeded';

  @override
  String get aiInferenceErrorRetryButton => 'Try Again';

  @override
  String get aiInferenceErrorServerMessage => 'The AI service encountered an error. Please try again later.';

  @override
  String get aiInferenceErrorServerTitle => 'Server Error';

  @override
  String get aiInferenceErrorSuggestionsTitle => 'Suggestions:';

  @override
  String get aiInferenceErrorTimeoutMessage => 'The request took too long to complete. Please try again or check if the service is responding.';

  @override
  String get aiInferenceErrorTimeoutTitle => 'Request Timed Out';

  @override
  String get aiInferenceErrorUnknownMessage => 'An unexpected error occurred. Please try again.';

  @override
  String get aiInferenceErrorUnknownTitle => 'Error';

  @override
  String get aiProviderAnthropicDescription => 'Anthropic\'s Claude family of AI assistants';

  @override
  String get aiProviderAnthropicName => 'Anthropic Claude';

  @override
  String get aiProviderFastWhisperDescription => 'Local speech recognition with FastWhisper';

  @override
  String get aiProviderFastWhisperName => 'FastWhisper';

  @override
  String get aiProviderGeminiDescription => 'Google\'s Gemini AI models';

  @override
  String get aiProviderGeminiName => 'Google Gemini';

  @override
  String get aiProviderGenericOpenAiDescription => 'API compatible with OpenAI format';

  @override
  String get aiProviderGenericOpenAiName => 'OpenAI Compatible';

  @override
  String get aiProviderNebiusAiStudioDescription => 'Nebius AI Studio\'s models';

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
  String get aiResponseTypeActionItemSuggestions => 'Action Item Suggestions';

  @override
  String get aiResponseTypeAudioTranscription => 'Audio Transcription';

  @override
  String get aiResponseTypeImageAnalysis => 'Image Analysis';

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
  String get aiSettingsClearFiltersButton => 'Clear';

  @override
  String aiSettingsFilterByCapabilityTooltip(String capability) {
    return 'Filter by $capability capability';
  }

  @override
  String aiSettingsFilterByProviderTooltip(String provider) {
    return 'Filter by $provider';
  }

  @override
  String get aiSettingsFilterByReasoningTooltip => 'Filter by reasoning capability';

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
  String get checklistItemDelete => '¿Eliminar elemento de la lista de verificación?';

  @override
  String get checklistItemDeleteCancel => 'Cancelar';

  @override
  String get checklistItemDeleteConfirm => 'Confirmar';

  @override
  String get checklistItemDeleteWarning => 'Esta acción no se puede deshacer.';

  @override
  String get checklistItemDrag => 'Arrastre las sugerencias a la lista de verificación';

  @override
  String get checklistNoSuggestionsTitle => 'No hay elementos de acción sugeridos';

  @override
  String get checklistSuggestionsOutdated => 'Obsoleto';

  @override
  String get checklistSuggestionsRunning => 'Pensando en sugerencias sin seguimiento...';

  @override
  String get checklistSuggestionsTitle => 'Elementos de acción sugeridos';

  @override
  String get checklistsTitle => 'Listas de verificación';

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
  String get configFlagAttemptEmbeddingDescription => 'Cuando está habilitado, la aplicación intentará generar incrustaciones para sus entradas para mejorar la búsqueda y las sugerencias de contenido relacionado.';

  @override
  String get configFlagAutoTranscribeDescription => 'Transcribir automáticamente grabaciones de audio en sus entradas. Esto requiere una conexión a Internet.';

  @override
  String get configFlagEnableAutoTaskTldrDescription => 'Generar automáticamente resúmenes para sus tareas para ayudarlo a comprender rápidamente su estado.';

  @override
  String get configFlagEnableCalendarPageDescription => 'Mostrar la página Calendario en la navegación principal. Vea y administre sus entradas en una vista de calendario.';

  @override
  String get configFlagEnableDashboardsPageDescription => 'Mostrar la página Paneles en la navegación principal. Vea sus datos e información en paneles personalizables.';

  @override
  String get configFlagEnableHabitsPageDescription => 'Mostrar la página Hábitos en la navegación principal. Rastree y administre sus hábitos diarios aquí.';

  @override
  String get configFlagEnableLoggingDescription => 'Habilitar el registro detallado para fines de depuración. Esto puede afectar el rendimiento.';

  @override
  String get configFlagEnableMatrixDescription => 'Habilitar la integración de Matrix para sincronizar sus entradas entre dispositivos y con otros usuarios de Matrix.';

  @override
  String get configFlagEnableNotifications => '¿Habilitar notificaciones?';

  @override
  String get configFlagEnableNotificationsDescription => 'Recibir notificaciones de recordatorios, actualizaciones y eventos importantes.';

  @override
  String get configFlagEnableTooltipDescription => 'Mostrar información sobre herramientas útil en toda la aplicación para guiarlo a través de las funciones.';

  @override
  String get configFlagPrivate => '¿Mostrar entradas privadas?';

  @override
  String get configFlagPrivateDescription => 'Habilite esto para que sus entradas sean privadas de forma predeterminada. Las entradas privadas solo son visibles para usted.';

  @override
  String get configFlagRecordLocationDescription => 'Registrar automáticamente su ubicación con las nuevas entradas. Esto ayuda con la organización y la búsqueda basadas en la ubicación.';

  @override
  String get configFlagResendAttachmentsDescription => 'Activar para reenviar automáticamente las cargas de archivos adjuntos fallidas cuando se restablezca la conexión.';

  @override
  String get configFlagUseCloudInferenceDescription => 'Utiliza servicios de IA basados en la nube para funciones mejoradas. Esto requiere una conexión a Internet.';

  @override
  String get conflictsResolved => 'resueltos';

  @override
  String get conflictsUnresolved => 'sin resolver';

  @override
  String get createCategoryTitle => 'Crear categoría:';

  @override
  String get createEntryLabel => 'Crear nueva entrada';

  @override
  String get createEntryTitle => 'Añadir';

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
  String get enhancedPromptFormAiResponseTypeSubtitle => 'Format of the expected response';

  @override
  String get enhancedPromptFormBasicConfigurationTitle => 'Basic Configuration';

  @override
  String get enhancedPromptFormConfigurationOptionsTitle => 'Configuration Options';

  @override
  String get enhancedPromptFormDescription => 'Create custom prompts that can be used with your AI models to generate specific types of responses';

  @override
  String get enhancedPromptFormDescriptionHelperText => 'Optional notes about this prompt\'s purpose and usage';

  @override
  String get enhancedPromptFormDisplayNameHelperText => 'A descriptive name for this prompt template';

  @override
  String get enhancedPromptFormPreconfiguredPromptDescription => 'Choose from ready-made prompt templates';

  @override
  String get enhancedPromptFormPromptConfigurationTitle => 'Prompt Configuration';

  @override
  String get enhancedPromptFormQuickStartDescription => 'Start with a pre-built template to save time';

  @override
  String get enhancedPromptFormQuickStartTitle => 'Quick Start';

  @override
  String get enhancedPromptFormRequiredInputDataSubtitle => 'Type of data this prompt expects';

  @override
  String get enhancedPromptFormSystemMessageHelperText => 'Instructions that define the AI\'s behavior and response style';

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
  String get inputDataTypeTasksListDescription => 'Use a list of tasks as input';

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
  String get journalDeleteQuestion => '¿Quieres borrar esta entrada del diario?';

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
  String get journalLinkedEntriesAiLabel => 'Mostrar entradas generadas por IA:';

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
  String get journalUnlinkQuestion => '¿Está seguro de que desea desvincular esta entrada?';

  @override
  String get maintenanceDeleteDatabaseConfirm => 'YES, DELETE DATABASE';

  @override
  String maintenanceDeleteDatabaseQuestion(String databaseName) {
    return 'Are you sure you want to delete $databaseName Database?';
  }

  @override
  String get maintenanceDeleteEditorDb => 'Eliminar la base de datos de borradores del editor';

  @override
  String get maintenanceDeleteLoggingDb => 'Eliminar la base de datos de registro';

  @override
  String get maintenanceDeleteSyncDb => 'Eliminar la base de datos de sincronización';

  @override
  String get maintenancePurgeAudioModels => 'Purgar modelos de audio';

  @override
  String get maintenancePurgeAudioModelsConfirm => 'YES, PURGE MODELS';

  @override
  String get maintenancePurgeAudioModelsMessage => 'Are you sure you want to purge all audio models? This action cannot be undone.';

  @override
  String get maintenancePurgeDeleted => 'Purgar elementos eliminados';

  @override
  String get maintenancePurgeDeletedConfirm => 'Yes, purge all';

  @override
  String get maintenancePurgeDeletedMessage => 'Are you sure you want to purge all deleted items? This action cannot be undone.';

  @override
  String get maintenanceReSync => 'Volver a sincronizar mensajes';

  @override
  String get maintenanceRecreateFts5 => 'Recrear el índice de texto completo';

  @override
  String get maintenanceRecreateFts5Confirm => 'YES, RECREATE INDEX';

  @override
  String get maintenanceRecreateFts5Message => 'Are you sure you want to recreate the full-text index? This may take some time.';

  @override
  String get maintenanceSyncDefinitions => 'Sync tags, measurables, dashboards, habits, categories';

  @override
  String get measurableDeleteConfirm => 'SÍ, ELIMINAR ESTE MEDIBLE';

  @override
  String get measurableDeleteQuestion => '¿Desea eliminar este tipo de datos medibles?';

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
  String get outboxMonitorNoAttachment => 'sin archivo adjunto';

  @override
  String get outboxMonitorRetries => 'reintentos';

  @override
  String get outboxMonitorRetry => 'reintentar';

  @override
  String get outboxMonitorSwitchLabel => 'habilitado';

  @override
  String get promptAddOrRemoveModelsButton => 'Add or Remove Models';

  @override
  String get promptAddPageTitle => 'Add Prompt';

  @override
  String get promptAiResponseTypeDescription => 'Format of the expected response';

  @override
  String get promptAiResponseTypeLabel => 'AI Response Type';

  @override
  String get promptBehaviorDescription => 'Configure how the prompt processes and responds';

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
  String get promptModelSelectionDescription => 'Choose compatible models for this prompt';

  @override
  String get promptModelSelectionTitle => 'Model Selection';

  @override
  String get promptNoModelsSelectedError => 'No models selected. Select at least one model.';

  @override
  String get promptReasoningModeDescription => 'Enable for prompts requiring deep thinking';

  @override
  String get promptReasoningModeLabel => 'Reasoning Mode';

  @override
  String get promptRequiredInputDataDescription => 'Type of data this prompt expects';

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
  String get settingsAdvancedShowCaseAboutLottiTooltip => 'Obtén más información sobre la aplicación Lotti, incluida la versión y los créditos.';

  @override
  String get settingsAdvancedShowCaseApiKeyTooltip => 'Administre sus claves API para varios proveedores de IA. Agregue, edite o elimine claves para configurar integraciones con servicios compatibles como OpenAI, Gemini y más. Asegúrese de manejar la información sensible de manera segura.';

  @override
  String get settingsAdvancedShowCaseConflictsTooltip => 'Resuelve los conflictos de sincronización para garantizar la coherencia de los datos.';

  @override
  String get settingsAdvancedShowCaseHealthImportTooltip => 'Importa datos relacionados con la salud desde fuentes externas.';

  @override
  String get settingsAdvancedShowCaseLogsTooltip => 'Accede y revisa los registros de la aplicación para la depuración y la supervisión.';

  @override
  String get settingsAdvancedShowCaseMaintenanceTooltip => 'Realiza tareas de mantenimiento para optimizar el rendimiento de la aplicación.';

  @override
  String get settingsAdvancedShowCaseMatrixSyncTooltip => 'Configura y administra las opciones de sincronización de Matrix para una integración de datos perfecta.';

  @override
  String get settingsAdvancedShowCaseModelsTooltip => 'Define AI models that use inference providers';

  @override
  String get settingsAdvancedShowCaseSyncOutboxTooltip => 'Ver y administrar los elementos que esperan ser sincronizados en la bandeja de salida.';

  @override
  String get settingsAdvancedTitle => 'Configuración avanzada';

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
  String get settingsCategoryShowCaseActiveTooltip => 'Activar esta opción para marcar la categoría como activa. Las categorías activas están actualmente en uso y se mostrarán de forma destacada para facilitar la accesibilidad.';

  @override
  String get settingsCategoryShowCaseColorTooltip => 'Selecciona un color para representar esta categoría. Puedes introducir un código de color HEX válido (por ejemplo, #FF5733) o usar el selector de color de la derecha para elegir un color visualmente.';

  @override
  String get settingsCategoryShowCaseDelTooltip => 'Haz clic en este botón para eliminar la categoría. Ten en cuenta que esta acción es irreversible, así que asegúrate de que quieres eliminar la categoría antes de continuar.';

  @override
  String get settingsCategoryShowCaseFavTooltip => 'Activa esta opción para marcar la categoría como favorita. Las categorías favoritas son más fáciles de acceder y se destacan para una referencia rápida.';

  @override
  String get settingsCategoryShowCaseNameTooltip => 'Introduce un nombre claro y relevante para la categoría. Mantenlo corto y descriptivo para que puedas identificar fácilmente su propósito.';

  @override
  String get settingsCategoryShowCasePrivateTooltip => 'Activa esta opción para marcar la categoría como privada. Las categorías privadas solo son visibles para ti y te ayudan a organizar de forma segura los hábitos y las tareas sensibles o personales.';

  @override
  String get settingsConflictsResolutionTitle => 'Resolución de Conflictos de Sincronización';

  @override
  String get settingsConflictsTitle => 'Conflictos de Sincronización';

  @override
  String get settingsDashboardDetailsLabel => 'Dashboard Details';

  @override
  String get settingsDashboardSaveLabel => 'Save';

  @override
  String get settingsDashboardsShowCaseActiveTooltip => 'Activa este interruptor para marcar el panel como activo. Los paneles activos se están utilizando actualmente y se mostrarán de forma destacada para facilitar la accesibilidad.';

  @override
  String get settingsDashboardsShowCaseCatTooltip => 'Selecciona una categoría que describa mejor el panel. Esto ayuda a organizar y clasificar tus paneles de forma eficaz. Ejemplos: \'Salud\', \'Productividad\', \'Trabajo\'.';

  @override
  String get settingsDashboardsShowCaseCopyTooltip => 'Pulsa para copiar este panel. Esto te permitirá duplicar el panel y utilizarlo en otro lugar.';

  @override
  String get settingsDashboardsShowCaseDelTooltip => 'Pulsa este botón para eliminar el panel de forma permanente. Ten cuidado, ya que esta acción no se puede deshacer y se eliminarán todos los datos relacionados.';

  @override
  String get settingsDashboardsShowCaseDescrTooltip => 'Proporciona una descripción detallada del panel. Esto ayuda a comprender el propósito y el contenido del panel. Ejemplos: \'Seguimiento de las actividades diarias de bienestar\', \'Supervisa las tareas y los objetivos relacionados con el trabajo\'.';

  @override
  String get settingsDashboardsShowCaseHealthChartsTooltip => 'Selecciona los gráficos de salud que quieres incluir en tu panel. Ejemplos: \'Peso\', \'Porcentaje de grasa corporal\'.';

  @override
  String get settingsDashboardsShowCaseNameTooltip => 'Introduce un nombre claro y relevante para el panel. Mantenlo corto y descriptivo para que puedas identificar fácilmente su propósito. Ejemplos: \'Seguimiento de bienestar\', \'Objetivos diarios\', \'Horario de trabajo\'.';

  @override
  String get settingsDashboardsShowCasePrivateTooltip => 'Activa este interruptor para que el panel sea privado. Los paneles privados solo son visibles para ti y no se compartirán con otros.';

  @override
  String get settingsDashboardsShowCaseSurveyChartsTooltip => 'Selecciona los gráficos de encuestas que quieres incluir en tu panel. Ejemplos: \'Satisfacción del cliente\', \'Comentarios de los empleados\'.';

  @override
  String get settingsDashboardsShowCaseWorkoutChartsTooltip => 'Selecciona los gráficos de entrenamiento que quieres incluir en tu panel. Ejemplos: \'Caminar\', \'Correr\', \'Nadar\'.';

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
  String get settingsHabitsShowCaseAlertTimeTooltip => 'Establece la hora específica a la que deseas recibir un recordatorio o alerta para este hábito. Esto asegura que nunca olvides completarlo. Ejemplo: \'8:00 PM\'.';

  @override
  String get settingsHabitsShowCaseArchivedTooltip => 'Activa este interruptor para archivar el hábito. Los hábitos archivados ya no están activos, pero se guardan para futuras referencias o revisiones. Ejemplos: \'Aprender guitarra\', \'Curso completado\'.';

  @override
  String get settingsHabitsShowCaseCatTooltip => 'Elige una categoría que describa mejor tu hábito o crea una nueva seleccionando el botón [+].\nEjemplos: \'Salud\', \'Productividad\', \'Ejercicio\'.';

  @override
  String get settingsHabitsShowCaseDashTooltip => 'Selecciona un tablero para organizar y realizar un seguimiento de tu hábito o crea uno nuevo con el botón [+].\nEjemplos: \'Rastreador de bienestar\', \'Objetivos diarios\', \'Horario de trabajo\'.';

  @override
  String get settingsHabitsShowCaseDelHabitTooltip => 'Toca este botón para eliminar el hábito de forma permanente. Ten cuidado, ya que esta acción no se puede deshacer y se eliminarán todos los datos relacionados.';

  @override
  String get settingsHabitsShowCaseDescrTooltip => 'Proporciona una descripción breve y significativa del hábito. Incluye cualquier detalle o contexto relevante para definir claramente el propósito y la importancia del hábito.\nEjemplos: \'Correr durante 30 minutos cada mañana para mejorar la forma física\' o \'Leer un capítulo al día para mejorar el conocimiento y la concentración\'.';

  @override
  String get settingsHabitsShowCaseNameTooltip => 'Introduce un nombre claro y descriptivo para el hábito.\nEvita los nombres demasiado largos y hazlo lo suficientemente conciso como para identificar el hábito fácilmente.\nEjemplos: \'Trote matutino\', \'Lectura diaria\'.';

  @override
  String get settingsHabitsShowCasePriorTooltip => 'Activa el interruptor para asignar prioridad al hábito. Los hábitos de alta prioridad a menudo representan tareas esenciales o urgentes en las que quieres centrarte. Ejemplos: \'Hacer ejercicio a diario\', \'Trabajar en el proyecto\'.';

  @override
  String get settingsHabitsShowCasePrivateTooltip => 'Utiliza este interruptor para marcar el hábito como privado. Los hábitos privados solo son visibles para ti y no se compartirán con otros. Ejemplos: \'Diario personal\', \'Meditación\'.';

  @override
  String get settingsHabitsShowCaseStarDateTooltip => 'Selecciona la fecha en la que quieres empezar a seguir este hábito. Esto ayuda a definir cuándo comienza el hábito y permite un seguimiento preciso del progreso. Ejemplo: \'1 de julio de 2025\'.';

  @override
  String get settingsHabitsShowCaseStartTimeTooltip => 'Establece la hora a partir de la cual este hábito debe ser visible o empezar a aparecer en tu horario. Esto ayuda a organizar tu día de forma eficaz. Ejemplo: \'7:00 AM\'.';

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
  String get settingsMatrixAcceptVerificationLabel => 'El otro dispositivo muestra emojis, continuar';

  @override
  String get settingsMatrixCancel => 'Cancelar';

  @override
  String get settingsMatrixCancelVerificationLabel => 'Cancelar verificación';

  @override
  String get settingsMatrixContinueVerificationLabel => 'Aceptar en el otro dispositivo para continuar';

  @override
  String get settingsMatrixDeleteLabel => 'Eliminar';

  @override
  String get settingsMatrixDone => 'Listo';

  @override
  String get settingsMatrixEnterValidUrl => 'Introduce una URL válida';

  @override
  String get settingsMatrixHomeServerLabel => 'Servidor doméstico';

  @override
  String get settingsMatrixHomeserverConfigTitle => 'Configuración del servidor doméstico Matrix';

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
  String get settingsMatrixNoUnverifiedLabel => 'No hay dispositivos sin verificar';

  @override
  String get settingsMatrixPasswordLabel => 'Contraseña';

  @override
  String get settingsMatrixPasswordTooShort => 'Contraseña demasiado corta';

  @override
  String get settingsMatrixPreviousPage => 'Página anterior';

  @override
  String get settingsMatrixQrTextPage => 'Escanea este código QR para invitar al dispositivo a una sala de sincronización.';

  @override
  String get settingsMatrixRoomConfigTitle => 'Configuración de la sala de sincronización Matrix';

  @override
  String get settingsMatrixStartVerificationLabel => 'Iniciar verificación';

  @override
  String get settingsMatrixStatsTitle => 'Estadísticas de Matrix';

  @override
  String get settingsMatrixTitle => 'Ajustes de sincronización de Matrix';

  @override
  String get settingsMatrixUnverifiedDevicesPage => 'Dispositivos no verificados';

  @override
  String get settingsMatrixUserLabel => 'Usuario';

  @override
  String get settingsMatrixUserNameTooShort => 'Nombre de usuario demasiado corto';

  @override
  String get settingsMatrixVerificationCancelledLabel => 'Cancelado en el otro dispositivo...';

  @override
  String get settingsMatrixVerificationSuccessConfirm => 'Entendido';

  @override
  String settingsMatrixVerificationSuccessLabel(String deviceName, String deviceID) {
    return 'Has verificado correctamente $deviceName ($deviceID)';
  }

  @override
  String get settingsMatrixVerifyConfirm => 'Confirma en el otro dispositivo que los emojis a continuación se muestran en ambos dispositivos, en el mismo orden:';

  @override
  String get settingsMatrixVerifyIncomingConfirm => 'Confirma que los emojis a continuación se muestran en ambos dispositivos, en el mismo orden:';

  @override
  String get settingsMatrixVerifyLabel => 'Verificar';

  @override
  String get settingsMeasurableAggregationLabel => 'Tipo de agregación predeterminado (opcional):';

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
  String get settingsMeasurableShowCaseAggreTypeTooltip => 'Selecciona el tipo de agregación predeterminado para los datos medibles. Esto determina cómo se resumirán los datos a lo largo del tiempo. \nOpciones: \'dailySum\', \'dailyMax\', \'dailyAvg\', \'hourlySum\'.';

  @override
  String get settingsMeasurableShowCaseDelTooltip => 'Haz clic en este botón para eliminar el tipo de medición. Ten en cuenta que esta acción es irreversible, así que asegúrate de que deseas eliminar el tipo de medición antes de continuar.';

  @override
  String get settingsMeasurableShowCaseDescrTooltip => 'Proporciona una descripción breve y significativa del tipo de medición. Incluye cualquier detalle relevante o contexto para definir claramente su propósito e importancia. \nEjemplos: \'Peso corporal medido en kilogramos\'';

  @override
  String get settingsMeasurableShowCaseNameTooltip => 'Introduce un nombre claro y descriptivo para el tipo de medición.\nEvita nombres demasiado largos y hazlo lo suficientemente conciso como para identificar el tipo de medición fácilmente. \nEjemplos: \'Peso\', \'Presión arterial\'.';

  @override
  String get settingsMeasurableShowCasePrivateTooltip => 'Activa esta opción para marcar el tipo de medición como privado. Los tipos de medición privados solo son visibles para ti y te ayudan a organizar datos confidenciales o personales de forma segura.';

  @override
  String get settingsMeasurableShowCaseUnitTooltip => 'Introduce una abreviatura de unidad clara y concisa para el tipo de medición. Esto ayuda a identificar la unidad de medida fácilmente.';

  @override
  String get settingsMeasurableUnitLabel => 'Abreviatura de la unidad (opcional):';

  @override
  String get settingsMeasurablesTitle => 'Tipos de medición';

  @override
  String get settingsSpeechAudioWithoutTranscript => 'Entradas de audio sin transcripción:';

  @override
  String get settingsSpeechAudioWithoutTranscriptButton => 'Buscar y transcribir';

  @override
  String get settingsSpeechLastActivity => 'Última actividad de transcripción:';

  @override
  String get settingsSpeechModelSelectionTitle => 'Modelo de reconocimiento de voz Whisper:';

  @override
  String get settingsSpeechTitle => 'Configuración de voz';

  @override
  String get settingsSyncOutboxTitle => 'Bandeja de salida de sincronización';

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
  String get settingsTagsShowCaseDeleteTooltip => 'Eliminar esta etiqueta de forma permanente. Esta acción no se puede deshacer.';

  @override
  String get settingsTagsShowCaseHideTooltip => 'Active esta opción para ocultar esta etiqueta de las sugerencias. Úsela para etiquetas que sean personales o que no se necesiten habitualmente.';

  @override
  String get settingsTagsShowCaseNameTooltip => 'Introduzca un nombre claro y relevante para la etiqueta. Manténgalo corto y descriptivo para que pueda categorizar fácilmente sus hábitos. Ejemplos: \"Salud\", \"Productividad\", \"Atención plena\".';

  @override
  String get settingsTagsShowCasePrivateTooltip => 'Active esta opción para que la etiqueta sea privada. Las etiquetas privadas solo son visibles para usted y no se compartirán con otros.';

  @override
  String get settingsTagsShowCaseTypeTooltip => 'Seleccione el tipo de etiqueta para categorizarla correctamente: \n[Etiqueta]-> Categorías generales como \'Salud\' o \'Productividad\'. \n[Persona]-> Usar para etiquetar personas específicas. \n[Historia]-> Adjuntar etiquetas a las historias para una mejor organización.';

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
  String get settingsThemingShowCaseDarkTooltip => 'Elija el tema oscuro para una apariencia más oscura.';

  @override
  String get settingsThemingShowCaseLightTooltip => 'Elija el tema claro para una apariencia más clara.';

  @override
  String get settingsThemingShowCaseModeTooltip => 'Seleccione su modo de tema preferido: Claro, Oscuro o Automático.';

  @override
  String get settingsThemingTitle => 'Temas';

  @override
  String get showcaseCloseButton => 'cerrar';

  @override
  String get showcaseNextButton => 'siguiente';

  @override
  String get showcasePreviousButton => 'anterior';

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
  String get syncDeleteConfigQuestion => '¿Desea eliminar la configuración de sincronización?';

  @override
  String get syncEntitiesConfirm => 'YES, SYNC ALL';

  @override
  String get syncEntitiesMessage => 'This will sync all tags, measurables, and categories. Do you want to continue?';

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
  String get tasksFilterTitle => 'Filtro de tareas';

  @override
  String get timeByCategoryChartTitle => 'Tiempo por categoría';

  @override
  String get timeByCategoryChartTotalLabel => 'Total';

  @override
  String get viewMenuTitle => 'Vista';
}

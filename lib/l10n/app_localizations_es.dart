// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get activeLabel => 'Activo';

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
  String get addActionAddTimer => 'Temporizador';

  @override
  String get addActionAddTimeRecording => 'Entrada de temporizador';

  @override
  String get addActionImportImage => 'Importar imagen';

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
  String get addToDictionary => 'Añadir al diccionario';

  @override
  String get addToDictionaryDuplicate =>
      'El término ya existe en el diccionario';

  @override
  String get addToDictionaryNoCategory =>
      'No se puede añadir al diccionario: la tarea no tiene categoría';

  @override
  String get addToDictionarySaveFailed => 'Error al guardar el diccionario';

  @override
  String get addToDictionarySuccess => 'Término añadido al diccionario';

  @override
  String get addToDictionaryTooLong =>
      'Término demasiado largo (máx. 50 caracteres)';

  @override
  String get agentActivityLogHeading => 'Registro de actividad';

  @override
  String agentControlsActionError(String error) {
    return 'La acción falló: $error';
  }

  @override
  String get agentControlsDeleteButton => 'Eliminar permanentemente';

  @override
  String get agentControlsDeleteDialogContent =>
      'Esto eliminará permanentemente todos los datos de este agente, incluyendo su historial, informes y observaciones. Esta acción no se puede deshacer.';

  @override
  String get agentControlsDeleteDialogTitle => '¿Eliminar agente?';

  @override
  String get agentControlsDestroyButton => 'Destruir';

  @override
  String get agentControlsDestroyDialogContent =>
      'Esto desactivará permanentemente al agente. Su historial se conservará para auditoría.';

  @override
  String get agentControlsDestroyDialogTitle => '¿Destruir agente?';

  @override
  String get agentControlsDestroyedMessage => 'Este agente ha sido destruido.';

  @override
  String get agentControlsPauseButton => 'Pausar';

  @override
  String get agentControlsReanalyzeButton => 'Reanalizar';

  @override
  String get agentControlsResumeButton => 'Reanudar';

  @override
  String get agentConversationEmpty => 'Aún no hay conversaciones.';

  @override
  String agentConversationThreadHeader(String runKey) {
    return 'Wake $runKey';
  }

  @override
  String agentConversationThreadSummary(
      int messageCount, int toolCallCount, String shortId) {
    return '$messageCount mensajes, $toolCallCount llamadas a herramientas · $shortId';
  }

  @override
  String agentDetailErrorLoading(String error) {
    return 'Error al cargar el agente: $error';
  }

  @override
  String get agentDetailNotFound => 'Agente no encontrado.';

  @override
  String get agentDetailUnexpectedType => 'Tipo de entidad inesperado.';

  @override
  String get agentEvolutionChartMttrTrend => 'Tendencia MTTR';

  @override
  String get agentEvolutionChartSuccessRateTrend => 'Tasa de éxito';

  @override
  String get agentEvolutionChartVersionPerformance => 'Por versión';

  @override
  String get agentEvolutionChartWakeHistory => 'Historial de wakes';

  @override
  String get agentEvolutionChatPlaceholder =>
      'Comparte comentarios o pregunta sobre el rendimiento...';

  @override
  String get agentEvolutionCurrentDirectives => 'Directivas actuales';

  @override
  String get agentEvolutionDashboardTitle => 'Rendimiento';

  @override
  String get agentEvolutionMetricActive => 'Activos';

  @override
  String get agentEvolutionMetricAvgDuration => 'Duración media';

  @override
  String get agentEvolutionMetricFailures => 'Fallos';

  @override
  String get agentEvolutionMetricNotAvailable => 'N/D';

  @override
  String get agentEvolutionMetricSuccess => 'Éxito';

  @override
  String get agentEvolutionMetricWakes => 'Activaciones';

  @override
  String get agentEvolutionMttrLabel => 'Tiempo medio de resolución';

  @override
  String get agentEvolutionNoteRecorded => 'Nota registrada';

  @override
  String get agentEvolutionProposalRationale => 'Justificación';

  @override
  String get agentEvolutionProposalRejected =>
      'Propuesta rechazada — continúa la conversación';

  @override
  String get agentEvolutionProposalTitle => 'Cambios propuestos';

  @override
  String get agentEvolutionProposedDirectives => 'Directivas propuestas';

  @override
  String get agentEvolutionRatingAdequate => 'Adecuado';

  @override
  String get agentEvolutionRatingExcellent => 'Excelente';

  @override
  String get agentEvolutionRatingNeedsWork => 'Necesita mejoras';

  @override
  String get agentEvolutionRatingPrompt =>
      '¿Qué tan bien funciona esta plantilla?';

  @override
  String get agentEvolutionSessionAbandoned => 'Sesión finalizada sin cambios';

  @override
  String agentEvolutionSessionCompleted(int version) {
    return 'Sesión completada — versión $version creada';
  }

  @override
  String get agentEvolutionSessionError =>
      'No se pudo iniciar la sesión de evolución';

  @override
  String get agentEvolutionSessionStarting =>
      'Iniciando sesión de evolución...';

  @override
  String get agentLifecycleActive => 'Activo';

  @override
  String get agentLifecycleCreated => 'Creado';

  @override
  String get agentLifecycleDestroyed => 'Destruido';

  @override
  String get agentLifecyclePaused => 'Pausado';

  @override
  String get agentMessageKindAction => 'Acción';

  @override
  String get agentMessageKindObservation => 'Observación';

  @override
  String get agentMessageKindSummary => 'Resumen';

  @override
  String get agentMessageKindSystem => 'Sistema';

  @override
  String get agentMessageKindThought => 'Pensamiento';

  @override
  String get agentMessageKindToolResult => 'Resultado de herramienta';

  @override
  String get agentMessageKindUser => 'Usuario';

  @override
  String get agentMessagePayloadEmpty => '(sin contenido)';

  @override
  String get agentMessagesEmpty => 'Aún no hay mensajes.';

  @override
  String agentMessagesErrorLoading(String error) {
    return 'Error al cargar los mensajes: $error';
  }

  @override
  String get agentObservationsEmpty =>
      'Aún no se han registrado observaciones.';

  @override
  String agentReportErrorLoading(String error) {
    return 'Error al cargar el informe: $error';
  }

  @override
  String get agentReportHistoryBadge => 'Informe';

  @override
  String get agentReportHistoryEmpty => 'Aún no hay instantáneas de informes.';

  @override
  String get agentReportHistoryError =>
      'Se produjo un error al cargar el historial de informes.';

  @override
  String get agentReportNone => 'Aún no hay informe disponible.';

  @override
  String get agentRunningIndicator => 'Ejecutando';

  @override
  String get agentStateConsecutiveFailures => 'Fallos consecutivos';

  @override
  String agentStateErrorLoading(String error) {
    return 'Error al cargar el estado: $error';
  }

  @override
  String get agentStateHeading => 'Información de estado';

  @override
  String get agentStateLastWake => 'Último despertar';

  @override
  String get agentStateNextWake => 'Próximo despertar';

  @override
  String get agentStateRevision => 'Revisión';

  @override
  String get agentStateSleepingUntil => 'Durmiendo hasta';

  @override
  String get agentStateWakeCount => 'Conteo de despertares';

  @override
  String get agentTabActivity => 'Actividad';

  @override
  String get agentTabConversations => 'Conversaciones';

  @override
  String get agentTabObservations => 'Observaciones';

  @override
  String get agentTabReports => 'Informes';

  @override
  String get agentTemplateActiveInstancesTitle => 'Instancias activas';

  @override
  String get agentTemplateAllProviders => 'Todos los proveedores';

  @override
  String get agentTemplateAssignedLabel => 'Plantilla';

  @override
  String get agentTemplateCreatedSuccess => 'Plantilla creada';

  @override
  String get agentTemplateCreateTitle => 'Crear plantilla';

  @override
  String get agentTemplateDeleteConfirm =>
      '¿Eliminar esta plantilla? Esto no se puede deshacer.';

  @override
  String get agentTemplateDeleteHasInstances =>
      'No se puede eliminar: agentes activos están usando esta plantilla.';

  @override
  String get agentTemplateDirectivesHint =>
      'Define la personalidad, el tono, los objetivos y el estilo del agente...';

  @override
  String get agentTemplateDirectivesLabel => 'Directivas';

  @override
  String get agentTemplateDisplayNameLabel => 'Nombre';

  @override
  String get agentTemplateEditTitle => 'Editar plantilla';

  @override
  String get agentTemplateEmptyList =>
      'Sin plantillas aún. Toca + para crear una.';

  @override
  String get agentTemplateEvolveAction => 'Evolucionar con IA';

  @override
  String get agentTemplateEvolveApprove => 'Aprobar y guardar';

  @override
  String get agentTemplateEvolveReject => 'Rechazar';

  @override
  String agentTemplateInstanceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count instancias',
      one: '1 instancia',
      zero: 'Sin instancias',
    );
    return '$_temp0';
  }

  @override
  String get agentTemplateKindTaskAgent => 'Agente de tareas';

  @override
  String get agentTemplateMetricsActiveInstances => 'Instancias activas';

  @override
  String get agentTemplateMetricsSuccessRate => 'Tasa de éxito';

  @override
  String get agentTemplateMetricsTotalWakes => 'Activaciones totales';

  @override
  String get agentTemplateModelLabel => 'ID de modelo';

  @override
  String get agentTemplateModelRequirements =>
      'Solo se muestran modelos de razonamiento con llamada a funciones';

  @override
  String get agentTemplateNoMetrics => 'Aún no hay datos de rendimiento';

  @override
  String get agentTemplateNoneAssigned => 'Sin plantilla asignada';

  @override
  String get agentTemplateNoSuitableModels =>
      'No se encontraron modelos adecuados';

  @override
  String get agentTemplateNoTemplates =>
      'No hay plantillas disponibles. Crea una en Configuración primero.';

  @override
  String get agentTemplateNotFound => 'Plantilla no encontrada';

  @override
  String get agentTemplateNoVersions => 'Sin versiones';

  @override
  String get agentTemplateRollbackAction => 'Revertir a esta versión';

  @override
  String agentTemplateRollbackConfirm(int version) {
    return '¿Revertir a la versión $version? El agente usará esta versión en su próximo despertar.';
  }

  @override
  String get agentTemplateSaveNewVersion => 'Guardar como nueva versión';

  @override
  String get agentTemplateSelectTitle => 'Seleccionar plantilla';

  @override
  String get agentTemplateSettingsSubtitle =>
      'Gestionar personalidades y directivas de agentes';

  @override
  String get agentTemplateStatusActive => 'Activo';

  @override
  String get agentTemplateStatusArchived => 'Archivado';

  @override
  String get agentTemplatesTitle => 'Plantillas de agentes';

  @override
  String get agentTemplateSwitchHint =>
      'Para usar una plantilla diferente, destruye este agente y crea uno nuevo.';

  @override
  String get agentTemplateVersionHistoryTitle => 'Historial de versiones';

  @override
  String agentTemplateVersionLabel(int version) {
    return 'Versión $version';
  }

  @override
  String get agentTemplateVersionSaved => 'Nueva versión guardada';

  @override
  String get agentThreadReportLabel => 'Informe producido durante este ciclo';

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
  String get aiBatchToggleTooltip => 'Cambiar a grabación estándar';

  @override
  String get aiConfigApiKeyEmptyError => 'La clave API no puede estar vacía';

  @override
  String get aiConfigApiKeyFieldLabel => 'Clave API';

  @override
  String aiConfigAssociatedModelsRemoved(int count) {
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
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count modelo$_temp0 asociado$_temp1 eliminado$_temp2';
  }

  @override
  String get aiConfigBaseUrlFieldLabel => 'URL base';

  @override
  String get aiConfigCommentFieldLabel => 'Comentario (Opcional)';

  @override
  String get aiConfigCreateButtonLabel => 'Crear prompt';

  @override
  String get aiConfigDescriptionFieldLabel => 'Descripción (Opcional)';

  @override
  String aiConfigFailedToLoadModels(String error) {
    return 'Error al cargar modelos: $error';
  }

  @override
  String get aiConfigFailedToLoadModelsGeneric =>
      'Error al cargar modelos. Por favor, inténtalo de nuevo.';

  @override
  String get aiConfigFailedToSaveMessage =>
      'Error al guardar la configuración. Por favor, inténtalo de nuevo.';

  @override
  String get aiConfigInputDataTypesTitle =>
      'Tipos de datos de entrada requeridos';

  @override
  String get aiConfigInputModalitiesFieldLabel => 'Modalidades de entrada';

  @override
  String get aiConfigInputModalitiesTitle => 'Modalidades de entrada';

  @override
  String get aiConfigInvalidUrlError => 'Por favor, introduzca una URL válida';

  @override
  String get aiConfigListCascadeDeleteWarning =>
      'Esto también eliminará todos los modelos asociados a este proveedor.';

  @override
  String get aiConfigListDeleteConfirmCancel => 'CANCELAR';

  @override
  String get aiConfigListDeleteConfirmDelete => 'ELIMINAR';

  @override
  String aiConfigListDeleteConfirmMessage(String configName) {
    return '¿Estás seguro de que quieres eliminar \"$configName\"?';
  }

  @override
  String get aiConfigListDeleteConfirmTitle => 'Confirmar eliminación';

  @override
  String get aiConfigListEmptyState =>
      'No se encontraron configuraciones. Añade una para comenzar.';

  @override
  String aiConfigListErrorDeleting(String configName, String error) {
    return 'Error al eliminar $configName: $error';
  }

  @override
  String get aiConfigListErrorLoading => 'Error al cargar las configuraciones';

  @override
  String aiConfigListItemDeleted(String configName) {
    return '$configName eliminado';
  }

  @override
  String get aiConfigListUndoDelete => 'DESHACER';

  @override
  String get aiConfigManageModelsButton => 'Gestionar modelos';

  @override
  String aiConfigModelRemovedMessage(String modelName) {
    return '$modelName eliminado del prompt';
  }

  @override
  String get aiConfigModelsTitle => 'Modelos disponibles';

  @override
  String get aiConfigNameFieldLabel => 'Nombre para mostrar';

  @override
  String get aiConfigNameTooShortError =>
      'El nombre debe tener al menos 3 caracteres';

  @override
  String get aiConfigNoModelsAvailable =>
      'Aún no se han configurado modelos de AI. Por favor, añada uno en los ajustes.';

  @override
  String get aiConfigNoModelsSelected =>
      'No se han seleccionado modelos. Se requiere al menos un modelo.';

  @override
  String get aiConfigNoProvidersAvailable =>
      'No hay proveedores de API disponibles. Por favor, añada primero un proveedor de API.';

  @override
  String get aiConfigNoSuitableModelsAvailable =>
      'Ningún modelo cumple los requisitos para este prompt. Por favor, configura modelos con las capacidades requeridas.';

  @override
  String get aiConfigOutputModalitiesFieldLabel => 'Modalidades de salida';

  @override
  String get aiConfigOutputModalitiesTitle => 'Modalidades de salida';

  @override
  String get aiConfigProviderDeletedSuccessfully =>
      'Proveedor eliminado correctamente';

  @override
  String get aiConfigProviderFieldLabel => 'Proveedor de inferencia';

  @override
  String get aiConfigProviderModelIdFieldLabel => 'ID de modelo del proveedor';

  @override
  String get aiConfigProviderModelIdTooShortError =>
      'El ID del modelo debe tener al menos 3 caracteres';

  @override
  String get aiConfigProviderTypeFieldLabel => 'Tipo de proveedor';

  @override
  String get aiConfigReasoningCapabilityDescription =>
      'El modelo puede realizar razonamiento paso a paso';

  @override
  String get aiConfigReasoningCapabilityFieldLabel =>
      'Capacidad de razonamiento';

  @override
  String get aiConfigRequiredInputDataFieldLabel =>
      'Datos de entrada requeridos';

  @override
  String get aiConfigResponseTypeFieldLabel => 'Tipo de respuesta AI';

  @override
  String get aiConfigResponseTypeNotSelectedError =>
      'Por favor, selecciona un tipo de respuesta';

  @override
  String get aiConfigResponseTypeSelectHint => 'Seleccionar tipo de respuesta';

  @override
  String get aiConfigSelectInputDataTypesPrompt =>
      'Seleccionar tipos de datos requeridos...';

  @override
  String get aiConfigSelectModalitiesPrompt => 'Seleccionar modalidades';

  @override
  String get aiConfigSelectProviderModalTitle =>
      'Seleccionar proveedor de inferencia';

  @override
  String get aiConfigSelectProviderNotFound =>
      'Proveedor de inferencia no encontrado';

  @override
  String get aiConfigSelectProviderTypeModalTitle =>
      'Seleccionar tipo de proveedor';

  @override
  String get aiConfigSelectResponseTypeTitle =>
      'Seleccionar tipo de respuesta AI';

  @override
  String get aiConfigSystemMessageFieldLabel => 'Mensaje del sistema';

  @override
  String get aiConfigUpdateButtonLabel => 'Actualizar prompt';

  @override
  String get aiConfigUseReasoningDescription =>
      'Si está activado, el modelo utilizará sus capacidades de razonamiento para este prompt.';

  @override
  String get aiConfigUseReasoningFieldLabel => 'Usar razonamiento';

  @override
  String get aiConfigUserMessageEmptyError =>
      'El mensaje del usuario no puede estar vacío';

  @override
  String get aiConfigUserMessageFieldLabel => 'Mensaje del usuario';

  @override
  String get aiFormCancel => 'Cancelar';

  @override
  String get aiFormFixErrors =>
      'Por favor, corrige los errores antes de guardar';

  @override
  String get aiFormNoChanges => 'No hay cambios sin guardar';

  @override
  String get aiInferenceErrorAuthenticationMessage =>
      'La autenticación falló. Por favor, verifica tu clave API y asegúrate de que sea válida.';

  @override
  String get aiInferenceErrorAuthenticationTitle => 'Autenticación fallida';

  @override
  String get aiInferenceErrorConnectionFailedMessage =>
      'No se pudo conectar al servicio de AI. Por favor, verifica tu conexión a Internet y asegúrate de que el servicio sea accesible.';

  @override
  String get aiInferenceErrorConnectionFailedTitle => 'Conexión fallida';

  @override
  String get aiInferenceErrorInvalidRequestMessage =>
      'La solicitud no fue válida. Por favor, verifica tu configuración e inténtalo de nuevo.';

  @override
  String get aiInferenceErrorInvalidRequestTitle => 'Solicitud no válida';

  @override
  String get aiInferenceErrorRateLimitMessage =>
      'Ha excedido el límite de solicitudes. Por favor, espere un momento antes de intentarlo de nuevo.';

  @override
  String get aiInferenceErrorRateLimitTitle => 'Límite de solicitudes excedido';

  @override
  String get aiInferenceErrorRetryButton => 'Reintentar';

  @override
  String get aiInferenceErrorServerMessage =>
      'El servicio de AI encontró un error. Por favor, inténtalo más tarde.';

  @override
  String get aiInferenceErrorServerTitle => 'Error del servidor';

  @override
  String get aiInferenceErrorSuggestionsTitle => 'Sugerencias:';

  @override
  String get aiInferenceErrorTimeoutMessage =>
      'La solicitud tardó demasiado en completarse. Por favor, inténtalo de nuevo o verifica si el servicio responde.';

  @override
  String get aiInferenceErrorTimeoutTitle => 'Tiempo de espera agotado';

  @override
  String get aiInferenceErrorUnknownMessage =>
      'Ocurrió un error inesperado. Por favor, inténtalo de nuevo.';

  @override
  String get aiInferenceErrorUnknownTitle => 'Error';

  @override
  String get aiInferenceErrorViewLogButton => 'Ver registro';

  @override
  String get aiModelSettings => 'Ajustes de modelo AI';

  @override
  String get aiProviderAlibabaDescription =>
      'La familia de modelos Qwen de Alibaba Cloud a través de la API DashScope';

  @override
  String get aiProviderAlibabaName => 'Alibaba Cloud (Qwen)';

  @override
  String get aiProviderAnthropicDescription =>
      'La familia de asistentes AI Claude de Anthropic';

  @override
  String get aiProviderAnthropicName => 'Anthropic Claude';

  @override
  String get aiProviderGeminiDescription => 'Modelos AI Gemini de Google';

  @override
  String get aiProviderGeminiName => 'Google Gemini';

  @override
  String get aiProviderGenericOpenAiDescription =>
      'API compatible con el formato OpenAI';

  @override
  String get aiProviderGenericOpenAiName => 'Compatible con OpenAI';

  @override
  String get aiProviderMistralDescription =>
      'API en la nube de Mistral AI con transcripción de audio nativa';

  @override
  String get aiProviderMistralName => 'Mistral';

  @override
  String get aiProviderNebiusAiStudioDescription =>
      'Modelos de Nebius AI Studio';

  @override
  String get aiProviderNebiusAiStudioName => 'Nebius AI Studio';

  @override
  String get aiProviderOllamaDescription =>
      'Ejecutar inferencia localmente con Ollama';

  @override
  String get aiProviderOllamaName => 'Ollama';

  @override
  String get aiProviderOpenAiDescription => 'Modelos GPT de OpenAI';

  @override
  String get aiProviderOpenAiName => 'OpenAI';

  @override
  String get aiProviderOpenRouterDescription => 'Modelos de OpenRouter';

  @override
  String get aiProviderOpenRouterName => 'OpenRouter';

  @override
  String get aiProviderVoxtralDescription =>
      'Transcripción Voxtral local (hasta 30 min de audio, 13 idiomas)';

  @override
  String get aiProviderVoxtralName => 'Voxtral (local)';

  @override
  String get aiProviderWhisperDescription =>
      'Transcripción Whisper local con API compatible con OpenAI';

  @override
  String get aiProviderWhisperName => 'Whisper (local)';

  @override
  String get aiRealtimeToggleTooltip => 'Cambiar a transcripción en vivo';

  @override
  String get aiRealtimeTranscribing => 'Transcripción en vivo...';

  @override
  String get aiRealtimeTranscriptionError =>
      'Transcripción en vivo desconectada. Audio guardado para procesamiento por lotes.';

  @override
  String get aiResponseDeleteCancel => 'Cancelar';

  @override
  String get aiResponseDeleteConfirm => 'Eliminar';

  @override
  String get aiResponseDeleteError =>
      'Error al eliminar la respuesta AI. Por favor, inténtalo de nuevo.';

  @override
  String get aiResponseDeleteTitle => 'Eliminar respuesta AI';

  @override
  String get aiResponseDeleteWarning =>
      '¿Estás seguro de que quieres eliminar esta respuesta AI? Esta acción no se puede deshacer.';

  @override
  String get aiResponseTypeAudioTranscription => 'Transcripción de audio';

  @override
  String get aiResponseTypeChecklistUpdates =>
      'Actualizaciones de lista de verificación';

  @override
  String get aiResponseTypeImageAnalysis => 'Análisis de imagen';

  @override
  String get aiResponseTypeImagePromptGeneration => 'Prompt de Imagen';

  @override
  String get aiResponseTypePromptGeneration => 'Prompt generado';

  @override
  String get aiResponseTypeTaskSummary => 'Resumen de tarea';

  @override
  String get aiSettingsAddedLabel => 'Añadido';

  @override
  String get aiSettingsAddModelButton => 'Añadir modelo';

  @override
  String get aiSettingsAddModelTooltip => 'Añadir este modelo a tu proveedor';

  @override
  String get aiSettingsAddPromptButton => 'Añadir prompt';

  @override
  String get aiSettingsAddProviderButton => 'Añadir proveedor';

  @override
  String get aiSettingsClearAllFiltersTooltip => 'Borrar todos los filtros';

  @override
  String get aiSettingsClearFiltersButton => 'Limpiar';

  @override
  String aiSettingsDeleteSelectedConfirmMessage(int count) {
    return '¿Estás seguro de que quieres eliminar $count prompts seleccionados? Esta acción no se puede deshacer.';
  }

  @override
  String get aiSettingsDeleteSelectedConfirmTitle =>
      'Eliminar prompts seleccionados';

  @override
  String aiSettingsDeleteSelectedLabel(int count) {
    return 'Eliminar ($count)';
  }

  @override
  String get aiSettingsDeleteSelectedTooltip =>
      'Eliminar prompts seleccionados';

  @override
  String aiSettingsFilterByCapabilityTooltip(String capability) {
    return 'Filtrar por capacidad $capability';
  }

  @override
  String aiSettingsFilterByProviderTooltip(String provider) {
    return 'Filtrar por $provider';
  }

  @override
  String get aiSettingsFilterByReasoningTooltip =>
      'Filtrar por capacidad de razonamiento';

  @override
  String aiSettingsFilterByResponseTypeTooltip(String responseType) {
    return 'Filtrar por prompts de $responseType';
  }

  @override
  String get aiSettingsModalityAudio => 'Audio';

  @override
  String get aiSettingsModalityText => 'Texto';

  @override
  String get aiSettingsModalityVision => 'Visión';

  @override
  String get aiSettingsNoModelsConfigured => 'No hay modelos AI configurados';

  @override
  String get aiSettingsNoPromptsConfigured => 'No hay prompts AI configurados';

  @override
  String get aiSettingsNoProvidersConfigured =>
      'No hay proveedores AI configurados';

  @override
  String get aiSettingsPageTitle => 'Ajustes AI';

  @override
  String get aiSettingsReasoningLabel => 'Razonamiento';

  @override
  String get aiSettingsSearchHint => 'Buscar configuraciones AI...';

  @override
  String get aiSettingsSelectLabel => 'Seleccionar';

  @override
  String get aiSettingsSelectModeTooltip =>
      'Alternar modo de selección para operaciones masivas';

  @override
  String get aiSettingsTabModels => 'Modelos';

  @override
  String get aiSettingsTabPrompts => 'Prompts';

  @override
  String get aiSettingsTabProviders => 'Proveedores';

  @override
  String get aiSetupWizardCreatesOptimized =>
      'Crea modelos, prompts y una categoría de prueba optimizados';

  @override
  String aiSetupWizardDescription(String providerName) {
    return 'Configurar o actualizar modelos, prompts y categoría de prueba para $providerName';
  }

  @override
  String get aiSetupWizardRunButton => 'Ejecutar configuración';

  @override
  String get aiSetupWizardRunLabel => 'Ejecutar asistente de configuración';

  @override
  String get aiSetupWizardRunningButton => 'Ejecutando...';

  @override
  String get aiSetupWizardSafeToRunMultiple =>
      'Se puede ejecutar varias veces - los elementos existentes se conservarán';

  @override
  String get aiSetupWizardTitle => 'Asistente de configuración AI';

  @override
  String get aiTaskSummaryCancelScheduled => 'Cancelar resumen programado';

  @override
  String get aiTaskSummaryRunning => 'Pensando en resumir la tarea...';

  @override
  String aiTaskSummaryScheduled(String time) {
    return 'Resumen en $time';
  }

  @override
  String get aiTaskSummaryTitle => 'Resumen de tareas de IA';

  @override
  String get aiTaskSummaryTriggerNow => 'Generar resumen ahora';

  @override
  String get aiTranscribingAudio => 'Transcribiendo audio...';

  @override
  String get apiKeyAddPageTitle => 'Añadir proveedor';

  @override
  String get apiKeyEditLoadError =>
      'Error al cargar la configuración de la clave API';

  @override
  String get apiKeyEditPageTitle => 'Editar proveedor';

  @override
  String get apiKeyFormCreateButton => 'Crear';

  @override
  String get apiKeyFormUpdateButton => 'Actualizar';

  @override
  String get apiKeysSettingsPageTitle => 'Proveedores de inferencia AI';

  @override
  String get audioRecordingCancel => 'CANCELAR';

  @override
  String get audioRecordingListening => 'Escuchando...';

  @override
  String get audioRecordingRealtime => 'Transcripción en vivo';

  @override
  String get audioRecordings => 'Grabaciones de audio';

  @override
  String get audioRecordingStandard => 'Estándar';

  @override
  String get audioRecordingStop => 'PARAR';

  @override
  String get automaticPrompts => 'Prompts automáticos';

  @override
  String get backfillManualDescription =>
      'Solicitar todas las entradas faltantes sin importar su antigüedad. Úsalo para recuperar brechas de sincronización antiguas.';

  @override
  String get backfillManualProcessing => 'Procesando...';

  @override
  String backfillManualSuccess(int count) {
    return '$count entradas solicitadas';
  }

  @override
  String get backfillManualTitle => 'Relleno manual';

  @override
  String get backfillManualTrigger => 'Solicitar entradas faltantes';

  @override
  String get backfillReRequestDescription =>
      'Volver a solicitar entradas que fueron solicitadas pero nunca recibidas. Úsalo cuando las respuestas estén atascadas.';

  @override
  String get backfillReRequestProcessing => 'Volviendo a solicitar...';

  @override
  String backfillReRequestSuccess(int count) {
    return '$count entradas vueltas a solicitar';
  }

  @override
  String get backfillReRequestTitle => 'Volver a solicitar pendientes';

  @override
  String get backfillReRequestTrigger =>
      'Volver a solicitar entradas pendientes';

  @override
  String get backfillSettingsInfo =>
      'El relleno automático solicita las entradas faltantes de las últimas 24 horas. Use el relleno manual para entradas más antiguas.';

  @override
  String get backfillSettingsSubtitle =>
      'Gestionar recuperación de brechas de sincronización';

  @override
  String get backfillSettingsTitle => 'Relleno de sincronización';

  @override
  String get backfillStatsBackfilled => 'Rellenado';

  @override
  String get backfillStatsDeleted => 'Eliminado';

  @override
  String backfillStatsHostsTitle(int count) {
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
    return '$count dispositivo$_temp0 conectado$_temp1';
  }

  @override
  String get backfillStatsMissing => 'Faltante';

  @override
  String get backfillStatsNoData =>
      'No hay datos de sincronización disponibles';

  @override
  String get backfillStatsReceived => 'Recibido';

  @override
  String get backfillStatsRefresh => 'Actualizar estadísticas';

  @override
  String get backfillStatsRequested => 'Solicitado';

  @override
  String get backfillStatsTitle => 'Estadísticas de sincronización';

  @override
  String get backfillStatsTotalEntries => 'Entradas totales';

  @override
  String get backfillStatsUnresolvable => 'No resoluble';

  @override
  String get backfillToggleDisabledDescription =>
      'Relleno desactivado - útil en redes con datos limitados';

  @override
  String get backfillToggleEnabledDescription =>
      'Solicitar automáticamente entradas de sincronización faltantes';

  @override
  String get backfillToggleTitle => 'Relleno automático';

  @override
  String get basicSettings => 'Ajustes básicos';

  @override
  String get cancelButton => 'Cancelar';

  @override
  String get categoryActiveDescription =>
      'Las categorías inactivas no aparecerán en las listas de selección';

  @override
  String get categoryAiModelDescription =>
      'Controlar qué prompts AI se pueden usar con esta categoría';

  @override
  String get categoryAutomaticPromptsDescription =>
      'Configurar prompts que se ejecutan automáticamente para diferentes tipos de contenido';

  @override
  String get categoryCreationError =>
      'No se pudo crear la categoría. Por favor, inténtalo de nuevo.';

  @override
  String get categoryDefaultLanguageDescription =>
      'Establecer un idioma predeterminado para las tareas de esta categoría';

  @override
  String get categoryDeleteConfirm => 'SÍ, ELIMINAR ESTA CATEGORÍA';

  @override
  String get categoryDeleteConfirmation =>
      'Esta acción no se puede deshacer. Todas las entradas de esta categoría se conservarán pero dejarán de estar categorizadas.';

  @override
  String get categoryDeleteQuestion => '¿Quieres eliminar esta categoría?';

  @override
  String get categoryDeleteTitle => '¿Eliminar categoría?';

  @override
  String get categoryFavoriteDescription =>
      'Marcar esta categoría como favorita';

  @override
  String get categoryNameRequired => 'El nombre de la categoría es obligatorio';

  @override
  String get categoryNotFound => 'Categoría no encontrada';

  @override
  String get categoryPrivateDescription =>
      'Ocultar esta categoría cuando el modo privado esté activado';

  @override
  String get categoryPromptFilterAll => 'Todos';

  @override
  String get categorySearchPlaceholder => 'Buscar categorías...';

  @override
  String get celebrationTapToContinue => 'Toca para continuar';

  @override
  String get chatInputCancelRealtime => 'Cancelar (Esc)';

  @override
  String get chatInputCancelRecording => 'Cancelar grabación (Esc)';

  @override
  String get chatInputConfigureModel => 'Configurar modelo';

  @override
  String get chatInputHintDefault =>
      'Pregunta sobre tus tareas y productividad...';

  @override
  String get chatInputHintSelectModel =>
      'Selecciona un modelo para empezar a chatear';

  @override
  String get chatInputListening => 'Escuchando...';

  @override
  String get chatInputPleaseWait => 'Espera...';

  @override
  String get chatInputProcessing => 'Procesando...';

  @override
  String get chatInputRecordVoice => 'Grabar mensaje de voz';

  @override
  String get chatInputSendTooltip => 'Enviar mensaje';

  @override
  String get chatInputStartRealtime => 'Iniciar transcripción en vivo';

  @override
  String get chatInputStopRealtime => 'Detener transcripción en vivo';

  @override
  String get chatInputStopTranscribe => 'Detener y transcribir';

  @override
  String get checklistAddItem => 'Agregar un nuevo elemento';

  @override
  String get checklistAllDone => '¡Todos los elementos completados!';

  @override
  String checklistCompletedShort(int completed, int total) {
    return '$completed/$total completados';
  }

  @override
  String get checklistDelete => '¿Eliminar lista de verificación?';

  @override
  String get checklistExportAsMarkdown =>
      'Exportar lista de verificación como Markdown';

  @override
  String get checklistExportFailed => 'Error en la exportación';

  @override
  String get checklistFilterShowAll => 'Mostrar todos los elementos';

  @override
  String get checklistFilterShowOpen => 'Mostrar elementos pendientes';

  @override
  String get checklistFilterStateAll => 'Mostrando todos los elementos';

  @override
  String get checklistFilterStateOpenOnly => 'Mostrando elementos pendientes';

  @override
  String checklistFilterToggleSemantics(String state) {
    return 'Alternar filtro de lista de verificación (actual: $state)';
  }

  @override
  String get checklistItemArchived => 'Elemento archivado';

  @override
  String get checklistItemArchiveUndo => 'Deshacer';

  @override
  String get checklistItemDelete =>
      '¿Eliminar elemento de la lista de verificación?';

  @override
  String get checklistItemDeleteCancel => 'Cancelar';

  @override
  String get checklistItemDeleteConfirm => 'Confirmar';

  @override
  String get checklistItemDeleted => 'Elemento eliminado';

  @override
  String get checklistItemDeleteWarning => 'Esta acción no se puede deshacer.';

  @override
  String get checklistItemDrag =>
      'Arrastre las sugerencias a la lista de verificación';

  @override
  String get checklistItemUnarchived => 'Elemento restaurado';

  @override
  String get checklistMarkdownCopied =>
      'Lista de verificación copiada como Markdown';

  @override
  String get checklistNoSuggestionsTitle =>
      'No hay elementos de acción sugeridos';

  @override
  String get checklistNothingToExport => 'No hay elementos para exportar';

  @override
  String get checklistShareHint => 'Mantener pulsado para compartir';

  @override
  String get checklistsReorder => 'Reordenar';

  @override
  String get checklistsTitle => 'Listas de verificación';

  @override
  String get checklistSuggestionsOutdated => 'Obsoleto';

  @override
  String get checklistSuggestionsRunning =>
      'Pensando en sugerencias sin seguimiento...';

  @override
  String get checklistSuggestionsTitle => 'Elementos de acción sugeridos';

  @override
  String get checklistUpdates => 'Actualizaciones de lista de verificación';

  @override
  String get clearButton => 'Borrar';

  @override
  String get colorLabel => 'Color:';

  @override
  String get colorPickerError => 'Color hexadecimal no válido';

  @override
  String get colorPickerHint => 'Ingrese el color hexadecimal o elija';

  @override
  String get commonError => 'Error';

  @override
  String get commonLoading => 'Cargando...';

  @override
  String get commonUnknown => 'Desconocido';

  @override
  String get completeHabitFailButton => 'Fallar';

  @override
  String get completeHabitSkipButton => 'Omitir';

  @override
  String get completeHabitSuccessButton => 'Éxito';

  @override
  String get configFlagAttemptEmbeddingDescription =>
      'Cuando está habilitado, la aplicación intentará generar incrustaciones para tus entradas para mejorar la búsqueda y las sugerencias de contenido relacionado.';

  @override
  String get configFlagAutoTranscribeDescription =>
      'Transcribir automáticamente grabaciones de audio en tus entradas. Esto requiere una conexión a Internet.';

  @override
  String get configFlagEnableAgents => 'Activar agentes';

  @override
  String get configFlagEnableAgentsDescription =>
      'Permitir que los agentes de IA supervisen y analicen tus tareas de forma autónoma.';

  @override
  String get configFlagEnableAiStreaming =>
      'Habilitar streaming de IA para acciones de tareas';

  @override
  String get configFlagEnableAiStreamingDescription =>
      'Transmitir respuestas de IA para acciones relacionadas con tareas. Desactívelo para almacenar respuestas en búfer y mantener la interfaz más fluida.';

  @override
  String get configFlagEnableAutoTaskTldrDescription =>
      'Generar automáticamente resúmenes para tus tareas para ayudarte a comprender rápidamente su estado.';

  @override
  String get configFlagEnableCalendarPage => 'Habilitar página Calendario';

  @override
  String get configFlagEnableCalendarPageDescription =>
      'Mostrar la página Calendario en la navegación principal. Ve y administra tus entradas en una vista de calendario.';

  @override
  String get configFlagEnableDailyOs => 'Habilitar DailyOS';

  @override
  String get configFlagEnableDailyOsDescription =>
      'Mostrar DailyOS en la navegación principal.';

  @override
  String get configFlagEnableDashboardsPage => 'Habilitar página Paneles';

  @override
  String get configFlagEnableDashboardsPageDescription =>
      'Mostrar la página Paneles en la navegación principal. Ve tus datos e información en paneles personalizables.';

  @override
  String get configFlagEnableEvents => 'Activar eventos';

  @override
  String get configFlagEnableEventsDescription =>
      'Mostrar la función de eventos para crear, rastrear y gestionar eventos en tu diario.';

  @override
  String get configFlagEnableHabitsPage => 'Habilitar página Hábitos';

  @override
  String get configFlagEnableHabitsPageDescription =>
      'Mostrar la página Hábitos en la navegación principal. Rastrea y administra tus hábitos diarios aquí.';

  @override
  String get configFlagEnableLogging => 'Habilitar registro';

  @override
  String get configFlagEnableLoggingDescription =>
      'Habilitar el registro detallado para fines de depuración. Esto puede afectar el rendimiento.';

  @override
  String get configFlagEnableMatrix => 'Habilitar sincronización Matrix';

  @override
  String get configFlagEnableMatrixDescription =>
      'Habilitar la integración de Matrix para sincronizar tus entradas entre dispositivos y con otros usuarios de Matrix.';

  @override
  String get configFlagEnableNotifications => '¿Habilitar notificaciones?';

  @override
  String get configFlagEnableNotificationsDescription =>
      'Recibir notificaciones de recordatorios, actualizaciones y eventos importantes.';

  @override
  String get configFlagEnableSessionRatings =>
      'Habilitar calificaciones de sesión';

  @override
  String get configFlagEnableSessionRatingsDescription =>
      'Solicitar una calificación rápida de sesión al detener un temporizador.';

  @override
  String get configFlagEnableTooltip =>
      'Habilitar información sobre herramientas';

  @override
  String get configFlagEnableTooltipDescription =>
      'Mostrar información sobre herramientas útil en toda la aplicación para guiarte a través de las funciones.';

  @override
  String get configFlagPrivate => '¿Mostrar entradas privadas?';

  @override
  String get configFlagPrivateDescription =>
      'Habilita esto para que tus entradas sean privadas de forma predeterminada. Las entradas privadas solo son visibles para ti.';

  @override
  String get configFlagRecordLocation => 'Registrar ubicación';

  @override
  String get configFlagRecordLocationDescription =>
      'Registrar automáticamente tu ubicación con las nuevas entradas. Esto ayuda con la organización y la búsqueda basadas en la ubicación.';

  @override
  String get configFlagResendAttachments => 'Reenviar archivos adjuntos';

  @override
  String get configFlagResendAttachmentsDescription =>
      'Activar para reenviar automáticamente las cargas de archivos adjuntos fallidas cuando se restablezca la conexión.';

  @override
  String get configFlagUseCloudInferenceDescription =>
      'Utiliza servicios de IA basados en la nube para funciones mejoradas. Esto requiere una conexión a Internet.';

  @override
  String get conflictEntityLabel => 'Entidad';

  @override
  String get conflictIdLabel => 'ID';

  @override
  String get conflictsCopyTextFromSync => 'Copiar texto desde sincronización';

  @override
  String get conflictsEmptyDescription =>
      'Todo está sincronizado. Los elementos resueltos siguen disponibles en el otro filtro.';

  @override
  String get conflictsEmptyTitle => 'No se detectaron conflictos';

  @override
  String get conflictsResolved => 'resueltos';

  @override
  String get conflictsResolveLocalVersion => 'Resolver con versión local';

  @override
  String get conflictsResolveRemoteVersion => 'Resolver con versión remota';

  @override
  String get conflictsUnresolved => 'sin resolver';

  @override
  String get copyAsMarkdown => 'Copiar como Markdown';

  @override
  String get copyAsText => 'Copiar como texto';

  @override
  String get correctionExampleCancel => 'CANCELAR';

  @override
  String get correctionExampleCaptured =>
      'Corrección guardada para aprendizaje de IA';

  @override
  String correctionExamplePending(int seconds) {
    return 'Guardando corrección en ${seconds}s...';
  }

  @override
  String get correctionExamplesEmpty =>
      'Aún no se han capturado correcciones. Edita un elemento de la lista para agregar tu primer ejemplo.';

  @override
  String get correctionExamplesSectionDescription =>
      'Cuando corriges manualmente elementos de la lista, esas correcciones se guardan aquí y se usan para mejorar las sugerencias de IA.';

  @override
  String get correctionExamplesSectionTitle =>
      'Ejemplos de Corrección de Lista';

  @override
  String correctionExamplesWarning(int count, int max) {
    return 'Tienes $count correcciones. Solo las $max más recientes se usarán en los prompts de IA. Considera eliminar ejemplos antiguos o redundantes.';
  }

  @override
  String get coverArtAssign => 'Establecer como imagen de portada';

  @override
  String get coverArtChipActive => 'Portada';

  @override
  String get coverArtChipSet => 'Establecer portada';

  @override
  String get coverArtRemove => 'Eliminar imagen de portada';

  @override
  String get createButton => 'Crear';

  @override
  String get createCategoryTitle => 'Crear categoría:';

  @override
  String get createEntryLabel => 'Crear nueva entrada';

  @override
  String get createEntryTitle => 'Añadir';

  @override
  String get createNewLinkedTask => 'Crear nueva tarea vinculada...';

  @override
  String get createPromptsFirst =>
      'Crea primero prompts AI para configurarlos aquí';

  @override
  String get customColor => 'Color personalizado';

  @override
  String get dailyOsActual => 'Real';

  @override
  String get dailyOsAddBlock => 'Añadir bloque';

  @override
  String get dailyOsAddBudget => 'Añadir presupuesto';

  @override
  String get dailyOsAddNote => 'Añadir una nota...';

  @override
  String get dailyOsAgreeToPlan => 'Aceptar plan';

  @override
  String get dailyOsCancel => 'Cancelar';

  @override
  String get dailyOsCategory => 'Categoría';

  @override
  String get dailyOsChooseCategory => 'Elegir una categoría...';

  @override
  String get dailyOsCompletionMessage =>
      '¡Buen trabajo! Has completado tu día.';

  @override
  String get dailyOsCopyToTomorrow => 'Copiar a mañana';

  @override
  String get dailyOsDayComplete => 'Día completado';

  @override
  String get dailyOsDayPlan => 'Plan del día';

  @override
  String get dailyOsDaySummary => 'Resumen del día';

  @override
  String get dailyOsDelete => 'Eliminar';

  @override
  String get dailyOsDeleteBudget => '¿Eliminar presupuesto?';

  @override
  String get dailyOsDeleteBudgetConfirm =>
      'Esto eliminará el presupuesto de tiempo de tu plan del día.';

  @override
  String get dailyOsDeletePlannedBlock => '¿Eliminar bloque?';

  @override
  String get dailyOsDeletePlannedBlockConfirm =>
      'Esto eliminará el bloque planificado de tu línea de tiempo.';

  @override
  String get dailyOsDoneForToday => 'Terminado por hoy';

  @override
  String get dailyOsDraftMessage =>
      'El plan es un borrador. Acepte para confirmarlo.';

  @override
  String get dailyOsDueToday => 'Vence hoy';

  @override
  String get dailyOsDueTodayShort => 'Hoy';

  @override
  String dailyOsDuplicateBudget(String categoryName) {
    return 'Ya existe un presupuesto para \"$categoryName\"';
  }

  @override
  String get dailyOsDuration1h => '1h';

  @override
  String get dailyOsDuration2h => '2h';

  @override
  String get dailyOsDuration30m => '30m';

  @override
  String get dailyOsDuration3h => '3h';

  @override
  String get dailyOsDuration4h => '4h';

  @override
  String dailyOsDurationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count horas',
      one: '1 hora',
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
      other: '$count minutos',
      one: '1 minuto',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsEditBudget => 'Editar presupuesto';

  @override
  String get dailyOsEditPlannedBlock => 'Editar bloque planificado';

  @override
  String get dailyOsEndTime => 'Fin';

  @override
  String get dailyOsEntry => 'Entrada';

  @override
  String get dailyOsExpandToMove =>
      'Expandir línea de tiempo para arrastrar este bloque';

  @override
  String get dailyOsExpandToMoveMore =>
      'Expandir línea de tiempo para mover más';

  @override
  String get dailyOsFailedToLoadBudgets => 'Error al cargar presupuestos';

  @override
  String get dailyOsFailedToLoadTimeline =>
      'Error al cargar la línea de tiempo';

  @override
  String get dailyOsFold => 'Contraer';

  @override
  String dailyOsHoursMinutesPlanned(int hours, int minutes) {
    return '${hours}h ${minutes}m planificados';
  }

  @override
  String dailyOsHoursPlanned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count horas planificadas',
      one: '1 hora planificada',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsInvalidTimeRange => 'Rango de tiempo no válido';

  @override
  String dailyOsMinutesPlanned(int count) {
    return '$count min planificados';
  }

  @override
  String get dailyOsNearLimit => 'Cerca del límite';

  @override
  String get dailyOsNoBudgets => 'Sin presupuestos de tiempo';

  @override
  String get dailyOsNoBudgetsHint =>
      'Añade presupuestos para rastrear cómo distribuyes tu tiempo entre categorías.';

  @override
  String get dailyOsNoBudgetWarning => 'Sin tiempo planificado';

  @override
  String get dailyOsNote => 'Nota';

  @override
  String get dailyOsNoTimeline => 'Sin entradas en la línea de tiempo';

  @override
  String get dailyOsNoTimelineHint =>
      'Inicia un temporizador o añade bloques planificados para ver tu día.';

  @override
  String get dailyOsOnTrack => 'En camino';

  @override
  String get dailyOsOver => 'Excedido';

  @override
  String get dailyOsOverallProgress => 'Progreso general';

  @override
  String get dailyOsOverBudget => 'Presupuesto excedido';

  @override
  String get dailyOsOverdue => 'Vencido';

  @override
  String get dailyOsOverdueShort => 'Tarde';

  @override
  String get dailyOsPlan => 'Plan';

  @override
  String get dailyOsPlanned => 'Planificado';

  @override
  String get dailyOsPlannedDuration => 'Duración planificada';

  @override
  String get dailyOsQuickCreateTask => 'Crear tarea para este presupuesto';

  @override
  String get dailyOsReAgree => 'Volver a aceptar';

  @override
  String get dailyOsRecorded => 'Registrado';

  @override
  String get dailyOsRemaining => 'Restante';

  @override
  String get dailyOsReviewMessage => 'Se detectaron cambios. Revisa tu plan.';

  @override
  String get dailyOsSave => 'Guardar';

  @override
  String get dailyOsSelectCategory => 'Seleccionar categoría';

  @override
  String get dailyOsStartTime => 'Inicio';

  @override
  String get dailyOsTasks => 'Tareas';

  @override
  String get dailyOsTimeBudgets => 'Presupuestos de tiempo';

  @override
  String dailyOsTimeLeft(String time) {
    return '$time restante';
  }

  @override
  String get dailyOsTimeline => 'Línea de tiempo';

  @override
  String dailyOsTimeOver(String time) {
    return '+$time excedido';
  }

  @override
  String get dailyOsTimeRange => 'Rango de tiempo';

  @override
  String get dailyOsTimesUp => 'Tiempo agotado';

  @override
  String get dailyOsTodayButton => 'Hoy';

  @override
  String get dailyOsUncategorized => 'Sin categoría';

  @override
  String get dailyOsViewModeClassic => 'Clásico';

  @override
  String get dailyOsViewModeDailyOs => 'Daily OS';

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
  String get defaultLanguage => 'Idioma predeterminado';

  @override
  String get deleteButton => 'Eliminar';

  @override
  String get deleteDeviceLabel => 'Eliminar dispositivo';

  @override
  String deviceDeletedSuccess(String deviceName) {
    return 'Dispositivo $deviceName eliminado correctamente';
  }

  @override
  String deviceDeleteFailed(String error) {
    return 'Error al eliminar el dispositivo: $error';
  }

  @override
  String get done => 'Hecho';

  @override
  String get doneButton => 'Listo';

  @override
  String get editMenuTitle => 'Editar';

  @override
  String get editorInsertDivider => 'Insertar separador';

  @override
  String get editorPlaceholder => 'Introducir notas...';

  @override
  String get enhancedPromptFormAdditionalDetailsTitle => 'Detalles adicionales';

  @override
  String get enhancedPromptFormAiResponseTypeSubtitle =>
      'Formato de la respuesta esperada';

  @override
  String get enhancedPromptFormBasicConfigurationTitle =>
      'Configuración básica';

  @override
  String get enhancedPromptFormConfigurationOptionsTitle =>
      'Opciones de configuración';

  @override
  String get enhancedPromptFormDescription =>
      'Crea prompts personalizados que se pueden usar con tus modelos AI para generar tipos específicos de respuestas';

  @override
  String get enhancedPromptFormDescriptionHelperText =>
      'Notas opcionales sobre el propósito y uso de este prompt';

  @override
  String get enhancedPromptFormDisplayNameHelperText =>
      'Un nombre descriptivo para esta plantilla de prompt';

  @override
  String get enhancedPromptFormPreconfiguredPromptDescription =>
      'Elegir entre plantillas de prompt prediseñadas';

  @override
  String get enhancedPromptFormPromptConfigurationTitle =>
      'Configuración del prompt';

  @override
  String get enhancedPromptFormQuickStartDescription =>
      'Comience con una plantilla prediseñada para ahorrar tiempo';

  @override
  String get enhancedPromptFormQuickStartTitle => 'Inicio rápido';

  @override
  String get enhancedPromptFormRequiredInputDataSubtitle =>
      'Tipo de datos que espera este prompt';

  @override
  String get enhancedPromptFormSystemMessageHelperText =>
      'Instrucciones que definen el comportamiento y estilo de respuesta de la AI';

  @override
  String get enhancedPromptFormUserMessageHelperText =>
      'El texto principal del prompt.';

  @override
  String get enterCategoryName => 'Introduzca el nombre de la categoría';

  @override
  String get entryActions => 'Acciones';

  @override
  String get entryLabelsActionSubtitle =>
      'Asignar etiquetas para organizar esta entrada';

  @override
  String get entryLabelsActionTitle => 'Etiquetas';

  @override
  String get entryLabelsEditTooltip => 'Editar etiquetas';

  @override
  String get entryLabelsHeaderTitle => 'Etiquetas';

  @override
  String get entryLabelsNoLabels => 'Sin etiquetas asignadas';

  @override
  String get entryTypeLabelAiResponse => 'Respuesta AI';

  @override
  String get entryTypeLabelChecklist => 'Lista de verificación';

  @override
  String get entryTypeLabelChecklistItem => 'Elemento de lista';

  @override
  String get entryTypeLabelHabitCompletionEntry => 'Hábito';

  @override
  String get entryTypeLabelJournalAudio => 'Audio';

  @override
  String get entryTypeLabelJournalEntry => 'Texto';

  @override
  String get entryTypeLabelJournalEvent => 'Evento';

  @override
  String get entryTypeLabelJournalImage => 'Foto';

  @override
  String get entryTypeLabelMeasurementEntry => 'Medición';

  @override
  String get entryTypeLabelQuantitativeEntry => 'Salud';

  @override
  String get entryTypeLabelSurveyEntry => 'Encuesta';

  @override
  String get entryTypeLabelTask => 'Tarea';

  @override
  String get entryTypeLabelWorkoutEntry => 'Entrenamiento';

  @override
  String get errorLoadingPrompts => 'Error al cargar los prompts';

  @override
  String get eventNameLabel => 'Evento:';

  @override
  String get favoriteLabel => 'Favorito';

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
  String get generateCoverArt => 'Generar portada';

  @override
  String get generateCoverArtSubtitle =>
      'Crear imagen desde descripción de voz';

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
  String get habitShowAlertAtLabel => 'Mostrar alerta a las';

  @override
  String get habitShowFromLabel => 'Mostrar desde';

  @override
  String get habitsOpenHeader => 'Vencido ahora';

  @override
  String get habitsPendingLaterHeader => 'Más tarde hoy';

  @override
  String get imageGenerationAcceptButton => 'Aceptar como portada';

  @override
  String get imageGenerationCancelEdit => 'Cancelar';

  @override
  String get imageGenerationEditPromptButton => 'Editar prompt';

  @override
  String get imageGenerationEditPromptLabel => 'Editar prompt';

  @override
  String get imageGenerationError => 'Error al generar imagen';

  @override
  String get imageGenerationGenerating => 'Generando imagen...';

  @override
  String get imageGenerationModalTitle => 'Imagen generada';

  @override
  String get imageGenerationRetry => 'Reintentar';

  @override
  String imageGenerationSaveError(String error) {
    return 'Error al guardar imagen: $error';
  }

  @override
  String imageGenerationWithReferences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Usando $count imágenes de referencia',
      one: 'Usando 1 imagen de referencia',
      zero: 'Sin imágenes de referencia',
    );
    return '$_temp0';
  }

  @override
  String get imagePromptGenerationCardTitle => 'Prompt de Imagen AI';

  @override
  String get imagePromptGenerationCopiedSnackbar =>
      'Prompt de imagen copiado al portapapeles';

  @override
  String get imagePromptGenerationCopyButton => 'Copiar Prompt';

  @override
  String get imagePromptGenerationCopyTooltip =>
      'Copiar prompt de imagen al portapapeles';

  @override
  String get imagePromptGenerationExpandTooltip => 'Mostrar prompt completo';

  @override
  String get imagePromptGenerationFullPromptLabel =>
      'Prompt de Imagen Completo:';

  @override
  String get images => 'Imágenes';

  @override
  String get inputDataTypeAudioFilesDescription =>
      'Usar archivos de audio como entrada';

  @override
  String get inputDataTypeAudioFilesName => 'Archivos de audio';

  @override
  String get inputDataTypeImagesDescription => 'Usar imágenes como entrada';

  @override
  String get inputDataTypeImagesName => 'Imágenes';

  @override
  String get inputDataTypeTaskDescription =>
      'Usar la tarea actual como entrada';

  @override
  String get inputDataTypeTaskName => 'Tarea';

  @override
  String get inputDataTypeTasksListDescription =>
      'Usar una lista de tareas como entrada';

  @override
  String get inputDataTypeTasksListName => 'Lista de tareas';

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
  String get journalHideLinkHint => 'Ocultar enlace';

  @override
  String get journalHideMapHint => 'Ocultar mapa';

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
  String get journalLinkFromHint => 'Vincular desde';

  @override
  String get journalLinkToHint => 'Vincular a';

  @override
  String get journalPrivateTooltip => 'solo privado';

  @override
  String get journalSearchHint => 'Buscar en el diario...';

  @override
  String get journalShareAudioHint => 'Compartir audio';

  @override
  String get journalShareHint => 'Compartir';

  @override
  String get journalSharePhotoHint => 'Compartir foto';

  @override
  String get journalShowLinkHint => 'Mostrar enlace';

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
      '¿Estás seguro de que quieres desvincular esta entrada?';

  @override
  String get linkedFromLabel => 'VINCULADO DESDE';

  @override
  String get linkedTasksMenuTooltip => 'Opciones de tareas vinculadas';

  @override
  String get linkedTasksTitle => 'Tareas vinculadas';

  @override
  String get linkedToLabel => 'VINCULADO A';

  @override
  String get linkExistingTask => 'Vincular tarea existente...';

  @override
  String get loggingFailedToLoad =>
      'Error al cargar registros. Por favor, inténtalo de nuevo.';

  @override
  String get loggingFailedToLoadMore =>
      'Error al cargar más resultados. Por favor, inténtalo de nuevo.';

  @override
  String get loggingSearchFailed =>
      'Error en la búsqueda. Por favor, inténtalo de nuevo.';

  @override
  String get logsSearchHint => 'Buscar todos los logs...';

  @override
  String get maintenanceDeleteDatabaseConfirm => 'SÍ, ELIMINAR BASE DE DATOS';

  @override
  String maintenanceDeleteDatabaseQuestion(String databaseName) {
    return '¿Estás seguro de que quieres eliminar la base de datos $databaseName?';
  }

  @override
  String get maintenanceDeleteEditorDb =>
      'Eliminar la base de datos de borradores del editor';

  @override
  String get maintenanceDeleteEditorDbDescription =>
      'Eliminar base de datos de borradores del editor';

  @override
  String get maintenanceDeleteLoggingDb =>
      'Eliminar la base de datos de registro';

  @override
  String get maintenanceDeleteLoggingDbDescription =>
      'Eliminar base de datos de registros';

  @override
  String get maintenanceDeleteSyncDb =>
      'Eliminar la base de datos de sincronización';

  @override
  String get maintenanceDeleteSyncDbDescription =>
      'Eliminar base de datos de sincronización';

  @override
  String get maintenancePopulateSequenceLog =>
      'Llenar registro de secuencia de sincronización';

  @override
  String maintenancePopulateSequenceLogComplete(int count) {
    return '$count entradas indexadas';
  }

  @override
  String get maintenancePopulateSequenceLogConfirm => 'SÍ, LLENAR';

  @override
  String get maintenancePopulateSequenceLogDescription =>
      'Indexar entradas existentes para soporte de relleno';

  @override
  String get maintenancePopulateSequenceLogMessage =>
      'Esto escaneará todas las entradas del diario y las añadirá al registro de secuencia de sincronización. Esto habilita las respuestas de relleno para entradas creadas antes de que se añadiera esta función.';

  @override
  String get maintenancePurgeDeleted => 'Purgar elementos eliminados';

  @override
  String get maintenancePurgeDeletedConfirm => 'Sí, purgar todo';

  @override
  String get maintenancePurgeDeletedDescription =>
      'Purgar permanentemente todos los elementos eliminados';

  @override
  String get maintenancePurgeDeletedMessage =>
      '¿Estás seguro de que quieres purgar todos los elementos eliminados? Esta acción no se puede deshacer.';

  @override
  String get maintenanceRecreateFts5 => 'Recrear el índice de texto completo';

  @override
  String get maintenanceRecreateFts5Confirm => 'SÍ, RECREAR ÍNDICE';

  @override
  String get maintenanceRecreateFts5Description =>
      'Recrear índice de búsqueda de texto completo';

  @override
  String get maintenanceRecreateFts5Message =>
      '¿Estás seguro de que quieres recrear el índice de texto completo? Esto puede tardar un tiempo.';

  @override
  String get maintenanceReSync => 'Volver a sincronizar mensajes';

  @override
  String get maintenanceReSyncDescription =>
      'Resincronizar mensajes desde el servidor';

  @override
  String get maintenanceSyncDefinitions =>
      'Sincronizar etiquetas, medibles, paneles, hábitos, categorías, ajustes AI';

  @override
  String get maintenanceSyncDefinitionsDescription =>
      'Sincronizar etiquetas, medibles, paneles, hábitos, categorías y ajustes AI';

  @override
  String get manageLinks => 'Gestionar vínculos...';

  @override
  String get matrixStatsError => 'Error al cargar estadísticas de Matrix';

  @override
  String get measurableDeleteConfirm => 'SÍ, ELIMINAR ESTE MEDIBLE';

  @override
  String get measurableDeleteQuestion =>
      '¿Quieres eliminar este tipo de datos medibles?';

  @override
  String get measurableNotFound => 'Medible no encontrado';

  @override
  String get modalityAudioDescription =>
      'Capacidades de procesamiento de audio';

  @override
  String get modalityAudioName => 'Audio';

  @override
  String get modalityImageDescription =>
      'Capacidades de procesamiento de imágenes';

  @override
  String get modalityImageName => 'Imagen';

  @override
  String get modalityTextDescription =>
      'Contenido y procesamiento basado en texto';

  @override
  String get modalityTextName => 'Texto';

  @override
  String get modelAddPageTitle => 'Añadir modelo';

  @override
  String get modelEditLoadError =>
      'Error al cargar la configuración del modelo';

  @override
  String get modelEditPageTitle => 'Editar modelo';

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
    return '$count modelo$_temp0 seleccionado$_temp1';
  }

  @override
  String get modelsSettingsPageTitle => 'Modelos AI';

  @override
  String get multiSelectAddButton => 'Añadir';

  @override
  String multiSelectAddButtonWithCount(int count) {
    return 'Añadir ($count)';
  }

  @override
  String get multiSelectNoItemsFound => 'No se encontraron elementos';

  @override
  String get navTabTitleCalendar => 'DailyOS';

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
  String nestedAiResponsesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count respuesta$_temp0 AI';
  }

  @override
  String get noDefaultLanguage => 'Sin idioma predeterminado';

  @override
  String get noPromptsAvailable => 'No hay prompts disponibles';

  @override
  String get noPromptsForType => 'No hay prompts disponibles para este tipo';

  @override
  String get noTasksFound => 'No se encontraron tareas';

  @override
  String get noTasksToLink => 'No hay tareas disponibles para vincular';

  @override
  String get outboxMonitorAttachmentLabel => 'Adjunto';

  @override
  String get outboxMonitorDelete => 'eliminar';

  @override
  String get outboxMonitorDeleteConfirmLabel => 'Eliminar';

  @override
  String get outboxMonitorDeleteConfirmMessage =>
      '¿Estás seguro de que quieres eliminar este elemento de sincronización? Esta acción no se puede deshacer.';

  @override
  String get outboxMonitorDeleteFailed =>
      'Error al eliminar. Por favor, inténtalo de nuevo.';

  @override
  String get outboxMonitorDeleteSuccess => 'Elemento eliminado';

  @override
  String get outboxMonitorEmptyDescription =>
      'No hay elementos de sincronización en esta vista.';

  @override
  String get outboxMonitorEmptyTitle => 'La bandeja de salida está vacía';

  @override
  String get outboxMonitorLabelAll => 'todos';

  @override
  String get outboxMonitorLabelError => 'error';

  @override
  String get outboxMonitorLabelPending => 'pendiente';

  @override
  String get outboxMonitorLabelSent => 'enviado';

  @override
  String get outboxMonitorLabelSuccess => 'éxito';

  @override
  String get outboxMonitorNoAttachment => 'sin archivo adjunto';

  @override
  String get outboxMonitorPayloadSizeLabel => 'Tamaño';

  @override
  String get outboxMonitorRetries => 'reintentos';

  @override
  String get outboxMonitorRetriesLabel => 'Reintentos';

  @override
  String get outboxMonitorRetry => 'reintentar';

  @override
  String get outboxMonitorRetryConfirmLabel => 'Reintentar ahora';

  @override
  String get outboxMonitorRetryConfirmMessage =>
      '¿Reintentar este elemento de sincronización ahora?';

  @override
  String get outboxMonitorRetryFailed =>
      'Error al reintentar. Por favor, inténtalo de nuevo.';

  @override
  String get outboxMonitorRetryQueued => 'Reintento programado';

  @override
  String get outboxMonitorSubjectLabel => 'Asunto';

  @override
  String get outboxMonitorSwitchLabel => 'habilitado';

  @override
  String get outboxMonitorVolumeChartTitle =>
      'Volumen de sincronización diario';

  @override
  String get privateLabel => 'Privado';

  @override
  String get promptAddOrRemoveModelsButton => 'Añadir o eliminar modelos';

  @override
  String get promptAddPageTitle => 'Añadir prompt';

  @override
  String get promptAiResponseTypeDescription =>
      'Formato de la respuesta esperada';

  @override
  String get promptAiResponseTypeLabel => 'Tipo de respuesta AI';

  @override
  String get promptBehaviorDescription =>
      'Configurar cómo el prompt procesa y responde';

  @override
  String get promptBehaviorTitle => 'Comportamiento del prompt';

  @override
  String get promptCancelButton => 'Cancelar';

  @override
  String get promptContentDescription =>
      'Definir los prompts del sistema y del usuario';

  @override
  String get promptContentTitle => 'Contenido del prompt';

  @override
  String get promptDefaultModelBadge => 'Predeterminado';

  @override
  String get promptDescriptionHint => 'Describir este prompt';

  @override
  String get promptDescriptionLabel => 'Descripción';

  @override
  String get promptDetailsDescription => 'Información básica sobre este prompt';

  @override
  String get promptDetailsTitle => 'Detalles del prompt';

  @override
  String get promptDisplayNameHint => 'Introducir un nombre descriptivo';

  @override
  String get promptDisplayNameLabel => 'Nombre para mostrar';

  @override
  String get promptEditLoadError => 'Error al cargar el prompt';

  @override
  String get promptEditPageTitle => 'Editar prompt';

  @override
  String get promptErrorLoadingModel => 'Error al cargar el modelo';

  @override
  String get promptGenerationCardTitle => 'Prompt de codificación AI';

  @override
  String get promptGenerationCopiedSnackbar => 'Prompt copiado al portapapeles';

  @override
  String get promptGenerationCopyButton => 'Copiar prompt';

  @override
  String get promptGenerationCopyTooltip => 'Copiar prompt al portapapeles';

  @override
  String get promptGenerationExpandTooltip => 'Mostrar prompt completo';

  @override
  String get promptGenerationFullPromptLabel => 'Prompt completo:';

  @override
  String get promptGoBackButton => 'Volver';

  @override
  String get promptLoadingModel => 'Cargando modelo...';

  @override
  String get promptModelSelectionDescription =>
      'Elegir modelos compatibles para este prompt';

  @override
  String get promptModelSelectionTitle => 'Selección de modelo';

  @override
  String get promptNoModelsSelectedError =>
      'No se seleccionaron modelos. Selecciona al menos un modelo.';

  @override
  String get promptReasoningModeDescription =>
      'Activar para prompts que requieren reflexión profunda';

  @override
  String get promptReasoningModeLabel => 'Modo de razonamiento';

  @override
  String get promptRequiredInputDataDescription =>
      'Tipo de datos que espera este prompt';

  @override
  String get promptRequiredInputDataLabel => 'Datos de entrada requeridos';

  @override
  String get promptSaveButton => 'Guardar prompt';

  @override
  String get promptSelectInputTypeHint => 'Seleccionar tipo de entrada';

  @override
  String get promptSelectionModalTitle => 'Seleccionar prompt preconfigurado';

  @override
  String get promptSelectModelsButton => 'Seleccionar modelos';

  @override
  String get promptSelectResponseTypeHint => 'Seleccionar tipo de respuesta';

  @override
  String get promptSetDefaultButton => 'Establecer como predeterminado';

  @override
  String get promptSettingsPageTitle => 'Prompts AI';

  @override
  String get promptSystemPromptHint => 'Introducir el prompt del sistema...';

  @override
  String get promptSystemPromptLabel => 'Prompt del sistema';

  @override
  String get promptTryAgainMessage =>
      'Por favor, inténtalo de nuevo o contacta con soporte';

  @override
  String get promptUsePreconfiguredButton => 'Usar prompt preconfigurado';

  @override
  String get promptUserPromptHint => 'Introducir el prompt del usuario...';

  @override
  String get promptUserPromptLabel => 'Prompt del usuario';

  @override
  String get provisionedSyncBundleImported =>
      'Código de aprovisionamiento importado';

  @override
  String get provisionedSyncConfigureButton => 'Configurar';

  @override
  String get provisionedSyncCopiedToClipboard => 'Copiado al portapapeles';

  @override
  String get provisionedSyncDisconnect => 'Desconectar';

  @override
  String get provisionedSyncDone => 'Sincronización configurada exitosamente';

  @override
  String get provisionedSyncError => 'Error en la configuración';

  @override
  String get provisionedSyncErrorConfigurationFailed =>
      'Ocurrió un error durante la configuración. Inténtalo de nuevo.';

  @override
  String get provisionedSyncErrorLoginFailed =>
      'Error de inicio de sesión. Verifica tus credenciales e inténtalo de nuevo.';

  @override
  String get provisionedSyncImportButton => 'Importar';

  @override
  String get provisionedSyncImportHint =>
      'Pega el código de aprovisionamiento aquí';

  @override
  String get provisionedSyncImportTitle => 'Configurar sincronización';

  @override
  String get provisionedSyncInvalidBundle =>
      'Código de aprovisionamiento no válido';

  @override
  String get provisionedSyncJoiningRoom =>
      'Uniéndose a la sala de sincronización...';

  @override
  String get provisionedSyncLoggingIn => 'Iniciando sesión...';

  @override
  String get provisionedSyncPasteClipboard => 'Pegar desde el portapapeles';

  @override
  String get provisionedSyncReady =>
      'Escanea este código QR en tu dispositivo móvil';

  @override
  String get provisionedSyncRetry => 'Reintentar';

  @override
  String get provisionedSyncRotatingPassword => 'Asegurando la cuenta...';

  @override
  String get provisionedSyncScanButton => 'Escanear código QR';

  @override
  String get provisionedSyncShowQr => 'Mostrar QR de aprovisionamiento';

  @override
  String get provisionedSyncSubtitle =>
      'Configurar sincronización desde un paquete de aprovisionamiento';

  @override
  String get provisionedSyncSummaryHomeserver => 'Servidor';

  @override
  String get provisionedSyncSummaryRoom => 'Sala';

  @override
  String get provisionedSyncSummaryUser => 'Usuario';

  @override
  String get provisionedSyncTitle => 'Sincronización provisionada';

  @override
  String get provisionedSyncVerifyDevicesTitle =>
      'Verificación de dispositivos';

  @override
  String get referenceImageContinue => 'Continuar';

  @override
  String referenceImageContinueWithCount(int count) {
    return 'Continuar ($count)';
  }

  @override
  String get referenceImageLoadError =>
      'Error al cargar las imágenes. Por favor, inténtalo de nuevo.';

  @override
  String get referenceImageSelectionSubtitle =>
      'Elige hasta 3 imágenes para guiar el estilo visual de la IA';

  @override
  String get referenceImageSelectionTitle =>
      'Seleccionar imágenes de referencia';

  @override
  String get referenceImageSkip => 'Omitir';

  @override
  String get saveButton => 'Guardar';

  @override
  String get saveButtonLabel => 'Guardar';

  @override
  String get saveLabel => 'Guardar';

  @override
  String get saveSuccessful => 'Guardado correctamente';

  @override
  String get searchHint => 'Buscar...';

  @override
  String get searchTasksHint => 'Buscar tareas...';

  @override
  String get selectAllowedPrompts =>
      'Seleccionar qué prompts están permitidos para esta categoría';

  @override
  String get selectButton => 'Seleccionar';

  @override
  String get selectColor => 'Seleccionar color';

  @override
  String get selectLanguage => 'Seleccionar idioma';

  @override
  String get sessionRatingCardLabel => 'Calificación de sesión';

  @override
  String get sessionRatingChallengeJustRight => 'Justo';

  @override
  String get sessionRatingChallengeTooEasy => 'Demasiado fácil';

  @override
  String get sessionRatingChallengeTooHard => 'Demasiado difícil';

  @override
  String get sessionRatingDifficultyLabel => 'Este trabajo se sintió...';

  @override
  String get sessionRatingEditButton => 'Editar calificación';

  @override
  String get sessionRatingEnergyQuestion => '¿Qué tan energizado te sentiste?';

  @override
  String get sessionRatingFocusQuestion => '¿Qué tan concentrado estuviste?';

  @override
  String get sessionRatingNoteHint => 'Nota rápida (opcional)';

  @override
  String get sessionRatingProductivityQuestion =>
      '¿Qué tan productiva fue esta sesión?';

  @override
  String get sessionRatingRateAction => 'Calificar sesión';

  @override
  String get sessionRatingSaveButton => 'Guardar';

  @override
  String get sessionRatingSaveError =>
      'No se pudo guardar la calificación. Inténtalo de nuevo.';

  @override
  String get sessionRatingSkipButton => 'Omitir';

  @override
  String get sessionRatingTitle => 'Calificar esta sesión';

  @override
  String get sessionRatingViewAction => 'Ver calificación';

  @override
  String get settingsAboutAppInformation => 'Información de la aplicación';

  @override
  String get settingsAboutAppTagline => 'Tu diario personal';

  @override
  String get settingsAboutBuildType => 'Tipo de compilación';

  @override
  String get settingsAboutBuiltWithFlutter =>
      'Desarrollado con Flutter y amor por el diario personal.';

  @override
  String get settingsAboutCredits => 'Créditos';

  @override
  String get settingsAboutJournalEntries => 'Entradas del diario';

  @override
  String get settingsAboutPlatform => 'Plataforma';

  @override
  String get settingsAboutThankYou => '¡Gracias por usar Lotti!';

  @override
  String get settingsAboutTitle => 'Acerca de Lotti';

  @override
  String get settingsAboutVersion => 'Versión';

  @override
  String get settingsAboutYourData => 'Tus datos';

  @override
  String get settingsAdvancedAboutSubtitle =>
      'Aprende más sobre la aplicación Lotti';

  @override
  String get settingsAdvancedConflictsSubtitle =>
      'Resolver conflictos de sincronización para asegurar consistencia de datos';

  @override
  String get settingsAdvancedHealthImportSubtitle =>
      'Importar datos relacionados con la salud desde fuentes externas';

  @override
  String get settingsAdvancedLogsSubtitle =>
      'Acceder y revisar registros de aplicación para depuración';

  @override
  String get settingsAdvancedMaintenanceSubtitle =>
      'Realizar tareas de mantenimiento para optimizar el rendimiento de la aplicación';

  @override
  String get settingsAdvancedMatrixSyncSubtitle =>
      'Configurar y gestionar ajustes de sincronización de Matrix';

  @override
  String get settingsAdvancedOutboxSubtitle =>
      'Ver y gestionar elementos esperando ser sincronizados';

  @override
  String get settingsAdvancedTitle => 'Configuración avanzada';

  @override
  String get settingsAiApiKeys => 'Proveedores de inferencia AI';

  @override
  String get settingsAiModels => 'Modelos AI';

  @override
  String get settingsCategoriesAddTooltip => 'Añadir categoría';

  @override
  String get settingsCategoriesDetailsLabel => 'Detalles de categoría';

  @override
  String get settingsCategoriesDuplicateError => 'La categoría ya existe';

  @override
  String get settingsCategoriesEmptyState => 'No se encontraron categorías';

  @override
  String get settingsCategoriesEmptyStateHint =>
      'Crea una categoría para organizar tus entradas';

  @override
  String get settingsCategoriesErrorLoading => 'Error al cargar categorías';

  @override
  String get settingsCategoriesHasAiSettings => 'Ajustes AI';

  @override
  String get settingsCategoriesHasAutomaticPrompts => 'AI automática';

  @override
  String get settingsCategoriesHasDefaultLanguage => 'Idioma predeterminado';

  @override
  String get settingsCategoriesNameLabel => 'Nombre de la categoría:';

  @override
  String get settingsCategoriesTitle => 'Categorías';

  @override
  String get settingsConflictsResolutionTitle =>
      'Resolución de Conflictos de Sincronización';

  @override
  String get settingsConflictsTitle => 'Conflictos de Sincronización';

  @override
  String get settingsDashboardDetailsLabel => 'Detalles del panel';

  @override
  String get settingsDashboardSaveLabel => 'Guardar';

  @override
  String get settingsDashboardsTitle => 'Paneles';

  @override
  String get settingsFlagsTitle => 'Configuración de indicadores';

  @override
  String get settingsHabitsDeleteTooltip => 'Eliminar hábito';

  @override
  String get settingsHabitsDescriptionLabel => 'Descripción (opcional):';

  @override
  String get settingsHabitsDetailsLabel => 'Detalles del hábito';

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
  String get settingsLabelsActionsTooltip => 'Acciones de etiqueta';

  @override
  String get settingsLabelsCategoriesAdd => 'Añadir categoría';

  @override
  String get settingsLabelsCategoriesHeading => 'Categorías aplicables';

  @override
  String get settingsLabelsCategoriesNone => 'Se aplica a todas las categorías';

  @override
  String get settingsLabelsCategoriesRemoveTooltip => 'Eliminar';

  @override
  String get settingsLabelsColorHeading => 'Seleccionar un color';

  @override
  String get settingsLabelsColorSubheading => 'Preajustes rápidos';

  @override
  String get settingsLabelsCreateSuccess => 'Etiqueta creada correctamente';

  @override
  String get settingsLabelsCreateTitle => 'Crear etiqueta';

  @override
  String get settingsLabelsDeleteCancel => 'Cancelar';

  @override
  String get settingsLabelsDeleteConfirmAction => 'Eliminar';

  @override
  String settingsLabelsDeleteConfirmMessage(Object labelName) {
    return '¿Estás seguro de que quieres eliminar \"$labelName\"? Las tareas con esta etiqueta perderán la asignación.';
  }

  @override
  String get settingsLabelsDeleteConfirmTitle => 'Eliminar etiqueta';

  @override
  String settingsLabelsDeleteSuccess(Object labelName) {
    return 'Etiqueta \"$labelName\" eliminada';
  }

  @override
  String get settingsLabelsDescriptionHint =>
      'Explicar cuándo aplicar esta etiqueta';

  @override
  String get settingsLabelsDescriptionLabel => 'Descripción (opcional)';

  @override
  String get settingsLabelsEditTitle => 'Editar etiqueta';

  @override
  String get settingsLabelsEmptyState => 'Aún no hay etiquetas';

  @override
  String get settingsLabelsEmptyStateHint =>
      'Toca el botón + para crear tu primera etiqueta.';

  @override
  String get settingsLabelsErrorLoading => 'Error al cargar etiquetas';

  @override
  String get settingsLabelsNameHint => 'Error, Bloqueante, Sincronización…';

  @override
  String get settingsLabelsNameLabel => 'Nombre de etiqueta';

  @override
  String get settingsLabelsNameRequired =>
      'El nombre de la etiqueta no puede estar vacío.';

  @override
  String get settingsLabelsPrivateDescription =>
      'Las etiquetas privadas solo aparecen cuando \"Mostrar entradas privadas\" está activado.';

  @override
  String get settingsLabelsPrivateTitle => 'Etiqueta privada';

  @override
  String get settingsLabelsSearchHint => 'Buscar etiquetas…';

  @override
  String get settingsLabelsSubtitle =>
      'Organizar tareas con etiquetas de colores';

  @override
  String get settingsLabelsTitle => 'Etiquetas';

  @override
  String get settingsLabelsUpdateSuccess => 'Etiqueta actualizada';

  @override
  String settingsLabelsUsageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tareas',
      one: '1 tarea',
    );
    return 'Usada en $_temp0';
  }

  @override
  String get settingsLogsTitle => 'Registros';

  @override
  String get settingsMaintenanceTitle => 'Mantenimiento';

  @override
  String get settingsMatrixAccept => 'Aceptar';

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
  String get settingsMatrixCount => 'Cantidad';

  @override
  String get settingsMatrixDeleteLabel => 'Eliminar';

  @override
  String get settingsMatrixDiagnosticCopied =>
      'Información de diagnóstico copiada al portapapeles';

  @override
  String get settingsMatrixDiagnosticCopyButton => 'Copiar al portapapeles';

  @override
  String get settingsMatrixDiagnosticDialogTitle =>
      'Información de diagnóstico de sincronización';

  @override
  String get settingsMatrixDiagnosticShowButton =>
      'Mostrar información de diagnóstico';

  @override
  String get settingsMatrixDone => 'Listo';

  @override
  String get settingsMatrixEnterValidUrl => 'Introduce una URL válida';

  @override
  String get settingsMatrixHomeserverConfigTitle =>
      'Configuración del servidor doméstico Matrix';

  @override
  String get settingsMatrixHomeServerLabel => 'Servidor doméstico';

  @override
  String get settingsMatrixLastUpdated => 'Última actualización:';

  @override
  String get settingsMatrixListUnverifiedLabel => 'Dispositivos no verificados';

  @override
  String get settingsMatrixLoginButtonLabel => 'Iniciar sesión';

  @override
  String get settingsMatrixLoginFailed => 'Error al iniciar sesión';

  @override
  String get settingsMatrixLogoutButtonLabel => 'Cerrar sesión';

  @override
  String get settingsMatrixMaintenanceSubtitle =>
      'Ejecutar tareas de mantenimiento y herramientas de recuperación de Matrix';

  @override
  String get settingsMatrixMaintenanceTitle => 'Mantenimiento';

  @override
  String get settingsMatrixMessageType => 'Tipo de mensaje';

  @override
  String get settingsMatrixMetric => 'Métrica';

  @override
  String get settingsMatrixMetrics => 'Métricas de sincronización';

  @override
  String get settingsMatrixMetricsNoData =>
      'Métricas de sincronización: sin datos';

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
  String get settingsMatrixRefresh => 'Actualizar';

  @override
  String get settingsMatrixRoomConfigTitle =>
      'Configuración de la sala de sincronización Matrix';

  @override
  String settingsMatrixRoomInviteMessage(String roomId, String senderId) {
    return 'Invitación a la sala $roomId de $senderId. ¿Aceptar?';
  }

  @override
  String get settingsMatrixRoomInviteTitle => 'Invitación a sala';

  @override
  String get settingsMatrixSentMessagesLabel => 'Mensajes enviados:';

  @override
  String get settingsMatrixStartVerificationLabel => 'Iniciar verificación';

  @override
  String get settingsMatrixStatsTitle => 'Estadísticas de Matrix';

  @override
  String get settingsMatrixSubtitle =>
      'Configurar sincronización cifrada de extremo a extremo';

  @override
  String get settingsMatrixTitle => 'Ajustes de sincronización de Matrix';

  @override
  String get settingsMatrixUnverifiedDevicesPage =>
      'Dispositivos no verificados';

  @override
  String get settingsMatrixUserLabel => 'Usuario';

  @override
  String get settingsMatrixUserNameTooShort =>
      'Nombre de usuario demasiado corto';

  @override
  String get settingsMatrixValue => 'Valor';

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
  String get settingsMeasurableDetailsLabel => 'Detalles del medible';

  @override
  String get settingsMeasurableFavoriteLabel => 'Favorito: ';

  @override
  String get settingsMeasurableNameLabel => 'Nombre de la medición:';

  @override
  String get settingsMeasurablePrivateLabel => 'Privado: ';

  @override
  String get settingsMeasurableSaveLabel => 'Guardar';

  @override
  String get settingsMeasurablesTitle => 'Tipos de medición';

  @override
  String get settingsMeasurableUnitLabel =>
      'Abreviatura de la unidad (opcional):';

  @override
  String get settingsResetGeminiConfirm => 'Restablecer';

  @override
  String get settingsResetGeminiConfirmQuestion =>
      'Esto mostrará el diálogo de configuración de Gemini de nuevo. ¿Continuar?';

  @override
  String get settingsResetGeminiSubtitle =>
      'Mostrar el diálogo de configuración de Gemini AI de nuevo';

  @override
  String get settingsResetGeminiTitle =>
      'Restablecer diálogo de configuración de Gemini';

  @override
  String get settingsResetHintsConfirm => 'Confirmar';

  @override
  String get settingsResetHintsConfirmQuestion =>
      '¿Restablecer las sugerencias dentro de la aplicación?';

  @override
  String settingsResetHintsResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sugerencias restablecidas',
      one: 'Una sugerencia restablecida',
      zero: 'Cero sugerencias restablecidas',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetHintsSubtitle =>
      'Borrar consejos únicos y sugerencias de introducción';

  @override
  String get settingsResetHintsTitle =>
      'Restablecer sugerencias de la aplicación';

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
  String get settingsSyncStatsSubtitle =>
      'Inspeccionar métricas del canal de sincronización';

  @override
  String get settingsSyncSubtitle =>
      'Configurar sincronización y ver estadísticas';

  @override
  String get settingsTagsDeleteTooltip => 'Eliminar etiqueta';

  @override
  String get settingsTagsDetailsLabel => 'Detalles de la etiqueta';

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
  String get settingThemingDark => 'Tema oscuro';

  @override
  String get settingThemingLight => 'Tema claro';

  @override
  String get showCompleted => 'Mostrar completadas';

  @override
  String get speechDictionaryHelper =>
      'Términos separados por punto y coma (máx. 50 caracteres) para mejor reconocimiento de voz';

  @override
  String get speechDictionaryHint => 'macOS; Kirkjubæjarklaustur; Claude Code';

  @override
  String get speechDictionaryLabel => 'Diccionario de voz';

  @override
  String get speechDictionarySectionDescription =>
      'Añade términos que el reconocimiento de voz suele escribir mal (nombres, lugares, términos técnicos)';

  @override
  String get speechDictionarySectionTitle => 'Reconocimiento de voz';

  @override
  String speechDictionaryWarning(Object count) {
    return 'Un diccionario grande ($count términos) puede aumentar los costos de API';
  }

  @override
  String get speechModalAddTranscription => 'Añadir transcripción';

  @override
  String get speechModalSelectLanguage => 'Seleccionar idioma';

  @override
  String get speechModalTitle => 'Reconocimiento de voz';

  @override
  String get speechModalTranscriptionProgress => 'Progreso de la transcripción';

  @override
  String get syncCreateNewRoom => 'Crear nueva sala';

  @override
  String get syncCreateNewRoomInstead => 'Crear nueva sala en su lugar';

  @override
  String get syncDeleteConfigConfirm => 'SÍ, ESTOY SEGURO';

  @override
  String get syncDeleteConfigQuestion =>
      '¿Quieres eliminar la configuración de sincronización?';

  @override
  String get syncDiscoveringRooms => 'Buscando salas de sincronización...';

  @override
  String get syncDiscoverRoomsButton => 'Descubrir salas existentes';

  @override
  String get syncDiscoveryError => 'Error al descubrir salas';

  @override
  String get syncEntitiesConfirm => 'INICIAR SINCRONIZACIÓN';

  @override
  String get syncEntitiesMessage => 'Elige los datos que quieres sincronizar.';

  @override
  String get syncEntitiesSuccessDescription => 'Todo está al día.';

  @override
  String get syncEntitiesSuccessTitle => 'Sincronización completada';

  @override
  String get syncInviteErrorForbidden =>
      'Permiso denegado. Es posible que no tenga acceso para invitar a este usuario.';

  @override
  String get syncInviteErrorNetwork =>
      'Error de red. Por favor, comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get syncInviteErrorRateLimited =>
      'Demasiadas solicitudes. Por favor, espera un momento e inténtalo de nuevo.';

  @override
  String get syncInviteErrorUnknown =>
      'No se pudo enviar la invitación. Por favor, inténtalo más tarde.';

  @override
  String get syncInviteErrorUserNotFound =>
      'Usuario no encontrado. Por favor, verifica que el código escaneado sea correcto.';

  @override
  String syncListCountSummary(String label, int itemCount) {
    String _temp0 = intl.Intl.pluralLogic(
      itemCount,
      locale: localeName,
      other: '$itemCount elementos',
      one: '1 elemento',
      zero: '0 elementos',
    );
    return '$label · $_temp0';
  }

  @override
  String get syncListPayloadKindLabel => 'Carga útil';

  @override
  String get syncListUnknownPayload => 'Carga útil desconocida';

  @override
  String get syncNoRoomsFound =>
      'No se encontraron salas de sincronización.\nPuede crear una nueva sala para comenzar a sincronizar.';

  @override
  String get syncNotLoggedInToast => 'La sincronización no está conectada';

  @override
  String get syncPayloadAgentEntity => 'Entidad de agente';

  @override
  String get syncPayloadAgentLink => 'Enlace de agente';

  @override
  String get syncPayloadAiConfig => 'Configuración AI';

  @override
  String get syncPayloadAiConfigDelete => 'Eliminación de configuración AI';

  @override
  String get syncPayloadBackfillRequest => 'Solicitud de relleno';

  @override
  String get syncPayloadBackfillResponse => 'Respuesta de relleno';

  @override
  String get syncPayloadEntityDefinition => 'Definición de entidad';

  @override
  String get syncPayloadEntryLink => 'Enlace de entrada';

  @override
  String get syncPayloadJournalEntity => 'Entrada de diario';

  @override
  String get syncPayloadTagEntity => 'Entidad de etiqueta';

  @override
  String get syncPayloadThemingSelection => 'Selección de tema';

  @override
  String get syncRetry => 'Reintentar';

  @override
  String get syncRoomCreatedUnknown => 'Desconocido';

  @override
  String get syncRoomDiscoveryTitle =>
      'Buscar sala de sincronización existente';

  @override
  String get syncRoomHasContent => 'Tiene contenido';

  @override
  String get syncRoomUnnamed => 'Sala sin nombre';

  @override
  String get syncRoomVerified => 'Verificado';

  @override
  String get syncSelectRoom => 'Seleccionar sala de sincronización';

  @override
  String get syncSelectRoomDescription =>
      'Encontramos salas de sincronización existentes. Selecciona una para unirte o crea una nueva sala.';

  @override
  String get syncSkip => 'Omitir';

  @override
  String get syncStepAgentEntities => 'Entidades de agente';

  @override
  String get syncStepAgentLinks => 'Enlaces de agente';

  @override
  String get syncStepAiSettings => 'Configuración de IA';

  @override
  String get syncStepCategories => 'Categorías';

  @override
  String get syncStepComplete => 'Completado';

  @override
  String get syncStepDashboards => 'Paneles';

  @override
  String get syncStepHabits => 'Hábitos';

  @override
  String get syncStepLabels => 'Etiquetas de color';

  @override
  String get syncStepMeasurables => 'Medibles';

  @override
  String get syncStepTags => 'Etiquetas de hashtag';

  @override
  String get taskAgentChipLabel => 'Agente';

  @override
  String taskAgentCountdownTooltip(String countdown) {
    return 'Próxima ejecución automática en $countdown';
  }

  @override
  String get taskAgentCreateChipLabel => 'Crear agente';

  @override
  String taskAgentCreateError(String error) {
    return 'Error al crear el agente: $error';
  }

  @override
  String get taskAgentRunNowTooltip => 'Ejecutar ahora';

  @override
  String get taskCategoryAllLabel => 'todos';

  @override
  String get taskCategoryLabel => 'Categoría:';

  @override
  String get taskCategoryUnassignedLabel => 'sin asignar';

  @override
  String get taskDueDateLabel => 'Fecha de vencimiento';

  @override
  String taskDueDateWithDate(String date) {
    return 'Vence: $date';
  }

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
  String get taskDueToday => 'Vence hoy';

  @override
  String get taskDueTomorrow => 'Vence mañana';

  @override
  String get taskDueYesterday => 'Venció ayer';

  @override
  String get taskEstimateLabel => 'Estimación:';

  @override
  String get taskLabelUnassignedLabel => 'sin asignar';

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
  String get taskLanguageIgbo => 'Igbo';

  @override
  String get taskLanguageIndonesian => 'Indonesio';

  @override
  String get taskLanguageItalian => 'Italiano';

  @override
  String get taskLanguageJapanese => 'Japonés';

  @override
  String get taskLanguageKorean => 'Coreano';

  @override
  String get taskLanguageLabel => 'Idioma:';

  @override
  String get taskLanguageLatvian => 'Letón';

  @override
  String get taskLanguageLithuanian => 'Lituano';

  @override
  String get taskLanguageNigerianPidgin => 'Pidgin nigeriano';

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
  String get taskLanguageSearchPlaceholder => 'Buscar idiomas...';

  @override
  String get taskLanguageSelectedLabel => 'Idioma actual';

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
  String get taskLanguageTurkish => 'Turco';

  @override
  String get taskLanguageTwi => 'Twi';

  @override
  String get taskLanguageUkrainian => 'Ucraniano';

  @override
  String get taskLanguageVietnamese => 'Vietnamita';

  @override
  String get taskLanguageYoruba => 'Yoruba';

  @override
  String get taskNameHint => 'Introduzca un nombre para la tarea';

  @override
  String get taskNoDueDateLabel => 'Sin fecha de vencimiento';

  @override
  String get taskNoEstimateLabel => 'Sin estimación';

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
  String get tasksAddLabelButton => 'Añadir etiqueta';

  @override
  String get tasksFilterTitle => 'Filtro de tareas';

  @override
  String get tasksLabelFilterAll => 'Todas';

  @override
  String get tasksLabelFilterTitle => 'Etiquetas';

  @override
  String get tasksLabelFilterUnlabeled => 'Sin etiqueta';

  @override
  String get tasksLabelsDialogClose => 'Cerrar';

  @override
  String get tasksLabelsHeaderEditTooltip => 'Editar etiquetas';

  @override
  String get tasksLabelsHeaderTitle => 'Etiquetas';

  @override
  String get tasksLabelsNoLabels => 'Sin etiquetas';

  @override
  String get tasksLabelsSheetApply => 'Aplicar';

  @override
  String get tasksLabelsSheetSearchHint => 'Buscar etiquetas…';

  @override
  String get tasksLabelsSheetTitle => 'Seleccionar etiquetas';

  @override
  String get tasksLabelsUpdateFailed => 'Error al actualizar etiquetas';

  @override
  String get tasksPriorityFilterAll => 'Todas';

  @override
  String get tasksPriorityFilterTitle => 'Prioridad';

  @override
  String get tasksPriorityP0 => 'Urgente';

  @override
  String get tasksPriorityP0Description => 'Urgente (Lo antes posible)';

  @override
  String get tasksPriorityP1 => 'Alta';

  @override
  String get tasksPriorityP1Description => 'Alta (Pronto)';

  @override
  String get tasksPriorityP2 => 'Media';

  @override
  String get tasksPriorityP2Description => 'Media (Predeterminada)';

  @override
  String get tasksPriorityP3 => 'Baja';

  @override
  String get tasksPriorityP3Description => 'Baja (Cuando sea posible)';

  @override
  String get tasksPriorityPickerTitle => 'Seleccionar prioridad';

  @override
  String get tasksPriorityTitle => 'Prioridad:';

  @override
  String get tasksQuickFilterClear => 'Borrar';

  @override
  String get tasksQuickFilterLabelsActiveTitle =>
      'Filtros de etiquetas activos';

  @override
  String get tasksQuickFilterUnassignedLabel => 'Sin asignar';

  @override
  String get tasksShowCoverArt => 'Mostrar imagen de portada en tarjetas';

  @override
  String get tasksShowCreationDate => 'Mostrar fecha de creación en tarjetas';

  @override
  String get tasksShowDueDate => 'Mostrar fecha de vencimiento en tarjetas';

  @override
  String get tasksSortByCreationDate => 'Creación';

  @override
  String get tasksSortByDate => 'Fecha';

  @override
  String get tasksSortByDueDate => 'Vencimiento';

  @override
  String get tasksSortByLabel => 'Ordenar por';

  @override
  String get tasksSortByPriority => 'Prioridad';

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
  String get taskSummaries => 'Resúmenes de tareas';

  @override
  String get timeByCategoryChartTitle => 'Tiempo por categoría';

  @override
  String get timeByCategoryChartTotalLabel => 'Total';

  @override
  String get unlinkButton => 'Desvincular';

  @override
  String get unlinkTaskConfirm =>
      '¿Estás seguro de que quieres desvincular esta tarea?';

  @override
  String get unlinkTaskTitle => 'Desvincular tarea';

  @override
  String get viewMenuTitle => 'Vista';

  @override
  String get whatsNewDoneButton => 'Listo';

  @override
  String get whatsNewSkipButton => 'Omitir';
}

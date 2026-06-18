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
  String get addActionAddScreenshot => 'Captura de pantalla';

  @override
  String get addActionAddTask => 'Tarea';

  @override
  String get addActionAddText => 'Entrada de texto';

  @override
  String get addActionAddTimer => 'Temporizador';

  @override
  String get addActionAddTimeRecording => 'Registro de tiempo';

  @override
  String get addActionImportImage => 'Importar imagen';

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
  String agentABComparisonChoose(String option) {
    return 'Elegir $option';
  }

  @override
  String agentABComparisonOption(String option) {
    return 'Opción $option';
  }

  @override
  String agentABComparisonPrefer(String option) {
    return 'Prefiero la Opción $option';
  }

  @override
  String get agentBinaryChoiceNo => 'No';

  @override
  String get agentBinaryChoiceYes => 'Sí';

  @override
  String get agentCategoryRatingsScaleMax => 'Arreglar primero';

  @override
  String get agentCategoryRatingsScaleMin => 'Déjalo';

  @override
  String agentCategoryRatingsStarLabel(int starIndex, int totalStars) {
    return '$starIndex de $totalStars estrellas';
  }

  @override
  String get agentCategoryRatingsSubmit => 'Usar estas prioridades';

  @override
  String get agentCategoryRatingsSubtitle =>
      '¿Qué tan importante es que arregle cada uno de estos puntos? 1 significa déjalo así, 5 significa arréglalo primero.';

  @override
  String get agentCategoryRatingsTitle => 'Ayúdame a priorizar';

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
  String agentConversationThreadSummary(
    int messageCount,
    int toolCallCount,
    String shortId,
  ) {
    return '$messageCount mensajes, $toolCallCount llamadas a herramientas · $shortId';
  }

  @override
  String agentConversationTokenCount(String tokenCount) {
    return '$tokenCount tokens';
  }

  @override
  String get agentDefaultProfileLabel => 'Perfil de inferencia predeterminado';

  @override
  String agentDetailErrorLoading(String error) {
    return 'Error al cargar el agente: $error';
  }

  @override
  String get agentDetailNotFound => 'Agente no encontrado.';

  @override
  String get agentDetailUnexpectedType => 'Tipo de entidad inesperado.';

  @override
  String get agentEvolutionApprovalRate => 'Tasa de aprobación';

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
  String get agentEvolutionHistoryTitle => 'Historial de evolución';

  @override
  String get agentEvolutionMetricActive => 'Activos';

  @override
  String get agentEvolutionMetricAvgDuration => 'Duración media';

  @override
  String get agentEvolutionMetricFailures => 'Fallos';

  @override
  String get agentEvolutionMetricSuccess => 'Éxito';

  @override
  String get agentEvolutionMetricWakes => 'Activaciones';

  @override
  String get agentEvolutionNoSessions => 'Aún no hay sesiones de evolución';

  @override
  String get agentEvolutionNoteRecorded => 'Nota registrada';

  @override
  String get agentEvolutionProposalApprovalFailed =>
      'Error en la aprobación — inténtalo de nuevo';

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
  String get agentEvolutionSessionAbandoned => 'Sesión finalizada sin cambios';

  @override
  String agentEvolutionSessionCompleted(int version) {
    return 'Sesión completada — versión $version creada';
  }

  @override
  String get agentEvolutionSessionCount => 'Sesiones';

  @override
  String get agentEvolutionSessionError =>
      'No se pudo iniciar la sesión de evolución';

  @override
  String agentEvolutionSessionProgress(int sessionNumber, int totalSessions) {
    return 'Sesión $sessionNumber de $totalSessions';
  }

  @override
  String get agentEvolutionSessionStarting =>
      'Iniciando sesión de evolución...';

  @override
  String agentEvolutionSessionTitle(int sessionNumber) {
    return 'Evolución #$sessionNumber';
  }

  @override
  String agentEvolutionSoulCurrentField(String field) {
    return 'Actual — $field';
  }

  @override
  String agentEvolutionSoulProposedField(String field) {
    return 'Propuesto — $field';
  }

  @override
  String get agentEvolutionStatusAbandoned => 'Abandonado';

  @override
  String get agentEvolutionStatusActive => 'Activo';

  @override
  String get agentEvolutionStatusCompleted => 'Completado';

  @override
  String get agentEvolutionTimelineFeedbackLabel => 'Retroalimentación';

  @override
  String get agentEvolutionVersionProposed => 'Versión propuesta';

  @override
  String get agentFeedbackCategoryAccuracy => 'Precisión';

  @override
  String get agentFeedbackCategoryBreakdownTitle => 'Desglose por categoría';

  @override
  String get agentFeedbackCategoryCommunication => 'Comunicación';

  @override
  String get agentFeedbackCategoryGeneral => 'General';

  @override
  String get agentFeedbackCategoryPrioritization => 'Priorización';

  @override
  String get agentFeedbackCategoryTimeliness => 'Puntualidad';

  @override
  String get agentFeedbackCategoryTooling => 'Herramientas';

  @override
  String get agentFeedbackClassificationTitle =>
      'Clasificación de retroalimentación';

  @override
  String get agentFeedbackExcellenceTitle => 'Notas de excelencia';

  @override
  String get agentFeedbackGrievancesTitle => 'Quejas';

  @override
  String get agentFeedbackHighPriorityTitle => 'Feedback de alta prioridad';

  @override
  String agentFeedbackItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos',
      one: '1 elemento',
    );
    return '$_temp0';
  }

  @override
  String get agentFeedbackSourceDecision => 'Decisión';

  @override
  String get agentFeedbackSourceMetric => 'Métrica';

  @override
  String get agentFeedbackSourceObservation => 'Observación';

  @override
  String get agentFeedbackSourceRating => 'Calificación';

  @override
  String get agentInstancesEmptyFiltered =>
      'Ninguna instancia coincide con tus filtros.';

  @override
  String get agentInstancesFilterClearAll => 'Limpiar todo';

  @override
  String get agentInstancesFilterClearSection => 'Limpiar';

  @override
  String get agentInstancesFilterSectionSoul => 'Alma';

  @override
  String get agentInstancesFilterSectionStatus => 'Estado';

  @override
  String get agentInstancesFilterSectionType => 'Tipo';

  @override
  String agentInstancesGroupActiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count activos',
      one: '1 activo',
    );
    return '$_temp0';
  }

  @override
  String get agentInstancesGroupBySoul => 'Alma';

  @override
  String get agentInstancesGroupByStatus => 'Estado';

  @override
  String get agentInstancesGroupByType => 'Tipo';

  @override
  String get agentInstancesKindEvolution => 'Evolución';

  @override
  String get agentInstancesKindTaskAgent => 'Agente de tareas';

  @override
  String get agentInstancesPageTitle => 'Instancias de agentes';

  @override
  String agentInstancesResultCountAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count instancias',
      one: '1 instancia',
    );
    return '$_temp0';
  }

  @override
  String agentInstancesResultCountFiltered(int filtered, int total) {
    return '$filtered de $total';
  }

  @override
  String get agentInstancesSearchClear => 'Limpiar búsqueda';

  @override
  String get agentInstancesSearchPlaceholder => 'Buscar instancias…';

  @override
  String get agentInstancesSortName => 'Nombre';

  @override
  String get agentInstancesSortOldest => 'Más antiguas';

  @override
  String get agentInstancesSortRecent => 'Recientes';

  @override
  String get agentInstancesTitle => 'Instancias';

  @override
  String get agentInstancesToolbarFilters => 'Filtros';

  @override
  String get agentInstancesToolbarGroupBy => 'Agrupar por';

  @override
  String get agentInstancesUnassignedSoul => 'Sin asignar';

  @override
  String get agentLifecycleActive => 'Activo';

  @override
  String get agentLifecycleCreated => 'Creado';

  @override
  String get agentLifecycleDestroyed => 'Destruido';

  @override
  String get agentLifecycleDormant => 'Inactivo';

  @override
  String get agentMessageKindAction => 'Acción';

  @override
  String get agentMessageKindMilestone => 'Hito';

  @override
  String get agentMessageKindObservation => 'Observación';

  @override
  String get agentMessageKindRetraction => 'Retractación';

  @override
  String get agentMessageKindSummary => 'Resumen';

  @override
  String get agentMessageKindSystem => 'Sistema';

  @override
  String get agentMessageKindSystemPrompt => 'Prompt del sistema';

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
  String agentPendingWakesActivityHourDetail(
    String hour,
    int count,
    String reasons,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count despertares',
      one: '1 despertar',
    );
    return '$hour: $_temp0 ($reasons)';
  }

  @override
  String get agentPendingWakesActivityTitle => 'Actividad de despertares (24h)';

  @override
  String agentPendingWakesActivityTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count despertares en total',
      one: '1 despertar en total',
    );
    return '$_temp0';
  }

  @override
  String get agentPendingWakesDeleteTooltip => 'Eliminar despertar';

  @override
  String get agentPendingWakesEmptyFiltered =>
      'Ningún despertar coincide con tus filtros.';

  @override
  String get agentPendingWakesFilterSectionType => 'Tipo';

  @override
  String get agentPendingWakesGroupByType => 'Tipo';

  @override
  String get agentPendingWakesPendingLabel => 'Pendiente';

  @override
  String agentPendingWakesRunningHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'En ejecución ($count)',
      one: 'En ejecución',
    );
    return '$_temp0';
  }

  @override
  String get agentPendingWakesScheduledLabel => 'Programado';

  @override
  String get agentPendingWakesSearchPlaceholder => 'Buscar despertares…';

  @override
  String get agentPendingWakesSortDueLatest => 'Vence más tarde';

  @override
  String get agentPendingWakesSortDueSoonest => 'Vence antes';

  @override
  String get agentPendingWakesTitle => 'Ciclos de despertar';

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
  String get agentRitualReviewAction => 'Iniciar conversación';

  @override
  String get agentRitualReviewNegativeSignals => 'Negativo';

  @override
  String get agentRitualReviewNeutralSignals => 'Neutro';

  @override
  String get agentRitualReviewNoFeedback =>
      'Sin señales de retroalimentación en esta ventana';

  @override
  String get agentRitualReviewNoNegativeSignals =>
      'No hay señales de retroalimentación negativas en esta pestaña';

  @override
  String get agentRitualReviewNoNeutralSignals =>
      'No hay señales de retroalimentación neutrales en esta pestaña';

  @override
  String get agentRitualReviewNoPositiveSignals =>
      'No hay señales de retroalimentación positivas en esta pestaña';

  @override
  String get agentRitualReviewPositiveSignals => 'Positivo';

  @override
  String get agentRitualReviewProposalSection => 'Propuesta actual';

  @override
  String get agentRitualReviewSessionHistory => 'Historial de sesiones';

  @override
  String get agentRitualReviewTitle => '1-on-1';

  @override
  String get agentRitualSummaryApprovedChangesHeading => 'Cambios aprobados';

  @override
  String get agentRitualSummaryConversationHeading => 'Conversación';

  @override
  String get agentRitualSummaryRecapHeading => 'Resumen de la sesión';

  @override
  String get agentRitualSummaryRoleAssistant => 'Agente';

  @override
  String get agentRitualSummaryRoleUser => 'Tú';

  @override
  String get agentRitualSummaryStartHint =>
      'Inicia un 1-on-1 para revisar qué molestó a la persona usuaria, qué funcionó bien y qué debería cambiar después.';

  @override
  String get agentRitualSummarySubtitle =>
      'Tus 1-on-1 anteriores, la actividad real de wakes y los cambios acordados.';

  @override
  String get agentRitualSummaryTokensSinceLast =>
      'Tokens desde el último 1-on-1';

  @override
  String get agentRitualSummaryWakeHistory30Days =>
      'Actividad de wakes (últimos 30 días)';

  @override
  String get agentRitualSummaryWakesSinceLast => 'Wakes desde el último 1-on-1';

  @override
  String get agentRunningIndicator => 'Ejecutando';

  @override
  String get agentSessionProgressTitle => 'Progreso de sesión';

  @override
  String get agentSettingsSubtitle => 'Plantillas, instancias y monitoreo';

  @override
  String get agentSettingsTitle => 'Agentes';

  @override
  String get agentSoulAntiSycophancyLabel => 'Política anti-adulación';

  @override
  String get agentSoulAssignedTemplatesTitle => 'Plantillas asignadas';

  @override
  String get agentSoulAssignmentLabel => 'Alma';

  @override
  String get agentSoulCoachingStyleLabel => 'Estilo de coaching';

  @override
  String get agentSoulCreatedSuccess => 'Alma creada';

  @override
  String get agentSoulCreateTitle => 'Crear alma';

  @override
  String get agentSoulDeleteConfirmBody =>
      'Esto eliminará el alma y todas sus versiones.';

  @override
  String get agentSoulDeleteConfirmTitle => 'Eliminar alma';

  @override
  String get agentSoulDetailTitle => 'Detalle del alma';

  @override
  String get agentSoulDisplayNameLabel => 'Nombre';

  @override
  String get agentSoulEvolutionHistoryTitle =>
      'Historial de evolución del alma';

  @override
  String get agentSoulEvolutionNoSessions =>
      'Aún no hay sesiones de evolución del alma';

  @override
  String get agentSoulFieldAntiSycophancy => 'Anti-adulación';

  @override
  String get agentSoulFieldCoachingStyle => 'Estilo de coaching';

  @override
  String get agentSoulFieldToneBounds => 'Límites de tono';

  @override
  String get agentSoulFieldVoice => 'Voz';

  @override
  String get agentSoulInfoTab => 'Info';

  @override
  String get agentSoulNoneAssigned => 'Sin alma asignada';

  @override
  String get agentSoulNotFound => 'Alma no encontrada';

  @override
  String get agentSoulProposalSubtitle => 'Cambios de personalidad propuestos';

  @override
  String get agentSoulProposalTitle => 'Propuesta de personalidad del alma';

  @override
  String get agentSoulReviewHeroSubtitle =>
      'Refina la personalidad en todas las plantillas que comparten esta alma. El agente de evolución ve los comentarios de cada plantilla que usa esta personalidad.';

  @override
  String get agentSoulReviewStartAction => 'Iniciar revisión de personalidad';

  @override
  String get agentSoulReviewStartHint =>
      'Inicia una sesión enfocada en la personalidad para revisar comentarios y evolucionar la voz, el tono, el estilo de coaching y la franqueza.';

  @override
  String agentSoulReviewTemplateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plantillas comparten esta alma',
      one: '1 plantilla comparte esta alma',
    );
    return '$_temp0';
  }

  @override
  String get agentSoulReviewTitle => 'Alma 1-on-1';

  @override
  String get agentSoulRollbackAction => 'Volver a esta versión';

  @override
  String agentSoulRollbackConfirm(int version) {
    return '¿Volver a la versión $version? Todas las plantillas que usan esta alma se verán afectadas.';
  }

  @override
  String get agentSoulSelectTitle => 'Seleccionar alma';

  @override
  String get agentSoulsEmptyFiltered => 'Ningún alma coincide con tus filtros.';

  @override
  String get agentSoulSettingsTab => 'Configuración';

  @override
  String get agentSoulsSearchPlaceholder => 'Buscar almas…';

  @override
  String get agentSoulsTitle => 'Almas';

  @override
  String get agentSoulToneBoundsLabel => 'Límites de tono';

  @override
  String get agentSoulVersionHistoryTitle => 'Historial de versiones';

  @override
  String agentSoulVersionLabel(int version) {
    return 'Versión $version';
  }

  @override
  String get agentSoulVersionSaved => 'Nueva versión de alma guardada';

  @override
  String get agentSoulVoiceDirectiveLabel => 'Directiva de voz';

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
  String get agentStatsAllDayLegend => 'Todo el día';

  @override
  String get agentStatsAverageLabel => 'Promedio';

  @override
  String agentStatsByTimeLegend(String time) {
    return 'Diario hasta las $time';
  }

  @override
  String get agentStatsCacheRateLabel => 'Tasa de caché';

  @override
  String get agentStatsDailyUsageHeading => 'Uso diario';

  @override
  String get agentStatsInputLabel => 'Entrada';

  @override
  String get agentStatsNoUsage =>
      'No se registró uso de tokens en los últimos 7 días.';

  @override
  String get agentStatsOutputLabel => 'Salida';

  @override
  String agentStatsSourceActiveFor(String duration) {
    return 'Activo durante $duration';
  }

  @override
  String get agentStatsSourceActivityHeading => 'Actividad de agentes';

  @override
  String agentStatsSourceWakes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count despertares',
      one: '1 despertar',
    );
    return '$_temp0';
  }

  @override
  String get agentStatsTabTitle => 'Estadísticas';

  @override
  String get agentStatsThoughtsLabel => 'Pensamientos';

  @override
  String get agentStatsTodayLabel => 'Hoy';

  @override
  String get agentStatsTokensPerWakeLabel => 'Tokens / despertar';

  @override
  String get agentStatsTokensUnit => 'tokens';

  @override
  String agentStatsUsageAboveAverage(String time) {
    return 'Hoy estás usando más tokens de lo habitual a las $time.';
  }

  @override
  String agentStatsUsageBelowAverage(String time) {
    return 'Hoy estás usando menos tokens de lo habitual a las $time.';
  }

  @override
  String get agentStatsWakesLabel => 'Despertares';

  @override
  String get agentSuggestionTimeEntryUpdateCurrent => 'Actual';

  @override
  String get agentSuggestionTimeEntryUpdateNoChange => '(sin cambios)';

  @override
  String get agentSuggestionTimeEntryUpdateProposed => 'Propuesto';

  @override
  String get agentSuggestionTimeEntryUpdateUnavailable =>
      'Entrada original no disponible';

  @override
  String get agentTabActivity => 'Actividad';

  @override
  String get agentTabConversations => 'Conversaciones';

  @override
  String get agentTabObservations => 'Observaciones';

  @override
  String get agentTabReports => 'Informes';

  @override
  String get agentTabStats => 'Estadísticas';

  @override
  String get agentTemplateAggregateTokenUsageHeading => 'Uso total de tokens';

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
  String get agentTemplateDisplayNameLabel => 'Nombre';

  @override
  String get agentTemplateEditTitle => 'Editar plantilla';

  @override
  String get agentTemplateEvolveApprove => 'Aprobar y guardar';

  @override
  String get agentTemplateEvolveReject => 'Rechazar';

  @override
  String get agentTemplateGeneralDirectiveHint =>
      'Define la personalidad, herramientas, objetivos y estilo de interacción del agente...';

  @override
  String get agentTemplateGeneralDirectiveLabel => 'Directiva general';

  @override
  String get agentTemplateInstanceBreakdownHeading => 'Desglose por instancia';

  @override
  String get agentTemplateKindDayAgent => 'Agente diario';

  @override
  String get agentTemplateKindImprover => 'Mejorador de plantilla';

  @override
  String get agentTemplateKindProjectAgent => 'Agente de proyecto';

  @override
  String get agentTemplateKindTaskAgent => 'Agente de tareas';

  @override
  String get agentTemplateMetricsTotalWakes => 'Activaciones totales';

  @override
  String get agentTemplateNoneAssigned => 'Sin plantilla asignada';

  @override
  String get agentTemplateNoTemplates =>
      'No hay plantillas disponibles. Crea una en Configuración primero.';

  @override
  String get agentTemplateNotFound => 'Plantilla no encontrada';

  @override
  String get agentTemplateNoVersions => 'Sin versiones';

  @override
  String get agentTemplateReportDirectiveHint =>
      'Define la estructura del informe, secciones requeridas y reglas de formato...';

  @override
  String get agentTemplateReportDirectiveLabel => 'Directiva de informe';

  @override
  String get agentTemplateReportsEmpty => 'Aún no hay informes.';

  @override
  String get agentTemplateReportsTab => 'Informes';

  @override
  String get agentTemplateRollbackAction => 'Revertir a esta versión';

  @override
  String agentTemplateRollbackConfirm(int version) {
    return '¿Revertir a la versión $version? El agente usará esta versión en su próximo despertar.';
  }

  @override
  String get agentTemplateSaveNewVersion => 'Guardar';

  @override
  String get agentTemplateSelectTitle => 'Seleccionar plantilla';

  @override
  String get agentTemplatesEmptyFiltered =>
      'Ninguna plantilla coincide con tus filtros.';

  @override
  String get agentTemplateSettingsTab => 'Ajustes';

  @override
  String get agentTemplatesFilterSectionKind => 'Tipo';

  @override
  String get agentTemplatesGroupByKind => 'Tipo';

  @override
  String get agentTemplatesGroupNone => 'Todas';

  @override
  String get agentTemplatesSearchPlaceholder => 'Buscar plantillas…';

  @override
  String get agentTemplateStatsTab => 'Estadísticas';

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
  String get agentTokenUsageCachedTokens => 'En caché';

  @override
  String get agentTokenUsageEmpty =>
      'Aún no se ha registrado el uso de tokens.';

  @override
  String agentTokenUsageErrorLoading(String error) {
    return 'Error al cargar el uso de tokens: $error';
  }

  @override
  String get agentTokenUsageHeading => 'Uso de tokens';

  @override
  String get agentTokenUsageInputTokens => 'Entrada';

  @override
  String get agentTokenUsageModel => 'Modelo';

  @override
  String get agentTokenUsageOutputTokens => 'Salida';

  @override
  String get agentTokenUsageThoughtsTokens => 'Pensamientos';

  @override
  String get agentTokenUsageTotalTokens => 'Total';

  @override
  String get agentTokenUsageWakeCount => 'Despertares';

  @override
  String get aggregationDailyAvg => 'Promedio diario';

  @override
  String get aggregationDailyMax => 'Máximo diario';

  @override
  String get aggregationDailySum => 'Suma diaria';

  @override
  String get aggregationHourlySum => 'Suma por hora';

  @override
  String get aggregationNone => 'Ninguna';

  @override
  String get aiAssistantTitle => 'Generar…';

  @override
  String get aiBatchToggleTooltip => 'Cambiar a grabación estándar';

  @override
  String get aiCapabilityChipImageGeneration => 'Generación de imágenes';

  @override
  String get aiCapabilityChipImageRecognition => 'Reconocimiento de imágenes';

  @override
  String get aiCapabilityChipThinking => 'Razonamiento';

  @override
  String get aiCapabilityChipTranscription => 'Transcripción';

  @override
  String get aiCardEmptyProposals =>
      'Sin propuestas abiertas · el agente mostrará nuevos cambios aquí';

  @override
  String aiCardHistoryToggle(int count) {
    return 'Historial · $count';
  }

  @override
  String get aiCardMenuActionDelete => 'Eliminar';

  @override
  String get aiCardMenuActionEdit => 'Editar';

  @override
  String get aiCardOpenAgentInternals => 'Abrir interior del agente';

  @override
  String get aiCardProposalConfirmed => 'Confirmada';

  @override
  String get aiCardProposalDismissed => 'Descartada';

  @override
  String get aiCardProposalKindAdd => 'Añadir';

  @override
  String get aiCardProposalKindDue => 'Vence';

  @override
  String get aiCardProposalKindEstimate => 'Estimación';

  @override
  String get aiCardProposalKindLabel => 'Etiqueta';

  @override
  String get aiCardProposalKindPriority => 'Prioridad';

  @override
  String get aiCardProposalKindRemove => 'Quitar';

  @override
  String get aiCardProposalKindStatus => 'Estado';

  @override
  String get aiCardProposalKindUpdate => 'Actualizar';

  @override
  String get aiCardReadMore => 'Leer más';

  @override
  String get aiCardShowLess => 'Mostrar menos';

  @override
  String get aiCardTitle => 'Resumen de IA';

  @override
  String get aiChatMessageCopied => 'Copiado al portapapeles';

  @override
  String get aiConfigFailedToLoadModelsGeneric =>
      'Error al cargar modelos. Por favor, inténtalo de nuevo.';

  @override
  String get aiConfigNoModelsAvailable =>
      'Aún no se han configurado modelos de AI. Por favor, añada uno en los ajustes.';

  @override
  String get aiConfigNoSuitableModelsAvailable =>
      'Ningún modelo cumple los requisitos para este prompt. Por favor, configura modelos con las capacidades requeridas.';

  @override
  String get aiConfigSelectProviderModalTitle =>
      'Seleccionar proveedor de inferencia';

  @override
  String get aiConfigSelectProviderTypeModalTitle =>
      'Seleccionar tipo de proveedor';

  @override
  String get aiConfigUseReasoningFieldLabel => 'Usar razonamiento';

  @override
  String aiDeleteToastCascadeDescription(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'También se eliminaron $count modelos: $names',
      one: 'También se eliminó 1 modelo: $names',
    );
    return '$_temp0';
  }

  @override
  String aiDeleteToastErrorTitle(String name) {
    return 'No se pudo eliminar $name';
  }

  @override
  String get aiDeleteToastModelTitle => 'Modelo eliminado';

  @override
  String get aiDeleteToastProfileTitle => 'Perfil eliminado';

  @override
  String get aiDeleteToastPromptTitle => 'Prompt eliminado';

  @override
  String get aiDeleteToastProviderTitle => 'Proveedor eliminado';

  @override
  String get aiDeleteToastSkillTitle => 'Habilidad eliminada';

  @override
  String get aiDeleteToastUndoAction => 'Deshacer';

  @override
  String get aiFormCancel => 'Cancelar';

  @override
  String get aiFormFixErrors =>
      'Por favor, corrige los errores antes de guardar';

  @override
  String get aiFormNoChanges => 'No hay cambios sin guardar';

  @override
  String get aiImageAnalysisPickerDefaultBadge => 'Predeterminado';

  @override
  String get aiImageAnalysisPickerTitle =>
      'Elige un modelo de análisis de imágenes';

  @override
  String get aiInferenceErrorAuthenticationTitle => 'Autenticación fallida';

  @override
  String get aiInferenceErrorConnectionFailedTitle => 'Conexión fallida';

  @override
  String get aiInferenceErrorInvalidRequestTitle => 'Solicitud no válida';

  @override
  String get aiInferenceErrorRateLimitTitle => 'Límite de solicitudes excedido';

  @override
  String get aiInferenceErrorRetryButton => 'Reintentar';

  @override
  String get aiInferenceErrorServerTitle => 'Error del servidor';

  @override
  String get aiInferenceErrorSuggestionsTitle => 'Sugerencias:';

  @override
  String get aiInferenceErrorTimeoutTitle => 'Tiempo de espera agotado';

  @override
  String get aiInferenceErrorUnknownTitle => 'Error';

  @override
  String get aiInternalsTitle => 'Interior del agente';

  @override
  String get aiModelDownloadCloseButton => 'Cerrar';

  @override
  String aiModelDownloadDialogDescription(String modelName) {
    return 'Lotti descargará $modelName en la caché de MLX Audio y lo usará para procesar voz localmente.';
  }

  @override
  String aiModelDownloadDialogTitle(String modelName) {
    return 'Instalar $modelName';
  }

  @override
  String get aiModelDownloadInstallTooltip => 'Instalar modelo';

  @override
  String get aiModelDownloadOpenProgressTooltip =>
      'Mostrar progreso de descarga';

  @override
  String get aiModelDownloadStatusChecking => 'Comprobando estado del modelo';

  @override
  String aiModelDownloadStatusDownloading(int percent) {
    return 'Descargando $percent %';
  }

  @override
  String get aiModelDownloadStatusDownloadingIndeterminate => 'Descargando';

  @override
  String get aiModelDownloadStatusFailed => 'Descarga fallida';

  @override
  String get aiModelDownloadStatusInstalled => 'Instalado';

  @override
  String get aiModelDownloadStatusNotInstalled => 'No instalado';

  @override
  String get aiModelDownloadStatusUnsupported => 'Requiere Apple Silicon';

  @override
  String get aiModelInstallChoiceCancelButton => 'Cancelar';

  @override
  String get aiModelInstallChoiceDescription =>
      'Elige primero el modelo local de voz a texto que quieres descargar. Puedes instalar los demás más tarde desde la lista de modelos.';

  @override
  String get aiModelInstallChoiceInstallButton => 'Instalar modelo';

  @override
  String get aiModelInstallChoiceRecommended => 'Recomendado';

  @override
  String get aiModelInstallChoiceTitle => 'Elegir modelo de MLX Audio';

  @override
  String aiOllamaModelInstalledSuccessfully(String modelName) {
    return '¡Modelo \"$modelName\" instalado correctamente!';
  }

  @override
  String get aiPickProviderBadgeDesktopOnly => 'SOLO ESCRITORIO';

  @override
  String get aiPickProviderBadgeNew => 'NUEVO';

  @override
  String get aiPickProviderBadgeRecommended => 'RECOMENDADO';

  @override
  String get aiPickProviderContinueButton => 'Continuar';

  @override
  String get aiPickProviderDontShowAgainButton => 'No volver a mostrar';

  @override
  String get aiPickProviderFooterHint =>
      'Puedes añadir más proveedores luego en Ajustes → IA. Tu clave API se guarda localmente.';

  @override
  String get aiPickProviderModalTitle => 'Configura las funciones de IA';

  @override
  String get aiPickProviderSubtitle =>
      'Elige un proveedor para empezar. Configuraremos los modelos y un perfil inicial automáticamente.';

  @override
  String get aiProfileCardActiveBadge => 'Activo';

  @override
  String get aiProfileModelPickerSearchHint => 'Buscar modelos…';

  @override
  String get aiProfileSlotModelMissing => 'no encontrado';

  @override
  String get aiPromptGenerationPickerTitle =>
      'Elige un modelo para generar prompts';

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
  String get aiProviderCardDraftBadge => 'BORRADOR';

  @override
  String get aiProviderCardFixButton => 'Solucionar';

  @override
  String get aiProviderCardMenuTooltip => 'Más acciones';

  @override
  String aiProviderCardModelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modelos',
      one: '1 modelo',
    );
    return '$_temp0';
  }

  @override
  String aiProviderCardModelCountWithLastUsed(int count, String lastUsed) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modelos · usados por última vez $lastUsed',
      one: '1 modelo · usado por última vez $lastUsed',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderCardOllamaHint =>
      'Asegúrate de que Ollama esté en ejecución';

  @override
  String aiProviderCardStatusConnected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Conectado · $count modelos',
      one: 'Conectado · 1 modelo',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderCardStatusConnectedShort => 'Conectado';

  @override
  String get aiProviderCardStatusInvalidKey => 'Clave no válida';

  @override
  String get aiProviderCardStatusOffline =>
      'Desconectado · Asegúrate de que Ollama esté en ejecución';

  @override
  String get aiProviderCardStatusOfflineShort => 'Desconectado';

  @override
  String get aiProviderConnectBackToProviders => 'Volver a proveedores';

  @override
  String get aiProviderConnectBreadcrumbAdd => 'Añadir proveedor';

  @override
  String get aiProviderConnectFieldBaseUrlHint =>
      'Déjalo en blanco para usar el endpoint oficial';

  @override
  String get aiProviderConnectFieldBaseUrlLabelOptional =>
      'URL base (opcional)';

  @override
  String get aiProviderConnectFieldBaseUrlPlaceholder =>
      'https://api.example.com';

  @override
  String get aiProviderConnectFieldDisplayNameHint =>
      'Se mostrará en tu lista de proveedores';

  @override
  String get aiProviderConnectionCheckingLabel =>
      'Comprobando la clave, listando los modelos disponibles…';

  @override
  String aiProviderConnectionFailedBadResponseDetail(String type) {
    return 'Forma de respuesta inesperada: $type';
  }

  @override
  String aiProviderConnectionFailedHttpDetail(int status, String message) {
    return 'HTTP $status · $message';
  }

  @override
  String get aiProviderConnectionFailedInvalidBaseUrlDetail =>
      'La URL base debe incluir un esquema http(s) y un host (p. ej. https://api.example.com)';

  @override
  String aiProviderConnectionFailedNetworkDetail(String message) {
    return '$message';
  }

  @override
  String get aiProviderConnectionFailedTimeoutDetail =>
      'Se agotó el tiempo de espera';

  @override
  String aiProviderConnectionFailedTitle(String providerName) {
    return 'No se pudo conectar con $providerName. Revisa la clave o tu red.';
  }

  @override
  String get aiProviderConnectionRetestButton => 'Volver a probar';

  @override
  String get aiProviderConnectionRetryButton => 'Reintentar';

  @override
  String aiProviderConnectionVerifiedSubtitle(int count, int ms) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modelos disponibles en tu cuenta · respondió en $ms ms',
      one: '1 modelo disponible en tu cuenta · respondió en $ms ms',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderConnectionVerifiedTitle => 'Conexión verificada';

  @override
  String aiProviderConnectKeyHelperLink(String url) {
    return 'Consigue una clave en $url';
  }

  @override
  String get aiProviderConnectKeyHiddenLabel => 'Oculta';

  @override
  String get aiProviderConnectKeyPrivacyHint =>
      'Tu clave API nunca sale de tu dispositivo.';

  @override
  String aiProviderConnectPageTitle(String providerName) {
    return 'Conectar $providerName';
  }

  @override
  String get aiProviderConnectSaveAndContinue => 'Guardar y continuar';

  @override
  String get aiProviderConnectSaveAsDraft => 'Guardar como borrador';

  @override
  String get aiProviderConnectSavedAsDraftToast => 'Guardado como borrador';

  @override
  String get aiProviderConnectStepChoose => 'Elegir proveedor';

  @override
  String get aiProviderConnectStepConnect => 'Conectar';

  @override
  String get aiProviderConnectStepReview => 'Revisar';

  @override
  String get aiProviderDetailActiveProfileTitle => 'Perfil activo';

  @override
  String get aiProviderDetailAddModelButton => 'Añadir modelo';

  @override
  String get aiProviderDetailApiKeyLabel => 'Clave API';

  @override
  String get aiProviderDetailBackTooltip => 'Atrás';

  @override
  String get aiProviderDetailBaseUrlLabel => 'URL base';

  @override
  String get aiProviderDetailConnectionTitle => 'Conexión';

  @override
  String get aiProviderDetailDangerZoneTitle => 'Zona de peligro';

  @override
  String get aiProviderDetailDisplayNameLabel => 'Nombre visible';

  @override
  String get aiProviderDetailEditButton => 'Editar';

  @override
  String get aiProviderDetailEditTooltip => 'Editar proveedor';

  @override
  String get aiProviderDetailLoadError =>
      'No se pudo cargar este proveedor. Inténtalo de nuevo desde los ajustes de IA.';

  @override
  String get aiProviderDetailMissingMessage =>
      'Este proveedor ya no está disponible.';

  @override
  String aiProviderDetailModelsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Modelos · $count',
      one: 'Modelos · 1',
      zero: 'Modelos',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderDetailNoModelsMessage =>
      'Aún no hay modelos. Añade uno para empezar a usar este proveedor.';

  @override
  String get aiProviderDetailPageTitle => 'Detalles del proveedor';

  @override
  String get aiProviderDetailRemoveButton => 'Eliminar proveedor';

  @override
  String get aiProviderDetailRemoveDescription =>
      'Elimina el proveedor y todos los modelos que dependen de él. No se puede deshacer.';

  @override
  String get aiProviderDetailRemoveTitle => 'Eliminar este proveedor';

  @override
  String get aiProviderDetailValueUnset => 'Sin definir';

  @override
  String get aiProviderEmbeddedRuntimeHint =>
      'Se ejecuta integrado en el proceso de la app de Apple. No hace falta servidor local ni URL base.';

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
  String get aiProviderMlxAudioDescription =>
      'Modelos MLX Audio integrados para STT y TTS locales en Apple Silicon';

  @override
  String get aiProviderMlxAudioName => 'MLX Audio (local)';

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
  String get aiProviderSelectContinue => 'Continuar';

  @override
  String get aiProviderSelectDontShowAgain => 'No mostrar de nuevo';

  @override
  String get aiProviderSetupOptionGeminiDescription =>
      'Modelos multimodales con transcripción de audio. Requiere clave API.';

  @override
  String get aiProviderSetupOptionMistralDescription =>
      'IA europea con razonamiento (Magistral) y audio (Voxtral).';

  @override
  String get aiProviderSetupOptionOpenAiDescription =>
      'Modelos GPT para chat y razonamiento. Requiere clave API con créditos.';

  @override
  String get aiProviderTaglineAlibaba =>
      'Modelos Qwen · multimodal · contexto largo';

  @override
  String get aiProviderTaglineAnthropic => 'Familia Claude · contexto largo';

  @override
  String get aiProviderTaglineGemini => 'Multimodal · transcripción de audio';

  @override
  String get aiProviderTaglineMlxAudio =>
      'Integrado · Apple Silicon · audio local';

  @override
  String get aiProviderTaglineOllama =>
      'Se ejecuta en local · sin llamadas a la nube';

  @override
  String get aiProviderTaglineOpenAi => 'Familia GPT · visión + razonamiento';

  @override
  String get aiProviderUnknownName => 'Proveedor de IA';

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
  String get aiRunningActivityOpenProgress => 'Mostrar progreso de la AI';

  @override
  String get aiSettingsAddedLabel => 'Añadido';

  @override
  String get aiSettingsAddModelButton => 'Añadir modelo';

  @override
  String get aiSettingsAddModelTooltip => 'Añadir este modelo a tu proveedor';

  @override
  String get aiSettingsAddProfileButton => 'Añadir perfil';

  @override
  String get aiSettingsAddProviderButton => 'Añadir proveedor';

  @override
  String get aiSettingsClearAllFiltersTooltip => 'Borrar todos los filtros';

  @override
  String get aiSettingsClearFiltersButton => 'Limpiar';

  @override
  String get aiSettingsCounterModels => 'Modelos';

  @override
  String get aiSettingsCounterProfiles => 'Perfiles';

  @override
  String get aiSettingsCounterProviders => 'Proveedores';

  @override
  String get aiSettingsEmptyDescription =>
      'Añade uno para habilitar la transcripción, el reconocimiento de imágenes, la generación de imágenes y la búsqueda semántica.';

  @override
  String get aiSettingsEmptyTitle => 'Aún no hay proveedores';

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
  String get aiSettingsFtueBannerDescription =>
      'Tarda alrededor de un minuto. Lotti configurará modelos y un perfil inicial para ti.';

  @override
  String get aiSettingsFtueBannerStartButton => 'Iniciar configuración';

  @override
  String get aiSettingsFtueBannerTitle => 'Añade tu primer proveedor de IA';

  @override
  String get aiSettingsModalityAudio => 'Audio';

  @override
  String get aiSettingsModalityText => 'Texto';

  @override
  String get aiSettingsModalityVision => 'Visión';

  @override
  String get aiSettingsNoModelsConfigured => 'No hay modelos AI configurados';

  @override
  String get aiSettingsNoProvidersConfigured =>
      'No hay proveedores AI configurados';

  @override
  String get aiSettingsPageLead =>
      'Configura los proveedores de IA, los modelos que Lotti puede usar y los perfiles de inferencia que deciden qué modelo gestiona cada tarea.';

  @override
  String get aiSettingsPageTitle => 'Ajustes AI';

  @override
  String get aiSettingsReasoningLabel => 'Razonamiento';

  @override
  String get aiSettingsSearchHint => 'Buscar configuraciones AI...';

  @override
  String get aiSettingsSearchHintShort => 'Buscar';

  @override
  String get aiSettingsTabModels => 'Modelos';

  @override
  String get aiSettingsTabProfiles => 'Perfiles';

  @override
  String get aiSettingsTabProviders => 'Proveedores';

  @override
  String get aiSetupPreviewAcceptButton => 'Aceptar y finalizar';

  @override
  String get aiSetupPreviewAlreadyAddedSectionLabel => 'Ya añadidos';

  @override
  String aiSetupPreviewCategoryFooter(String categoryName) {
    return 'Configura la categoría de prueba $categoryName para probarla.';
  }

  @override
  String aiSetupPreviewConnectedHeader(String providerName) {
    return '$providerName conectado';
  }

  @override
  String get aiSetupPreviewCustomizeButton => 'Personalizar';

  @override
  String get aiSetupPreviewLead =>
      'Revisa lo que Lotti va a añadir. Desmarca lo que no quieras; siempre podrás configurarlo manualmente más tarde.';

  @override
  String get aiSetupPreviewLiveBadge => 'En vivo';

  @override
  String aiSetupPreviewModalTitle(String providerName) {
    return 'Configuración de $providerName';
  }

  @override
  String get aiSetupPreviewModelsSectionLabel => 'Modelos';

  @override
  String get aiSetupPreviewProfileSectionLabel => 'Perfil de inferencia';

  @override
  String get aiSetupPreviewProfileSetActiveBadge => 'Activar';

  @override
  String aiSetupResultBulletCategoryCreated(String categoryName) {
    return 'Categoría de prueba $categoryName configurada';
  }

  @override
  String aiSetupResultBulletCategoryReused(String categoryName) {
    return 'Reutilizando la categoría de prueba existente $categoryName';
  }

  @override
  String aiSetupResultBulletModels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modelos configurados',
      one: '1 modelo configurado',
    );
    return '$_temp0';
  }

  @override
  String aiSetupResultBulletProfile(String profileName) {
    return 'Perfil de inferencia $profileName creado';
  }

  @override
  String aiSetupResultErrorsHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count problemas',
      one: '1 problema',
    );
    return '$_temp0 en la configuración';
  }

  @override
  String aiSetupResultHeader(String providerName) {
    return '$providerName está conectado';
  }

  @override
  String aiSetupResultKnownModelsMissing(String providerName) {
    return 'No se pudieron encontrar las configuraciones de modelo requeridas para $providerName';
  }

  @override
  String get aiSetupResultLead =>
      'Lo hemos configurado todo por ti. Las funciones de IA están listas para usar en tu diario.';

  @override
  String aiSetupResultModalTitle(String providerName) {
    return '$providerName listo';
  }

  @override
  String get aiSetupResultStartUsingButton => 'Empezar a usar IA';

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
  String get aiSummaryPlayTooltip => 'Leer el resumen';

  @override
  String get aiSummaryPreparingTooltip => 'Preparando el audio';

  @override
  String get aiSummarySpeakTooltip => 'Leer resumen en voz alta localmente';

  @override
  String get aiSummaryStopTooltip => 'Detener';

  @override
  String get aiSummaryThinkingLabel => 'Pensando…';

  @override
  String get aiSummaryTtsUnavailable =>
      'La lectura en voz alta no está disponible';

  @override
  String get aiTaskSummaryTitle => 'Resumen de tareas de IA';

  @override
  String get aiTranscriptionPickerDefaultBadge => 'Predeterminado';

  @override
  String get aiTranscriptionPickerTitle => 'Elige un modelo de transcripción';

  @override
  String get apiKeyAddPageTitle => 'Añadir proveedor';

  @override
  String get apiKeyAuthenticationDescription => 'Asegura tu conexión a la API';

  @override
  String get apiKeyAuthenticationTitle => 'Autenticación';

  @override
  String get apiKeyAvailableModelsDescription =>
      'Añade rápidamente modelos preconfigurados para este proveedor';

  @override
  String get apiKeyAvailableModelsTitle => 'Modelos disponibles';

  @override
  String get apiKeyBaseUrlLabel => 'URL base';

  @override
  String get apiKeyDisplayNameHint => 'Introduce un nombre descriptivo';

  @override
  String get apiKeyDisplayNameLabel => 'Nombre para mostrar';

  @override
  String get apiKeyEditGoBackButton => 'Atrás';

  @override
  String get apiKeyEditLoadError =>
      'Error al cargar la configuración de la clave API';

  @override
  String get apiKeyEditLoadErrorRetry =>
      'Inténtalo de nuevo o contacta con soporte';

  @override
  String get apiKeyEditPageTitle => 'Editar proveedor';

  @override
  String get apiKeyHideTooltip => 'Ocultar clave API';

  @override
  String get apiKeyInputHint => 'Introduce tu clave API';

  @override
  String get apiKeyInputLabel => 'Clave API';

  @override
  String apiKeyKnownModelInputLabel(String modalities) {
    return 'Entrada: $modalities';
  }

  @override
  String apiKeyKnownModelOutputLabel(String modalities) {
    return 'Salida: $modalities';
  }

  @override
  String get apiKeyProviderConfigDescription =>
      'Configura los ajustes de tu proveedor de inferencia de IA';

  @override
  String get apiKeyProviderConfigTitle => 'Configuración del proveedor';

  @override
  String get apiKeyProviderTypeHint => 'Selecciona un tipo de proveedor';

  @override
  String get apiKeyProviderTypeLabel => 'Tipo de proveedor';

  @override
  String get apiKeyShowTooltip => 'Mostrar clave API';

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
  String backfillAdvancedRecoveryActions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count acciones',
      one: '1 acción',
    );
    return '$_temp0';
  }

  @override
  String get backfillAdvancedRecoveryTitle => 'Recuperación avanzada';

  @override
  String get backfillAskPeersConfirmAccept => 'Preguntar a pares';

  @override
  String backfillAskPeersConfirmContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Esto vuelve a poner las $count entradas irresolubles del registro de secuencia como faltantes para que el barrido normal de relleno pregunte de nuevo a los pares. Los pares que aún tienen los datos responderán; las entradas realmente irrecuperables se retirarán de nuevo tras la ventana de amnistía de 7 días.',
      one:
          'Esto vuelve a poner 1 entrada irresoluble del registro de secuencia como faltante para que el barrido normal de relleno pregunte de nuevo a los pares. Los pares que aún tienen los datos responderán; las entradas realmente irrecuperables se retirarán de nuevo tras la ventana de amnistía de 7 días.',
    );
    return '$_temp0';
  }

  @override
  String get backfillAskPeersConfirmTitle =>
      '¿Preguntar de nuevo a los pares por entradas irresolubles?';

  @override
  String get backfillAskPeersDescription =>
      'Vuelve cada entrada irresoluble del registro de secuencia a faltante y deja que el barrido normal de relleno pregunte a los pares.';

  @override
  String get backfillAskPeersProcessing => 'Reabriendo…';

  @override
  String get backfillAskPeersTitle => 'Preguntar a pares por irresolubles';

  @override
  String backfillAskPeersTrigger(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Preguntar a pares por $count entradas',
      one: 'Preguntar a pares por 1 entrada',
    );
    return '$_temp0';
  }

  @override
  String get backfillCatchUpDescription =>
      'Solicita ahora a los pares las entradas faltantes recientes.';

  @override
  String backfillDevicesMeta(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count IDs de dispositivo',
      one: '1 ID de dispositivo',
    );
    return '$_temp0';
  }

  @override
  String get backfillManualDescription =>
      'Solicitar todas las entradas faltantes sin importar su antigüedad. Úsalo para recuperar brechas de sincronización antiguas.';

  @override
  String get backfillManualProcessing => 'Procesando...';

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
  String get backfillReRequestTitle => 'Volver a solicitar pendientes';

  @override
  String get backfillReRequestTrigger =>
      'Volver a solicitar entradas pendientes';

  @override
  String get backfillResetUnresolvableDescription =>
      'Restablece las entradas marcadas como irresolubles como faltantes para que puedan volver a solicitarse. Úsalo después de la repoblación del registro de secuencia.';

  @override
  String get backfillResetUnresolvableProcessing => 'Restableciendo...';

  @override
  String get backfillResetUnresolvableTitle => 'Restablecer irresolubles';

  @override
  String get backfillResetUnresolvableTrigger =>
      'Restablecer entradas irresolubles';

  @override
  String get backfillRetireStuckConfirmAccept => 'Retirar ahora';

  @override
  String backfillRetireStuckConfirmContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Marca $count entradas del registro de secuencia actualmente abiertas (faltantes o solicitadas) como irresolubles. Úsalo para desbloquear la marca de agua cuando hay entradas atascadas desde hace un tiempo sin que haya pasado la ventana de amnistía de 7 días. Las entradas pueden resucitarse si sus datos llegan al disco con un reloj vectorial válido.',
      one:
          'Marca 1 entrada del registro de secuencia actualmente abierta (faltante o solicitada) como irresoluble. Úsalo para desbloquear la marca de agua cuando hay entradas atascadas desde hace un tiempo sin que haya pasado la ventana de amnistía de 7 días. Las entradas pueden resucitarse si sus datos llegan al disco con un reloj vectorial válido.',
    );
    return '$_temp0';
  }

  @override
  String get backfillRetireStuckConfirmTitle =>
      '¿Retirar ahora las entradas atascadas?';

  @override
  String get backfillRetireStuckDescription =>
      'Fuerza cada entrada del registro de secuencia faltante o solicitada actualmente abierta a irresoluble. Omite la amnistía de 7 días — úsalo solo para filas atascadas que bloquean la marca de agua.';

  @override
  String get backfillRetireStuckProcessing => 'Retirando…';

  @override
  String get backfillRetireStuckTitle => 'Retirar entradas atascadas';

  @override
  String backfillRetireStuckTrigger(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Retirar $count entradas atascadas',
      one: 'Retirar 1 entrada atascada',
    );
    return '$_temp0';
  }

  @override
  String get backfillSettingsSubtitle =>
      'Gestionar recuperación de brechas de sincronización';

  @override
  String get backfillSettingsTitle => 'Relleno de sincronización';

  @override
  String get backfillStatsBackfilled => 'Rellenado';

  @override
  String get backfillStatsBurned => 'Anulado';

  @override
  String get backfillStatsDeleted => 'Eliminado';

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
  String get backfillStatusInboundQueue => 'Cola entrante';

  @override
  String get backfillStatusMissing => 'Faltante';

  @override
  String get backfillStatusSkipped => 'Omitido';

  @override
  String get backfillToggleDescription =>
      'Solicita las entradas faltantes de las últimas 24 horas.';

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
  String get categoryActiveSwitchDescription =>
      'Seleccionable para nuevas entradas';

  @override
  String get categoryAiDefaultsDescription =>
      'Establecer el perfil de IA y la plantilla de agente predeterminados para nuevas tareas en esta categoría';

  @override
  String get categoryAiDefaultsTitle => 'Valores predeterminados de IA';

  @override
  String get categoryCreationError =>
      'No se pudo crear la categoría. Por favor, inténtalo de nuevo.';

  @override
  String get categoryDayPlanDescription =>
      'Hacer que esta categoría esté disponible para seleccionarla en tu plan del día';

  @override
  String get categoryDayPlanLabel => 'Plan del día';

  @override
  String get categoryDefaultLanguageDescription =>
      'Establecer un idioma predeterminado para las tareas de esta categoría';

  @override
  String get categoryDefaultProfileHint => 'Seleccionar un perfil…';

  @override
  String get categoryDefaultTemplateHint => 'Seleccionar una plantilla…';

  @override
  String get categoryDefaultTemplateLabel =>
      'Plantilla de agente predeterminada';

  @override
  String get categoryDeleteConfirm => 'SÍ, ELIMINAR ESTA CATEGORÍA';

  @override
  String get categoryDeleteConfirmation =>
      'Esta acción no se puede deshacer. Todas las entradas de esta categoría se conservarán pero dejarán de estar categorizadas.';

  @override
  String get categoryDeleteTitle => '¿Eliminar categoría?';

  @override
  String get categoryFavoriteBadgeLabel => 'Favorita';

  @override
  String get categoryFavoriteDescription =>
      'Marcar esta categoría como favorita';

  @override
  String get categoryIconChooseHint => 'Elegir un icono';

  @override
  String get categoryIconCreateHint => 'Elegir un icono';

  @override
  String get categoryIconEditHint => 'Elegir otro icono';

  @override
  String get categoryIconLabel => 'Icono';

  @override
  String get categoryIconPickerTitle => 'Elegir icono';

  @override
  String get categoryNameRequired => 'El nombre de la categoría es obligatorio';

  @override
  String get categoryNotFound => 'Categoría no encontrada';

  @override
  String get categoryPrivateBadgeLabel => 'Privada';

  @override
  String get categoryPrivateDescription =>
      'Solo visible cuando se muestran las entradas privadas';

  @override
  String get categorySearchPlaceholder => 'Buscar categorías...';

  @override
  String get changeSetCardTitle => 'Cambios propuestos';

  @override
  String get changeSetConfirmAll => 'Confirmar todos';

  @override
  String changeSetConfirmAllPartialIssues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos tuvieron problemas parciales',
      one: '1 elemento tuvo problemas parciales',
    );
    return '$_temp0';
  }

  @override
  String get changeSetConfirmError => 'No se pudo aplicar el cambio';

  @override
  String get changeSetItemConfirmed => 'Cambio aplicado';

  @override
  String changeSetItemConfirmedWithWarning(String warning) {
    return 'Aplicado con advertencia: $warning';
  }

  @override
  String get changeSetItemRejected => 'Cambio rechazado';

  @override
  String changeSetPendingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pendientes',
      one: '1 pendiente',
    );
    return '$_temp0';
  }

  @override
  String get changeSetSwipeConfirm => 'Confirmar';

  @override
  String get changeSetSwipeReject => 'Rechazar';

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
  String checklistAiConfidenceLabel(String level) {
    return 'Confianza: $level';
  }

  @override
  String get checklistAiMarkComplete => 'Marcar como completado';

  @override
  String get checklistAiSuggestionBody =>
      'Este elemento parece estar completado:';

  @override
  String get checklistAiSuggestionTitle => 'Sugerencia de IA';

  @override
  String get checklistAllDone => '¡Todos los elementos completados!';

  @override
  String get checklistCollapseTooltip => 'Contraer';

  @override
  String checklistCompletedShort(int completed, int total) {
    return '$completed/$total completados';
  }

  @override
  String get checklistDelete => '¿Eliminar lista de verificación?';

  @override
  String get checklistExpandTooltip => 'Expandir';

  @override
  String get checklistExportAsMarkdown =>
      'Exportar lista de verificación como Markdown';

  @override
  String get checklistExportFailed => 'Error en la exportación';

  @override
  String get checklistItemArchived => 'Elemento archivado';

  @override
  String get checklistItemArchiveUndo => 'Deshacer';

  @override
  String get checklistItemDeleteCancel => 'Cancelar';

  @override
  String get checklistItemDeleteConfirm => 'Confirmar';

  @override
  String get checklistItemDeleted => 'Elemento eliminado';

  @override
  String get checklistItemDeleteWarning => 'Esta acción no se puede deshacer.';

  @override
  String get checklistMarkdownCopied =>
      'Lista de verificación copiada como Markdown';

  @override
  String get checklistMoreTooltip => 'Más';

  @override
  String get checklistNoneDone => 'Aún no hay elementos completados.';

  @override
  String get checklistNothingToExport => 'No hay elementos para exportar';

  @override
  String get checklistProgressSemantics =>
      'Progreso de la lista de verificación';

  @override
  String get checklistShare => 'Compartir';

  @override
  String get checklistShareHint => 'Mantener pulsado para compartir';

  @override
  String get checklistsReorder => 'Reordenar';

  @override
  String get clearButton => 'Borrar';

  @override
  String get colorCustomLabel => 'Personalizado';

  @override
  String get colorLabel => 'Color';

  @override
  String get commonError => 'Error';

  @override
  String get commonLoading => 'Cargando...';

  @override
  String get commonUnknown => 'Desconocido';

  @override
  String get completeHabitFailButton => 'No hecho';

  @override
  String get completeHabitSkipButton => 'Omitir';

  @override
  String get completeHabitSuccessButton => 'Éxito';

  @override
  String get configFlagAttemptEmbeddingDescription =>
      'Cuando está habilitado, la aplicación intentará generar incrustaciones para tus entradas para mejorar la búsqueda y las sugerencias de contenido relacionado.';

  @override
  String get configFlagDailyOsNextEnabled => 'Usar el nuevo DailyOS agéntico';

  @override
  String get configFlagDailyOsNextEnabledDescription =>
      'Reemplaza la superficie actual de DailyOS por el nuevo flujo de captura y reconciliación con voz dirigido por agente. Vista previa temprana — la lógica del backend está simulada.';

  @override
  String get configFlagEnableAiStreaming =>
      'Habilitar streaming de IA para acciones de tareas';

  @override
  String get configFlagEnableAiStreamingDescription =>
      'Transmitir respuestas de IA para acciones relacionadas con tareas. Desactívelo para almacenar respuestas en búfer y mantener la interfaz más fluida.';

  @override
  String get configFlagEnableAiSummaryTts => 'Reproducción de resúmenes de IA';

  @override
  String get configFlagEnableAiSummaryTtsDescription =>
      'Muestra el botón local de texto a voz en los resúmenes de IA de tareas. Requiere un modelo TTS de MLX Audio instalado.';

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
  String get configFlagEnableEmbeddings => 'Generar incrustaciones';

  @override
  String get configFlagEnableEvents => 'Activar eventos';

  @override
  String get configFlagEnableEventsDescription =>
      'Mostrar la función de eventos para crear, rastrear y gestionar eventos en tu diario.';

  @override
  String get configFlagEnableForkHealing =>
      'Reparación de bifurcaciones del agente';

  @override
  String get configFlagEnableForkHealingDescription =>
      'Fusiona historiales de agente divergentes por el uso en varios dispositivos en el siguiente despertar.';

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
  String get configFlagEnableProjects => 'Activar proyectos';

  @override
  String get configFlagEnableProjectsDescription =>
      'Mostrar funciones de gestión de proyectos para organizar tareas en proyectos.';

  @override
  String get configFlagEnableSessionRatings =>
      'Habilitar calificaciones de sesión';

  @override
  String get configFlagEnableSessionRatingsDescription =>
      'Solicitar una calificación rápida de sesión al detener un temporizador.';

  @override
  String get configFlagEnableSyncedAlerts => 'Alertas sincronizadas';

  @override
  String get configFlagEnableSyncedAlertsDescription =>
      'Sincroniza alertas de IA y tareas entre tus dispositivos y permite que programen notificaciones locales del sistema.';

  @override
  String get configFlagEnableTooltip =>
      'Habilitar información sobre herramientas';

  @override
  String get configFlagEnableTooltipDescription =>
      'Mostrar información sobre herramientas útil en toda la aplicación para guiarte a través de las funciones.';

  @override
  String get configFlagEnableVectorSearch => 'Búsqueda vectorial';

  @override
  String get configFlagEnableVectorSearchDescription =>
      'Activa la búsqueda vectorial en los filtros de tareas. Requiere incrustaciones activadas y Ollama en ejecución.';

  @override
  String get configFlagEnableWhatsNew => 'Mostrar «Novedades»';

  @override
  String get configFlagEnableWhatsNewDescription =>
      'Resalta nuevas funciones y cambios dentro del árbol de Ajustes.';

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
  String get configFlagShowSidebarWakeQueue =>
      'Mostrar la cola de despertares en la barra lateral';

  @override
  String get configFlagShowSidebarWakeQueueDescription =>
      'Muestra la cola de despertares encima de Ajustes — la cabecera, los dos próximos despertares con cuenta atrás y un enlace a la lista completa.';

  @override
  String get configFlagShowSyncActivityIndicator =>
      'Mostrar indicador de actividad de sincronización';

  @override
  String get configFlagShowSyncActivityIndicatorDescription =>
      'Muestra la actividad de sincronización en directo en la barra lateral — una franja LED tx/rx con la profundidad de bandejas de entrada y salida.';

  @override
  String get conflictApplyButton => 'Aplicar';

  @override
  String get conflictApplyFailedTitle => 'No se pudo aplicar la resolución';

  @override
  String conflictBannerAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count días',
      one: 'hace 1 día',
    );
    return '$_temp0';
  }

  @override
  String conflictBannerAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count h',
      one: 'hace 1 h',
    );
    return '$_temp0';
  }

  @override
  String get conflictBannerAgoJustNow => 'justo ahora';

  @override
  String conflictBannerAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count min',
      one: 'hace 1 min',
    );
    return '$_temp0';
  }

  @override
  String conflictBannerDivergedAgo(String entity, String ago) {
    return '$entity · divergió $ago';
  }

  @override
  String conflictBannerFieldsDifferList(String fields) {
    return 'Diferencias: $fields';
  }

  @override
  String get conflictDetailEntryNotFoundTitle => 'Entrada no encontrada';

  @override
  String get conflictDetailLoadErrorTitle => 'No se pudo cargar el conflicto';

  @override
  String get conflictDetailNotFoundTitle => 'Conflicto no encontrado';

  @override
  String get conflictFieldCategory => 'categoría';

  @override
  String get conflictFieldDuration => 'duración';

  @override
  String get conflictFieldTitle => 'Título';

  @override
  String get conflictFieldWordCount => 'número de palabras';

  @override
  String get conflictFooterHelperLocalSelected =>
      'Conserva tu edición local y descarta la versión sincronizada.';

  @override
  String get conflictFooterHelperPickASide => 'Elige un lado para aplicar.';

  @override
  String get conflictFooterHelperRemoteSelected =>
      'Acepta la versión sincronizada y descarta tu edición local.';

  @override
  String conflictHeaderPillEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entradas',
      one: '1 entrada',
    );
    return '$_temp0';
  }

  @override
  String conflictHeaderPillFieldsDiffer(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count campos difieren',
      one: '1 campo difiere',
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
    return '$status, $timestamp, $entityType, conflicto $id';
  }

  @override
  String conflictListItemTooltipFullId(String id) {
    return 'ID del conflicto: $id';
  }

  @override
  String get conflictMetaLocalEdit => 'edición local';

  @override
  String get conflictMetaVecPrefix => 'vec';

  @override
  String get conflictMetaViaSync => 'vía sync';

  @override
  String get conflictPageLeadDesktop =>
      'Diferencias resaltadas en línea. Haz clic en un lado para usar esa versión, o abre Editar y combinar para fusionarlas.';

  @override
  String get conflictPageLeadMobile =>
      'Diferencias resaltadas en línea. Toca un lado para usar esa versión.';

  @override
  String get conflictPageTitle => 'Conflicto de sincronización';

  @override
  String get conflictPickerEditMerge => 'Editar y combinar…';

  @override
  String get conflictPickerUseFromSync => 'Usar desde sincronización';

  @override
  String get conflictPickerUseThisDevice => 'Usar este dispositivo';

  @override
  String get conflictsEmptyDescription =>
      'Todo está sincronizado. Los elementos resueltos siguen disponibles en el otro filtro.';

  @override
  String get conflictsEmptyTitle => 'No se detectaron conflictos';

  @override
  String get conflictSideFromSync => 'DESDE SINCRONIZACIÓN';

  @override
  String get conflictSideThisDevice => 'ESTE DISPOSITIVO';

  @override
  String get conflictsResolved => 'resueltos';

  @override
  String get conflictsUnresolved => 'sin resolver';

  @override
  String conflictWordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count palabras',
      one: '$count palabra',
    );
    return '$_temp0';
  }

  @override
  String get copyAsMarkdown => 'Copiar como Markdown';

  @override
  String get copyAsText => 'Copiar como texto';

  @override
  String get correctionExampleCancel => 'CANCELAR';

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
  String get coverArtChipActive => 'Portada';

  @override
  String get coverArtChipSet => 'Establecer portada';

  @override
  String get coverArtGenerationComplete => '¡Arte de portada listo!';

  @override
  String get coverArtGenerationDismissHint =>
      'Puedes cerrar esto — la generación continúa en segundo plano';

  @override
  String get createButton => 'Crear';

  @override
  String get createCategoryTitle => 'Crear categoría';

  @override
  String get createEntryLabel => 'Crear nueva entrada';

  @override
  String get createEntryTitle => 'Añadir';

  @override
  String get createNewLinkedTask => 'Crear nueva tarea vinculada...';

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
  String get dailyOsDayPlan => 'Plan del día';

  @override
  String get dailyOsDaySummary => 'Resumen del día';

  @override
  String get dailyOsDelete => 'Eliminar';

  @override
  String get dailyOsDeletePlannedBlock => '¿Eliminar bloque?';

  @override
  String get dailyOsDeletePlannedBlockConfirm =>
      'Esto eliminará el bloque planificado de tu línea de tiempo.';

  @override
  String get dailyOsDraftMessage =>
      'El plan es un borrador. Acepte para confirmarlo.';

  @override
  String get dailyOsDueToday => 'Vence hoy';

  @override
  String get dailyOsDueTodayShort => 'Hoy';

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
  String get dailyOsEditPlannedBlock => 'Editar bloque planificado';

  @override
  String get dailyOsEndTime => 'Fin';

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
  String get dailyOsInvalidTimeRange => 'Rango de tiempo no válido';

  @override
  String get dailyOsNearLimit => 'Cerca del límite';

  @override
  String get dailyOsNextAgendaCapacityComfortable => 'Cómodo';

  @override
  String get dailyOsNextAgendaCapacityNearFull => 'Casi lleno';

  @override
  String get dailyOsNextAgendaCapacityNoPlan => 'Aún sin plan';

  @override
  String dailyOsNextAgendaCapacityOf(String capacity) {
    return 'de $capacity';
  }

  @override
  String get dailyOsNextAgendaCapacityOver => 'Sobrecargado';

  @override
  String get dailyOsNextAgendaDonutLeft => 'libre';

  @override
  String get dailyOsNextAgendaDonutOver => 'de más';

  @override
  String dailyOsNextAgendaHeadlineLeft(String duration) {
    return '$duration restantes';
  }

  @override
  String dailyOsNextAgendaHeadlineOver(String duration) {
    return '$duration de más';
  }

  @override
  String get dailyOsNextAgendaNoPlanBody =>
      'Tu tiempo registrado está aquí de todos modos: habla un check-in y prepararé un día a tu alrededor.';

  @override
  String dailyOsNextAgendaNoPlanSummary(String duration) {
    return '$duration registrado hasta ahora. Habla un check-in y prepararé un día a tu alrededor.';
  }

  @override
  String get dailyOsNextAgendaNoPlanTitle => 'Aún no hay plan para hoy.';

  @override
  String get dailyOsNextAgendaStateDone => 'Hecho';

  @override
  String get dailyOsNextAgendaStateInProgress => 'En curso';

  @override
  String get dailyOsNextAgendaStateOpen => 'Abierto';

  @override
  String get dailyOsNextAgendaStateOverdue => 'Atrasado';

  @override
  String dailyOsNextAgendaSummary(String scheduled, String capacity) {
    return '$scheduled de $capacity comprometidos';
  }

  @override
  String dailyOsNextAgendaTrackedLegend(String duration, int completedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      completedCount,
      locale: localeName,
      other: '$completedCount hechas',
      one: '1 hecha',
    );
    return 'Registrado · $duration · $_temp0';
  }

  @override
  String get dailyOsNextCaptureCaptured => 'Entendido.';

  @override
  String get dailyOsNextCaptureDoneCta => 'Listo';

  @override
  String get dailyOsNextCaptureErrorMicrophonePermissionDenied =>
      'Se denegó el permiso del micrófono.';

  @override
  String get dailyOsNextCaptureErrorNoActiveRealtimeSession =>
      'No hay ninguna sesión en tiempo real activa.';

  @override
  String get dailyOsNextCaptureErrorNoAudioRecorded =>
      'No se grabó ningún audio.';

  @override
  String get dailyOsNextCaptureErrorRealtimeTranscriptionFailed =>
      'Falló la transcripción en tiempo real.';

  @override
  String get dailyOsNextCaptureErrorRealtimeTranscriptionStartFailed =>
      'No se pudo iniciar la transcripción en tiempo real.';

  @override
  String get dailyOsNextCaptureErrorRecordingStartFailed =>
      'No se pudo iniciar la grabación.';

  @override
  String get dailyOsNextCaptureErrorTranscriptionFailed =>
      'Falló la transcripción.';

  @override
  String get dailyOsNextCaptureHeadlineCaptured => '¿Se ve bien?';

  @override
  String get dailyOsNextCaptureHeadlineLead => '¿Qué tienes en mente';

  @override
  String get dailyOsNextCaptureHeadlineListening => 'Te escucho.';

  @override
  String get dailyOsNextCaptureHeadlineTail => 'para hoy?';

  @override
  String dailyOsNextCaptureHeadlineTailForDate(String date) {
    return 'para $date?';
  }

  @override
  String get dailyOsNextCaptureHeadlineTailTomorrow => 'para mañana?';

  @override
  String get dailyOsNextCaptureHeadlineTailYesterday => 'para ayer?';

  @override
  String get dailyOsNextCaptureHeadlineTranscribing => 'Tomando nota…';

  @override
  String get dailyOsNextCaptureIdleClick => 'Haz clic para hablar';

  @override
  String get dailyOsNextCaptureIdleExample =>
      '«Trabajo profundo por la mañana, un paseo después de comer, correos antes de las cinco.»';

  @override
  String get dailyOsNextCaptureIdleHint =>
      'Toca para hablar · escribe en su lugar';

  @override
  String get dailyOsNextCaptureIdleTalk => 'Toca para hablar';

  @override
  String get dailyOsNextCaptureListeningStatus => 'Escuchando…';

  @override
  String dailyOsNextCapturePastPrompt(String date) {
    return '¿Quieres registrar algo del $date?';
  }

  @override
  String get dailyOsNextCaptureReconcileCta => 'Revisar';

  @override
  String get dailyOsNextCapturesPanelTitle => 'Capturas';

  @override
  String get dailyOsNextCaptureTranscribing => 'Transcribiendo…';

  @override
  String get dailyOsNextCaptureTranscriptHint =>
      'Corrige lo que la transcripción haya entendido mal antes de planificar.';

  @override
  String get dailyOsNextCaptureTranscriptLabel => 'Revisa la transcripción';

  @override
  String get dailyOsNextCaptureTypeInstead => 'Escribe en su lugar';

  @override
  String get dailyOsNextCaptureVoiceButtonReset => 'Empezar de nuevo';

  @override
  String get dailyOsNextCaptureVoiceButtonStart => 'Empezar a escuchar';

  @override
  String get dailyOsNextCaptureVoiceButtonStop => 'Detener';

  @override
  String get dailyOsNextCategoryFilterAll => 'Todas las categorías';

  @override
  String get dailyOsNextCategoryFilterDescription =>
      'Solo las categorías activadas para el plan del día se usan en el procesamiento automático de Daily OS.';

  @override
  String get dailyOsNextCategoryFilterEmpty =>
      'Aún no hay categorías activadas para el plan del día.';

  @override
  String get dailyOsNextCategoryFilterIncludeAll => 'Incluir todas';

  @override
  String get dailyOsNextCategoryFilterTitle => 'Categorías de procesamiento';

  @override
  String get dailyOsNextCategoryFilterTooltip =>
      'Elegir categorías de procesamiento de Daily OS';

  @override
  String dailyOsNextCommitCapacityNote(String scheduled, String capacity) {
    return '$scheduled de $capacity comprometidos. Margen cómodo — puedes absorber una sorpresa.';
  }

  @override
  String get dailyOsNextCommitDraftOverline => 'TU DÍA, EN BORRADOR';

  @override
  String get dailyOsNextCommitExplainer =>
      'Confirma para pasar el día de borrador a comprometido.';

  @override
  String get dailyOsNextCommitFinalStepEyebrow => 'ÚLTIMO PASO';

  @override
  String get dailyOsNextCommitHeadline => 'Hazlo tuyo.';

  @override
  String get dailyOsNextCommitHoldHelper => 'Mantén un segundo para confirmar';

  @override
  String get dailyOsNextCommitHoldWordDone => 'Comprometido';

  @override
  String get dailyOsNextCommitHoldWordHolding => 'Sigue así';

  @override
  String get dailyOsNextCommitHoldWordIdle => 'Mantén';

  @override
  String get dailyOsNextCommitLockingIn => 'Fijando…';

  @override
  String get dailyOsNextCommitShepherdSubline =>
      'Yo lo guío — tú haces el trabajo.';

  @override
  String get dailyOsNextCommitSubCaption =>
      'Después aún puedes hablar conmigo, pero la estructura se queda.';

  @override
  String get dailyOsNextCommitTitle => 'Confirmar';

  @override
  String get dailyOsNextCommitTodayIsYours => 'El día es tuyo.';

  @override
  String get dailyOsNextDayBack => 'Atrás';

  @override
  String get dailyOsNextDayCheckInCta => 'Hablar un check-in';

  @override
  String get dailyOsNextDayDeleteDialogBody =>
      'Los bloques planificados para este día se eliminarán. Tus capturas y sus grabaciones de audio se quedan en tu diario.';

  @override
  String get dailyOsNextDayDeleteDialogCancel => 'Cancelar';

  @override
  String get dailyOsNextDayDeleteDialogConfirm => 'Eliminar';

  @override
  String get dailyOsNextDayDeleteDialogTitle => '¿Eliminar este plan?';

  @override
  String get dailyOsNextDayLockInCta => 'Confirmar';

  @override
  String get dailyOsNextDayMenuDeletePlan => 'Eliminar plan';

  @override
  String get dailyOsNextDayMenuInspectAgent => 'Inspeccionar agente';

  @override
  String get dailyOsNextDayMoreTooltip => 'Más';

  @override
  String get dailyOsNextDayRefineCta => 'Ajustar';

  @override
  String get dailyOsNextDayRefineFooterHint =>
      'Habla para reorganizar el plan — verás cada cambio antes de que se guarde nada.';

  @override
  String get dailyOsNextDayTitle => 'Tu día';

  @override
  String get dailyOsNextDayWhyChipLabel => 'POR QUÉ';

  @override
  String get dailyOsNextDayWrapUpCta => 'Cerrar día';

  @override
  String get dailyOsNextDraftingHeader => 'Preparando tu día…';

  @override
  String get dailyOsNextDraftingNudgeAccept => 'Sí, protege las mañanas';

  @override
  String get dailyOsNextDraftingNudgeDecline => 'Hoy no';

  @override
  String get dailyOsNextDraftingReasoningOverline => '✦ RAZONAMIENTO';

  @override
  String get dailyOsNextDraftingStatusAfternoon => 'Ordenando la tarde…';

  @override
  String get dailyOsNextDraftingStatusAlmost => 'Casi listo…';

  @override
  String get dailyOsNextDraftingStatusBreathing =>
      'Dejando espacio para respirar…';

  @override
  String get dailyOsNextDraftingStatusDeepWork =>
      'Colocando el trabajo profundo primero…';

  @override
  String get dailyOsNextDraftingStatusMatching => 'Asignando tareas a tu día…';

  @override
  String get dailyOsNextDraftingStatusReading => 'Leyendo tu registro…';

  @override
  String get dailyOsNextDraftingStatusTimings => 'Revisando los horarios…';

  @override
  String get dailyOsNextDraftingStatusYesterday =>
      'Observando el ritmo de ayer…';

  @override
  String get dailyOsNextEditTitleHint => 'Editar título';

  @override
  String get dailyOsNextGenericError =>
      'Algo salió mal. Inténtalo de nuevo en un momento.';

  @override
  String get dailyOsNextGreetingAfternoon => 'Buenas tardes.';

  @override
  String get dailyOsNextGreetingEvening => 'Buenas noches.';

  @override
  String dailyOsNextGreetingHiName(String name) {
    return 'Hola $name 👋';
  }

  @override
  String get dailyOsNextGreetingMorning => 'Buenos días.';

  @override
  String get dailyOsNextKnowledgeConfirm => 'Confirmar';

  @override
  String get dailyOsNextKnowledgeConfirmedHeader => 'Confirmado';

  @override
  String get dailyOsNextKnowledgeEdit => 'Editar';

  @override
  String get dailyOsNextKnowledgeEditCancel => 'Cancelar';

  @override
  String get dailyOsNextKnowledgeEditHookHint => 'Resumen de una línea';

  @override
  String get dailyOsNextKnowledgeEditSave => 'Guardar';

  @override
  String get dailyOsNextKnowledgeEditStatementHint => '¿Qué debo recordar?';

  @override
  String get dailyOsNextKnowledgeEmpty =>
      'Nada aún — recordaré lo que me digas.';

  @override
  String dailyOsNextKnowledgeNudge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cosas que noté — revisar',
      one: '1 cosa que noté — revisar',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextKnowledgeProposedHeader => 'Esperando tu confirmación';

  @override
  String get dailyOsNextKnowledgeRetract => 'Olvidar';

  @override
  String get dailyOsNextKnowledgeStale => '¿Sigue siendo así?';

  @override
  String get dailyOsNextKnowledgeTitle => 'Lo que he aprendido';

  @override
  String get dailyOsNextParsedCardBreakLinkTooltip => 'Romper enlace';

  @override
  String get dailyOsNextPlanViewAgenda => 'Agenda';

  @override
  String get dailyOsNextPlanViewDay => 'Día';

  @override
  String get dailyOsNextReconcileBadgeMatched => 'VINCULADO';

  @override
  String get dailyOsNextReconcileBadgeNew => 'NUEVO';

  @override
  String get dailyOsNextReconcileBadgeUpdate => 'ACTUALIZAR';

  @override
  String get dailyOsNextReconcileBuildDayCta => 'Construir mi día';

  @override
  String get dailyOsNextReconcileDecideOverline => 'VALE LA PENA DECIDIR';

  @override
  String get dailyOsNextReconcileDefaultBehaviorHint =>
      'Tus decisiones aquí alimentan el plan — no decidir significa «déjalo donde está».';

  @override
  String dailyOsNextReconcileError(String detail) {
    return 'Algo salió mal: $detail';
  }

  @override
  String get dailyOsNextReconcileHeadline => 'Esto es lo que escuché.';

  @override
  String get dailyOsNextReconcileHeardEmpty =>
      'Las tarjetas de la captura aparecerán aquí cuando termine el análisis.';

  @override
  String get dailyOsNextReconcileHeardOverline => 'ESCUCHADO';

  @override
  String get dailyOsNextReconcileLowConfidence => 'confianza baja';

  @override
  String get dailyOsNextReconcileReRecord => 'Volver a grabar';

  @override
  String get dailyOsNextReconcileVoiceHint =>
      'Revisa las decisiones antes de armar tu día';

  @override
  String get dailyOsNextRefineAccept => 'Aceptar';

  @override
  String get dailyOsNextRefineCurrentPlan => 'PLAN ACTUAL';

  @override
  String get dailyOsNextRefineDiffAdded => 'AÑADIDO';

  @override
  String get dailyOsNextRefineDiffDropped => 'DESCARTADO';

  @override
  String get dailyOsNextRefineDiffMoved => 'MOVIDO';

  @override
  String get dailyOsNextRefineHeadlineDiffReady => 'Esto es lo que cambiaría.';

  @override
  String get dailyOsNextRefineHeadlineIdle => '¿Qué cambiamos?';

  @override
  String get dailyOsNextRefineHeadlineThinking => 'Reajustando tu plan…';

  @override
  String get dailyOsNextRefineKeepTalking => 'Seguir hablando';

  @override
  String get dailyOsNextRefineLooksGood => 'Se ve bien';

  @override
  String get dailyOsNextRefineNoChanges =>
      'No llegaron cambios del plan. Reformúlalo e inténtalo de nuevo.';

  @override
  String get dailyOsNextRefineOverline => '🎤 REFINAMIENTO';

  @override
  String get dailyOsNextRefineRevert => 'Deshacer';

  @override
  String get dailyOsNextRefineStatusAccepted => 'Confirmado.';

  @override
  String get dailyOsNextRefineStatusDiffReady => 'Esto es lo que cambió.';

  @override
  String get dailyOsNextRefineStatusIdle => 'Toca para hablar.';

  @override
  String get dailyOsNextRefineStatusListening => 'Escuchando…';

  @override
  String get dailyOsNextRefineStatusThinking => '✦ Reformando el plan…';

  @override
  String get dailyOsNextRefineTitle => 'Refinar el plan';

  @override
  String get dailyOsNextRenameFailed =>
      'No se pudo renombrar: inténtalo de nuevo.';

  @override
  String get dailyOsNextShutdownCarryoverDrop => 'Descartar';

  @override
  String get dailyOsNextShutdownCarryoverDropped => 'Descartado';

  @override
  String get dailyOsNextShutdownCarryoverOverline => 'PASA A MAÑANA';

  @override
  String get dailyOsNextShutdownCarryoverPickDate => 'Elegir fecha';

  @override
  String get dailyOsNextShutdownCarryoverScheduled => 'Programado';

  @override
  String get dailyOsNextShutdownCloseDay => 'Cerrar el día';

  @override
  String get dailyOsNextShutdownCompletedOverline => 'LO QUE HICISTE';

  @override
  String get dailyOsNextShutdownMetricEnergy => 'ENERGÍA';

  @override
  String dailyOsNextShutdownMetricEnergyDelta(String delta) {
    return '$delta vs. semana';
  }

  @override
  String get dailyOsNextShutdownMetricFlow => 'SESIONES DE FLUJO';

  @override
  String get dailyOsNextShutdownMetricFocus => 'TIEMPO DE FOCO';

  @override
  String get dailyOsNextShutdownMetricSwitches => 'CAMBIOS DE CONTEXTO';

  @override
  String dailyOsNextShutdownMetricSwitchesAvg(String avg) {
    return 'media $avg esta semana';
  }

  @override
  String get dailyOsNextShutdownReflectionOverline =>
      '💬 REFLEXIÓN DE UNA LÍNEA';

  @override
  String get dailyOsNextShutdownReflectionPlaceholder =>
      'p. ej., la mañana fue ágil, la tarde se hizo larga después del café con Sarah.';

  @override
  String get dailyOsNextShutdownReflectionPrompt =>
      '¿Cómo aterrizó hoy? (Alimenta el borrador de mañana.)';

  @override
  String get dailyOsNextShutdownReflectionSpeak => 'Háblalo';

  @override
  String get dailyOsNextShutdownReflectionSubmit => 'Saltar';

  @override
  String get dailyOsNextShutdownReflectionThanks =>
      'Anotado — alimenta el día de mañana.';

  @override
  String get dailyOsNextShutdownSaveAndClose => 'Guardar y cerrar';

  @override
  String get dailyOsNextShutdownTitle => 'Cerrar el día';

  @override
  String get dailyOsNextShutdownTomorrowOverline => '✦ PARA MAÑANA';

  @override
  String dailyOsNextStateDueOnDate(String date) {
    return 'Vence el $date';
  }

  @override
  String get dailyOsNextStateDueToday => 'Vence hoy';

  @override
  String dailyOsNextStateInProgress(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'En curso · $count sesiones',
      one: 'En curso · 1 sesión',
      zero: 'En curso',
    );
    return '$_temp0';
  }

  @override
  String dailyOsNextStateOverdue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Atrasado · $days días',
      one: 'Atrasado · 1 día',
      zero: 'Atrasado',
    );
    return '$_temp0';
  }

  @override
  String dailyOsNextStateOverdueOnDate(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Atrasado $days días el $date',
      one: 'Atrasado 1 día el $date',
      zero: 'Atrasado el $date',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextStateRecurringMissed => 'Recurrente · perdido';

  @override
  String get dailyOsNextTimelineActual => 'Real';

  @override
  String get dailyOsNextTimelineBoth => 'Plan y real';

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
    return 'Sesión $index de $total';
  }

  @override
  String get dailyOsNextTimelineShowBoth => 'Mostrar plan y real juntos';

  @override
  String get dailyOsNextTimelineShowPaged => 'Mostrar plan y real deslizable';

  @override
  String get dailyOsNextTimelineSwipeHint =>
      'Desliza para ver lo real · pellizca verticalmente para zoom';

  @override
  String get dailyOsNextTimelineTracked => 'registrado';

  @override
  String dailyOsNextTimeSpentEarlierSessions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sesiones anteriores',
      one: '1 sesión anterior',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextTimeSpentShowLess => 'Mostrar menos';

  @override
  String dailyOsNextTimeSpentSummary(String duration, int completedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      completedCount,
      locale: localeName,
      other: '$completedCount hechas',
      one: '1 hecha',
    );
    return '$duration · $_temp0';
  }

  @override
  String get dailyOsNextTimeSpentTitle => 'HOY HASTA AHORA';

  @override
  String get dailyOsNextTimeSpentTitlePast => 'TIEMPO REGISTRADO';

  @override
  String get dailyOsNextTriageConfirmDefer => 'Aplazado';

  @override
  String get dailyOsNextTriageConfirmDone => 'Marcado como hecho';

  @override
  String get dailyOsNextTriageConfirmDoNow => 'Hecho ya';

  @override
  String get dailyOsNextTriageConfirmDrop => 'Descartado';

  @override
  String get dailyOsNextTriageConfirmToday => 'Añadido a hoy';

  @override
  String get dailyOsNextTriageDefer => 'Aplazar';

  @override
  String get dailyOsNextTriageDone => 'Hecho';

  @override
  String get dailyOsNextTriageDoNow => 'Hacer ahora';

  @override
  String get dailyOsNextTriageDrop => 'Descartar';

  @override
  String get dailyOsNextTriageToday => 'Hoy';

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
  String get dailyOsPlanCreated => 'Plan creado con éxito';

  @override
  String get dailyOsPlanCreatedDescription =>
      'Tus bloques de tiempo se han guardado. Puedes empezar a registrar tus tareas.';

  @override
  String get dailyOsPlanned => 'Planificado';

  @override
  String get dailyOsPlanWithoutVoice => 'Planificar sin voz';

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
  String get dailyOsSaveError => 'No se pudo guardar el plan';

  @override
  String get dailyOsSaveErrorDescription =>
      'Algo salió mal. Por favor, inténtalo de nuevo.';

  @override
  String get dailyOsSavePlan => 'Guardar plan';

  @override
  String get dailyOsSelectCategory => 'Seleccionar categoría';

  @override
  String get dailyOsSetTimeBlocks => 'Configurar bloques de tiempo';

  @override
  String get dailyOsSetTimeBlocksAddNew => 'Añadir nuevo bloque de tiempo';

  @override
  String get dailyOsSetTimeBlocksFavourites => 'Favoritos';

  @override
  String get dailyOsSetTimeBlocksOther => 'Otras categorías';

  @override
  String get dailyOsSetTimeBlocksTapHint =>
      'Toca para añadir un bloque de tiempo';

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
  String get dashboardActiveLabel => 'Activo';

  @override
  String get dashboardActiveSwitchDescription =>
      'Se muestra en la lista de paneles';

  @override
  String get dashboardAddChartsTitle => 'Gráficos';

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
  String get dashboardAddMeasurementTooltip => 'Añadir medición';

  @override
  String get dashboardAddSurveyButton => 'Gráficos de encuesta';

  @override
  String get dashboardAddSurveyTitle => 'Gráficos de encuesta';

  @override
  String get dashboardAddWorkoutButton => 'Gráficos de entrenamiento';

  @override
  String get dashboardAddWorkoutTitle => 'Gráficos de entrenamiento';

  @override
  String get dashboardAggregationDailyAverage => 'Promedio diario';

  @override
  String get dashboardAggregationDailyMax => 'Máximo diario';

  @override
  String get dashboardAggregationDailyTotal => 'Total diario';

  @override
  String get dashboardAggregationHourlyTotal => 'Total por hora';

  @override
  String get dashboardAggregationLabel => 'Tipo de agregación:';

  @override
  String get dashboardCategoryLabel => 'Categoría';

  @override
  String get dashboardChartNoData => 'Sin datos en este rango';

  @override
  String get dashboardCopyHint => 'Guardar y copiar la configuración del panel';

  @override
  String get dashboardCopyLabel => 'Guardar y copiar la configuración';

  @override
  String get dashboardDeleteConfirm => 'SÍ, BORRAR ESTE PANEL';

  @override
  String get dashboardDeleteHint => 'Borrar panel';

  @override
  String get dashboardDeleteQuestion => '¿Quieres borrar este panel?';

  @override
  String get dashboardDescriptionLabel => 'Descripción (opcional)';

  @override
  String get dashboardHealthBloodPressure => 'Presión arterial';

  @override
  String get dashboardHealthDiastolic => 'Diastólica';

  @override
  String get dashboardHealthSystolic => 'Sistólica';

  @override
  String get dashboardNameLabel => 'Nombre del panel';

  @override
  String get dashboardNotFound => 'Panel no encontrado';

  @override
  String get dashboardPrivateLabel => 'Privado';

  @override
  String get dashboardTakeSurveyTooltip => 'Responder encuesta';

  @override
  String get defaultLanguage => 'Idioma predeterminado';

  @override
  String get deleteButton => 'Eliminar';

  @override
  String get deleteDeviceLabel => 'Eliminar dispositivo';

  @override
  String get designSystemActionVariantTitle => 'Con acción';

  @override
  String get designSystemActivatedLabel => 'Activa';

  @override
  String get designSystemAvatarAwayLabel => 'Ausente';

  @override
  String get designSystemAvatarBusyLabel => 'Ocupado';

  @override
  String get designSystemAvatarConnectedLabel => 'Conectado';

  @override
  String get designSystemAvatarEnabledLabel => 'Habilitado';

  @override
  String get designSystemAvatarSizeMatrixTitle => 'Matriz de tamaños';

  @override
  String get designSystemAvatarStatusMatrixTitle => 'Matriz de estados';

  @override
  String get designSystemBackLabel => 'Atrás';

  @override
  String get designSystemBreadcrumbCurrentLabel => 'Breadcrumbs';

  @override
  String get designSystemBreadcrumbDesignSystemLabel => 'Sistema de diseño';

  @override
  String get designSystemBreadcrumbHomeLabel => 'Inicio';

  @override
  String get designSystemBreadcrumbMobileLabel => 'Móvil';

  @override
  String get designSystemBreadcrumbProjectsLabel => 'Proyectos';

  @override
  String get designSystemBreadcrumbSampleLabel => 'Breadcrumb';

  @override
  String get designSystemBreadcrumbTrailTitle => 'Ruta de breadcrumbs';

  @override
  String get designSystemCalendarPickerLabel => 'Selector de calendario';

  @override
  String get designSystemCalendarViewsTitle => 'Vistas del calendario';

  @override
  String get designSystemCaptionDescriptionSample =>
      'Eliminar a todos los usuarios ha despublicado este proyecto. Añade usuarios para volver a publicar.';

  @override
  String get designSystemCaptionIconLeftLabel => 'Icono a la izquierda';

  @override
  String get designSystemCaptionIconTopLabel => 'Icono arriba';

  @override
  String get designSystemCaptionNoIconLabel => 'Sin icono';

  @override
  String get designSystemCaptionTitleSample => 'Título';

  @override
  String get designSystemCaptionVariantsTitle => 'Variantes de caption';

  @override
  String get designSystemCaptionWithActionsLabel => 'Con acciones';

  @override
  String get designSystemCaptionWithoutActionsLabel => 'Sin acciones';

  @override
  String get designSystemCheckboxLabel => 'Casilla de verificación';

  @override
  String get designSystemContextMenuDeleteLabel => 'Eliminar';

  @override
  String get designSystemContextMenuVariantsTitle =>
      'Variantes de menú contextual';

  @override
  String get designSystemCountdownVariantTitle => 'Con cuenta regresiva';

  @override
  String get designSystemDateCardsTitle => 'Tarjetas de fecha';

  @override
  String get designSystemDefaultLabel => 'Predeterminado';

  @override
  String get designSystemDisabledLabel => 'Desactivado';

  @override
  String get designSystemDividerLabelText => 'Etiqueta del separador';

  @override
  String get designSystemDropdownComboboxTitle => 'Cuadro combinado';

  @override
  String get designSystemDropdownFieldLabel => 'Etiqueta';

  @override
  String get designSystemDropdownInputLabel => 'Entrada';

  @override
  String get designSystemDropdownListTitle => 'Lista desplegable';

  @override
  String get designSystemDropdownMultiselectInputLabel => 'Selecciona equipos';

  @override
  String get designSystemDropdownMultiselectTitle => 'Selección múltiple';

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
  String get designSystemFileUploadClickLabel => 'Haz clic para subir';

  @override
  String get designSystemFileUploadCompleteLabel => 'Completado';

  @override
  String get designSystemFileUploadDefaultLabel => 'Predeterminado';

  @override
  String get designSystemFileUploadDragLabel => 'o arrastra y suelta';

  @override
  String get designSystemFileUploadDropZoneSectionTitle => 'Zona de subida';

  @override
  String get designSystemFileUploadErrorLabel => 'Error';

  @override
  String get designSystemFileUploadFailedText => 'Error al subir';

  @override
  String get designSystemFileUploadHintText =>
      'SVG, PNG, JPG o GIF (máx. 800×400px)';

  @override
  String get designSystemFileUploadHoverLabel => 'Al pasar';

  @override
  String get designSystemFileUploadItemSectionTitle => 'Elementos de archivo';

  @override
  String get designSystemFileUploadRetryLabel => 'Reintentar';

  @override
  String get designSystemFileUploadUploadingLabel => 'Subiendo';

  @override
  String get designSystemFilledLabel => 'Relleno';

  @override
  String get designSystemHeaderApiDocumentationLabel => 'Documentación de API';

  @override
  String get designSystemHeaderBackActionLabel => 'Atrás';

  @override
  String get designSystemHeaderDesktopSectionTitle => 'Escritorio';

  @override
  String get designSystemHeaderHelpActionLabel => 'Ayuda';

  @override
  String get designSystemHeaderMobileSectionTitle => 'Móvil';

  @override
  String get designSystemHeaderNotificationsActionLabel => 'Notificaciones';

  @override
  String get designSystemHeaderSearchActionLabel => 'Buscar';

  @override
  String get designSystemHorizontalLabel => 'Horizontal';

  @override
  String get designSystemHoverLabel => 'Al pasar';

  @override
  String get designSystemInfoLabel => 'Info';

  @override
  String get designSystemInputErrorSample => 'Este campo es obligatorio';

  @override
  String get designSystemInputHelperSample => 'Introduce tu nombre';

  @override
  String get designSystemInputHintSample => 'Marcador...';

  @override
  String get designSystemInputLabelSample => 'Etiqueta';

  @override
  String get designSystemInputVariantsTitle => 'Variantes de campo de entrada';

  @override
  String get designSystemInputWithErrorLabel => 'Con error';

  @override
  String get designSystemInputWithHelperLabel => 'Con texto de ayuda';

  @override
  String get designSystemInputWithIconsLabel => 'Con iconos';

  @override
  String get designSystemListItemActivatedLabel => 'Activado';

  @override
  String get designSystemListItemOneLineLabel => 'Una línea';

  @override
  String get designSystemListItemSubtitleSample => 'Subtítulo';

  @override
  String get designSystemListItemTitleSample => 'Título';

  @override
  String get designSystemListItemTwoLinesLabel => 'Dos líneas';

  @override
  String get designSystemListItemVariantsTitle =>
      'Variantes de elemento de lista';

  @override
  String get designSystemListItemWithDividerLabel => 'Con separador';

  @override
  String get designSystemMediumLabel => 'Mediano';

  @override
  String designSystemMyDailyDurationHoursMinutesCompact(
    int hours,
    int minutes,
  ) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get designSystemMyDailyEditPlanLabel => 'Editar plan';

  @override
  String get designSystemMyDailyGreetingMorning => 'Buenos días.';

  @override
  String designSystemMyDailyGreetingWithName(String name) {
    return 'Hola, $name';
  }

  @override
  String get designSystemMyDailyHikeWithDanielaTitle =>
      'Senderismo con Daniela';

  @override
  String get designSystemMyDailyLunchBreakTitle => 'Pausa para comer';

  @override
  String get designSystemMyDailyMeetingsLabel => 'Reuniones';

  @override
  String get designSystemMyDailyMeetingWithDannyTitle => 'Reunión con Danny';

  @override
  String get designSystemMyDailyProfileActionLabel => 'Perfil';

  @override
  String get designSystemMyDailySkiWithMattTitle => 'Ir a esquiar con Matt';

  @override
  String get designSystemMyDailyTapToExpandLabel => 'Toca para expandir';

  @override
  String get designSystemNavigationCollapsedLabel => 'Contraída';

  @override
  String get designSystemNavigationDailyFilterSectionTitle => 'Filtro diario';

  @override
  String get designSystemNavigationExpandedLabel => 'Expandida';

  @override
  String get designSystemNavigationFilterByBlockLabel => 'Filtrar por bloque';

  @override
  String get designSystemNavigationHikingLabel => 'Senderismo';

  @override
  String get designSystemNavigationHolidayLabel => 'Vacaciones';

  @override
  String get designSystemNavigationInsightsLabel => 'Paneles';

  @override
  String get designSystemNavigationLottiTasksLabel => 'Tareas de Lotti';

  @override
  String get designSystemNavigationMyDailyLabel => 'Mi día';

  @override
  String get designSystemNavigationNewLabel => 'Nuevo';

  @override
  String get designSystemNavigationPlaceholderLabel => 'Marcador de posición';

  @override
  String get designSystemNavigationSidebarSectionTitle =>
      'Variantes de barra lateral';

  @override
  String get designSystemNavigationSubComponentsSectionTitle =>
      'Subcomponentes';

  @override
  String get designSystemNavigationTabBarSectionTitle =>
      'Variantes de barra de pestañas';

  @override
  String get designSystemPressedLabel => 'Pulsada';

  @override
  String get designSystemProgressBarChunkyLabel => 'Segmentada';

  @override
  String get designSystemProgressBarLabelAndPercentageLabel =>
      'Etiqueta + porcentaje';

  @override
  String get designSystemProgressBarLabelOnlyLabel => 'Solo etiqueta';

  @override
  String get designSystemProgressBarOffLabel => 'Apagada';

  @override
  String get designSystemProgressBarPercentageOnlyLabel => 'Porcentaje';

  @override
  String get designSystemProgressBarQuestBarLabel => 'Barra de misión';

  @override
  String get designSystemProgressBarQuestLabel => 'Etiqueta de mega premio';

  @override
  String get designSystemProgressBarSampleLabel =>
      'Etiqueta de barra de progreso';

  @override
  String get designSystemRadioButtonLabel => 'Botón de radio';

  @override
  String get designSystemScrollbarSizesTitle =>
      'Tamaños de barra de desplazamiento';

  @override
  String get designSystemSearchFilledText => 'Búsqueda de Lotti';

  @override
  String get designSystemSearchHintLabel => 'Escribe usuario';

  @override
  String get designSystemSelectedLabel => 'Seleccionado';

  @override
  String get designSystemSizeScaleTitle => 'Escala de tamaños';

  @override
  String get designSystemSmallLabel => 'Pequeño';

  @override
  String get designSystemSpinnerPlainLabel => 'Sin fondo';

  @override
  String get designSystemSpinnerSkeletonPulseLabel => 'Pulso';

  @override
  String get designSystemSpinnerSkeletonsTitle => 'Esqueletos';

  @override
  String get designSystemSpinnerSkeletonWaveLabel => 'Onda';

  @override
  String get designSystemSpinnerSpinnersTitle => 'Spinners';

  @override
  String get designSystemSpinnerTrackLabel => 'Con pista';

  @override
  String designSystemSplitButtonDropdownSemantics(String label) {
    return 'Abrir opciones de $label';
  }

  @override
  String get designSystemStateMatrixTitle => 'Matriz de estados';

  @override
  String get designSystemSuccessLabel => 'Éxito';

  @override
  String get designSystemTabBarTitle => 'Barra de pestañas';

  @override
  String get designSystemTabPendingLabel => 'Pendiente';

  @override
  String get designSystemTaskListBlockedLabel => 'Bloqueado';

  @override
  String get designSystemTaskListDefaultLabel => 'Predeterminado';

  @override
  String get designSystemTaskListHoverLabel => 'Al pasar';

  @override
  String get designSystemTaskListItemSectionTitle =>
      'Variantes de elemento de lista de tareas';

  @override
  String get designSystemTaskListOnHoldLabel => 'En espera';

  @override
  String get designSystemTaskListOpenLabel => 'Abierto';

  @override
  String get designSystemTaskListPressedLabel => 'Presionado';

  @override
  String get designSystemTaskListSampleTime => '8:00-9:30';

  @override
  String get designSystemTaskListSampleTitle => 'Pruebas de usuario';

  @override
  String get designSystemTaskListWithDividerLabel => 'Con separador';

  @override
  String get designSystemTextareaErrorSample => 'Este campo es obligatorio';

  @override
  String get designSystemTextareaHelperSample => 'Introduce tu mensaje aquí';

  @override
  String get designSystemTextareaHintSample => 'Escribe algo...';

  @override
  String get designSystemTextareaLabelSample => 'Etiqueta';

  @override
  String get designSystemTextareaVariantsTitle => 'Variantes de textarea';

  @override
  String get designSystemTextareaWithCounterLabel => 'Con contador';

  @override
  String get designSystemTextareaWithErrorLabel => 'Con error';

  @override
  String get designSystemTextareaWithHelperLabel => 'Con texto de ayuda';

  @override
  String get designSystemTimePickerFormatsTitle => 'Formatos de hora';

  @override
  String get designSystemTimePickerTwelveHourLabel => '12 horas';

  @override
  String get designSystemTimePickerTwentyFourHourLabel => '24 horas';

  @override
  String get designSystemTitleOnlyVariantTitle => 'Variante solo título';

  @override
  String get designSystemToastDetailsLabel => 'Detalles de la notificación';

  @override
  String get designSystemToggleLabel => 'Etiqueta del toggle';

  @override
  String get designSystemTooltipIconMessageSample =>
      'Información útil sobre este campo';

  @override
  String get designSystemTooltipIconVariantsTitle => 'Icono de tooltip';

  @override
  String get designSystemUndoLabel => 'Deshacer';

  @override
  String get designSystemVariantMatrixTitle => 'Matriz de variantes';

  @override
  String get designSystemVerticalLabel => 'Vertical';

  @override
  String get designSystemWarningLabel => 'Advertencia';

  @override
  String get designSystemWeeklyCalendarLabel => 'Calendario semanal';

  @override
  String get designSystemWithLabelLabel => 'Con etiqueta';

  @override
  String get desktopEmptyStateSelectDashboard =>
      'Selecciona un panel para ver los detalles';

  @override
  String get desktopEmptyStateSelectProject =>
      'Selecciona un proyecto para ver los detalles';

  @override
  String get desktopEmptyStateSelectTask =>
      'Selecciona una tarea para ver los detalles';

  @override
  String deviceDeletedSuccess(String deviceName) {
    return 'Dispositivo $deviceName eliminado correctamente';
  }

  @override
  String deviceDeleteFailed(String error) {
    return 'Error al eliminar el dispositivo: $error';
  }

  @override
  String get doneButton => 'Listo';

  @override
  String get editMenuTitle => 'Editar';

  @override
  String get editorInsertDivider => 'Insertar separador';

  @override
  String get editorPlaceholder => 'Introducir notas...';

  @override
  String get embeddingSelectAll => 'Seleccionar todo';

  @override
  String get embeddingUnselectAll => 'Deseleccionar todo';

  @override
  String get enhancedPromptFormPreconfiguredPromptDescription =>
      'Elegir entre plantillas de prompt prediseñadas';

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
  String get filterSelectionNoMatches => 'Sin coincidencias';

  @override
  String get geminiThinkingModeHighDescription =>
      'Razonamiento más profundo; puede aumentar la latencia y el coste.';

  @override
  String get geminiThinkingModeHighLabel => 'Alto';

  @override
  String get geminiThinkingModeLowDescription =>
      'Razonamiento bajo para prompts cotidianos rápidos.';

  @override
  String get geminiThinkingModeLowLabel => 'Bajo';

  @override
  String get geminiThinkingModeMediumDescription =>
      'Razonamiento equilibrado para respuestas más cuidadas.';

  @override
  String get geminiThinkingModeMediumLabel => 'Medio';

  @override
  String get geminiThinkingModeMinimalDescription =>
      'La opción más rápida; Gemini puede pensar brevemente en prompts complejos.';

  @override
  String get geminiThinkingModeMinimalLabel => 'Mínimo';

  @override
  String get generateCoverArt => 'Generar portada';

  @override
  String get generateCoverArtSubtitle =>
      'Crear imagen desde descripción de voz';

  @override
  String get habitActiveFromLabel => 'Fecha de inicio';

  @override
  String get habitActiveSwitchDescription =>
      'Se muestra en la página de Hábitos';

  @override
  String get habitArchivedLabel => 'Archivado';

  @override
  String get habitCategoryHint => 'Seleccionar una categoría';

  @override
  String get habitCategoryLabel => 'Categoría';

  @override
  String get habitCloseCompletionLabel => 'Cerrar registro de hábito';

  @override
  String habitCompleteSemanticLabel(String habit) {
    return 'Registrar $habit';
  }

  @override
  String get habitCompletionStatusCompleted => 'Completado';

  @override
  String get habitCompletionStatusFailed => 'Fallido';

  @override
  String get habitCompletionStatusOpen => 'Pendiente';

  @override
  String get habitCompletionStatusSkipped => 'Omitido';

  @override
  String get habitDashboardHint => 'Seleccionar un panel';

  @override
  String get habitDashboardLabel => 'Panel (opcional)';

  @override
  String habitDayStatusSemantic(String habit, String status) {
    return '$habit, $status';
  }

  @override
  String get habitDeleteConfirm => 'SÍ, BORRAR ESTE HÁBITO';

  @override
  String get habitDeleteQuestion => '¿Quieres borrar este hábito?';

  @override
  String habitHeatmapDaySemantic(String date, int done, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total hechos',
      one: '1 hecho',
    );
    return '$date, $done de $_temp0';
  }

  @override
  String get habitLogOtherDayHint => 'Mantén pulsado para registrar otro día';

  @override
  String get habitNotRecordedLabel => 'Sin registrar';

  @override
  String get habitPriorityLabel => 'Prioridad';

  @override
  String get habitsAboveGoal => 'En marcha';

  @override
  String habitsActiveHabitsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hábitos activos',
      one: '1 hábito activo',
    );
    return '$_temp0';
  }

  @override
  String get habitsAllDoneToday => 'Todo hecho hoy';

  @override
  String get habitsCompletedHeader => 'Completado';

  @override
  String get habitsCompletionRateTitle => 'Tasa de cumplimiento';

  @override
  String get habitsConsistencyTitle => 'Constancia';

  @override
  String habitsDayFailedPercent(int percent) {
    return '$percent% marcados como no hechos';
  }

  @override
  String habitsDaySkippedPercent(int percent) {
    return '$percent% omitidos';
  }

  @override
  String habitsDaySuccessfulPercent(int percent) {
    return '$percent% con éxito';
  }

  @override
  String get habitsDoneTodayLabel => 'Hecho hoy';

  @override
  String get habitSectionOptionsTitle => 'Opciones';

  @override
  String get habitSectionScheduleTitle => 'Programación';

  @override
  String get habitsFilterAll => 'todos';

  @override
  String get habitsFilterCompleted => 'hecho';

  @override
  String get habitsFilterOpenNow => 'vencido';

  @override
  String get habitsFilterPendingLater => 'más tarde';

  @override
  String get habitsGoalLineLabel => 'Meta';

  @override
  String get habitsHeatmapEmpty =>
      'Añade un hábito para empezar a construir tu constancia';

  @override
  String get habitsHeatmapLess => 'Menos';

  @override
  String get habitsHeatmapMore => 'Más';

  @override
  String get habitShowAlertAtLabel => 'Mostrar alerta a las';

  @override
  String get habitShowFromLabel => 'Mostrar desde';

  @override
  String habitsLaggardHint(String habit, int kept, int active) {
    return '$habit — $kept de $active cumplidos';
  }

  @override
  String get habitsOpenHeader => 'Vencido ahora';

  @override
  String get habitsPendingLaterHeader => 'Más tarde hoy';

  @override
  String habitsPointsToGoal(int points) {
    String _temp0 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: '$points pts para la meta',
      one: '1 pt para la meta',
    );
    return '$_temp0';
  }

  @override
  String get habitsRecordButton => 'Registrar';

  @override
  String get habitsRollingAverageLabel => 'promedio de 7 días';

  @override
  String get habitsStartStreakToday => 'Empieza una racha hoy';

  @override
  String habitsStreakLongCount(int count) {
    return '$count con racha de 7 días';
  }

  @override
  String habitsStreakShortCount(int count) {
    return '$count con racha de 3 días';
  }

  @override
  String get habitsTapForBreakdown => 'Toca un día para ver el desglose';

  @override
  String habitsToGoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'faltan $count',
      one: 'falta 1',
    );
    return '$_temp0';
  }

  @override
  String habitStreakDaysSemantic(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días seguidos',
      one: '1 día seguido',
    );
    return '$_temp0';
  }

  @override
  String get habitsVsPreviousWeek => 'vs. semana anterior';

  @override
  String get imageGenerationError => 'Error al generar imagen';

  @override
  String get imageGenerationGenerating => 'Generando imagen...';

  @override
  String get imageGenerationProviderRejectedTitle =>
      'El proveedor de imágenes rechazó esta solicitud';

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
  String get inactiveLabel => 'Inactivo';

  @override
  String get inactiveSwitchDescription =>
      'Se puede elegir para nuevas entradas cuando está activo';

  @override
  String get inferenceProfileCreateTitle => 'Crear perfil';

  @override
  String get inferenceProfileDescriptionLabel => 'Descripción';

  @override
  String get inferenceProfileDesktopOnly => 'Solo escritorio';

  @override
  String get inferenceProfileDesktopOnlyDescription =>
      'Solo disponible en plataformas de escritorio (p. ej. para modelos locales)';

  @override
  String inferenceProfileDetailLoadError(String error) {
    return 'No se pudo cargar el perfil: $error';
  }

  @override
  String get inferenceProfileDetailNotFound => 'Perfil no encontrado';

  @override
  String get inferenceProfileEditTitle => 'Editar perfil';

  @override
  String get inferenceProfileImageGeneration => 'Generación de imágenes';

  @override
  String get inferenceProfileImageRecognition => 'Reconocimiento de imágenes';

  @override
  String get inferenceProfileNameLabel => 'Nombre del perfil';

  @override
  String get inferenceProfileNameRequired => 'Se requiere un nombre de perfil';

  @override
  String get inferenceProfilePinnedHostHelper =>
      'Cuando está configurado, solo este dispositivo ejecuta automáticamente la inferencia para entradas de audio sincronizadas que usan este perfil.';

  @override
  String get inferenceProfilePinnedHostLabel => 'Dispositivo fijado';

  @override
  String get inferenceProfilePinnedHostNoEligibleNodes =>
      'Ningún dispositivo conocido anuncia los proveedores que este perfil usa. Abre la configuración de nodos de sincronización en el dispositivo destino.';

  @override
  String get inferenceProfilePinnedHostNoneHelper =>
      'Las entradas de audio sincronizadas no se transcriben automáticamente cuando ningún dispositivo está fijado.';

  @override
  String get inferenceProfilePinnedHostNoneLabel =>
      'Sin fijar (sin auto-disparador)';

  @override
  String get inferenceProfilePinnedHostThisDeviceSuffix =>
      ' (este dispositivo)';

  @override
  String get inferenceProfileSaveButton => 'Guardar';

  @override
  String get inferenceProfileSelectModel => 'Seleccionar un modelo…';

  @override
  String get inferenceProfileSelectProfile => 'Seleccionar un perfil…';

  @override
  String get inferenceProfilesEmpty => 'Aún no hay perfiles de inferencia';

  @override
  String inferenceProfileSkillModelRequired(String slotName) {
    return 'Requiere modelo de $slotName';
  }

  @override
  String get inferenceProfileSkillsSection => 'Habilidades automatizadas';

  @override
  String inferenceProfileSkillUsesModel(String slotName) {
    return 'Usa modelo de $slotName';
  }

  @override
  String get inferenceProfilesTitle => 'Perfiles de inferencia';

  @override
  String get inferenceProfileThinking => 'Pensamiento';

  @override
  String get inferenceProfileThinkingHighEnd => 'Pensamiento (alta gama)';

  @override
  String get inferenceProfileThinkingRequired =>
      'Se requiere un modelo de pensamiento';

  @override
  String get inferenceProfileTranscription => 'Transcripción';

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
  String get insightsChartCompareCaption => 'Este período vs. el anterior';

  @override
  String get insightsChartCompareCaptionPartial =>
      'Este período hasta ahora vs. el anterior';

  @override
  String get insightsChartCompareHint => 'Comparación en la tabla de abajo';

  @override
  String get insightsChartCumulativeCaption => 'Total acumulado en el rango';

  @override
  String get insightsChartCumulativeShort =>
      'Aún no hay días suficientes para un total acumulado';

  @override
  String get insightsChartDailyCaption => 'Tiempo por día';

  @override
  String get insightsChartHourlyCaption => 'Tiempo por hora';

  @override
  String get insightsChartPerDay => 'Por día';

  @override
  String get insightsChartPerHour => 'Por hora';

  @override
  String get insightsChartPerWeek => 'Por semana';

  @override
  String get insightsChartRunningTotal => 'Total acumulado';

  @override
  String get insightsChartTitle => 'Tiempo por categoría';

  @override
  String get insightsChartWeeklyCaption => 'Tiempo por semana';

  @override
  String get insightsChooseFocusCategories => 'Elegir categorías de foco';

  @override
  String get insightsCompare => 'Comparar';

  @override
  String get insightsCompareFullPeriod => 'período completo';

  @override
  String get insightsComparePrevious => 'Anterior';

  @override
  String get insightsCompareSameDays => 'mismos días';

  @override
  String get insightsCompareTooltip => 'Comparar con el período anterior';

  @override
  String get insightsCompareVs => 'vs';

  @override
  String get insightsDeletedCategory => 'Categoría eliminada';

  @override
  String get insightsDeltaNew => 'nuevo';

  @override
  String get insightsEmptyBody =>
      'El tiempo que registres en tus entradas y tareas aparecerá aquí.';

  @override
  String get insightsEmptyChart => 'Sin datos en este rango';

  @override
  String get insightsEmptyPreviousPeriod => 'Ver el período anterior';

  @override
  String get insightsEmptyShowYear => 'Ver este año';

  @override
  String get insightsEmptyTitle => 'No hay tiempo registrado en este rango';

  @override
  String get insightsFocusCategoriesEmpty => 'Aún no hay categorías activas.';

  @override
  String get insightsFocusCategoriesTitle => 'Categorías de foco';

  @override
  String get insightsKpiFocus => 'FOCO';

  @override
  String get insightsKpiFocusHelp => 'Categorías que sigues';

  @override
  String get insightsKpiOther => 'OTRO';

  @override
  String get insightsKpiOtherHelp => 'Todo lo demás';

  @override
  String insightsKpiTopCategory(String category, String share) {
    return 'Más en $category · $share';
  }

  @override
  String get insightsKpiTotal => 'TOTAL';

  @override
  String get insightsLoadError => 'No se pudieron cargar los datos de tiempo';

  @override
  String get insightsOtherCategories => 'Otros';

  @override
  String get insightsPartialWeek => 'semana parcial';

  @override
  String get insightsPeriodDay => 'Día';

  @override
  String get insightsPeriodJump => 'Saltar a una fecha';

  @override
  String get insightsPeriodMonth => 'Mes';

  @override
  String get insightsPeriodNext => 'Período siguiente';

  @override
  String get insightsPeriodPrevious => 'Período anterior';

  @override
  String get insightsPeriodQuarter => 'Trimestre';

  @override
  String get insightsPeriodToDateSuffix => 'hasta ahora';

  @override
  String get insightsPeriodWeek => 'Semana';

  @override
  String get insightsPeriodYear => 'Año';

  @override
  String get insightsRangeMonthToDate => 'Este mes hasta ahora';

  @override
  String get insightsRangeMtd => 'Este mes';

  @override
  String get insightsRangeYearToDate => 'Este año hasta ahora';

  @override
  String get insightsRangeYtd => 'Este año';

  @override
  String get insightsRefreshError =>
      'No se pudo actualizar — se muestran los últimos datos cargados';

  @override
  String get insightsTableAvgPerDay => 'MEDIA/DÍA';

  @override
  String get insightsTableCategory => 'CATEGORÍA';

  @override
  String get insightsTableCompareNote => 'Cambio frente al período anterior';

  @override
  String get insightsTableCurrent => 'ACTUAL';

  @override
  String get insightsTableDelta => 'Cambio';

  @override
  String get insightsTablePrevious => 'ANTERIOR';

  @override
  String get insightsTableShare => 'PORCENTAJE';

  @override
  String get insightsTableTotal => 'TOTAL';

  @override
  String get insightsTimeAnalysisTitle => 'Análisis de tiempo';

  @override
  String get insightsUncategorized => 'Sin categoría';

  @override
  String get journalCopyImageLabel => 'Copiar imagen';

  @override
  String get journalDateFromLabel => 'Fecha desde:';

  @override
  String get journalDateInvalid => 'Intervalo de fechas no válido';

  @override
  String get journalDateLabel => 'Fecha';

  @override
  String get journalDateNowButton => 'Ahora';

  @override
  String get journalDateSaveButton => 'GUARDAR';

  @override
  String get journalDateTimeRangeTitle => 'Fecha y hora';

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
  String get journalDurationLabel => 'Duración';

  @override
  String get journalEndDateLabel => 'Fecha de fin';

  @override
  String get journalEndsAnotherDayHint => 'Elige una fecha de fin distinta';

  @override
  String get journalEndsAnotherDayLabel => 'Termina otro día';

  @override
  String get journalEndTimeLabel => 'Hora de fin';

  @override
  String get journalFavoriteTooltip => 'solo destacados';

  @override
  String get journalFilterEntryTypesTitle => 'Tipos de entrada';

  @override
  String get journalFilterFlagged => 'Marcados';

  @override
  String get journalFilterPrivate => 'Privados';

  @override
  String get journalFilterShowTitle => 'Mostrar';

  @override
  String get journalFilterStarred => 'Destacados';

  @override
  String get journalFlaggedTooltip => 'solo marcados';

  @override
  String get journalHideLinkHint => 'Ocultar enlace';

  @override
  String get journalHideMapHint => 'Ocultar mapa';

  @override
  String get journalLinkedEntriesActivityFilterAudio => 'Audio';

  @override
  String get journalLinkedEntriesActivityFilterCode => 'Código';

  @override
  String get journalLinkedEntriesActivityFilterImages => 'Imágenes';

  @override
  String get journalLinkedEntriesActivityFilterTimer => 'Temporizador';

  @override
  String get journalLinkedEntriesFilterModalTitle => 'Filtrar y ordenar';

  @override
  String get journalLinkedEntriesShowFlaggedOnly =>
      'Mostrar solo entradas marcadas';

  @override
  String get journalLinkedEntriesShowHidden => 'Mostrar entradas ocultas';

  @override
  String get journalLinkedEntriesSortLabel => 'Ordenar por';

  @override
  String get journalLinkedEntriesSortNewestFirst => 'Más recientes primero';

  @override
  String get journalLinkedEntriesSortOldestFirst => 'Más antiguas primero';

  @override
  String get journalLinkedFromLabel => 'Vinculado de:';

  @override
  String get journalLinkFromHint => 'Vincular desde';

  @override
  String get journalLinkToHint => 'Vincular a';

  @override
  String journalOvernightNextDay(String date) {
    return 'Termina $date (día siguiente)';
  }

  @override
  String get journalPrivateTooltip => 'solo privado';

  @override
  String get journalSearchHint => 'Buscar en el diario...';

  @override
  String get journalShareHint => 'Compartir';

  @override
  String get journalShowLinkHint => 'Mostrar enlace';

  @override
  String get journalShowMapHint => 'Mostrar mapa';

  @override
  String get journalStartDateLabel => 'Fecha de inicio';

  @override
  String get journalStartTimeLabel => 'Hora de inicio';

  @override
  String get journalTodayButton => 'Hoy';

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
  String get knowledgeGraphEmpty => 'Aún no hay enlaces para explorar';

  @override
  String get knowledgeGraphTitle => 'Grafo de conocimiento';

  @override
  String get knowledgeGraphTooltip => 'Explorar enlaces';

  @override
  String get linkedFromCaption => 'desde';

  @override
  String get linkedTaskImageBadge => 'De tarea vinculada';

  @override
  String get linkedTasksMenuTooltip => 'Opciones de tareas vinculadas';

  @override
  String get linkedTasksTitle => 'Tareas vinculadas';

  @override
  String get linkedToCaption => 'a';

  @override
  String get linkExistingTask => 'Vincular tarea existente...';

  @override
  String get loggingDomainAgentRuntime => 'Runtime de agentes';

  @override
  String get loggingDomainAgentWorkflow => 'Flujo de agentes';

  @override
  String get loggingDomainAi => 'IA';

  @override
  String get loggingDomainCalendar => 'Calendario y tiempo';

  @override
  String get loggingDomainChat => 'Chat';

  @override
  String get loggingDomainDailyOs => 'Daily OS';

  @override
  String get loggingDomainDatabase => 'Base de datos';

  @override
  String get loggingDomainGeneral => 'General';

  @override
  String get loggingDomainHabits => 'Hábitos';

  @override
  String get loggingDomainHealth => 'Salud';

  @override
  String get loggingDomainLabels => 'Etiquetas';

  @override
  String get loggingDomainLocation => 'Ubicación';

  @override
  String get loggingDomainNavigation => 'Navegación';

  @override
  String get loggingDomainNotifications => 'Notificaciones';

  @override
  String get loggingDomainPersistence => 'Persistencia';

  @override
  String get loggingDomainRatings => 'Valoraciones';

  @override
  String get loggingDomainScreenshots => 'Capturas de pantalla';

  @override
  String get loggingDomainSettings => 'Ajustes';

  @override
  String get loggingDomainSpeech => 'Voz y audio';

  @override
  String get loggingDomainSync => 'Sincronización';

  @override
  String get loggingDomainTasks => 'Tareas y listas';

  @override
  String get loggingDomainTheming => 'Temas';

  @override
  String get loggingDomainWhatsNew => 'Novedades';

  @override
  String get maintenanceDeleteAgentDb => 'Eliminar la base de datos de agentes';

  @override
  String get maintenanceDeleteAgentDbDescription =>
      'Eliminar la base de datos de agentes y reiniciar la app';

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
  String get maintenanceDeleteSyncDb =>
      'Eliminar la base de datos de sincronización';

  @override
  String get maintenanceDeleteSyncDbDescription =>
      'Eliminar base de datos de sincronización';

  @override
  String get maintenanceGenerateEmbeddings => 'Generar embeddings';

  @override
  String get maintenanceGenerateEmbeddingsConfirm => 'SÍ, GENERAR';

  @override
  String get maintenanceGenerateEmbeddingsDescription =>
      'Generar embeddings para las entradas de las categorías seleccionadas';

  @override
  String get maintenanceGenerateEmbeddingsMessage =>
      'Selecciona categorías para generar embeddings.';

  @override
  String maintenanceGenerateEmbeddingsProgress(
    int processed,
    int total,
    int embedded,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      embedded,
      locale: localeName,
      other: '$embedded incrustadas',
      one: '1 incrustada',
    );
    String _temp1 = intl.Intl.pluralLogic(
      embedded,
      locale: localeName,
      other: '$embedded incrustadas',
      one: '1 incrustada',
    );
    String _temp2 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$processed / $total entradas ($_temp0)',
      one: '$processed / $total entrada ($_temp1)',
    );
    return '$_temp2';
  }

  @override
  String get maintenancePopulatePhaseAgentEntities =>
      'Procesando entidades de agentes...';

  @override
  String get maintenancePopulatePhaseAgentLinks =>
      'Procesando enlaces de agentes...';

  @override
  String get maintenancePopulatePhaseJournal =>
      'Procesando entradas del diario...';

  @override
  String get maintenancePopulatePhaseLinks =>
      'Procesando enlaces de entradas...';

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
  String get maintenancePurgeSentOutbox =>
      'Purgar elementos enviados antiguos de la bandeja de salida';

  @override
  String get maintenancePurgeSentOutboxConfirm => 'SÍ, PURGAR';

  @override
  String get maintenancePurgeSentOutboxDescription =>
      'Eliminar filas de la bandeja de salida enviadas hace más de 7 días y liberar disco';

  @override
  String get maintenancePurgeSentOutboxQuestion =>
      '¿Purgar elementos de la bandeja de salida enviados hace más de 7 días? Esto elimina las filas ya enviadas por bloques y ejecuta VACUUM para liberar disco. Los elementos pendientes y con error se conservan.';

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
  String get maintenanceReSyncAgentEntities => 'Entidades de agente';

  @override
  String get maintenanceReSyncDescription =>
      'Resincronizar mensajes desde el servidor';

  @override
  String get maintenanceReSyncEntityTypes => 'Tipos de entidad';

  @override
  String get maintenanceReSyncJournalEntities => 'Entradas del diario';

  @override
  String get maintenanceReSyncSelectAtLeastOne =>
      'Selecciona al menos un tipo de entidad';

  @override
  String get maintenanceReSyncStart => 'Iniciar';

  @override
  String get maintenanceSyncDefinitions =>
      'Sincronizar medibles, paneles, hábitos, categorías, ajustes AI';

  @override
  String get maintenanceSyncDefinitionsDescription =>
      'Sincronizar medibles, paneles, hábitos, categorías y ajustes AI';

  @override
  String get manageLinks => 'Gestionar vínculos...';

  @override
  String get measurableDeleteConfirm => 'SÍ, ELIMINAR ESTE MEDIBLE';

  @override
  String get measurableDeleteQuestion =>
      '¿Quieres eliminar este tipo de datos medibles?';

  @override
  String get measurableNotFound => 'Medible no encontrado';

  @override
  String get measurementCommentHint => 'Añade una nota (opcional)';

  @override
  String get measurementQuickAddLabel => 'Añadir rápido';

  @override
  String get mediaShowInFileExplorerAction =>
      'Mostrar en el Explorador de archivos';

  @override
  String get mediaShowInFilesAction => 'Mostrar en Archivos';

  @override
  String get mediaShowInFinderAction => 'Mostrar en Finder';

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
  String get modelEditBackTooltip => 'Atrás';

  @override
  String get modelEditDescriptionHint => 'Describe este modelo';

  @override
  String get modelEditDescriptionLabel => 'Descripción';

  @override
  String get modelEditDisplayNameHint => 'Un nombre amigable para este modelo';

  @override
  String get modelEditDisplayNameLabel => 'Nombre visible';

  @override
  String get modelEditFunctionCallingDescription =>
      'Este modelo admite llamadas a funciones y herramientas.';

  @override
  String get modelEditFunctionCallingLabel => 'Llamadas a funciones';

  @override
  String get modelEditGeminiThinkingModeLabel =>
      'Modo de pensamiento de Gemini';

  @override
  String get modelEditInputModalitiesHint => 'Selecciona los tipos de entrada';

  @override
  String get modelEditInputModalitiesLabel => 'Modalidades de entrada';

  @override
  String get modelEditLoadError =>
      'Error al cargar la configuración del modelo';

  @override
  String get modelEditMaxTokensHint => 'Opcional — déjalo vacío para ilimitado';

  @override
  String get modelEditMaxTokensLabel => 'Tokens máximos de compleción';

  @override
  String get modelEditModalityNoneSelected => 'Ninguno seleccionado';

  @override
  String get modelEditOutputModalitiesHint => 'Selecciona los tipos de salida';

  @override
  String get modelEditOutputModalitiesLabel => 'Modalidades de salida';

  @override
  String get modelEditPageTitle => 'Editar modelo';

  @override
  String get modelEditProviderHint => 'Selecciona un proveedor';

  @override
  String get modelEditProviderLabel => 'Proveedor';

  @override
  String get modelEditProviderModelIdHint => 'p. ej. gpt-4-turbo';

  @override
  String get modelEditProviderModelIdLabel => 'ID de modelo del proveedor';

  @override
  String get modelEditReasoningDescription =>
      'Este modelo usa pensamiento extendido / cadena de razonamiento.';

  @override
  String get modelEditReasoningLabel => 'Modelo de razonamiento';

  @override
  String get modelEditSaveButton => 'Guardar';

  @override
  String get modelEditSectionCapabilities => 'Capacidades';

  @override
  String get modelEditSectionIdentity => 'Identidad';

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
  String get multiSelectAddButton => 'Añadir';

  @override
  String multiSelectAddButtonWithCount(int count) {
    return 'Añadir ($count)';
  }

  @override
  String get multiSelectNoItemsFound => 'No se encontraron elementos';

  @override
  String navTabMoreSemanticsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Más, $count destinos adicionales',
      one: 'Más, 1 destino adicional',
    );
    return '$_temp0';
  }

  @override
  String get navTabTitleCalendar => 'DailyOS';

  @override
  String get navTabTitleHabits => 'Hábitos';

  @override
  String get navTabTitleInsights => 'Paneles';

  @override
  String get navTabTitleJournal => 'Diario';

  @override
  String get navTabTitleMore => 'Más';

  @override
  String get navTabTitleProjects => 'Proyectos';

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
  String get noTasksFound => 'No se encontraron tareas';

  @override
  String get noTasksToLink => 'No hay tareas disponibles para vincular';

  @override
  String get notificationBellEmptySemantics =>
      'Notificaciones, sin alertas sin leer';

  @override
  String get notificationBellTooltip => 'Notificaciones';

  @override
  String notificationBellUnseenSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'alertas sin leer',
      one: 'alerta sin leer',
    );
    return 'Notificaciones, $count $_temp0';
  }

  @override
  String get notificationInboxDismiss => 'Descartar notificación';

  @override
  String get notificationInboxEmpty => 'Estás al día.';

  @override
  String get notificationInboxError =>
      'No se pudieron cargar las notificaciones.';

  @override
  String get notificationInboxTitle => 'Notificaciones';

  @override
  String get notificationSuggestionAttentionBodyFallback =>
      'Abre la tarea para revisarla.';

  @override
  String notificationSuggestionAttentionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sugerencias necesitan tu atención',
      one: '1 sugerencia necesita tu atención',
    );
    return '$_temp0';
  }

  @override
  String get optionalCategoryLabel => 'Categoría (opcional)';

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
  String get outboxMonitorFetchFailed =>
      'No se pudo cargar la bandeja de salida. Tira hacia abajo para actualizar e inténtalo de nuevo.';

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
  String get outboxMonitorVolumeChartTitle =>
      'Volumen de sincronización diario';

  @override
  String get privateLabel => 'Privado';

  @override
  String get privateSwitchDescription =>
      'Solo visible cuando se muestran las entradas privadas';

  @override
  String get projectAgentNotProvisioned =>
      'Todavía no se ha configurado un agente de proyecto para este proyecto.';

  @override
  String get projectAgentSectionTitle => 'Agente';

  @override
  String projectCountSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count proyectos',
      one: '$count proyecto',
    );
    return '$_temp0';
  }

  @override
  String get projectCreateButton => 'Nuevo proyecto';

  @override
  String get projectCreateTitle => 'Crear proyecto';

  @override
  String get projectDetailTitle => 'Detalles del proyecto';

  @override
  String get projectErrorCreateFailed => 'Error al crear el proyecto.';

  @override
  String get projectErrorLoadFailed =>
      'No se pudieron cargar los datos del proyecto.';

  @override
  String get projectErrorLoadProjects => 'Error al cargar los proyectos';

  @override
  String get projectErrorUpdateFailed =>
      'No se pudo actualizar el proyecto. Inténtalo de nuevo.';

  @override
  String get projectFilterLabel => 'Proyecto';

  @override
  String get projectHealthBandAtRisk => 'En riesgo';

  @override
  String get projectHealthBandBlocked => 'Bloqueado';

  @override
  String get projectHealthBandOnTrack => 'En marcha';

  @override
  String get projectHealthBandSurviving => 'A flote';

  @override
  String get projectHealthBandWatch => 'Vigilar';

  @override
  String get projectHealthSectionTitle => 'Salud del proyecto';

  @override
  String projectHealthSummary(int projectCount, int taskCount) {
    String _temp0 = intl.Intl.pluralLogic(
      projectCount,
      locale: localeName,
      other: '$projectCount proyectos',
      one: '$projectCount proyecto',
    );
    String _temp1 = intl.Intl.pluralLogic(
      taskCount,
      locale: localeName,
      other: '$taskCount tareas',
      one: '$taskCount tarea',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get projectHealthTitle => 'Proyectos';

  @override
  String projectLinkedTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tareas vinculadas',
      one: '$count tarea vinculada',
    );
    return '$_temp0';
  }

  @override
  String get projectLinkedTasks => 'Tareas vinculadas';

  @override
  String get projectManageTooltip => 'Gestionar proyectos';

  @override
  String get projectNoLinkedTasks => 'Aún no hay tareas vinculadas';

  @override
  String get projectNoProjects => 'Aún no hay proyectos';

  @override
  String get projectNotFound => 'Proyecto no encontrado';

  @override
  String get projectPickerLabel => 'Proyecto';

  @override
  String get projectPickerUnassigned => 'Sin proyecto';

  @override
  String get projectRecommendationDismissTooltip => 'Descartar';

  @override
  String get projectRecommendationResolveTooltip => 'Marcar como resuelto';

  @override
  String get projectRecommendationsTitle => 'Siguientes pasos recomendados';

  @override
  String get projectRecommendationUpdateError =>
      'No se pudo actualizar la recomendación. Inténtalo de nuevo.';

  @override
  String get projectsFilterStatusLabel => 'Estado:';

  @override
  String get projectsFilterTooltip => 'Filtrar proyectos';

  @override
  String get projectShowcaseAiReportTitle => 'Informe de IA';

  @override
  String projectShowcaseBlockedLegend(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bloqueadas',
      one: '$count bloqueada',
    );
    return '$_temp0';
  }

  @override
  String projectShowcaseBlockedTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tareas bloqueadas',
      one: '$count tarea bloqueada',
    );
    return '$_temp0';
  }

  @override
  String projectShowcaseCompletedLegend(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count completadas',
      one: '$count completada',
    );
    return '$_temp0';
  }

  @override
  String get projectShowcaseDescriptionTitle => 'Descripción';

  @override
  String projectShowcaseDueDate(String date) {
    return 'Vence $date';
  }

  @override
  String get projectShowcaseHealthScoreDescription =>
      'Esta puntuación se basa en la velocidad de las tareas, los bloqueos y el tiempo que queda hasta la fecha límite.';

  @override
  String get projectShowcaseHealthScoreTitle => 'Puntuación de salud';

  @override
  String get projectShowcaseNoResults =>
      'Ningún proyecto coincide con tu búsqueda.';

  @override
  String get projectShowcaseOneOnOneReviewsTab => 'Revisiones 1:1';

  @override
  String get projectShowcaseOngoing => 'En curso';

  @override
  String get projectShowcaseProjectTasksTab => 'Tareas del proyecto';

  @override
  String get projectShowcaseSearchHint => 'Buscar proyectos';

  @override
  String projectShowcaseSessionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sesiones',
      one: '$count sesión',
    );
    return '$_temp0';
  }

  @override
  String projectShowcaseTasksCompleted(int completed, int total) {
    return '$completed/$total tareas completadas';
  }

  @override
  String projectShowcaseUpdatedHoursAgo(int hours) {
    return 'Actualizado hace $hours h ↻';
  }

  @override
  String projectShowcaseUpdatedMinutesAgo(int minutes) {
    return 'Actualizado hace $minutes min ↻';
  }

  @override
  String get projectShowcaseUsefulness => 'Utilidad';

  @override
  String get projectShowcaseViewBlocker => 'Ver bloqueo';

  @override
  String get projectStatusActive => 'Activo';

  @override
  String get projectStatusArchived => 'Archivado';

  @override
  String get projectStatusChangeTitle => 'Cambiar estado';

  @override
  String get projectStatusCompleted => 'Completado';

  @override
  String get projectStatusMonitoring => 'En observación';

  @override
  String get projectStatusOnHold => 'En pausa';

  @override
  String get projectStatusOpen => 'Abierto';

  @override
  String get projectSummaryOutdated => 'El resumen está desactualizado.';

  @override
  String projectSummaryOutdatedScheduled(String date, String time) {
    return 'El resumen está desactualizado. La próxima actualización será el $date a las $time.';
  }

  @override
  String get projectTargetDateLabel => 'Fecha objetivo';

  @override
  String get projectTitleLabel => 'Título del proyecto';

  @override
  String get projectTitleRequired =>
      'El título del proyecto no puede estar vacío';

  @override
  String get promptDefaultModelBadge => 'Predeterminado';

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
  String get promptSelectionModalTitle => 'Seleccionar prompt preconfigurado';

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
  String get queueCatchUpNowButton => 'Sincronizar ahora';

  @override
  String get queueCatchUpNowDone =>
      'Puesta al día iniciada — la cola se está vaciando.';

  @override
  String queueCatchUpNowError(String reason) {
    return 'Puesta al día fallida: $reason';
  }

  @override
  String get queueDepthCardEmpty => 'Cola vacía — el procesador está al día.';

  @override
  String get queueDepthCardLoading => 'Leyendo profundidad de la cola…';

  @override
  String get queueDepthCardTitle => 'Cola de entrada';

  @override
  String get queueFetchAllHistoryCancel => 'Cancelar';

  @override
  String queueFetchAllHistoryCancelled(int events) {
    String _temp0 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: '$events eventos obtenidos',
      one: '1 evento obtenido',
      zero: 'ningún evento obtenido',
    );
    return 'Cancelado — $_temp0 hasta ahora.';
  }

  @override
  String get queueFetchAllHistoryClose => 'Cerrar';

  @override
  String get queueFetchAllHistoryDescription =>
      'Recorre todo el historial visible de la sala hacia la cola. Puedes cancelarlo en cualquier momento; una nueva ejecución retoma donde se detuvo la paginación.';

  @override
  String queueFetchAllHistoryDone(int events, int pages) {
    String _temp0 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages páginas',
      one: '1 página',
    );
    String _temp1 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages páginas',
      one: '1 página',
    );
    String _temp2 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: '$events eventos obtenidos en $_temp0.',
      one: '1 evento obtenido en $_temp1.',
      zero: 'Ningún evento obtenido.',
    );
    return '$_temp2';
  }

  @override
  String queueFetchAllHistoryError(String reason) {
    return 'Obtención detenida: $reason';
  }

  @override
  String get queueFetchAllHistoryErrorUnknown =>
      'La obtención se detuvo inesperadamente.';

  @override
  String queueFetchAllHistoryProgress(int events, int pages) {
    String _temp0 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: 'Página $pages  ·  $events eventos obtenidos',
      one: 'Página $pages  ·  1 evento obtenido',
    );
    return '$_temp0';
  }

  @override
  String get queueFetchAllHistoryTitle => 'Obteniendo historial';

  @override
  String queueSkippedBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count omitidos',
      one: '1 omitido',
    );
    return '$_temp0';
  }

  @override
  String queueSkippedCardBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count eventos de sincronización que la cola descartó. Toca reintentar para volver a intentarlo.',
      one:
          '1 evento de sincronización que la cola descartó. Toca reintentar para volver a intentarlo.',
    );
    return '$_temp0';
  }

  @override
  String get queueSkippedCardTitle => 'Eventos omitidos';

  @override
  String get queueSkippedRetryAll => 'Reintentar eventos omitidos';

  @override
  String queueSkippedRetryAllDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eventos en cola para reintento.',
      one: '1 evento en cola para reintento.',
      zero: 'No hay eventos omitidos.',
    );
    return '$_temp0';
  }

  @override
  String queueSkippedRetryAllError(String reason) {
    return 'Reintento fallido: $reason';
  }

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
      'Elige hasta 5 imágenes para guiar el estilo visual de la IA';

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
  String get saveShortcutTooltip => 'Guardar — Ctrl+S (⌘S en Mac)';

  @override
  String get saveSuccessful => 'Guardado correctamente';

  @override
  String get searchHint => 'Buscar...';

  @override
  String get searchModeFullText => 'Texto completo';

  @override
  String get searchModeVector => 'Vector';

  @override
  String get searchTasksHint => 'Buscar tareas...';

  @override
  String get selectButton => 'Seleccionar';

  @override
  String get selectColor => 'Elegir un color';

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
  String get settingsAboutDailyOsPersonalizationTitle =>
      'Personalización de Daily OS';

  @override
  String get settingsAboutDailyOsUserNameHelper =>
      'Se usa solo para el saludo de Daily OS en este dispositivo.';

  @override
  String get settingsAboutDailyOsUserNameLabel => 'Tu nombre';

  @override
  String get settingsAboutJournalEntries => 'Entradas del diario';

  @override
  String get settingsAboutPlatform => 'Plataforma';

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
  String get settingsAdvancedHealthImportSubtitle =>
      'Importar datos relacionados con la salud desde fuentes externas';

  @override
  String get settingsAdvancedMaintenanceSubtitle =>
      'Realizar tareas de mantenimiento para optimizar el rendimiento de la aplicación';

  @override
  String get settingsAdvancedOutboxSubtitle =>
      'Ver y gestionar elementos esperando ser sincronizados';

  @override
  String get settingsAdvancedSubtitle =>
      'Configuración avanzada y mantenimiento';

  @override
  String get settingsAdvancedTitle => 'Configuración avanzada';

  @override
  String get settingsAgentsInstancesSubtitle => 'Agentes en ejecución';

  @override
  String get settingsAgentsPendingWakesSubtitle =>
      'Temporizadores de despertar programados';

  @override
  String get settingsAgentsSoulsSubtitle =>
      'Personalidades duraderas de agentes';

  @override
  String get settingsAgentsStatsSubtitle => 'Uso de tokens y actividad';

  @override
  String get settingsAgentsTemplatesSubtitle =>
      'Plantillas de agentes compartidas';

  @override
  String get settingsAiModelsSubtitle =>
      'Filas de modelos y capacidades por proveedor';

  @override
  String get settingsAiModelsTitle => 'Modelos';

  @override
  String get settingsAiProfilesSubtitle => 'Proveedores y modelos';

  @override
  String get settingsAiProfilesTitle => 'Perfiles de inferencia';

  @override
  String get settingsAiProvidersSubtitle =>
      'Proveedores de IA conectados y claves';

  @override
  String get settingsAiProvidersTitle => 'Proveedores';

  @override
  String get settingsAiSubtitle =>
      'Configurar proveedores de AI, modelos y prompts';

  @override
  String get settingsAiTitle => 'Configuración de AI';

  @override
  String get settingsBeamPageEditModelTitle => 'Editar modelo';

  @override
  String get settingsBeamPageEditProfileTitle => 'Editar perfil';

  @override
  String get settingsCategoriesCreateTitle => 'Crear categoría';

  @override
  String get settingsCategoriesDetailsLabel => 'Editar categoría';

  @override
  String get settingsCategoriesEmptyState => 'Aún no hay categorías';

  @override
  String get settingsCategoriesEmptyStateHint =>
      'Crea una categoría para organizar tus entradas';

  @override
  String get settingsCategoriesErrorLoading => 'Error al cargar categorías';

  @override
  String get settingsCategoriesNameLabel => 'Nombre de la categoría';

  @override
  String settingsCategoriesNoMatchQuery(String query) {
    return 'Ninguna categoría coincide con \"$query\"';
  }

  @override
  String get settingsCategoriesSearchHint => 'Buscar categorías…';

  @override
  String get settingsCategoriesSubtitle => 'Categorías con configuración de AI';

  @override
  String settingsCategoriesTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tareas',
      one: '$count tarea',
    );
    return '$_temp0';
  }

  @override
  String get settingsCategoriesTitle => 'Categorías';

  @override
  String get settingsConflictsTitle => 'Conflictos de Sincronización';

  @override
  String get settingsDashboardDetailsLabel => 'Editar panel';

  @override
  String get settingsDashboardSaveLabel => 'Guardar';

  @override
  String get settingsDashboardsCreateTitle => 'Crear panel';

  @override
  String get settingsDashboardsEmptyState => 'Aún no hay paneles';

  @override
  String get settingsDashboardsEmptyStateHint =>
      'Toca el botón + para crear tu primer panel.';

  @override
  String get settingsDashboardsErrorLoading => 'Error al cargar paneles';

  @override
  String settingsDashboardsNoMatchQuery(String query) {
    return 'Ningún panel coincide con \"$query\"';
  }

  @override
  String get settingsDashboardsSearchHint => 'Buscar paneles…';

  @override
  String get settingsDashboardsSubtitle => 'Personaliza tus vistas del panel';

  @override
  String get settingsDashboardsTitle => 'Paneles';

  @override
  String get settingsDefinitionsSubtitle =>
      'Hábitos, categorías, etiquetas, paneles y medibles';

  @override
  String get settingsDefinitionsTitle => 'Definiciones';

  @override
  String get settingsFlagsEmptySearch =>
      'Ningún indicador coincide con tu búsqueda';

  @override
  String get settingsFlagsSearchHint => 'Buscar indicadores';

  @override
  String get settingsFlagsSubtitle => 'Configurar indicadores y opciones';

  @override
  String get settingsFlagsTitle => 'Configuración de indicadores';

  @override
  String get settingsHabitsCreateTitle => 'Crear hábito';

  @override
  String get settingsHabitsDeleteTooltip => 'Eliminar hábito';

  @override
  String get settingsHabitsDescriptionLabel => 'Descripción (opcional)';

  @override
  String get settingsHabitsDetailsLabel => 'Editar hábito';

  @override
  String get settingsHabitsEmptyState => 'Aún no hay hábitos';

  @override
  String get settingsHabitsEmptyStateHint =>
      'Toca el botón + para crear tu primer hábito.';

  @override
  String get settingsHabitsErrorLoading => 'Error al cargar hábitos';

  @override
  String get settingsHabitsNameLabel => 'Nombre del hábito';

  @override
  String settingsHabitsNoMatchQuery(String query) {
    return 'Ningún hábito coincide con \"$query\"';
  }

  @override
  String get settingsHabitsPrivateLabel => 'Privado:';

  @override
  String get settingsHabitsSaveLabel => 'Guardar';

  @override
  String get settingsHabitsSearchHint => 'Buscar hábitos…';

  @override
  String get settingsHabitsSubtitle => 'Gestionar tus hábitos y rutinas';

  @override
  String get settingsHabitsTitle => 'Hábitos';

  @override
  String get settingsHealthImportActivity => 'Importar datos de actividad';

  @override
  String get settingsHealthImportBloodPressure =>
      'Importar datos de presión arterial';

  @override
  String get settingsHealthImportBodyMeasurement =>
      'Importar datos de medidas corporales';

  @override
  String get settingsHealthImportFromDate => 'Inicio';

  @override
  String get settingsHealthImportHeartRate =>
      'Importar datos de frecuencia cardíaca';

  @override
  String get settingsHealthImportSleep => 'Importar datos de sueño';

  @override
  String get settingsHealthImportTitle => 'Importación de salud';

  @override
  String get settingsHealthImportToDate => 'Fin';

  @override
  String get settingsHealthImportWorkout => 'Importar datos de entrenamiento';

  @override
  String get settingsLabelsCategoriesAdd => 'Añadir categoría';

  @override
  String get settingsLabelsCategoriesHeading => 'Categorías aplicables';

  @override
  String get settingsLabelsCategoriesNone => 'Se aplica a todas las categorías';

  @override
  String get settingsLabelsCategoriesRemoveTooltip => 'Eliminar';

  @override
  String get settingsLabelsColorHeading => 'Color';

  @override
  String get settingsLabelsColorSubheading => 'Preajustes rápidos';

  @override
  String get settingsLabelsCreateTitle => 'Crear etiqueta';

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
  String settingsLabelsNoMatchCreate(String query) {
    return 'Crear etiqueta \"$query\"';
  }

  @override
  String settingsLabelsNoMatchQuery(String query) {
    return 'Ninguna etiqueta coincide con \"$query\"';
  }

  @override
  String get settingsLabelsPrivateDescription =>
      'Solo visible cuando se muestran las entradas privadas';

  @override
  String get settingsLabelsPrivateTitle => 'Privado';

  @override
  String get settingsLabelsSearchHint => 'Buscar etiquetas…';

  @override
  String get settingsLabelsSubtitle =>
      'Organizar tareas con etiquetas de colores';

  @override
  String get settingsLabelsTitle => 'Etiquetas';

  @override
  String settingsLabelsUsageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tareas',
      one: '1 tarea',
    );
    return '$_temp0';
  }

  @override
  String get settingsLoggingDomainsSubtitle =>
      'Controla qué dominios escriben en el registro';

  @override
  String get settingsLoggingDomainsTitle => 'Dominios de registro';

  @override
  String get settingsLoggingGlobalToggle => 'Activar registro';

  @override
  String get settingsLoggingGlobalToggleSubtitle =>
      'Interruptor principal para todo el registro';

  @override
  String get settingsLoggingSlowQueries => 'Consultas lentas de base de datos';

  @override
  String get settingsLoggingSlowQueriesSubtitle =>
      'Las consultas lentas se escriben en slow_queries-YYYY-MM-DD.log';

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
  String get settingsMatrixContinueVerificationLabel =>
      'Aceptar en el otro dispositivo para continuar';

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
  String get settingsMatrixLastUpdated => 'Última actualización:';

  @override
  String get settingsMatrixListUnverifiedLabel => 'Dispositivos no verificados';

  @override
  String get settingsMatrixMaintenanceSubtitle =>
      'Ejecutar tareas de mantenimiento y herramientas de recuperación de Matrix';

  @override
  String get settingsMatrixMaintenanceTitle => 'Mantenimiento';

  @override
  String get settingsMatrixMetrics => 'Métricas de sincronización';

  @override
  String get settingsMatrixNextPage => 'Página siguiente';

  @override
  String get settingsMatrixNoUnverifiedLabel =>
      'No hay dispositivos sin verificar';

  @override
  String get settingsMatrixPreviousPage => 'Página anterior';

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
  String get settingsMatrixTitle => 'Ajustes de sincronización de Matrix';

  @override
  String get settingsMatrixUnverifiedDevicesPage =>
      'Dispositivos no verificados';

  @override
  String get settingsMatrixVerificationCancelledLabel =>
      'Cancelado en el otro dispositivo...';

  @override
  String get settingsMatrixVerificationSuccessConfirm => 'Entendido';

  @override
  String settingsMatrixVerificationSuccessLabel(
    String deviceName,
    String deviceID,
  ) {
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
  String get settingsMeasurableAggregationHelper =>
      'Cómo se combinan las entradas de un día en los gráficos';

  @override
  String get settingsMeasurableAggregationLabel => 'Agregación predeterminada';

  @override
  String get settingsMeasurableDeleteTooltip => 'Eliminar tipo de medición';

  @override
  String get settingsMeasurableDescriptionLabel => 'Descripción (opcional)';

  @override
  String get settingsMeasurableDetailsLabel => 'Editar medible';

  @override
  String get settingsMeasurableNameLabel => 'Nombre de la medición';

  @override
  String get settingsMeasurablePrivateLabel => 'Privado: ';

  @override
  String get settingsMeasurableSaveLabel => 'Guardar';

  @override
  String get settingsMeasurablesCreateTitle => 'Crear medible';

  @override
  String get settingsMeasurablesEmptyState => 'Aún no hay medibles';

  @override
  String get settingsMeasurablesEmptyStateHint =>
      'Los medibles son números que sigues a lo largo del tiempo: peso, agua, pasos.';

  @override
  String get settingsMeasurablesErrorLoading => 'Error al cargar medibles';

  @override
  String settingsMeasurablesNoMatchQuery(String query) {
    return 'Ningún medible coincide con \"$query\"';
  }

  @override
  String get settingsMeasurablesSearchHint => 'Buscar medibles…';

  @override
  String get settingsMeasurablesSubtitle =>
      'Configurar tipos de datos medibles';

  @override
  String get settingsMeasurablesTitle => 'Medibles';

  @override
  String get settingsMeasurableUnitLabel =>
      'Abreviatura de la unidad (opcional)';

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
  String get settingsSpeechSubtitle => 'Voz y lectura en voz alta';

  @override
  String get settingsSpeechTitle => 'Habla';

  @override
  String get settingsSyncConflictsSubtitle =>
      'Resolver conflictos de sincronización para asegurar consistencia de datos';

  @override
  String get settingsSyncNodeProfileCapabilitiesEmpty =>
      'Ninguna detectada — el auto-disparador de inferencia de audio sincronizado no apuntará a este dispositivo.';

  @override
  String get settingsSyncNodeProfileCapabilitiesLabel =>
      'Capacidades de IA detectadas';

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
      'Visible para tus otros dispositivos al elegir a cuál fijar un perfil.';

  @override
  String get settingsSyncNodeProfileDisplayNameLabel =>
      'Nombre del dispositivo';

  @override
  String get settingsSyncNodeProfileKnownNodesEmpty =>
      'Ningún otro dispositivo ha publicado aún un perfil.';

  @override
  String get settingsSyncNodeProfileKnownNodesTitle =>
      'Dispositivos de sincronización conocidos';

  @override
  String get settingsSyncNodeProfileSaveButton => 'Guardar';

  @override
  String get settingsSyncNodeProfileSubtitle =>
      'Nombra este dispositivo y revisa las capacidades visibles para tus otros dispositivos.';

  @override
  String get settingsSyncNodeProfileTitle => 'Este dispositivo';

  @override
  String get settingsSyncOutboxTitle => 'Bandeja de salida de sincronización';

  @override
  String get settingsSyncStatsSubtitle =>
      'Inspeccionar métricas del canal de sincronización';

  @override
  String get settingsSyncSubtitle =>
      'Configurar sincronización y ver estadísticas';

  @override
  String get settingsThemingAutomatic => 'Automático';

  @override
  String get settingsThemingDark => 'Apariencia oscura';

  @override
  String get settingsThemingLight => 'Apariencia clara';

  @override
  String get settingsThemingSubtitle =>
      'Personalizar la apariencia y los temas';

  @override
  String get settingsThemingTitle => 'Temas';

  @override
  String get settingsV2CategoryEmptyBody =>
      'Elige un sub-ajuste a la izquierda.';

  @override
  String get settingsV2DetailRootCrumb => 'Ajustes';

  @override
  String get settingsV2EmptyStateBody =>
      'Elige una sección a la izquierda para empezar.';

  @override
  String get settingsV2ResizeHandleLabel => 'Redimensionar árbol de ajustes';

  @override
  String get settingsV2UnimplementedTitle => 'Panel aún no disponible';

  @override
  String get settingsWhatsNewSubtitle =>
      'Mira las últimas actualizaciones y funciones';

  @override
  String get settingsWhatsNewTitle => 'Novedades';

  @override
  String get settingThemingDark => 'Tema oscuro';

  @override
  String get settingThemingLight => 'Tema claro';

  @override
  String get sidebarRunningTimerLabel => 'Temporizador en curso';

  @override
  String get sidebarRunningTimerStopTooltip => 'Detener temporizador';

  @override
  String get sidebarToggleCollapseLabel => 'Contraer barra lateral';

  @override
  String get sidebarToggleExpandLabel => 'Expandir barra lateral';

  @override
  String get sidebarWakesCancelTooltip => 'Cancelar despertar';

  @override
  String get sidebarWakesHeader => 'Despertares';

  @override
  String get sidebarWakesNow => 'ahora';

  @override
  String get sidebarWakesOpenList => 'Abrir lista';

  @override
  String get skillsSectionTitle => 'Habilidades';

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
  String get speechModalSelectLanguage => 'Seleccionar idioma';

  @override
  String get speechModalTitle => 'Reconocimiento de voz';

  @override
  String get speechSettingsModelDescription =>
      'Modelo de voz en el dispositivo';

  @override
  String get speechSettingsModelDownloadsOnce => 'Se descarga una vez';

  @override
  String get speechSettingsModelLabel => 'Modelo';

  @override
  String get speechSettingsRecommendedBadge => 'Recomendado';

  @override
  String get speechSettingsSpeedDescription =>
      'Con qué rapidez se leen los resúmenes';

  @override
  String get speechSettingsSpeedLabel => 'Velocidad de lectura';

  @override
  String get speechSettingsVoiceDescription =>
      'Elige la voz que lee los resúmenes en voz alta';

  @override
  String get speechSettingsVoiceLabel => 'Voz';

  @override
  String get speechVoiceGenderFemale => 'Femenina';

  @override
  String get speechVoiceGenderMale => 'Masculina';

  @override
  String get speechVoicePreviewTooltip => 'Escuchar la voz';

  @override
  String syncActivityIndicatorSemantics(int outbox, int inbox) {
    return 'Actividad de sincronización. Bandeja de salida: $outbox. Bandeja de entrada: $inbox. Abrir bandeja de salida de sincronización.';
  }

  @override
  String get syncDeleteConfigConfirm => 'SÍ, ESTOY SEGURO';

  @override
  String get syncDeleteConfigQuestion =>
      '¿Quieres eliminar la configuración de sincronización?';

  @override
  String get syncEntitiesConfirm => 'INICIAR SINCRONIZACIÓN';

  @override
  String get syncEntitiesMessage => 'Elige los datos que quieres sincronizar.';

  @override
  String get syncEntitiesSuccessDescription => 'Todo está al día.';

  @override
  String get syncEntitiesSuccessTitle => 'Sincronización completada';

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
  String get syncNotLoggedInToast => 'La sincronización no está conectada';

  @override
  String get syncPayloadAgentBundle => 'Paquete de agente';

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
  String get syncPayloadConfigFlag => 'Indicador de configuración';

  @override
  String get syncPayloadEntityDefinition => 'Definición de entidad';

  @override
  String get syncPayloadEntryLink => 'Enlace de entrada';

  @override
  String get syncPayloadJournalEntity => 'Entrada de diario';

  @override
  String get syncPayloadNotification => 'Notificación';

  @override
  String get syncPayloadNotificationStateUpdate =>
      'Actualización de estado de notificación';

  @override
  String get syncPayloadOutboxBundle => 'Paquete de salida';

  @override
  String get syncPayloadSyncNodeProfile => 'Perfil del nodo de sincronización';

  @override
  String get syncPayloadThemingSelection => 'Selección de tema';

  @override
  String get syncStepAgentEntities => 'Entidades de agente';

  @override
  String get syncStepAgentLinks => 'Enlaces de agente';

  @override
  String get syncStepAiSettings => 'Configuración de IA';

  @override
  String get syncStepBackfillAgentEntityClocks =>
      'Rellenar relojes de entidades de agente';

  @override
  String get syncStepBackfillAgentLinkClocks =>
      'Rellenar relojes de enlaces de agente';

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
  String get taskActionBarAudioRecordingActive => 'Grabación de audio en curso';

  @override
  String get taskActionBarMoreActions => 'Más acciones';

  @override
  String get taskActionBarOpenRunningTimer => 'Abrir cronómetro en curso';

  @override
  String get taskActionBarStopTracking => 'Detener registro de tiempo';

  @override
  String get taskActionBarTrackTime => 'Registrar tiempo';

  @override
  String get taskAgentCancelTimerTooltip => 'Cancelar';

  @override
  String taskAgentCountdownTooltip(String countdown) {
    return 'Próxima ejecución automática en $countdown';
  }

  @override
  String get taskAgentCreateChipLabel => 'Asignar agente';

  @override
  String taskAgentCreateError(String error) {
    return 'Error al crear el agente: $error';
  }

  @override
  String get taskAgentRunNowTooltip => 'Actualizar';

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
  String get taskEditTitleLabel => 'Editar título de la tarea';

  @override
  String get taskEstimateLabel => 'Estimación:';

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
  String get taskLanguageLabel => 'Idioma';

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
  String get taskLanguageSelectedLabel => 'Idioma actual';

  @override
  String get taskLanguageSerbian => 'Serbio';

  @override
  String get taskLanguageSetAction => 'Establecer idioma';

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
  String get tasksAgentFilterAll => 'Todos';

  @override
  String get tasksAgentFilterHasAgent => 'Con agente';

  @override
  String get tasksAgentFilterNoAgent => 'Sin agente';

  @override
  String get tasksAgentFilterTitle => 'Agente';

  @override
  String get tasksFilterApplyTitle => 'Aplicar filtro';

  @override
  String get tasksFilterClearAll => 'Borrar todo';

  @override
  String get tasksFilterTitle => 'Filtro de tareas';

  @override
  String get taskShowcaseAudio => 'Audio';

  @override
  String taskShowcaseCompletedCount(int completed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      completed,
      locale: localeName,
      other: '$completed / $total hechos',
      one: '1 / $total hecho',
    );
    return '$_temp0';
  }

  @override
  String taskShowcaseDueDate(String date) {
    return 'Vence: $date';
  }

  @override
  String get taskShowcaseJumpToSection => 'Ir a la sección';

  @override
  String get taskShowcaseLinked => 'Vinculado';

  @override
  String get taskShowcaseNoResults => 'Ninguna tarea coincide con tu búsqueda.';

  @override
  String get taskShowcaseReadMore => 'Leer más';

  @override
  String taskShowcaseRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count grabaciones',
      one: '1 grabación',
    );
    return '$_temp0';
  }

  @override
  String taskShowcaseTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tareas',
      one: '1 tarea',
    );
    return '$_temp0';
  }

  @override
  String get taskShowcaseTaskDescription => 'Descripción de la tarea';

  @override
  String get taskShowcaseTimeTracker => 'Registro de tiempo';

  @override
  String get taskShowcaseTodo => 'Pendiente';

  @override
  String get taskShowcaseTodos => 'Pendientes';

  @override
  String get tasksLabelFilterAll => 'Todas';

  @override
  String get tasksLabelFilterTitle => 'Etiqueta';

  @override
  String get tasksLabelFilterUnlabeled => 'Sin etiqueta';

  @override
  String get tasksLabelsDialogClose => 'Cerrar';

  @override
  String get tasksLabelsSheetApply => 'Aplicar';

  @override
  String get tasksLabelsSheetSearchHint => 'Buscar etiquetas…';

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
  String get tasksQuickFilterClear => 'Borrar';

  @override
  String get tasksQuickFilterLabelsActiveTitle =>
      'Filtros de etiquetas activos';

  @override
  String get tasksQuickFilterUnassignedLabel => 'Sin asignar';

  @override
  String get tasksSavedFilterDeleteConfirmTooltip =>
      'Toca otra vez para eliminar';

  @override
  String get tasksSavedFilterDeleteTooltip => 'Eliminar filtro guardado';

  @override
  String get tasksSavedFilterDragHandleSemantics => 'Arrastra para reordenar';

  @override
  String get tasksSavedFilterRenameSemantics => 'Renombrar filtro guardado';

  @override
  String get tasksSavedFiltersSaveButtonLabel => 'Guardar';

  @override
  String get tasksSavedFiltersSavePopupCancel => 'Cancelar';

  @override
  String tasksSavedFiltersSavePopupHelper(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count filtros activos. Guardados en la barra lateral, bajo Tareas.',
      one: '1 filtro activo. Guardado en la barra lateral, bajo Tareas.',
    );
    return '$_temp0';
  }

  @override
  String get tasksSavedFiltersSavePopupHint => 'p. ej. Bloqueadas o en pausa';

  @override
  String get tasksSavedFiltersSavePopupSave => 'Guardar';

  @override
  String get tasksSavedFiltersSavePopupTitle =>
      'Asigna un nombre a este filtro';

  @override
  String get tasksSavedFilterToastDeleted => 'Filtro eliminado';

  @override
  String tasksSavedFilterToastSaved(String name) {
    return 'Guardado «$name»';
  }

  @override
  String tasksSavedFilterToastUpdated(String name) {
    return 'Actualizado «$name»';
  }

  @override
  String get tasksSearchModeLabel => 'Modo de búsqueda';

  @override
  String get tasksShowCreationDate => 'Mostrar fecha de creación en tarjetas';

  @override
  String get tasksShowDueDate => 'Mostrar fecha de vencimiento en tarjetas';

  @override
  String get tasksSortByCreationDate => 'Creación';

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
  String get taskTitleEmpty => 'Sin título';

  @override
  String get taskUntitled => '(sin título)';

  @override
  String get thinkingDisclosureCopied => 'Razonamiento copiado';

  @override
  String get thinkingDisclosureCopy => 'Copiar razonamiento';

  @override
  String get thinkingDisclosureHide => 'Ocultar razonamiento';

  @override
  String get thinkingDisclosureShow => 'Mostrar razonamiento';

  @override
  String get thinkingDisclosureStateCollapsed => 'contraído';

  @override
  String get thinkingDisclosureStateExpanded => 'expandido';

  @override
  String get timeEntryItemEnd => 'Fin';

  @override
  String get timeEntryItemRunning => 'En curso';

  @override
  String get timeEntryItemStart => 'Inicio';

  @override
  String get unlinkButton => 'Desvincular';

  @override
  String get unlinkTaskConfirm =>
      '¿Estás seguro de que quieres desvincular esta tarea?';

  @override
  String get unlinkTaskTitle => 'Desvincular tarea';

  @override
  String vectorSearchTiming(int elapsed, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '${elapsed}ms, $count resultados',
      one: '${elapsed}ms, $count resultado',
    );
    return '$_temp0';
  }

  @override
  String get viewMenuTitle => 'Vista';

  @override
  String get viewMenuZoomIn => 'Ampliar';

  @override
  String get viewMenuZoomOut => 'Reducir';

  @override
  String get viewMenuZoomReset => 'Tamaño real';

  @override
  String get whatsNewDoneButton => 'Listo';

  @override
  String get whatsNewSkipButton => 'Omitir';
}

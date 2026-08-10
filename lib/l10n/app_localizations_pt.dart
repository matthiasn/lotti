// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get activeLabel => 'Ativo';

  @override
  String get addActionAddEvent => 'Adicionar um evento';

  @override
  String get addActionAddEventHint => 'Cria um evento e o abre.';

  @override
  String get addActionAddImageFromClipboard => 'Colar uma imagem';

  @override
  String get addActionAddImageFromClipboardHint =>
      'Anexa a imagem da sua área de transferência.';

  @override
  String get addActionAddScreenshot => 'Capturar uma captura de tela';

  @override
  String get addActionAddScreenshotHint =>
      'Fecha este painel e depois captura a tela.';

  @override
  String get addActionAddTask => 'Tarefa';

  @override
  String get addActionAddTimer => 'Temporizador';

  @override
  String get addActionAddTimeRecording => 'Entrada do temporizador';

  @override
  String get addActionCreateLinkedTask => 'Vincular uma nova tarefa';

  @override
  String get addActionCreateLinkedTaskHint =>
      'Cria e abre uma nova tarefa vinculada a esta.';

  @override
  String get addActionCreateTask => 'Adicionar uma tarefa';

  @override
  String get addActionCreateTaskHint => 'Cria uma nova tarefa e a abre.';

  @override
  String get addActionImportImage => 'Importar uma imagem';

  @override
  String get addActionImportImageHint =>
      'Abre sua galeria ou o seletor de arquivos.';

  @override
  String get addActionStartTimer => 'Iniciar um cronômetro';

  @override
  String get addActionStartTimerHint =>
      'Começa a registrar o tempo imediatamente.';

  @override
  String get addHabitCommentLabel => 'Comentário';

  @override
  String get addHabitDateLabel => 'Concluído em';

  @override
  String get addLinkedEntryLabel => 'Add linked entry';

  @override
  String get addMeasurementCommentLabel => 'Comentário';

  @override
  String get addMeasurementDateLabel => 'Observado em';

  @override
  String get addMeasurementSaveButton => 'Salvar';

  @override
  String get addToDictionary => 'Adicionar ao dicionário';

  @override
  String get addToDictionaryDuplicate => 'O termo já existe no dicionário';

  @override
  String get addToDictionaryNoCategory =>
      'Não é possível adicionar ao dicionário: a tarefa não tem categoria';

  @override
  String get addToDictionarySaveFailed => 'Falha ao salvar o dicionário';

  @override
  String get addToDictionarySuccess => 'Termo adicionado ao dicionário';

  @override
  String get addToDictionaryTooLong =>
      'Prazo muito longo (máximo de 50 caracteres)';

  @override
  String agentABComparisonChoose(String option) {
    return 'Escolha $option';
  }

  @override
  String agentABComparisonOption(String option) {
    return 'Opção $option';
  }

  @override
  String agentABComparisonPrefer(String option) {
    return 'Eu prefiro a opção $option';
  }

  @override
  String get agentBinaryChoiceNo => 'Não';

  @override
  String get agentBinaryChoiceYes => 'Sim';

  @override
  String get agentCategoryRatingsScaleMax => 'Corrija primeiro';

  @override
  String get agentCategoryRatingsScaleMin => 'Deixe';

  @override
  String agentCategoryRatingsStarLabel(int starIndex, int totalStars) {
    return '$starIndex de $totalStars estrelas';
  }

  @override
  String get agentCategoryRatingsSubmit => 'Use essas prioridades';

  @override
  String get agentCategoryRatingsSubtitle =>
      'Quão importante é que eu corrija cada um deles? 1 significa deixar como está, 5 significa consertar primeiro.';

  @override
  String get agentCategoryRatingsTitle => 'Ajude-me a priorizar';

  @override
  String agentControlsActionError(String error) {
    return 'Falha na ação: $error';
  }

  @override
  String get agentControlsDeleteButton => 'Excluir permanentemente';

  @override
  String get agentControlsDeleteDialogContent =>
      'Isso excluirá permanentemente todos os dados deste agente, incluindo histórico, relatórios e observações. Isto não pode ser desfeito.';

  @override
  String get agentControlsDeleteDialogTitle => 'Excluir agente?';

  @override
  String get agentControlsDestroyButton => 'Destruir';

  @override
  String get agentControlsDestroyDialogContent =>
      'Isso desativará permanentemente o agente. Sua história será preservada para auditoria.';

  @override
  String get agentControlsDestroyDialogTitle => 'Destruir Agente?';

  @override
  String get agentControlsDestroyedMessage => 'Este agente foi destruído.';

  @override
  String get agentControlsPauseButton => 'Pausa';

  @override
  String get agentControlsReanalyzeButton => 'Reanalisar';

  @override
  String get agentControlsResumeButton => 'Currículo';

  @override
  String get agentConversationEmpty => 'Nenhuma conversa ainda.';

  @override
  String agentConversationThreadSummary(
    int messageCount,
    int toolCallCount,
    String shortId,
  ) {
    return '$messageCount mensagens, $toolCallCount chamadas de ferramenta · $shortId';
  }

  @override
  String agentConversationTokenCount(String tokenCount) {
    return '$tokenCount tokens';
  }

  @override
  String get agentDefaultProfileLabel => 'Perfil de inferência padrão';

  @override
  String agentDetailErrorLoading(String error) {
    return 'Erro ao carregar o agente: $error';
  }

  @override
  String get agentDetailNotFound => 'Agente não encontrado.';

  @override
  String get agentDetailUnexpectedType => 'Tipo de entidade inesperado.';

  @override
  String get agentEvolutionApprovalRate => 'Taxa de aprovação';

  @override
  String get agentEvolutionChartMttrTrend => 'Tendência MTTR';

  @override
  String get agentEvolutionChartSuccessRateTrend => 'Tendência de sucesso';

  @override
  String get agentEvolutionChartVersionPerformance => 'Por versão';

  @override
  String get agentEvolutionChartWakeHistory => 'Histórico de despertar';

  @override
  String get agentEvolutionChatPlaceholder =>
      'Compartilhe comentários ou pergunte sobre desempenho...';

  @override
  String get agentEvolutionCurrentDirectives => 'Diretivas Atuais';

  @override
  String get agentEvolutionHistoryTitle => 'História da Evolução';

  @override
  String get agentEvolutionMetricActive => 'Ativo';

  @override
  String get agentEvolutionMetricAvgDuration => 'Duração média';

  @override
  String get agentEvolutionMetricFailures => 'Falhas';

  @override
  String get agentEvolutionMetricSuccess => 'Sucesso';

  @override
  String get agentEvolutionMetricWakes => 'Acorda';

  @override
  String get agentEvolutionNoSessions => 'Nenhuma sessão de evolução ainda';

  @override
  String get agentEvolutionNoteRecorded => 'Nota gravada';

  @override
  String get agentEvolutionProposalApprovalFailed =>
      'Falha na aprovação. Tente novamente';

  @override
  String get agentEvolutionProposalRationale => 'Justificativa';

  @override
  String get agentEvolutionProposalRejected =>
      'Proposta rejeitada – continue a conversa';

  @override
  String get agentEvolutionProposalTitle => 'Mudanças propostas';

  @override
  String get agentEvolutionProposedDirectives => 'Diretivas propostas';

  @override
  String get agentEvolutionSessionAbandoned =>
      'A sessão terminou sem alterações';

  @override
  String agentEvolutionSessionCompleted(int version) {
    return 'Sessão concluída — versão $version criada';
  }

  @override
  String get agentEvolutionSessionCount => 'Sessões';

  @override
  String get agentEvolutionSessionError =>
      'Falha ao iniciar a sessão de evolução';

  @override
  String agentEvolutionSessionProgress(int sessionNumber, int totalSessions) {
    return 'Sessão $sessionNumber de $totalSessions';
  }

  @override
  String get agentEvolutionSessionStarting => 'Iniciando sessão de evolução...';

  @override
  String agentEvolutionSessionTitle(int sessionNumber) {
    return 'Evolução #$sessionNumber';
  }

  @override
  String agentEvolutionSoulCurrentField(String field) {
    return 'Atual — $field';
  }

  @override
  String agentEvolutionSoulProposedField(String field) {
    return 'Proposta — $field';
  }

  @override
  String get agentEvolutionStatusAbandoned => 'Abandonado';

  @override
  String get agentEvolutionStatusActive => 'Ativo';

  @override
  String get agentEvolutionStatusCompleted => 'Concluído';

  @override
  String get agentEvolutionTimelineFeedbackLabel => 'Comentários';

  @override
  String get agentEvolutionVersionProposed => 'Versão proposta';

  @override
  String get agentFeedbackCategoryAccuracy => 'Precisão';

  @override
  String get agentFeedbackCategoryBreakdownTitle => 'Divisão de categorias';

  @override
  String get agentFeedbackCategoryCommunication => 'Comunicação';

  @override
  String get agentFeedbackCategoryGeneral => 'Geral';

  @override
  String get agentFeedbackCategoryPrioritization => 'Priorização';

  @override
  String get agentFeedbackCategoryTimeliness => 'Oportunidade';

  @override
  String get agentFeedbackCategoryTooling => 'Ferramentas';

  @override
  String get agentFeedbackClassificationTitle => 'Classificação de Feedback';

  @override
  String get agentFeedbackExcellenceTitle => 'Notas de Excelência';

  @override
  String get agentFeedbackGrievancesTitle => 'Queixas';

  @override
  String get agentFeedbackHighPriorityTitle => 'Feedback de alta prioridade';

  @override
  String agentFeedbackItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get agentFeedbackSourceDecision => 'Decisão';

  @override
  String get agentFeedbackSourceMetric => 'Métrica';

  @override
  String get agentFeedbackSourceObservation => 'Observação';

  @override
  String get agentFeedbackSourceRating => 'Avaliação';

  @override
  String get agentInstancesEmptyFiltered =>
      'Nenhuma instância corresponde aos seus filtros.';

  @override
  String get agentInstancesFilterClearAll => 'Limpar tudo';

  @override
  String get agentInstancesFilterClearSection => 'Limpar';

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
      other: '$count ativo',
      one: '1 ativo',
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
  String get agentInstancesKindEvolution => 'Evolução';

  @override
  String get agentInstancesKindTaskAgent => 'Agente de Tarefas';

  @override
  String get agentInstancesPageTitle => 'Instâncias de agente';

  @override
  String agentInstancesResultCountAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count instâncias',
      one: '1 instância',
    );
    return '$_temp0';
  }

  @override
  String agentInstancesResultCountFiltered(int filtered, int total) {
    return '$filtered de $total';
  }

  @override
  String get agentInstancesSearchClear => 'Limpar pesquisa';

  @override
  String get agentInstancesSearchPlaceholder => 'Pesquisar instâncias…';

  @override
  String get agentInstancesSortName => 'Nome';

  @override
  String get agentInstancesSortOldest => 'Mais antigo';

  @override
  String get agentInstancesSortRecent => 'Recente';

  @override
  String get agentInstancesTitle => 'Instâncias';

  @override
  String get agentInstancesToolbarFilters => 'Filtros';

  @override
  String get agentInstancesToolbarGroupBy => 'Agrupar por';

  @override
  String get agentInstancesUnassignedSoul => 'Não atribuído';

  @override
  String get agentLifecycleActive => 'Ativo';

  @override
  String get agentLifecycleCreated => 'Criado';

  @override
  String get agentLifecycleDestroyed => 'Destruído';

  @override
  String get agentLifecycleDormant => 'Dormente';

  @override
  String get agentMessageKindAction => 'Ação';

  @override
  String get agentMessageKindMilestone => 'Marco';

  @override
  String get agentMessageKindObservation => 'Observação';

  @override
  String get agentMessageKindRetraction => 'Retração';

  @override
  String get agentMessageKindSummary => 'Resumo';

  @override
  String get agentMessageKindSystem => 'Sistema';

  @override
  String get agentMessageKindSystemPrompt => 'Alerta do sistema';

  @override
  String get agentMessageKindThought => 'Pensamento';

  @override
  String get agentMessageKindToolResult => 'Resultado da ferramenta';

  @override
  String get agentMessageKindUser => 'Usuário';

  @override
  String get agentMessagePayloadEmpty => '(sem conteúdo)';

  @override
  String get agentMessagesEmpty => 'Nenhuma mensagem ainda.';

  @override
  String agentMessagesErrorLoading(String error) {
    return 'Falha ao carregar mensagens: $error';
  }

  @override
  String get agentObservationsEmpty => 'Nenhuma observação registrada ainda.';

  @override
  String get agentPendingWakesDeleteTooltip => 'Remover despertar';

  @override
  String get agentPendingWakesEmptyFiltered =>
      'Nenhuma ativação corresponde aos seus filtros.';

  @override
  String get agentPendingWakesFilterSectionType => 'Tipo';

  @override
  String get agentPendingWakesGroupByType => 'Tipo';

  @override
  String get agentPendingWakesPendingLabel => 'Pendente';

  @override
  String agentPendingWakesRunningHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Em execução agora ($count)',
      one: 'Em execução agora',
    );
    return '$_temp0';
  }

  @override
  String get agentPendingWakesScheduledLabel => 'Agendado';

  @override
  String get agentPendingWakesSearchPlaceholder => 'A pesquisa acorda…';

  @override
  String get agentPendingWakesSortDueLatest => 'Vencimento mais recente';

  @override
  String get agentPendingWakesSortDueSoonest => 'Prazo mais breve';

  @override
  String get agentPendingWakesTitle => 'Ciclos de despertar';

  @override
  String get agentReportHistoryBadge => 'Relatório';

  @override
  String get agentReportHistoryEmpty =>
      'Ainda não há instantâneos de relatório.';

  @override
  String get agentReportHistoryError =>
      'Ocorreu um erro ao carregar o histórico do relatório.';

  @override
  String get agentReportNone => 'Nenhum relatório disponível ainda.';

  @override
  String get agentRitualContinueAction => 'Continuar a conversa';

  @override
  String get agentRitualOpeningHint =>
      'A ler o que aconteceu desde a vossa última conversa…';

  @override
  String get agentRitualReviewAction => 'Iniciar conversa';

  @override
  String get agentRitualReviewNegativeSignals => 'Negativo';

  @override
  String get agentRitualReviewNeutralSignals => 'Neutro';

  @override
  String get agentRitualReviewNoFeedback =>
      'Nenhum sinal de feedback nesta janela';

  @override
  String get agentRitualReviewNoNegativeSignals =>
      'Nenhum sinal de feedback negativo nesta guia';

  @override
  String get agentRitualReviewNoNeutralSignals =>
      'Nenhum sinal de feedback neutro nesta guia';

  @override
  String get agentRitualReviewNoPositiveSignals =>
      'Nenhum sinal de feedback positivo nesta guia';

  @override
  String get agentRitualReviewPositiveSignals => 'Positivo';

  @override
  String get agentRitualReviewProposalSection => 'Proposta Atual';

  @override
  String get agentRitualReviewSessionHistory => 'Conversas anteriores';

  @override
  String get agentRitualReviewTitle => '1 contra 1';

  @override
  String get agentRitualSinceLastHeading => 'Desde a nossa última conversa';

  @override
  String get agentRitualStartHeading => 'Iniciar uma conversa individual';

  @override
  String get agentRitualSummaryApprovedChangesHeading => 'Alterações aprovadas';

  @override
  String get agentRitualSummaryConversationHeading => 'Conversa';

  @override
  String get agentRitualSummaryRecapHeading => 'Recapitulação da sessão';

  @override
  String get agentRitualSummaryRoleAssistant => 'Agente';

  @override
  String get agentRitualSummaryRoleUser => 'Você';

  @override
  String get agentRitualSummaryStartHint =>
      'Revê o que te incomodou, o que funcionou e o que deve mudar a seguir.';

  @override
  String get agentRitualSummaryTokensSinceLast =>
      'Tokens desde o último 1 contra 1';

  @override
  String get agentRitualSummaryWakeHistory30Days =>
      'Atividade de despertar (últimos 30 dias)';

  @override
  String get agentRitualSummaryWakesSinceLast =>
      'Acorda desde o último confronto individual';

  @override
  String get agentRitualTypingSemantics =>
      'O agente está a redigir uma resposta';

  @override
  String agentRitualWakesSinceLastCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count despertares desde a vossa última conversa',
      one: '1 despertar desde a vossa última conversa',
    );
    return '$_temp0';
  }

  @override
  String get agentRunningIndicator => 'Correndo';

  @override
  String get agentsCreateGoal => 'Novo agente de meta';

  @override
  String get agentSessionProgressTitle => 'Progresso da sessão';

  @override
  String get agentSettingsSubtitle => 'Modelos, instâncias e monitoramento';

  @override
  String get agentSettingsTitle => 'Agentes';

  @override
  String get agentSoulAntiSycophancyLabel => 'Política Anti-Bajulação';

  @override
  String get agentSoulAssignedTemplatesTitle => 'Modelos atribuídos';

  @override
  String get agentSoulAssignmentLabel => 'Alma';

  @override
  String get agentSoulCoachingStyleLabel => 'Estilo de treinamento';

  @override
  String get agentSoulCreatedSuccess => 'Alma criada';

  @override
  String get agentSoulCreateTitle => 'Criar alma';

  @override
  String get agentSoulDeleteConfirmBody =>
      'Isto removerá a alma e todas as suas versões.';

  @override
  String get agentSoulDeleteConfirmTitle => 'Excluir alma';

  @override
  String get agentSoulDetailTitle => 'Detalhe da Alma';

  @override
  String get agentSoulDisplayNameLabel => 'Nome';

  @override
  String get agentSoulEvolutionHistoryTitle => 'História da Evolução da Alma';

  @override
  String get agentSoulEvolutionNoSessions =>
      'Nenhuma sessão de evolução da alma ainda';

  @override
  String get agentSoulFieldAntiSycophancy => 'Anti-bajulação';

  @override
  String get agentSoulFieldCoachingStyle => 'Estilo de treinamento';

  @override
  String get agentSoulFieldToneBounds => 'Limites de tom';

  @override
  String get agentSoulFieldVoice => 'Voz';

  @override
  String get agentSoulInfoTab => 'Informações';

  @override
  String get agentSoulNoneAssigned => 'Nenhuma alma designada';

  @override
  String get agentSoulNotFound => 'Alma não encontrada';

  @override
  String get agentSoulProposalSubtitle => 'Mudanças de personalidade propostas';

  @override
  String get agentSoulProposalTitle => 'Proposta de Personalidade da Alma';

  @override
  String get agentSoulReviewStartAction => 'Iniciar revisão de personalidade';

  @override
  String get agentSoulReviewStartHint =>
      'Inicie uma sessão focada na personalidade para revisar o feedback e evoluir a voz, o tom, o estilo de coaching e a franqueza.';

  @override
  String agentSoulReviewTemplateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modelos compartilhando esta alma',
      one: '1 modelo compartilhando esta alma',
    );
    return '$_temp0';
  }

  @override
  String get agentSoulReviewTitle => 'Alma 1 contra 1';

  @override
  String get agentSoulRollbackAction => 'Reverter para esta versão';

  @override
  String agentSoulRollbackConfirm(int version) {
    return 'Reverter para a versão $version? Todos os modelos que usam esta alma receberão a mudança.';
  }

  @override
  String get agentSoulSelectTitle => 'Selecione Alma';

  @override
  String get agentSoulsEmptyFiltered =>
      'Nenhuma alma corresponde aos seus filtros.';

  @override
  String get agentSoulSettingsTab => 'Configurações';

  @override
  String get agentSoulsSearchPlaceholder => 'Procure almas…';

  @override
  String get agentSoulsTitle => 'Almas';

  @override
  String get agentSoulToneBoundsLabel => 'Limites de tom';

  @override
  String get agentSoulVersionHistoryTitle => 'Histórico de versões';

  @override
  String agentSoulVersionLabel(int version) {
    return 'Versão $version';
  }

  @override
  String get agentSoulVersionSaved => 'Nova versão do soul salva';

  @override
  String get agentSoulVoiceDirectiveLabel => 'Diretiva de Voz';

  @override
  String get agentsPageEmpty =>
      'Ainda não há agentes de metas. Cria um e ele acompanha o teu progresso discretamente.';

  @override
  String get agentsPageLoadFailed =>
      'Não foi possível carregar seus agentes agora.';

  @override
  String get agentsPageTitle => 'Agentes';

  @override
  String get agentStateConsecutiveFailures => 'Falhas consecutivas';

  @override
  String agentStateErrorLoading(String error) {
    return 'Falha ao carregar o estado: $error';
  }

  @override
  String get agentStateHeading => 'Informações do estado';

  @override
  String get agentStateLastWake => 'Último velório';

  @override
  String get agentStateNextWake => 'Próximo despertar';

  @override
  String get agentStateRevision => 'Revisão';

  @override
  String get agentStateSleepingUntil => 'Dormindo até';

  @override
  String get agentStateWakeCount => 'Contagem de despertares';

  @override
  String get agentSuggestionTimeEntryUpdateCurrent => 'Atual';

  @override
  String get agentSuggestionTimeEntryUpdateNoChange => '(inalterado)';

  @override
  String get agentSuggestionTimeEntryUpdateProposed => 'Proposto';

  @override
  String get agentSuggestionTimeEntryUpdateUnavailable =>
      'Entrada original não disponível';

  @override
  String agentSummaryAddItem(Object title) {
    return 'Adicionar: \"$title\"';
  }

  @override
  String agentSummaryArchiveItem(Object title) {
    return 'Arquivar: \"$title\"';
  }

  @override
  String agentSummaryCheckItem(Object title) {
    return 'Marcar: \"$title\"';
  }

  @override
  String agentSummaryCreateFollowUp(Object title) {
    return 'Criar tarefa de acompanhamento: \"$title\"';
  }

  @override
  String agentSummaryCreateFollowUpRelated(Object title, Object relation) {
    return 'Criar tarefa de acompanhamento: \"$title\" — $relation';
  }

  @override
  String agentSummaryCreateTask(Object title) {
    return 'Criar tarefa: $title';
  }

  @override
  String agentSummaryFollowUpTask(Object title) {
    return 'Tarefa de acompanhamento: $title';
  }

  @override
  String agentSummaryGoalRevisionCadence(String value) {
    return 'Alterar a cadência para $value';
  }

  @override
  String agentSummaryGoalRevisionPeriod(String value) {
    return 'Alterar o período para $value';
  }

  @override
  String agentSummaryGoalRevisionScope(String value) {
    return 'aplica-se a $value';
  }

  @override
  String agentSummaryGoalRevisionTarget(String value) {
    return 'Alterar a meta para $value';
  }

  @override
  String agentSummaryMigrateItem(Object title) {
    return 'Mover para a tarefa de acompanhamento: \"$title\"';
  }

  @override
  String get agentSummaryRecommendNextSteps => 'Recomendar os passos seguintes';

  @override
  String agentSummaryRecommendNextStepsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Recomendar $count passos seguintes',
      one: 'Recomendar 1 passo seguinte',
    );
    return '$_temp0';
  }

  @override
  String agentSummaryRestoreItem(Object title) {
    return 'Restaurar: \"$title\"';
  }

  @override
  String agentSummaryReviseTimeEntryText(Object summary) {
    return 'Revisar o texto do registro de tempo: \"$summary\"';
  }

  @override
  String agentSummarySetDueDate(Object date) {
    return 'Definir o prazo para $date';
  }

  @override
  String agentSummarySetEstimate(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Definir a estimativa como $minutes minutos',
      one: 'Definir a estimativa como 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String agentSummarySetLanguage(Object language) {
    return 'Definir o idioma como \"$language\"';
  }

  @override
  String agentSummarySetPriority(Object priority) {
    return 'Definir a prioridade como $priority';
  }

  @override
  String agentSummarySetStatus(Object status) {
    return 'Definir o estado como $status';
  }

  @override
  String agentSummarySetTitle(Object title) {
    return 'Definir o título como \"$title\"';
  }

  @override
  String get agentSummarySuggestFollowUpTask =>
      'Propor uma tarefa de acompanhamento';

  @override
  String agentSummaryTimeEntry(Object range, Object summary) {
    return 'Registro de tempo $range: \"$summary\"';
  }

  @override
  String agentSummaryTimeRangeBetween(Object start, Object end) {
    return '$start–$end';
  }

  @override
  String agentSummaryTimeRangeFrom(Object start) {
    return 'a partir de $start';
  }

  @override
  String agentSummaryTimeRangeUntil(Object end) {
    return 'até $end';
  }

  @override
  String agentSummaryUncheckItem(Object title) {
    return 'Desmarcar: \"$title\"';
  }

  @override
  String agentSummaryUpdateItem(Object title) {
    return 'Alterar: \"$title\"';
  }

  @override
  String agentSummaryUpdateProjectStatus(Object status) {
    return 'Definir o estado do projeto como $status';
  }

  @override
  String agentSummaryUpdateRunningTimer(Object summary) {
    return 'Alterar o texto do cronômetro em execução: \"$summary\"';
  }

  @override
  String get agentSummaryUpdateTimeEntry => 'Atualizar o registro de tempo';

  @override
  String agentSummaryUpdateTimeEntryRange(Object range) {
    return 'Atualizar o registro de tempo $range';
  }

  @override
  String agentSummaryUpdateTimeEntryRangeText(Object range, Object summary) {
    return 'Atualizar o registro de tempo $range: \"$summary\"';
  }

  @override
  String get agentTabActivity => 'Atividade';

  @override
  String get agentTabConversations => 'Conversas';

  @override
  String get agentTabObservations => 'Observações';

  @override
  String get agentTabReports => 'Relatórios';

  @override
  String get agentTabStats => 'Estatísticas';

  @override
  String get agentTemplateAggregateTokenUsageHeading => 'Uso agregado de token';

  @override
  String get agentTemplateAssignedLabel => 'Modelo';

  @override
  String get agentTemplateCreatedSuccess => 'Modelo criado';

  @override
  String get agentTemplateCreateTitle => 'Criar modelo';

  @override
  String get agentTemplateDeleteConfirm =>
      'Excluir este modelo? Isto não pode ser desfeito.';

  @override
  String get agentTemplateDeleteHasInstances =>
      'Não é possível excluir: os agentes ativos estão usando este modelo.';

  @override
  String get agentTemplateDisplayNameLabel => 'Nome';

  @override
  String get agentTemplateEditTitle => 'Editar modelo';

  @override
  String get agentTemplateEvolutionTab => 'Evolução';

  @override
  String get agentTemplateEvolveApprove => 'Aprovar e salvar';

  @override
  String get agentTemplateEvolveReject => 'Rejeitar';

  @override
  String get agentTemplateGeneralDirectiveHint =>
      'Defina a personalidade, ferramentas, objetivos e estilo de interação do agente...';

  @override
  String get agentTemplateGeneralDirectiveLabel => 'Diretiva Geral';

  @override
  String get agentTemplateInstanceBreakdownHeading =>
      'Detalhamento por instância';

  @override
  String agentTemplateInstanceLastActive(String date) {
    return 'Último despertar: $date';
  }

  @override
  String get agentTemplateInstanceNeverActive => 'Nunca acordada';

  @override
  String get agentTemplateInstanceOpenTask => 'Abrir tarefa';

  @override
  String get agentTemplateInstancesEmpty => 'Ainda não há instâncias.';

  @override
  String get agentTemplateInstancesHeading => 'Instâncias';

  @override
  String agentTemplateInstanceStarted(String date) {
    return 'Iniciada em $date';
  }

  @override
  String get agentTemplateKindDayAgent => 'Agente diurno';

  @override
  String get agentTemplateKindEventAgent => 'Agente de Eventos';

  @override
  String get agentTemplateKindImprover => 'Melhorador de modelo';

  @override
  String get agentTemplateKindProjectAgent => 'Agente de Projeto';

  @override
  String get agentTemplateKindTaskAgent => 'Agente de Tarefas';

  @override
  String get agentTemplateMetricsTotalWakes => 'Total de despertares';

  @override
  String get agentTemplateNoneAssigned => 'Nenhum modelo atribuído';

  @override
  String get agentTemplateNoTemplates =>
      'Nenhum modelo disponível. Crie um em Configurações primeiro.';

  @override
  String get agentTemplateNotFound => 'Modelo não encontrado';

  @override
  String get agentTemplateNoVersions => 'Nenhuma versão';

  @override
  String get agentTemplateReportDirectiveHint =>
      'Defina a estrutura do relatório, seções obrigatórias e regras de formatação...';

  @override
  String get agentTemplateReportDirectiveLabel => 'Diretiva de Relatório';

  @override
  String get agentTemplateReportsEmpty => 'Ainda não há relatórios.';

  @override
  String get agentTemplateReportsTab => 'Relatórios';

  @override
  String get agentTemplateRollbackAction => 'Reverter para esta versão';

  @override
  String agentTemplateRollbackConfirm(int version) {
    return 'Reverter para a versão $version? O agente utilizará esta versão em seu próximo wake.';
  }

  @override
  String get agentTemplateSaveNewVersion => 'Salvar';

  @override
  String get agentTemplateSelectTitle => 'Selecione o modelo';

  @override
  String get agentTemplatesEmptyFiltered =>
      'Nenhum modelo corresponde aos seus filtros.';

  @override
  String get agentTemplateSettingsTab => 'Configurações';

  @override
  String get agentTemplatesFilterSectionKind => 'Gentil';

  @override
  String get agentTemplatesGroupByKind => 'Gentil';

  @override
  String get agentTemplatesGroupNone => 'Todos';

  @override
  String get agentTemplatesSearchPlaceholder => 'Pesquisar modelos…';

  @override
  String get agentTemplateStatsTab => 'Estatísticas';

  @override
  String get agentTemplateStatusActive => 'Ativo';

  @override
  String get agentTemplateStatusArchived => 'Arquivado';

  @override
  String get agentTemplatesTitle => 'Modelos de agente';

  @override
  String get agentTemplateSwitchHint =>
      'Para usar um modelo diferente, destrua este agente e crie um novo.';

  @override
  String get agentTemplateVersionHistoryTitle => 'Histórico de versões';

  @override
  String agentTemplateVersionLabel(int version) {
    return 'Versão $version';
  }

  @override
  String get agentTemplateVersionSaved => 'Nova versão salva';

  @override
  String get agentThreadReportLabel =>
      'Relatório produzido durante este velório';

  @override
  String get agentTokenUsageCachedTokens => 'Em cache';

  @override
  String get agentTokenUsageEmpty => 'Nenhum uso de token registrado ainda.';

  @override
  String agentTokenUsageErrorLoading(String error) {
    return 'Falha ao carregar o uso do token: $error';
  }

  @override
  String get agentTokenUsageHeading => 'Uso de token';

  @override
  String get agentTokenUsageInputTokens => 'Entrada';

  @override
  String get agentTokenUsageModel => 'Modelo';

  @override
  String get agentTokenUsageOutputTokens => 'Saída';

  @override
  String get agentTokenUsageThoughtsTokens => 'Pensamentos';

  @override
  String get agentTokenUsageTotalTokens => 'Total';

  @override
  String get agentTokenUsageWakeCount => 'Acorda';

  @override
  String get agentToolGoalRevisionLabel => 'Proposta de revisão da meta';

  @override
  String get aggregationDailyAvg => 'Média diária';

  @override
  String get aggregationDailyMax => 'Máximo diário';

  @override
  String get aggregationDailySum => 'Soma diária';

  @override
  String get aggregationHourlySum => 'Soma horária';

  @override
  String get aggregationNone => 'Valores brutos';

  @override
  String get aiAssistantTitle => 'Gerar…';

  @override
  String get aiAttributionArtifactOutput => 'Output';

  @override
  String get aiAttributionCompletedAt => 'Completed at';

  @override
  String get aiAttributionCost => 'Cost';

  @override
  String get aiAttributionCostUnknown => 'Cost unknown';

  @override
  String get aiAttributionCreator => 'Creator';

  @override
  String get aiAttributionDiagnostics => 'Diagnostics';

  @override
  String get aiAttributionDuration => 'Duration';

  @override
  String get aiAttributionInteractions => 'Interactions';

  @override
  String get aiAttributionLoading => 'Loading AI attribution…';

  @override
  String get aiAttributionNoInteractionDetails =>
      'No interaction details are available.';

  @override
  String get aiAttributionRequestEvidence => 'Request evidence';

  @override
  String get aiAttributionResponseEvidence => 'Response evidence';

  @override
  String aiAttributionSecondary(String model, String time, int callCount) {
    String _temp0 = intl.Intl.pluralLogic(
      callCount,
      locale: localeName,
      other: '$callCount calls',
      one: '1 call',
      zero: 'no calls',
    );
    return '$model · $time · $_temp0';
  }

  @override
  String get aiAttributionStartedAt => 'Started at';

  @override
  String get aiAttributionStatus => 'Status';

  @override
  String get aiAttributionStatusCancelled => 'Cancelled';

  @override
  String get aiAttributionStatusFailed => 'Failed';

  @override
  String get aiAttributionStatusPartial => 'Partial';

  @override
  String get aiAttributionStatusSucceeded => 'Completed';

  @override
  String aiAttributionSummary(String actor, String trigger, String status) {
    return '$actor · $trigger · $status';
  }

  @override
  String get aiAttributionTitle => 'AI attribution';

  @override
  String aiAttributionTokenBreakdown(
    String input,
    String output,
    String cached,
    String reasoning,
  ) {
    return 'Input: $input · Output: $output · Cached: $cached · Reasoning: $reasoning';
  }

  @override
  String get aiAttributionTokens => 'Tokens';

  @override
  String get aiAttributionTokenUsageUnknown => 'Token usage unknown';

  @override
  String get aiAttributionTrigger => 'Trigger';

  @override
  String get aiAttributionTriggerAgent => 'Agent';

  @override
  String get aiAttributionTriggerAutomatic => 'Automatic';

  @override
  String get aiAttributionTriggerImported => 'Imported';

  @override
  String get aiAttributionTriggerManual => 'Manual';

  @override
  String get aiAttributionTriggerScheduled => 'Scheduled';

  @override
  String get aiAttributionTriggerSynced => 'From sync';

  @override
  String get aiAttributionUnavailable => 'AI attribution is unavailable.';

  @override
  String get aiAttributionUnknownCreator => 'Unknown creator';

  @override
  String get aiAttributionUnknownModel => 'Unknown model';

  @override
  String get aiAttributionYou => 'You';

  @override
  String get aiCapabilityChipImageGeneration => 'Geração de imagem';

  @override
  String get aiCapabilityChipImageRecognition => 'Reconhecimento de imagem';

  @override
  String get aiCapabilityChipThinking => 'Pensando';

  @override
  String get aiCapabilityChipTranscription => 'Transcrição';

  @override
  String aiCardHistoryToggle(int count) {
    return 'História · $count';
  }

  @override
  String get aiCardMenuActionDelete => 'Excluir';

  @override
  String get aiCardMenuActionEdit => 'Editar';

  @override
  String get aiCardMenuTooltip => 'Mais ações';

  @override
  String get aiCardOpenAgentInternals => 'Abra os internos do agente';

  @override
  String get aiCardProposalConfirmed => 'Confirmado';

  @override
  String get aiCardProposalDismissed => 'Dispensado';

  @override
  String get aiCardProposalKindAdd => 'Adicionar';

  @override
  String get aiCardProposalKindDue => 'Devido';

  @override
  String get aiCardProposalKindEstimate => 'Estimativa';

  @override
  String get aiCardProposalKindLabel => 'Etiqueta';

  @override
  String get aiCardProposalKindPriority => 'Prioridade';

  @override
  String get aiCardProposalKindRemove => 'Remover';

  @override
  String get aiCardProposalKindStatus => 'Estado';

  @override
  String get aiCardProposalKindUpdate => 'Atualizar';

  @override
  String get aiCardReadMore => 'Leia mais';

  @override
  String get aiCardShowLess => 'Mostrar menos';

  @override
  String get aiCardTitle => 'Resumo de IA';

  @override
  String get aiChatAssistantResponding => 'O assistente está respondendo';

  @override
  String get aiChatMessageCopied => 'Copiado para a área de transferência';

  @override
  String get aiConfigFailedToLoadModelsGeneric =>
      'Falha ao carregar modelos. Por favor, tente novamente.';

  @override
  String get aiConfigNoModelsAvailable =>
      'Nenhum modelo de IA está configurado ainda. Adicione um nas configurações.';

  @override
  String get aiConfigNoSuitableModelsAvailable =>
      'Nenhum modelo atende aos requisitos deste prompt. Configure modelos que suportem os recursos necessários.';

  @override
  String get aiConfigSelectProviderModalTitle =>
      'Selecione o provedor de inferência';

  @override
  String get aiConfigSelectProviderTypeModalTitle =>
      'Selecione o tipo de provedor';

  @override
  String get aiConfigUseReasoningFieldLabel => 'Use o raciocínio';

  @override
  String aiConsumptionAttributionReference(String id) {
    return 'Attribution $id';
  }

  @override
  String aiConsumptionCallsLine(int count, int measured) {
    return 'Chamadas de IA: $count · impacto medido para $measured';
  }

  @override
  String aiConsumptionCostLine(String cost) {
    return 'Custo: $cost';
  }

  @override
  String aiConsumptionImpactLine(String energy, String carbon, String water) {
    return 'Impacto: $energy · $carbon CO₂e · $water água';
  }

  @override
  String aiConsumptionLedgerCap(int limit) {
    return 'Mostrando as chamadas $limit mais recentes neste período';
  }

  @override
  String get aiConsumptionLedgerTitle => 'Chamadas recentes';

  @override
  String get aiConsumptionMetricsNotReported => 'Não relatado';

  @override
  String aiConsumptionTokensLabel(String tokens) {
    return '$tokens tokens';
  }

  @override
  String aiConsumptionTokensLine(String input, String output) {
    return 'Tokens: $input entrada · $output saída';
  }

  @override
  String get aiConsumptionTypeAgentTurn => 'Turno do agente';

  @override
  String get aiConsumptionTypeAudioTranscription => 'Transcrição';

  @override
  String get aiConsumptionTypeEmbeddingIndexing => 'Embedding indexing';

  @override
  String get aiConsumptionTypeImageAnalysis => 'Análise de imagem';

  @override
  String get aiConsumptionTypeImageGeneration => 'Geração de imagem';

  @override
  String get aiConsumptionTypePromptGeneration => 'Geração de prompt';

  @override
  String get aiConsumptionTypeTextGeneration => 'Geração de texto';

  @override
  String aiConsumptionWorkGroup(int callCount) {
    String _temp0 = intl.Intl.pluralLogic(
      callCount,
      locale: localeName,
      other: '$callCount calls',
      one: '1 call',
    );
    return 'AI work · $_temp0';
  }

  @override
  String aiDeleteToastCascadeDescription(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Também removeu $count modelos: $names',
      one: 'Também removeu 1 modelo: $names',
    );
    return '$_temp0';
  }

  @override
  String aiDeleteToastErrorTitle(String name) {
    return 'Não foi possível excluir $name';
  }

  @override
  String get aiDeleteToastModelTitle => 'Modelo excluído';

  @override
  String get aiDeleteToastProfileTitle => 'Perfil excluído';

  @override
  String get aiDeleteToastPromptTitle => 'Prompt excluído';

  @override
  String get aiDeleteToastProviderTitle => 'Provedor excluído';

  @override
  String get aiDeleteToastSkillTitle => 'Habilidade excluída';

  @override
  String get aiDeleteToastUndoAction => 'Desfazer';

  @override
  String get aiFormCancel => 'Cancelar';

  @override
  String get aiFormFixErrors => 'Corrija os erros antes de salvar';

  @override
  String get aiFormNoChanges => 'Nenhuma alteração não salva';

  @override
  String get aiImageAnalysisPickerDefaultBadge => 'Padrão';

  @override
  String get aiImageAnalysisPickerTitle =>
      'Escolha um modelo de análise de imagem';

  @override
  String get aiImageGenerationPickerTitle =>
      'Escolha um modelo de geração de imagem';

  @override
  String get aiImpactBreakdownBoth => 'Ambos';

  @override
  String get aiImpactBreakdownCategory => 'Por categoria';

  @override
  String get aiImpactBreakdownModel => 'Por modelo';

  @override
  String get aiImpactCategoryTitle => 'Divisão por categoria';

  @override
  String get aiImpactChartHint =>
      'Toque em uma barra para definir o escopo das chamadas · toque em uma série para isolar';

  @override
  String get aiImpactChartShareCaption => 'Composição ao longo do tempo';

  @override
  String get aiImpactChartShareSegment => 'Compartilhar';

  @override
  String aiImpactChartTitle(String metric) {
    return '$metric por categoria';
  }

  @override
  String aiImpactChartTitleModel(String metric) {
    return '$metric por modelo';
  }

  @override
  String get aiImpactCoverageNote =>
      'Energia, CO₂e e custo são medidos apenas para modelos de nuvem.';

  @override
  String get aiImpactEmptyBody =>
      'As chamadas de IA de suas tarefas e agentes aparecerão aqui.';

  @override
  String get aiImpactEmptyTitle => 'Nenhum uso de IA neste intervalo';

  @override
  String get aiImpactKpiCarbon => 'CO₂E';

  @override
  String get aiImpactKpiCost => 'CUSTO';

  @override
  String aiImpactKpiDeltaBaseline(String period) {
    return 'vs $period';
  }

  @override
  String get aiImpactKpiEnergy => 'ENERGIA';

  @override
  String get aiImpactKpiRequests => 'PEDIDOS';

  @override
  String get aiImpactKpiTokens => 'FICHAS';

  @override
  String get aiImpactLedgerClearFilter => 'Mostrar tudo';

  @override
  String get aiImpactLoadError =>
      'Não foi possível carregar os dados de impacto da IA';

  @override
  String get aiImpactLocationColumn => 'LOCALIZAÇÃO';

  @override
  String get aiImpactLocationTitle => 'Impacto por localização';

  @override
  String get aiImpactLocationUnknown => 'Desconhecido';

  @override
  String get aiImpactMetricCarbon => 'CO₂e';

  @override
  String get aiImpactMetricCost => 'Custo';

  @override
  String get aiImpactMetricEnergy => 'Energia';

  @override
  String get aiImpactMetricRequests => 'Solicitações';

  @override
  String get aiImpactMetricTokens => 'Fichas';

  @override
  String aiImpactModelCallsLabel(String count) {
    return '$count chamadas';
  }

  @override
  String get aiImpactModelColumn => 'MODELO';

  @override
  String get aiImpactModelCostHeavy => 'caro';

  @override
  String get aiImpactModelCoverageNote =>
      'Os modelos locais estão excluídos deste gráfico.';

  @override
  String get aiImpactModelOther => 'Outros modelos';

  @override
  String aiImpactModelRatePerMillion(String cost) {
    return '$cost/1 milhão de tokens';
  }

  @override
  String get aiImpactModelTitle => 'Detalhamento do modelo';

  @override
  String get aiImpactModelUnknown => 'Modelo desconhecido';

  @override
  String get aiImpactRenewableColumn => 'RENOVÁVEL';

  @override
  String get aiImpactTitle => 'Impacto da IA';

  @override
  String get aiInferenceErrorAuthenticationTitle => 'Falha na autenticação';

  @override
  String get aiInferenceErrorConnectionFailedTitle => 'Falha na conexão';

  @override
  String get aiInferenceErrorInvalidRequestTitle => 'Solicitação inválida';

  @override
  String get aiInferenceErrorRateLimitTitle => 'Limite de taxa excedido';

  @override
  String get aiInferenceErrorRetryButton => 'Tente novamente';

  @override
  String get aiInferenceErrorServerTitle => 'Erro no servidor';

  @override
  String get aiInferenceErrorSuggestionsTitle => 'Sugestões:';

  @override
  String get aiInferenceErrorTimeoutTitle => 'Solicitação expirou';

  @override
  String get aiInferenceErrorUnknownTitle => 'Erro';

  @override
  String get aiInternalsTitle => 'Internos do agente';

  @override
  String get aiModelCardDeleteTooltip => 'Excluir modelo';

  @override
  String get aiModelDownloadCloseButton => 'Fechar';

  @override
  String aiModelDownloadDialogDescription(String modelName) {
    return 'Lotti fará o download de $modelName no cache de áudio MLX e o usará para processamento de fala local.';
  }

  @override
  String aiModelDownloadDialogTitle(String modelName) {
    return 'Instale $modelName';
  }

  @override
  String get aiModelDownloadInstallTooltip => 'Instalar modelo';

  @override
  String get aiModelDownloadOpenProgressTooltip =>
      'Mostrar progresso do download';

  @override
  String get aiModelDownloadStatusChecking => 'Verificando o status do modelo';

  @override
  String aiModelDownloadStatusDownloading(int percent) {
    return 'Baixando $percent%';
  }

  @override
  String get aiModelDownloadStatusDownloadingIndeterminate => 'Baixando';

  @override
  String get aiModelDownloadStatusFailed => 'Falha no download';

  @override
  String get aiModelDownloadStatusInstalled => 'Instalado';

  @override
  String get aiModelDownloadStatusNotInstalled => 'Não instalado';

  @override
  String get aiModelDownloadStatusUnsupported => 'Apple Silicon necessário';

  @override
  String get aiModelInstallChoiceCancelButton => 'Cancelar';

  @override
  String get aiModelInstallChoiceDescription =>
      'Escolha o modelo local de fala para texto para fazer o download primeiro. Você pode instalar os outros posteriormente na lista de modelos.';

  @override
  String get aiModelInstallChoiceInstallButton => 'Instalar modelo';

  @override
  String get aiModelInstallChoiceRecommended => 'Recomendado';

  @override
  String get aiModelInstallChoiceTitle => 'Escolha o modelo de áudio MLX';

  @override
  String get aiModelPickerByProviderLabel => 'Escolha um provedor';

  @override
  String get aiModelPickerCurrentDefaultLabel => 'Padrão atual';

  @override
  String aiModelPickerProviderModelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modelos',
      one: '1 modelo',
    );
    return '$_temp0';
  }

  @override
  String aiOllamaModelInstalledSuccessfully(String modelName) {
    return 'Modelo \"$modelName\" instalado com sucesso!';
  }

  @override
  String get aiPickProviderBadgeDesktopOnly => 'SOMENTE PARA COMPUTADOR';

  @override
  String get aiPickProviderBadgeNew => 'NOVO';

  @override
  String get aiPickProviderBadgeRecommended => 'RECOMENDADO';

  @override
  String get aiPickProviderContinueButton => 'Continuar';

  @override
  String get aiPickProviderDontShowAgainButton => 'Não mostre novamente';

  @override
  String get aiPickProviderFooterHint =>
      'Você pode adicionar mais provedores posteriormente em Configurações → IA. Sua chave de API é armazenada localmente.';

  @override
  String get aiPickProviderModalTitle => 'Configurar recursos de IA';

  @override
  String get aiPickProviderSubtitle =>
      'Escolha um provedor para começar. Configuraremos modelos e um perfil inicial automaticamente.';

  @override
  String get aiProfileCardInUseBadge => 'Em uso';

  @override
  String get aiProfileModelPickerSearchHint => 'Pesquisar modelos…';

  @override
  String get aiProfileSlotModelMissing => 'faltando';

  @override
  String get aiPromptGenerationPickerTitle =>
      'Escolha um modelo de geração de prompt';

  @override
  String get aiProviderAlibabaName => 'Nuvem Alibaba (Qwen)';

  @override
  String get aiProviderAnthropicName => 'Claude antrópico';

  @override
  String get aiProviderCardDraftBadge => 'ESBOÇO';

  @override
  String get aiProviderCardFixButton => 'Correção';

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
      other: '$count modelos · último usado $lastUsed',
      one: '1 modelo · último usado $lastUsed',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderCardOllamaHint =>
      'Certifique-se de que Ollama esteja em execução';

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
  String get aiProviderCardStatusInvalidKey => 'Chave inválida';

  @override
  String get aiProviderCardStatusOffline =>
      'Off-line · Certifique-se de que Ollama esteja em execução';

  @override
  String get aiProviderCardStatusOfflineShort => 'Off-line';

  @override
  String get aiProviderConnectBackToProviders => 'Voltar para provedores';

  @override
  String get aiProviderConnectBreadcrumbAdd => 'Adicionar provedor';

  @override
  String get aiProviderConnectFieldBaseUrlHint =>
      'Deixe em branco para usar o endpoint oficial';

  @override
  String get aiProviderConnectFieldBaseUrlLabelOptional =>
      'URL base (opcional)';

  @override
  String get aiProviderConnectFieldBaseUrlPlaceholder =>
      'https://api.example.com';

  @override
  String get aiProviderConnectFieldDisplayNameHint =>
      'Exibido na sua lista de provedores';

  @override
  String get aiProviderConnectionCheckingLabel =>
      'Verificando chave, listando modelos disponíveis…';

  @override
  String aiProviderConnectionFailedBadResponseDetail(String type) {
    return 'Formato de resposta inesperado: $type';
  }

  @override
  String aiProviderConnectionFailedHttpDetail(int status, String message) {
    return 'HTTP $status · $message';
  }

  @override
  String get aiProviderConnectionFailedInvalidBaseUrlDetail =>
      'O URL base deve incluir esquema http(s) e host (por exemplo, https://api.example.com)';

  @override
  String aiProviderConnectionFailedNetworkDetail(String message) {
    return '$message';
  }

  @override
  String get aiProviderConnectionFailedTimeoutDetail => 'A solicitação expirou';

  @override
  String aiProviderConnectionFailedTitle(String providerName) {
    return 'Não foi possível entrar em contato com $providerName. Verifique a chave ou sua rede.';
  }

  @override
  String get aiProviderConnectionRetestButton => 'Teste novamente';

  @override
  String get aiProviderConnectionRetryButton => 'Tentar novamente';

  @override
  String aiProviderConnectionVerifiedSubtitle(int count, int ms) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modelos disponíveis em sua conta · respondeu em ${ms}ms',
      one: '1 modelo disponível em sua conta · respondeu em ${ms}ms',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderConnectionVerifiedTitle => 'Conexão verificada';

  @override
  String aiProviderConnectKeyHelperLink(String url) {
    return 'Obtenha uma chave em $url';
  }

  @override
  String get aiProviderConnectKeyHiddenLabel => 'Oculto';

  @override
  String get aiProviderConnectKeyPrivacyHint =>
      'Sua chave API nunca sai do seu dispositivo.';

  @override
  String aiProviderConnectPageTitle(String providerName) {
    return 'Conectar $providerName';
  }

  @override
  String get aiProviderConnectSaveAndContinue => 'Salvar e continuar';

  @override
  String get aiProviderConnectSaveAsDraft => 'Salvar como rascunho';

  @override
  String get aiProviderConnectSavedAsDraftToast => 'Salvo como rascunho';

  @override
  String get aiProviderConnectStepChoose => 'Escolha o provedor';

  @override
  String get aiProviderConnectStepConnect => 'Conectar';

  @override
  String get aiProviderConnectStepReview => 'Revisão';

  @override
  String get aiProviderDetailAddModelButton => 'Adicionar modelo';

  @override
  String get aiProviderDetailApiKeyLabel => 'Chave de API';

  @override
  String get aiProviderDetailBackTooltip => 'Voltar';

  @override
  String get aiProviderDetailBaseUrlLabel => 'URL base';

  @override
  String get aiProviderDetailConnectionTitle => 'Conexão';

  @override
  String get aiProviderDetailDangerZoneTitle => 'Zona de perigo';

  @override
  String get aiProviderDetailDisplayNameLabel => 'Nome de exibição';

  @override
  String get aiProviderDetailEditButton => 'Editar';

  @override
  String get aiProviderDetailEditTooltip => 'Editar provedor';

  @override
  String get aiProviderDetailLoadError =>
      'Não foi possível carregar este provedor. Tente novamente na lista Configurações de IA.';

  @override
  String get aiProviderDetailMissingMessage =>
      'Este provedor não está mais disponível.';

  @override
  String aiProviderDetailModelsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Modelos · $count',
      one: 'Modelos · 1',
      zero: 'Models',
    );
    return '$_temp0';
  }

  @override
  String get aiProviderDetailNoModelsMessage =>
      'Ainda não há modelos. Adicione um para começar a usar este provedor.';

  @override
  String get aiProviderDetailPageTitle => 'Detalhes do provedor';

  @override
  String get aiProviderDetailProfilesUsingTitle =>
      'Perfis que usam este provedor';

  @override
  String get aiProviderDetailRemoveButton => 'Remover provedor';

  @override
  String get aiProviderDetailRemoveDescription =>
      'Exclui o provedor e todos os modelos que dependem dele. Isto não pode ser desfeito.';

  @override
  String get aiProviderDetailRemoveTitle => 'Remover este provedor';

  @override
  String get aiProviderDetailValueUnset => 'Não definido';

  @override
  String get aiProviderEmbeddedRuntimeHint =>
      'É executado integrado no processo do aplicativo Apple. Nenhum servidor local ou URL base é necessário.';

  @override
  String get aiProviderGeminiName => 'Google Gêmeos';

  @override
  String get aiProviderGenericOpenAiName => 'Compatível com OpenAI';

  @override
  String get aiProviderMeliousName => 'Melious.ai';

  @override
  String get aiProviderMistralName => 'Mistral';

  @override
  String get aiProviderMlxAudioName => 'Áudio MLX (local)';

  @override
  String get aiProviderNebiusAiStudioName => 'Estúdio de IA Nebius';

  @override
  String get aiProviderOllamaName => 'Ollama';

  @override
  String get aiProviderOmlxName => 'oMLX (local)';

  @override
  String get aiProviderOpenAiName => 'OpenAI';

  @override
  String get aiProviderOpenRouterName => 'OpenRouter';

  @override
  String get aiProviderTaglineAlibaba =>
      'Modelos Qwen · multimodal · contexto longo';

  @override
  String get aiProviderTaglineAnthropic => 'Família Claude · contexto longo';

  @override
  String get aiProviderTaglineGemini => 'Multimodal · transcrição de áudio';

  @override
  String get aiProviderTaglineMelious =>
      'Hospedado na UE · catálogo dinâmico · roteamento ecológico';

  @override
  String get aiProviderTaglineMlxAudio =>
      'Incorporado · Apple Silicon · áudio local';

  @override
  String get aiProviderTaglineOllama =>
      'Funciona localmente · sem chamadas na nuvem';

  @override
  String get aiProviderTaglineOmlx =>
      'Inferência MLX local · Compatível com OpenAI';

  @override
  String get aiProviderTaglineOpenAi => 'Família GPT · visão + raciocínio';

  @override
  String get aiProviderUnknownName => 'Provedor de IA';

  @override
  String get aiProviderVoxtralName => 'Voxtral (local)';

  @override
  String get aiProviderWhisperName => 'Sussurro (local)';

  @override
  String get aiResponseDeleteCancel => 'Cancelar';

  @override
  String get aiResponseDeleteConfirm => 'Excluir';

  @override
  String get aiResponseDeleteError =>
      'Falha ao excluir a resposta do AI. Por favor, tente novamente.';

  @override
  String get aiResponseDeleteTitle => 'Excluir resposta de IA';

  @override
  String get aiResponseDeleteWarning =>
      'Tem certeza de que deseja excluir esta resposta de IA? Isto não pode ser desfeito.';

  @override
  String get aiResponseShowLess => 'Mostrar menos';

  @override
  String get aiResponseShowMore => 'Mostrar mais';

  @override
  String get aiRunningActivityOpenProgress => 'Mostrar o progresso da IA';

  @override
  String get aiSettingsAddedLabel => 'Adicionado';

  @override
  String get aiSettingsAddModelButton => 'Adicionar modelo';

  @override
  String get aiSettingsAddModelErrorDescription =>
      'Algo deu errado ao adicionar o modelo. Por favor, tente novamente.';

  @override
  String get aiSettingsAddModelErrorTitle =>
      'Não foi possível adicionar o modelo';

  @override
  String get aiSettingsAddModelTooltip =>
      'Adicione este modelo ao seu provedor';

  @override
  String get aiSettingsAddProfileButton => 'Adicionar perfil';

  @override
  String get aiSettingsAddProviderButton => 'Adicionar provedor';

  @override
  String get aiSettingsAgentWakeConcurrencyDescription =>
      'Escolha quantos agentes diferentes podem executar inferência ao mesmo tempo. Valores mais altos respondem mais rapidamente, mas utilizam mais capacidade do provedor e do dispositivo.';

  @override
  String get aiSettingsAgentWakeConcurrencyLabel =>
      'Agente simultâneo é ativado';

  @override
  String get aiSettingsClearAllFiltersTooltip => 'Limpar todos os filtros';

  @override
  String get aiSettingsClearFiltersButton => 'Limpar';

  @override
  String get aiSettingsCounterModels => 'Modelos';

  @override
  String get aiSettingsCounterProfiles => 'Perfis';

  @override
  String get aiSettingsCounterProviders => 'Provedores';

  @override
  String get aiSettingsEmptyDescription =>
      'Adicione um para desbloquear transcrição, reconhecimento de imagem, geração de imagem e pesquisa semântica.';

  @override
  String get aiSettingsEmptyTitle => 'Ainda não há provedores';

  @override
  String aiSettingsFilterByCapabilityTooltip(String capability) {
    return 'Filtrar por capacidade $capability';
  }

  @override
  String aiSettingsFilterByProviderTooltip(String provider) {
    return 'Filtrar por $provider';
  }

  @override
  String get aiSettingsFilterByReasoningTooltip =>
      'Filtrar por capacidade de raciocínio';

  @override
  String get aiSettingsFtueBannerDescription =>
      'Demora cerca de um minuto. Lotti configurará modelos e um perfil inicial para você.';

  @override
  String get aiSettingsFtueBannerStartButton => 'Iniciar configuração';

  @override
  String get aiSettingsFtueBannerTitle =>
      'Adicione seu primeiro provedor de IA';

  @override
  String get aiSettingsModalityAudio => 'Áudio';

  @override
  String get aiSettingsModalityText => 'Texto';

  @override
  String get aiSettingsModalityVision => 'Visão';

  @override
  String get aiSettingsNoModelsConfigured => 'Nenhum modelo de IA configurado';

  @override
  String get aiSettingsNoProvidersConfigured =>
      'Nenhum provedor de IA configurado';

  @override
  String get aiSettingsPageLead =>
      'Configure os provedores de IA, os modelos que Lotti pode chamar e os perfis de inferência que decidem qual modelo lida com qual tarefa.';

  @override
  String get aiSettingsPageTitle => 'Configurações de IA';

  @override
  String get aiSettingsReasoningLabel => 'Raciocínio';

  @override
  String get aiSettingsRemoveModelTooltip =>
      'Remova este modelo do seu provedor';

  @override
  String get aiSettingsSearchHint =>
      'Pesquise fornecedores, modelos, perfis...';

  @override
  String get aiSettingsSearchHintShort => 'Pesquisar';

  @override
  String get aiSettingsTabModels => 'Modelos';

  @override
  String get aiSettingsTabProfiles => 'Perfis';

  @override
  String get aiSettingsTabProviders => 'Provedores';

  @override
  String get aiSetupPreviewAcceptButton => 'Aceitar e finalizar';

  @override
  String get aiSetupPreviewAlreadyAddedSectionLabel => 'Já adicionado';

  @override
  String aiSetupPreviewCategoryFooter(String categoryName) {
    return 'Configure uma categoria de teste $categoryName para experimentar.';
  }

  @override
  String aiSetupPreviewConnectedHeader(String providerName) {
    return '$providerName conectado';
  }

  @override
  String get aiSetupPreviewCustomizeButton => 'Personalizar';

  @override
  String get aiSetupPreviewLead =>
      'Revise o que Lotti irá adicionar. Desmarque tudo o que você não deseja; você sempre pode configurá-lo manualmente mais tarde.';

  @override
  String get aiSetupPreviewLiveBadge => 'Ao vivo';

  @override
  String aiSetupPreviewModalTitle(String providerName) {
    return 'Configuração de $providerName';
  }

  @override
  String get aiSetupPreviewModelsSectionLabel => 'Modelos';

  @override
  String get aiSetupPreviewProfileSectionLabel => 'Perfil de inferência';

  @override
  String get aiSetupPreviewProfileSetActiveBadge => 'Definir ativo';

  @override
  String aiSetupResultBulletCategoryCreated(String categoryName) {
    return 'Configure uma categoria de teste $categoryName para experimentar';
  }

  @override
  String aiSetupResultBulletCategoryReused(String categoryName) {
    return 'Reutilizando a categoria de teste existente $categoryName';
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
    return 'Perfil de inferência criado $profileName';
  }

  @override
  String aiSetupResultErrorsHeader(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count problemas',
      one: '1 issue',
    );
    return '$_temp0 durante a configuração';
  }

  @override
  String aiSetupResultHeader(String providerName) {
    return '$providerName está conectado';
  }

  @override
  String aiSetupResultKnownModelsMissing(String providerName) {
    return 'Falha ao encontrar as configurações necessárias do modelo $providerName';
  }

  @override
  String get aiSetupResultLead =>
      'Nós configuramos as coisas para você. Os recursos de IA estão prontos para uso em seu diário.';

  @override
  String aiSetupResultModalTitle(String providerName) {
    return '$providerName pronto';
  }

  @override
  String get aiSetupResultStartUsingButton => 'Comece a usar IA';

  @override
  String get aiSetupWizardCreatesOptimized =>
      'Cria modelos otimizados, prompts e uma categoria de teste';

  @override
  String aiSetupWizardDescription(String providerName) {
    return 'Configurar ou atualizar modelos, prompts e categoria de teste para $providerName';
  }

  @override
  String get aiSetupWizardRunButton => 'Executar configuração';

  @override
  String get aiSetupWizardRunLabel => 'Execute o assistente de configuração';

  @override
  String get aiSetupWizardRunningButton => 'Correndo...';

  @override
  String get aiSetupWizardSafeToRunMultiple =>
      'É seguro executar várias vezes - os itens existentes serão mantidos';

  @override
  String get aiSetupWizardTitle => 'Assistente de configuração de IA';

  @override
  String get aiSummaryPlayTooltip => 'Resumo do jogo';

  @override
  String get aiSummaryPreparingTooltip => 'Preparando áudio';

  @override
  String get aiSummarySpeakTooltip => 'Leia o resumo em voz alta localmente';

  @override
  String get aiSummaryStopTooltip => 'Pare';

  @override
  String get aiSummaryThinkingLabel => 'Pensando…';

  @override
  String get aiSummaryTtsUnavailable =>
      'A conversão de texto em fala não está disponível';

  @override
  String get aiTaskSummaryTitle => 'Resumo da tarefa de IA';

  @override
  String get aiTranscriptionPickerDefaultBadge => 'Padrão';

  @override
  String get aiTranscriptionPickerTitle => 'Escolha um modelo de transcrição';

  @override
  String get apiKeyAddPageTitle => 'Adicionar provedor';

  @override
  String get apiKeyAuthenticationDescription => 'Proteja sua conexão API';

  @override
  String get apiKeyAuthenticationTitle => 'Autenticação';

  @override
  String get apiKeyAvailableModelsDescription =>
      'Adicione rapidamente modelos pré-configurados para este provedor';

  @override
  String get apiKeyAvailableModelsTitle => 'Modelos Disponíveis';

  @override
  String get apiKeyBaseUrlLabel => 'URL base';

  @override
  String get apiKeyDisplayNameHint => 'Digite um nome amigável';

  @override
  String get apiKeyDisplayNameLabel => 'Nome de exibição';

  @override
  String get apiKeyDynamicModelsDescription =>
      'Pesquise o catálogo de modelos ao vivo deste fornecedor e adicione qualquer modelo';

  @override
  String get apiKeyEditGoBackButton => 'Voltar';

  @override
  String get apiKeyEditLoadError =>
      'Falha ao carregar a configuração da chave de API';

  @override
  String get apiKeyEditLoadErrorRetry =>
      'Tente novamente ou entre em contato com o suporte';

  @override
  String get apiKeyEditPageTitle => 'Editar provedor';

  @override
  String get apiKeyHideTooltip => 'Ocultar chave de API';

  @override
  String get apiKeyInputHint => 'Insira sua chave API';

  @override
  String get apiKeyInputLabel => 'Chave de API';

  @override
  String apiKeyKnownModelInputLabel(String modalities) {
    return 'Em: $modalities';
  }

  @override
  String apiKeyKnownModelOutputLabel(String modalities) {
    return 'Fora: $modalities';
  }

  @override
  String get apiKeyProviderConfigDescription =>
      'Defina as configurações do seu provedor de inferência de IA';

  @override
  String get apiKeyProviderConfigTitle => 'Configuração do provedor';

  @override
  String get apiKeyProviderTypeHint => 'Selecione um tipo de provedor';

  @override
  String get apiKeyProviderTypeLabel => 'Tipo de provedor';

  @override
  String get apiKeyShowTooltip => 'Mostrar chave de API';

  @override
  String get audioRecordingCancel => 'Cancelar';

  @override
  String get audioRecordingDiscardDialogBody =>
      'Esta gravação será excluída. Nenhuma entrada de áudio, transcrição ou resumo da tarefa será criada.';

  @override
  String get audioRecordingDiscardDialogCancel => 'Continue gravando';

  @override
  String get audioRecordingDiscardDialogConfirm => 'Descartar';

  @override
  String get audioRecordingDiscardDialogTitle => 'Descartar gravação?';

  @override
  String get audioRecordingPause => 'Pausar';

  @override
  String get audioRecordingResume => 'Retomar';

  @override
  String get audioRecordings => 'Gravações de áudio';

  @override
  String get audioRecordingStop => 'Parar';

  @override
  String backfillAdvancedRecoveryActions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ações',
      one: '1 ação',
    );
    return '$_temp0';
  }

  @override
  String get backfillAdvancedRecoveryTitle => 'Recuperação avançada';

  @override
  String get backfillAgentClocksDescription =>
      'Adiciona um relógio vetorial às entidades e ligações de agente guardadas sem um, para que os teus outros dispositivos as possam ordenar e receber.';

  @override
  String get backfillAgentClocksFailed =>
      'Não foi possível reparar os relógios vetoriais dos agentes';

  @override
  String get backfillAgentClocksTitle => 'Relógios vetoriais dos agentes';

  @override
  String get backfillAgentClocksTrigger => 'Reparar relógios vetoriais';

  @override
  String get backfillAskPeersConfirmAccept => 'Pergunte aos colegas';

  @override
  String backfillAskPeersConfirmContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Isso faz com que todas $count entradas de log de sequência não resolvíveis voltem a ser perdidas, para que a varredura de preenchimento normal pergunte novamente aos pares. Os pares que ainda possuem a carga responderão; entradas verdadeiramente irrecuperáveis serão retiradas novamente após a janela de anistia de 7 dias.',
      one:
          'Isso transforma 1 entrada de log de sequência insolúvel de volta em falta, para que a varredura de preenchimento normal pergunte novamente aos pares. Os pares que ainda possuem a carga responderão; entradas verdadeiramente irrecuperáveis ​​serão retiradas novamente após a janela de anistia de 7 dias.',
    );
    return '$_temp0';
  }

  @override
  String get backfillAskPeersConfirmTitle =>
      'Perguntar novamente aos colegas sobre entradas insolúveis?';

  @override
  String get backfillAskPeersDescription =>
      'Inverta todas as entradas de log de sequência não resolvidas de volta para ausentes e deixe o backfill normal varrer novamente os pares.';

  @override
  String get backfillAskPeersProcessing => 'Reabrindo…';

  @override
  String get backfillAskPeersTitle => 'Pergunte aos colegas o que é insolúvel';

  @override
  String backfillAskPeersTrigger(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Peça aos colegas $count entradas',
      one: 'Peça aos colegas 1 entrada',
    );
    return '$_temp0';
  }

  @override
  String get backfillCatchUpDescription =>
      'Extraia entradas ausentes recentes de colegas agora mesmo.';

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
      'Solicite todas as entradas ausentes, independentemente da idade. Use isto para recuperar lacunas de sincronização mais antigas.';

  @override
  String get backfillManualProcessing => 'Processando...';

  @override
  String get backfillManualTitle => 'Preenchimento manual';

  @override
  String get backfillManualTrigger => 'Solicitar entradas ausentes';

  @override
  String get backfillReRequestDescription =>
      'Solicite novamente entradas que foram solicitadas, mas nunca recebidas. Use isto quando as respostas estiverem travadas.';

  @override
  String get backfillReRequestProcessing => 'Solicitando novamente...';

  @override
  String get backfillReRequestTitle => 'Nova solicitação pendente';

  @override
  String get backfillReRequestTrigger =>
      'Solicitar novamente entradas pendentes';

  @override
  String get backfillResetUnresolvableDescription =>
      'Redefina as entradas marcadas como insolúveis de volta para ausentes para que possam ser solicitadas novamente. Use após o repovoamento do log de sequência.';

  @override
  String get backfillResetUnresolvableProcessing => 'Redefinindo...';

  @override
  String get backfillResetUnresolvableTitle => 'Redefinir insolúvel';

  @override
  String get backfillResetUnresolvableTrigger =>
      'Redefinir entradas insolúveis';

  @override
  String get backfillRetireStuckConfirmAccept => 'Aposente-se agora';

  @override
  String backfillRetireStuckConfirmContent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Isso marca $count entradas de log de sequência atualmente abertas (ausentes ou solicitadas) como insolúveis. Use isto para desbloquear a marca d\'água quando as entradas ficarem presas por um tempo sem que o período de anistia de 7 dias tenha passado. As entradas ainda poderão ser ressuscitadas se sua carga chegar posteriormente ao disco com um relógio vetorial válido.',
      one:
          'Isso marca 1 entrada de log de sequência atualmente aberta (ausente ou solicitada) como insolúvel. Use isto para desbloquear a marca d\'água quando as entradas ficarem presas por um tempo sem que o período de anistia de 7 dias tenha passado. As entradas ainda poderão ser ressuscitadas se sua carga útil chegar posteriormente ao disco com um relógio de vetor válido.',
    );
    return '$_temp0';
  }

  @override
  String get backfillRetireStuckConfirmTitle =>
      'Descontinuar entradas travadas agora?';

  @override
  String get backfillRetireStuckDescription =>
      'Força todas as entradas de log de sequência solicitadas ou ausentes atualmente abertas a serem insolúveis. Ignora a anistia de 7 dias – use apenas para linhas travadas que bloqueiam a marca d’água.';

  @override
  String get backfillRetireStuckProcessing => 'Aposentar-se…';

  @override
  String get backfillRetireStuckTitle => 'Remover entradas travadas';

  @override
  String backfillRetireStuckTrigger(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Retirar $count entradas travadas',
      one: 'Retirar 1 entrada travada',
    );
    return '$_temp0';
  }

  @override
  String get backfillSettingsSubtitle =>
      'Gerenciar a recuperação de lacunas de sincronização';

  @override
  String get backfillSettingsTitle => 'Sincronização de preenchimento';

  @override
  String get backfillStatsBackfilled => 'Preenchido';

  @override
  String get backfillStatsBurned => 'Queimado';

  @override
  String get backfillStatsDeleted => 'Excluído';

  @override
  String get backfillStatsMissing => 'Desaparecido';

  @override
  String get backfillStatsNoData => 'Não há dados de sincronização disponíveis';

  @override
  String get backfillStatsReceived => 'Recebido';

  @override
  String get backfillStatsRefresh => 'Atualizar estatísticas';

  @override
  String get backfillStatsRequested => 'Solicitado';

  @override
  String get backfillStatsTitle => 'Sincronizar estatísticas';

  @override
  String get backfillStatsTotalEntries => 'Total de entradas';

  @override
  String get backfillStatsUnresolvable => 'Insolúvel';

  @override
  String get backfillStatusInboundQueue => 'Fila de entrada';

  @override
  String get backfillStatusMissing => 'Desaparecido';

  @override
  String get backfillStatusSkipped => 'Ignorado';

  @override
  String get backfillToggleDescription =>
      'Solicita entradas ausentes das últimas 24 horas.';

  @override
  String get backfillToggleTitle => 'Preenchimento automático';

  @override
  String get basicSettings => 'Configurações básicas';

  @override
  String get calendarHasPlanLabel => 'Tem um plano';

  @override
  String get calendarTodayLabel => 'Hoje';

  @override
  String get cancelButton => 'Cancelar';

  @override
  String get categoryActiveDescription =>
      'As categorias inativas não aparecerão nas listas de seleção';

  @override
  String get categoryActiveSwitchDescription =>
      'Selecionável para novas entradas';

  @override
  String get categoryAiDefaultsDescription =>
      'Defina o perfil de IA padrão e o modelo de agente para novas tarefas nesta categoria';

  @override
  String get categoryAiDefaultsTitle => 'Padrões de IA';

  @override
  String get categoryAutomaticAgentWakesDescription =>
      'Let the assistant in this category update itself when a task changes. Applies to new tasks; existing ones keep their own setting.';

  @override
  String get categoryAutomaticAgentWakesLabel =>
      'Wake the assistant automatically';

  @override
  String get categoryAutomaticInferenceDescription =>
      'Transcribe new audio and analyze new images in this category automatically';

  @override
  String get categoryAutomaticInferenceLabel => 'Automatic inference';

  @override
  String get categoryCreationError =>
      'Falha ao criar categoria. Por favor, tente novamente.';

  @override
  String get categoryDayPlanDescription =>
      'Disponibilize esta categoria para seleção no plano diário';

  @override
  String get categoryDayPlanLabel => 'Planejamento do dia';

  @override
  String get categoryDefaultEventTemplateHint => 'Selecione um modelo';

  @override
  String get categoryDefaultEventTemplateLabel =>
      'Modelo de agente de eventos padrão';

  @override
  String get categoryDefaultLanguageDescription =>
      'Defina um idioma padrão para tarefas nesta categoria';

  @override
  String get categoryDefaultProfileHint => 'Selecione um perfil';

  @override
  String get categoryDefaultTemplateHint => 'Selecione um modelo';

  @override
  String get categoryDefaultTemplateLabel => 'Modelo de agente padrão';

  @override
  String get categoryDeleteConfirm => 'Sim, excluir esta categoria';

  @override
  String get categoryDeleteConfirmation =>
      'Esta ação não pode ser desfeita. Todas as entradas nesta categoria permanecerão, mas não serão mais categorizadas.';

  @override
  String get categoryDeleteTitle => 'Excluir categoria?';

  @override
  String get categoryFavoriteBadgeLabel => 'Favorito';

  @override
  String get categoryFavoriteDescription =>
      'Marcar esta categoria como favorita';

  @override
  String get categoryIconChooseHint => 'Selecione um ícone';

  @override
  String get categoryIconCreateHint => 'Selecione um ícone';

  @override
  String get categoryIconEditHint => 'Selecione um ícone diferente';

  @override
  String get categoryIconLabel => 'Ícone';

  @override
  String get categoryIconPickerTitle => 'Escolha o ícone';

  @override
  String get categoryNameRequired => 'O nome da categoria é obrigatório';

  @override
  String get categoryNotFound => 'Categoria não encontrada';

  @override
  String get categoryPrivateBadgeLabel => 'Privado';

  @override
  String get categoryPrivateDescription =>
      'Visível apenas quando entradas privadas são mostradas';

  @override
  String get categorySearchPlaceholder => 'Pesquisar categorias...';

  @override
  String get changeSetCardTitle => 'Mudanças propostas';

  @override
  String get changeSetConfirmAll => 'Confirme tudo';

  @override
  String changeSetConfirmAllPartialIssues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens tiveram problemas parciais',
      one: '1 item teve problemas parciais',
    );
    return '$_temp0';
  }

  @override
  String get changeSetConfirmError => 'Falha ao aplicar a alteração';

  @override
  String get changeSetItemConfirmed => 'Alteração aplicada';

  @override
  String changeSetItemConfirmedWithWarning(String warning) {
    return 'Aplicado com aviso: $warning';
  }

  @override
  String get changeSetItemRejected => 'Alteração rejeitada';

  @override
  String changeSetPendingCount(int count) {
    return '$count pendentes';
  }

  @override
  String get changeSetSwipeConfirm => 'Confirmar';

  @override
  String get changeSetSwipeReject => 'Rejeitar';

  @override
  String get chatInputCancelRealtime => 'Cancelar (Esc)';

  @override
  String get chatInputCancelRecording => 'Cancelar gravação (Esc)';

  @override
  String get chatInputConfigureModel => 'Configurar modelo';

  @override
  String get chatInputHintDefault =>
      'Pergunte sobre suas tarefas e produtividade...';

  @override
  String get chatInputHintSelectModel =>
      'Selecione um modelo para começar a conversar';

  @override
  String get chatInputListening => 'Ouvindo...';

  @override
  String get chatInputNoAudioRecorded => 'No audio was recorded. Try again.';

  @override
  String get chatInputPleaseWait => 'Por favor, espere...';

  @override
  String get chatInputProcessing => 'Processando...';

  @override
  String get chatInputRecordVoice => 'Gravar mensagem de voz';

  @override
  String get chatInputSendTooltip => 'Enviar mensagem';

  @override
  String get chatInputStopRealtime => 'Interromper a transcrição ao vivo';

  @override
  String get chatInputStopTranscribe => 'Pare e transcreva';

  @override
  String get checklistAddItem => 'Adicionar um novo item';

  @override
  String checklistAiConfidenceLabel(String level) {
    return 'Confiança: $level';
  }

  @override
  String get checklistAiMarkComplete => 'Marcar como concluído';

  @override
  String get checklistAiSuggestionBody => 'Este item parece estar concluído:';

  @override
  String get checklistAiSuggestionTitle => 'Sugestão de IA';

  @override
  String get checklistAllDone => 'Todos os itens concluídos!';

  @override
  String get checklistCollapseTooltip => 'Recolher';

  @override
  String checklistCompletedShort(int completed, int total) {
    return '$completed/$total concluído';
  }

  @override
  String get checklistDelete => 'Excluir lista de verificação?';

  @override
  String get checklistExpandTooltip => 'Expandir';

  @override
  String get checklistExportAsMarkdown =>
      'Exportar lista de verificação como Markdown';

  @override
  String get checklistExportFailed => 'Falha na exportação';

  @override
  String get checklistItemArchived => 'Item arquivado';

  @override
  String get checklistItemArchiveUndo => 'Desfazer';

  @override
  String get checklistItemDeleteCancel => 'Cancelar';

  @override
  String get checklistItemDeleteConfirm => 'Confirmar';

  @override
  String get checklistItemDeleted => 'Item excluído';

  @override
  String get checklistItemDeleteWarning => 'Esta ação não pode ser desfeita.';

  @override
  String get checklistMarkdownCopied =>
      'Lista de verificação copiada como Markdown';

  @override
  String get checklistMoreTooltip => 'Mais';

  @override
  String get checklistNoneDone => 'Nenhum item concluído ainda.';

  @override
  String get checklistNothingToExport => 'Nenhum item para exportar';

  @override
  String get checklistProgressSemantics => 'Progresso da lista de verificação';

  @override
  String get checklistShare => 'Compartilhar';

  @override
  String get checklistShareHint => 'Pressione e segure para compartilhar';

  @override
  String get checklistsReorder => 'Reordenar';

  @override
  String get clearButton => 'Limpar';

  @override
  String get colorCustomLabel => 'Personalizado';

  @override
  String get colorLabel => 'Cor';

  @override
  String get commandPaletteNoResults =>
      'Nenhum comando disponível corresponde à sua pesquisa';

  @override
  String get commandPaletteSearchHint => 'Comandos de pesquisa…';

  @override
  String get commandPaletteTitle => 'Paleta de comandos';

  @override
  String get commonError => 'Erro';

  @override
  String get commonLoading => 'Carregando...';

  @override
  String get commonUnknown => 'Desconhecido';

  @override
  String get completeHabitFailButton => 'Perdido';

  @override
  String get completeHabitSkipButton => 'Pular';

  @override
  String get completeHabitSuccessButton => 'Sucesso';

  @override
  String get configFlagAttemptEmbeddingDescription =>
      'Quando ativado, o aplicativo tentará gerar incorporações para suas entradas para melhorar a pesquisa e sugestões de conteúdo relacionado.';

  @override
  String get configFlagDailyOsOnboardingEnabled =>
      'Passo a passo diário do sistema operacional';

  @override
  String get configFlagDailyOsOnboardingEnabledDescription =>
      'Oriente os usuários iniciantes do Daily OS através de um check-in real que transforma a fala em uma tarefa e um plano diário.';

  @override
  String get configFlagEnableAgentsPage => 'Ativar página Agentes';

  @override
  String get configFlagEnableAgentsPageDescription =>
      'Mostre a página Agentes na navegação principal. Acompanhe a saúde dos seus agentes de metas num relance e confira cada um deles.';

  @override
  String get configFlagEnableAiStreaming =>
      'Habilite o streaming de IA para ações de tarefas';

  @override
  String get configFlagEnableAiStreamingDescription =>
      'Transmita respostas de IA para ações relacionadas a tarefas. Desligue para armazenar respostas em buffer e manter a IU mais suave.';

  @override
  String get configFlagEnableAiSummaryTts => 'Reprodução de resumo de IA';

  @override
  String get configFlagEnableAiSummaryTtsDescription =>
      'Mostre o botão de conversão de texto em fala local nos resumos de IA de tarefas. Requer um modelo MLX Audio TTS instalado.';

  @override
  String get configFlagEnableDailyOs => 'Ativar DailyOS';

  @override
  String get configFlagEnableDailyOsDescription =>
      'Mostrar o DailyOS na navegação principal.';

  @override
  String get configFlagEnableDashboardsPage => 'Ativar página Painéis';

  @override
  String get configFlagEnableDashboardsPageDescription =>
      'Mostre a página Painéis na navegação principal. Visualize seus dados e insights em painéis personalizáveis.';

  @override
  String get configFlagEnableEmbeddings => 'Gerar incorporações';

  @override
  String get configFlagEnableEvents => 'Habilitar eventos';

  @override
  String get configFlagEnableEventsDescription =>
      'Mostre o recurso Eventos para criar, rastrear e gerenciar eventos em seu diário.';

  @override
  String get configFlagEnableForkHealing => 'Cura do garfo do agente';

  @override
  String get configFlagEnableForkHealingDescription =>
      'Cure históricos de agentes divergentes do uso de vários dispositivos, mesclando-os no próximo despertar.';

  @override
  String get configFlagEnableHabitsPage => 'Habilitar página de hábitos';

  @override
  String get configFlagEnableHabitsPageDescription =>
      'Mostre a página Hábitos na navegação principal. Acompanhe e gerencie seus hábitos diários aqui.';

  @override
  String get configFlagEnableLogging => 'Habilitar registro';

  @override
  String get configFlagEnableLoggingDescription =>
      'Habilite o registro detalhado para fins de depuração. Isso pode afetar o desempenho.';

  @override
  String get configFlagEnableMatrix => 'Ativar sincronização Matrix';

  @override
  String get configFlagEnableMatrixDescription =>
      'Habilite a integração do Matrix para sincronizar suas entradas entre dispositivos e com outros usuários do Matrix.';

  @override
  String get configFlagEnableNotifications => 'Ativar notificações?';

  @override
  String get configFlagEnableNotificationsDescription =>
      'Receba notificações de lembretes, atualizações e eventos importantes.';

  @override
  String get configFlagEnableProjects => 'Habilitar projetos';

  @override
  String get configFlagEnableProjectsDescription =>
      'Mostre recursos de gerenciamento de projetos para organizar tarefas em projetos.';

  @override
  String get configFlagEnableSessionRatings =>
      'Habilitar classificações de sessão';

  @override
  String get configFlagEnableSessionRatingsDescription =>
      'Solicita uma classificação rápida da sessão quando você interrompe um cronômetro.';

  @override
  String get configFlagEnableTooltip => 'Ativar dicas de ferramentas';

  @override
  String get configFlagEnableTooltipDescription =>
      'Mostre dicas úteis em todo o aplicativo para guiá-lo pelos recursos.';

  @override
  String get configFlagEnableVectorSearch => 'Pesquisa vetorial';

  @override
  String get configFlagEnableVectorSearchDescription =>
      'Ative a pesquisa vetorial em filtros de tarefas. Requer que os embeddings estejam habilitados e o Ollama em execução.';

  @override
  String get configFlagEnableWhatsNew => 'Mostrar o que há de novo';

  @override
  String get configFlagEnableWhatsNewDescription =>
      'Destaque novos recursos e alterações na árvore Configurações.';

  @override
  String get configFlagPrivate => 'Mostrar entradas privadas?';

  @override
  String get configFlagPrivateDescription =>
      'Habilite isto para tornar suas entradas privadas por padrão. As entradas privadas são visíveis apenas para você.';

  @override
  String get configFlagRecordLocation => 'Local de registro';

  @override
  String get configFlagRecordLocationDescription =>
      'Registre automaticamente sua localização com novas entradas. Isso ajuda na organização e pesquisa baseada em localização.';

  @override
  String get configFlagResendAttachments => 'Reenviar anexos';

  @override
  String get configFlagResendAttachmentsDescription =>
      'Ative esta opção para reenviar automaticamente uploads de anexos com falha quando a conexão for restaurada.';

  @override
  String get conflictApplyButton => 'Aplicar';

  @override
  String get conflictApplyFailedTitle => 'Não foi possível aplicar a resolução';

  @override
  String conflictBannerAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dias atrás',
      one: '1 dia atrás',
    );
    return '$_temp0';
  }

  @override
  String conflictBannerAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count h atrás',
      one: '1 h atrás',
    );
    return '$_temp0';
  }

  @override
  String get conflictBannerAgoJustNow => 'agora mesmo';

  @override
  String conflictBannerAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutos atrás',
      one: '1 minuto atrás',
    );
    return '$_temp0';
  }

  @override
  String conflictBannerDivergedAgo(String entity, String ago) {
    return '$entity · divergiu $ago';
  }

  @override
  String conflictBannerFieldsDifferList(String fields) {
    return 'Difere em: $fields';
  }

  @override
  String get conflictCombineApply => 'Aplicar combinado';

  @override
  String get conflictCombineStartFrom => 'Começar de';

  @override
  String get conflictConfirmDeletion => 'Confirmar exclusão';

  @override
  String get conflictDeleteVsEditDescription =>
      'Esta entrada foi editada em um dispositivo e excluída em outro. Nada é removido até que você escolha.';

  @override
  String get conflictDeleteVsEditTitle => 'Excluído em um dispositivo';

  @override
  String get conflictDetailEntryNotFoundTitle => 'Entrada não encontrada';

  @override
  String get conflictDetailLoadErrorTitle =>
      'Não foi possível carregar o conflito';

  @override
  String get conflictDetailNotFoundTitle => 'Conflito não encontrado';

  @override
  String get conflictDiffRecommended => 'Recomendado';

  @override
  String conflictDiffUnchanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count campos inalterados',
      one: '1 campo inalterado',
    );
    return '$_temp0';
  }

  @override
  String get conflictFieldBody => 'Corpo';

  @override
  String get conflictFieldCategory => 'Categoria';

  @override
  String get conflictFieldDuration => 'Duração';

  @override
  String get conflictFieldEnd => 'Fim';

  @override
  String get conflictFieldFlag => 'Bandeira';

  @override
  String get conflictFieldOther => 'Outros detalhes';

  @override
  String get conflictFieldOtherDescription =>
      'Estas versões diferem em detalhes não mostrados individualmente aqui.';

  @override
  String get conflictFieldPrivate => 'Privado';

  @override
  String get conflictFieldStarred => 'Com estrela';

  @override
  String get conflictFieldStart => 'Começar';

  @override
  String get conflictFieldTitle => 'Título';

  @override
  String get conflictFieldWordCount => 'contagem de palavras';

  @override
  String get conflictFlagFollowUp => 'Acompanhamento necessário';

  @override
  String get conflictFlagImport => 'Importado';

  @override
  String get conflictFlagNone => 'Nenhum';

  @override
  String get conflictFooterHelperLocalSelected =>
      'Manterá sua edição local e descartará a versão sincronizada.';

  @override
  String get conflictFooterHelperPickASide => 'Escolha um lado para aplicar.';

  @override
  String get conflictFooterHelperRemoteSelected =>
      'Aceitará a versão sincronizada e descartará sua edição local.';

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
      other: '$count campos diferem',
      one: '1 campo difere',
    );
    return '$_temp0';
  }

  @override
  String get conflictKeepEdited => 'Mantenha a versão editada';

  @override
  String conflictListItemSemanticsLabel(
    String status,
    String timestamp,
    String entityType,
    String id,
  ) {
    return '$status, $timestamp, $entityType, conflito $id';
  }

  @override
  String conflictListItemTooltipFullId(String id) {
    return 'ID do conflito: $id';
  }

  @override
  String get conflictMetaLocalEdit => 'edição local';

  @override
  String get conflictMetaVecPrefix => 'vec';

  @override
  String get conflictMetaViaSync => 'via sincronização';

  @override
  String conflictNotificationBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entradas foram editadas em dois dispositivos',
      one: '1 entrada foi editada em dois dispositivos',
    );
    return '$_temp0';
  }

  @override
  String get conflictNotificationTitle =>
      'A sincronização precisa da sua análise';

  @override
  String get conflictPageLeadDesktop =>
      'Diferenças destacadas inline. Clique em um lado para usar essa versão ou abra Editar e mesclar para combiná-los.';

  @override
  String get conflictPageLeadMobile =>
      'Diferenças destacadas inline. Toque em um lado para usar essa versão.';

  @override
  String get conflictPageTitle => 'Conflito de sincronização';

  @override
  String get conflictPickerCombine => 'Combine…';

  @override
  String get conflictPickerEditMerge => 'Editar e mesclar…';

  @override
  String get conflictPickerUseFromSync => 'Usar da sincronização';

  @override
  String get conflictPickerUseThisDevice => 'Use este dispositivo';

  @override
  String get conflictResolvedToast => 'Conflito resolvido';

  @override
  String get conflictsEmptyDescription =>
      'Tudo está sincronizado agora. Os itens resolvidos permanecem disponíveis no outro filtro.';

  @override
  String get conflictsEmptyTitle => 'Nenhum conflito detectado';

  @override
  String get conflictSideFromSync => 'DA SINCRONIZAÇÃO';

  @override
  String get conflictSideThisDevice => 'ESTE DISPOSITIVO';

  @override
  String get conflictsResolved => 'resolvido';

  @override
  String get conflictsUnresolved => 'não resolvido';

  @override
  String get conflictValueAbsent => 'Não definido';

  @override
  String get conflictValueNo => 'Não';

  @override
  String get conflictValueYes => 'Sim';

  @override
  String conflictWordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count palavras',
      one: '$count palavra',
    );
    return '$_temp0';
  }

  @override
  String get contactUsDiscordLabel => 'Discord';

  @override
  String get contactUsEmailSubject => 'Comentários sobre o Lotti';

  @override
  String get contactUsGithubLabel => 'GitHub';

  @override
  String get contactUsLabel => 'Fale conosco';

  @override
  String get copyAsMarkdown => 'Copiar como Markdown';

  @override
  String get copyAsText => 'Copiar como texto';

  @override
  String get correctionExampleCancel => 'Cancelar';

  @override
  String correctionExamplePending(int seconds) {
    return 'Salvando a correção em ${seconds}s...';
  }

  @override
  String get correctionExamplesEmpty =>
      'Nenhuma correção capturada ainda. Edite um item da lista de verificação para adicionar seu primeiro exemplo.';

  @override
  String get correctionExamplesSectionDescription =>
      'Quando você corrige manualmente os itens da lista de verificação, essas correções são salvas aqui e usadas para melhorar as sugestões de IA.';

  @override
  String get correctionExamplesSectionTitle =>
      'Exemplos de correção de lista de verificação';

  @override
  String correctionExamplesWarning(int count, int max) {
    return 'Você tem $count correções. Somente o $max mais recente será usado nos prompts de IA. Considere excluir exemplos antigos ou redundantes.';
  }

  @override
  String get coverArtChipActive => 'Capa';

  @override
  String get coverArtChipSet => 'Definir capa';

  @override
  String get coverArtGenerationComplete => 'Arte da capa pronta!';

  @override
  String get coverArtGenerationDismissHint =>
      'Você pode fechar isto – a geração continua em segundo plano';

  @override
  String get createButton => 'Criar';

  @override
  String get createCategoryTitle => 'Criar categoria';

  @override
  String get createEntryLabel => 'Criar nova entrada';

  @override
  String get createEntryTitle => 'Adicionar';

  @override
  String get createEntryTriggerHintFull =>
      'Adicionar uma nota, uma lista, uma nota de voz, uma imagem e mais';

  @override
  String get createNewLinkedTask => 'Criar nova tarefa vinculada…';

  @override
  String get createNewLinkedTaskTitle => 'New linked task';

  @override
  String get customColor => 'Cor personalizada';

  @override
  String get dailyOsDayPlan => 'Plano do dia';

  @override
  String get dailyOsNextActivityActionFailed =>
      'That action didn\'t finish. Your recording is still safe—try again.';

  @override
  String get dailyOsNextActivityAgentActionFailed =>
      'A ação não chegou ao fim. Não se perdeu nada — tenta de novo.';

  @override
  String get dailyOsNextActivityAgentJobDraft =>
      'A criação do teu plano do dia não chegou ao fim.';

  @override
  String get dailyOsNextActivityAgentJobModelFailed =>
      'O modelo de IA não conseguiu concluir isto.';

  @override
  String get dailyOsNextActivityAgentJobNoPlan =>
      'Ainda não há nenhum plano do dia para atualizar.';

  @override
  String get dailyOsNextActivityAgentJobParse =>
      'A leitura do teu registo não chegou ao fim.';

  @override
  String get dailyOsNextActivityAgentJobRefine =>
      'A atualização do teu plano do dia não chegou ao fim.';

  @override
  String get dailyOsNextActivityAgentJobRetryHint =>
      'Não se perdeu nada. Tenta de novo quando quiseres.';

  @override
  String get dailyOsNextActivityAgentJobSetupRequired =>
      'Ainda não há nenhum modelo de IA configurado para planear.';

  @override
  String get dailyOsNextActivityAgentJobTemporary =>
      'O serviço de IA estava ocupado ou inacessível.';

  @override
  String get dailyOsNextActivityDaySummary => 'Day summary';

  @override
  String get dailyOsNextActivityDeleteDialogBody =>
      'The audio and its pending transcription are removed from this day.';

  @override
  String get dailyOsNextActivityDeleteDialogTitle => 'Delete this recording?';

  @override
  String get dailyOsNextActivityDeleteRecording => 'Delete';

  @override
  String get dailyOsNextActivityEmpty => 'No recordings or check-ins yet.';

  @override
  String get dailyOsNextActivityLoadFailed =>
      'Your saved activity is still on this device, but it couldn\'t be loaded right now.';

  @override
  String get dailyOsNextActivityMissingAudio =>
      'This entry is retained, but its audio file isn\'t available on this device. Restore the file, then retry.';

  @override
  String get dailyOsNextActivityNeedsAttention => 'Needs attention';

  @override
  String get dailyOsNextActivityOpenAiSetup =>
      'Abrir a configuração do Daily OS';

  @override
  String get dailyOsNextActivityOpenSetup => 'Open transcription setup';

  @override
  String get dailyOsNextActivityPlanAvailable => 'Your day plan is available.';

  @override
  String get dailyOsNextActivityPlanCreated => 'Plan created';

  @override
  String get dailyOsNextActivityReady => 'Ready to use';

  @override
  String get dailyOsNextActivityRetry => 'Retry transcription';

  @override
  String get dailyOsNextActivityRetryLoad => 'Try loading again';

  @override
  String get dailyOsNextActivityRetryStep => 'Tentar de novo';

  @override
  String get dailyOsNextActivitySaved => 'Saved locally';

  @override
  String get dailyOsNextActivitySetupRequired =>
      'Your recording is safe. Set up an audio transcription model, then retry.';

  @override
  String get dailyOsNextActivitySubmitted => 'Added to day';

  @override
  String get dailyOsNextActivityTranscribing => 'Transcribing';

  @override
  String get dailyOsNextActivityTranscriptPending =>
      'Your recording is saved. The transcript is still pending.';

  @override
  String get dailyOsNextActivityUseToPlan => 'Use to build plan';

  @override
  String get dailyOsNextActivityUseToRefine => 'Use to refine';

  @override
  String get dailyOsNextActivityWaitingForNetwork => 'Waiting for connection';

  @override
  String get dailyOsNextAgendaCapacityComfortable => 'Confortável';

  @override
  String get dailyOsNextAgendaCapacityNearFull => 'Quase cheio';

  @override
  String get dailyOsNextAgendaCapacityNoPlan => 'Ainda não há plano';

  @override
  String dailyOsNextAgendaCapacityOf(String capacity) {
    return 'de $capacity';
  }

  @override
  String get dailyOsNextAgendaCapacityOver => 'Excesso de capacidade';

  @override
  String get dailyOsNextAgendaDonutLeft => 'esquerda';

  @override
  String get dailyOsNextAgendaDonutOver => 'acabou';

  @override
  String dailyOsNextAgendaHeadlineLeft(String duration) {
    return '$duration restante';
  }

  @override
  String dailyOsNextAgendaHeadlineOver(String duration) {
    return '$duration acabou';
  }

  @override
  String get dailyOsNextAgendaNoPlanBody =>
      'Seu tempo monitorado está aqui de qualquer maneira - faça um check-in e eu elaborarei um rascunho do dia em torno dele.';

  @override
  String dailyOsNextAgendaNoPlanSummary(String duration) {
    return '$duration monitorado até agora. Fale um check-in e eu elaborarei um dia em torno disso.';
  }

  @override
  String get dailyOsNextAgendaNoPlanTitle => 'Nenhum plano ainda para hoje.';

  @override
  String get dailyOsNextAgendaStateDone => 'Concluído';

  @override
  String get dailyOsNextAgendaStateInProgress => 'Em andamento';

  @override
  String get dailyOsNextAgendaStateOpen => 'Abrir';

  @override
  String get dailyOsNextAgendaStateOverdue => 'Atrasado';

  @override
  String dailyOsNextAgendaSummary(String scheduled, String capacity) {
    return '$scheduled de $capacity comprometido';
  }

  @override
  String dailyOsNextAgendaTrackedLegend(String duration, int completedCount) {
    return 'Rastreado · $duration · $completedCount concluído';
  }

  @override
  String get dailyOsNextBlockEditCategoryLabel => 'Categoria';

  @override
  String get dailyOsNextBlockEditFailed =>
      'Não foi possível atualizar o bloco. Tente novamente.';

  @override
  String get dailyOsNextBlockEditNameLabel => 'Título';

  @override
  String get dailyOsNextBlockEditOpenTask => 'Tarefa aberta';

  @override
  String get dailyOsNextBlockEditSave => 'Salvar alterações';

  @override
  String get dailyOsNextBlockEditSaved => 'Cronograma atualizado.';

  @override
  String get dailyOsNextBlockEditTimeLabel => 'Início e fim';

  @override
  String get dailyOsNextBlockEditTitle => 'Editar bloco';

  @override
  String get dailyOsNextBlockEditTooltip => 'Editar bloco';

  @override
  String get dailyOsNextBlockEditWhyLabel => 'Por que desta vez';

  @override
  String get dailyOsNextBlockMoveTooltip => 'Mover bloco';

  @override
  String get dailyOsNextBlockResizeEndTooltip => 'Ajustar final';

  @override
  String get dailyOsNextBlockResizeStartTooltip => 'Ajustar início';

  @override
  String get dailyOsNextCaptureCaptured => 'Entendi.';

  @override
  String get dailyOsNextCaptureDoneCta => 'Concluído';

  @override
  String get dailyOsNextCaptureErrorAudioPersistFailed =>
      'The recording couldn\'t be saved.';

  @override
  String get dailyOsNextCaptureErrorMicrophonePermissionDenied =>
      'A permissão do microfone foi negada.';

  @override
  String get dailyOsNextCaptureErrorNoAudioRecorded =>
      'Nenhum áudio foi gravado.';

  @override
  String get dailyOsNextCaptureErrorRecordingSavedPendingTranscription =>
      'Your recording is saved. Transcription couldn\'t finish.';

  @override
  String get dailyOsNextCaptureErrorRecordingStartFailed =>
      'A gravação não pôde ser iniciada.';

  @override
  String get dailyOsNextCaptureHeadlineCaptured => 'Isso parece certo?';

  @override
  String get dailyOsNextCaptureHeadlineLead => 'O que está em sua mente';

  @override
  String get dailyOsNextCaptureHeadlineListening => 'Estou ouvindo.';

  @override
  String get dailyOsNextCaptureHeadlineTail => 'para hoje?';

  @override
  String dailyOsNextCaptureHeadlineTailForDate(String date) {
    return 'para $date?';
  }

  @override
  String get dailyOsNextCaptureHeadlineTailTomorrow => 'para amanhã?';

  @override
  String get dailyOsNextCaptureHeadlineTailYesterday => 'para ontem?';

  @override
  String get dailyOsNextCaptureHeadlineTranscribing => 'Escrevendo isso…';

  @override
  String get dailyOsNextCaptureIdleClick => 'Clique para falar';

  @override
  String get dailyOsNextCaptureIdleExample =>
      '“Trabalho intenso esta manhã, uma caminhada depois do almoço, e-mails antes das cinco.”';

  @override
  String get dailyOsNextCaptureIdleHint =>
      'Toque para falar · digite em vez disso';

  @override
  String get dailyOsNextCaptureIdleTalk => 'Toque para falar';

  @override
  String get dailyOsNextCaptureListeningStatus => 'Ouvindo…';

  @override
  String dailyOsNextCapturePastPrompt(String date) {
    return 'Há algo que você ainda queira acompanhar a partir de $date?';
  }

  @override
  String get dailyOsNextCaptureReconcileCta => 'Revisão';

  @override
  String get dailyOsNextCaptureRecordingSavedStatus => 'Recording saved';

  @override
  String get dailyOsNextCapturesPanelTitle => 'Capturas';

  @override
  String get dailyOsNextCaptureTranscribing => 'Transcrevendo…';

  @override
  String get dailyOsNextCaptureTranscriptHint =>
      'Corrija qualquer coisa errada na transcrição antes de planejar.';

  @override
  String get dailyOsNextCaptureTranscriptLabel => 'Transcrição da revisão';

  @override
  String get dailyOsNextCaptureTypeInstead => 'Digite em vez disso';

  @override
  String get dailyOsNextCaptureVoiceButtonReset => 'Recomeçar';

  @override
  String get dailyOsNextCaptureVoiceButtonStart => 'Comece a ouvir';

  @override
  String get dailyOsNextCaptureVoiceButtonStop => 'Pare de ouvir';

  @override
  String get dailyOsNextCategoryFilterAll => 'Todas as categorias';

  @override
  String get dailyOsNextCategoryFilterDescription =>
      'Somente categorias habilitadas para planejamento diário são exibidas para processamento automatizado do Daily OS.';

  @override
  String get dailyOsNextCategoryFilterEmpty =>
      'Nenhuma categoria habilitada para planejamento do dia ainda.';

  @override
  String get dailyOsNextCategoryFilterIncludeAll => 'Incluir tudo';

  @override
  String get dailyOsNextCategoryFilterTitle => 'Categorias de processamento';

  @override
  String get dailyOsNextCategoryFilterTooltip =>
      'Escolha as categorias de processamento diário do sistema operacional';

  @override
  String dailyOsNextCommitCapacityNote(String scheduled, String capacity) {
    return '$scheduled de $capacity comprometido. Margem confortável – você pode absorver uma surpresa.';
  }

  @override
  String get dailyOsNextCommitDraftOverline => 'SEU DIA, Elaborado';

  @override
  String get dailyOsNextCommitExplainer =>
      'Assine para passar hoje do rascunho para o compromisso.';

  @override
  String get dailyOsNextCommitFinalStepEyebrow => 'ETAPA FINAL';

  @override
  String get dailyOsNextCommitHeadline => 'Faça com que seja seu.';

  @override
  String get dailyOsNextCommitHoldHelper => 'Espere um segundo para assinar';

  @override
  String get dailyOsNextCommitHoldWordDone => 'Comprometido';

  @override
  String get dailyOsNextCommitHoldWordHolding => 'Continue segurando';

  @override
  String get dailyOsNextCommitHoldWordIdle => 'Espera';

  @override
  String get dailyOsNextCommitLockingIn => 'Bloqueando…';

  @override
  String get dailyOsNextCommitShepherdSubline =>
      'Eu cuidarei disso – você faz o trabalho.';

  @override
  String get dailyOsNextCommitSubCaption =>
      'Você ainda pode falar comigo depois - mas os ossos permanecem no lugar.';

  @override
  String get dailyOsNextCommitTitle => 'Tranque-o';

  @override
  String get dailyOsNextCommitTodayIsYours => 'Hoje é seu.';

  @override
  String get dailyOsNextDayAgentStatusAttention => 'Needs attention';

  @override
  String get dailyOsNextDayAgentStatusDayClosed => 'Day closed';

  @override
  String get dailyOsNextDayAgentStatusWorking => 'Planning…';

  @override
  String dailyOsNextDayAgentTokensToday(int tokens) {
    return '$tokens tokens spent planning this day';
  }

  @override
  String get dailyOsNextDayBack => 'Voltar';

  @override
  String get dailyOsNextDayCheckInCta => 'Fale um check-in';

  @override
  String get dailyOsNextDayDeleteDialogBody =>
      'Os blocos elaborados para este dia serão removidos. As capturas e suas gravações de áudio permanecem em seu diário.';

  @override
  String get dailyOsNextDayDeleteDialogCancel => 'Cancelar';

  @override
  String get dailyOsNextDayDeleteDialogConfirm => 'Excluir';

  @override
  String get dailyOsNextDayDeleteDialogTitle => 'Excluir este plano?';

  @override
  String get dailyOsNextDayLockInCta => 'Bloquear';

  @override
  String get dailyOsNextDayMenuDeletePlan => 'Excluir plano';

  @override
  String get dailyOsNextDayMenuInspectAgent => 'Inspecionar agente';

  @override
  String get dailyOsNextDayMenuSettings =>
      'Configurações diárias do sistema operacional';

  @override
  String get dailyOsNextDayMoreTooltip => 'Mais';

  @override
  String get dailyOsNextDayRefineCta => 'Refinar';

  @override
  String get dailyOsNextDayRefineFooterHint =>
      'Fale para reformular o plano – você verá todas as alterações antes que qualquer coisa seja salva.';

  @override
  String get dailyOsNextDayTitle => 'Seu dia';

  @override
  String get dailyOsNextDayWhyChipLabel => 'POR QUE';

  @override
  String get dailyOsNextDayWrapUpCta => 'Concluir';

  @override
  String get dailyOsNextDraftingBackToDecisions => 'Voltar às decisões';

  @override
  String get dailyOsNextDraftingHeader => 'Desenhando o seu dia…';

  @override
  String get dailyOsNextDraftingNudgeAccept => 'Sim, proteja as manhãs';

  @override
  String get dailyOsNextDraftingNudgeDecline => 'Hoje não';

  @override
  String get dailyOsNextDraftingProgressBlocks => 'Blocos de desenho';

  @override
  String get dailyOsNextDraftingProgressMatching => 'Tarefas correspondentes';

  @override
  String get dailyOsNextDraftingProgressQueued => 'Na fila';

  @override
  String get dailyOsNextDraftingProgressReading => 'Check-in de leitura';

  @override
  String get dailyOsNextDraftingProgressSaving => 'Plano de poupança';

  @override
  String get dailyOsNextDraftingProgressValidating => 'Validando';

  @override
  String get dailyOsNextDraftingReasoningOverline => '✦ RACIOCÍNIO';

  @override
  String get dailyOsNextDraftingRecoveryBody =>
      'O velório não produziu um plano. Tente novamente ou volte e ajuste as decisões antes de redigir.';

  @override
  String get dailyOsNextDraftingRecoveryTitle => 'Rascunho parado';

  @override
  String get dailyOsNextDraftingRetry => 'Tente novamente';

  @override
  String get dailyOsNextDraftingStatusAfternoon => 'Sequenciando a tarde…';

  @override
  String get dailyOsNextDraftingStatusAlmost => 'Quase lá…';

  @override
  String get dailyOsNextDraftingStatusBreathing =>
      'Deixando espaço para respirar…';

  @override
  String get dailyOsNextDraftingStatusDeepWork =>
      'Colocando o trabalho profundo em primeiro lugar…';

  @override
  String get dailyOsNextDraftingStatusMatching =>
      'Combinando tarefas com o seu dia…';

  @override
  String get dailyOsNextDraftingStatusReading => 'Lendo seu check-in…';

  @override
  String get dailyOsNextDraftingStatusTimings => 'Verificando os horários…';

  @override
  String get dailyOsNextDraftingStatusYesterday =>
      'Olhando para o ritmo de ontem…';

  @override
  String get dailyOsNextEditTitleHint => 'Editar título';

  @override
  String get dailyOsNextGenericError =>
      'Algo deu errado. Tente novamente em alguns instantes.';

  @override
  String get dailyOsNextGreetingAfternoon => 'Boa tarde.';

  @override
  String get dailyOsNextGreetingEvening => 'Boa noite.';

  @override
  String dailyOsNextGreetingHiName(String name) {
    return 'Olá $name 👋';
  }

  @override
  String get dailyOsNextGreetingMorning => 'Bom dia.';

  @override
  String get dailyOsNextKnowledgeConfirm => 'Confirmar';

  @override
  String get dailyOsNextKnowledgeConfirmedHeader => 'Confirmado';

  @override
  String get dailyOsNextKnowledgeEdit => 'Editar';

  @override
  String get dailyOsNextKnowledgeEditCancel => 'Cancelar';

  @override
  String get dailyOsNextKnowledgeEditHookHint => 'Resumo de uma linha';

  @override
  String get dailyOsNextKnowledgeEditSave => 'Salvar';

  @override
  String get dailyOsNextKnowledgeEditStatementHint => 'O que devo lembrar?';

  @override
  String get dailyOsNextKnowledgeEmpty =>
      'Nada ainda - vou lembrar o que você me disser.';

  @override
  String dailyOsNextKnowledgeNudge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count coisas que notei — revise',
      one: '1 coisa que notei — revise',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextKnowledgeProposedHeader => 'Aguardando sua confirmação';

  @override
  String get dailyOsNextKnowledgeRetract => 'Esqueça';

  @override
  String get dailyOsNextKnowledgeStale => 'Ainda é verdade?';

  @override
  String get dailyOsNextKnowledgeTitle => 'O que eu aprendi';

  @override
  String get dailyOsNextParsedCardBreakLinkTooltip => 'Quebrar link';

  @override
  String get dailyOsNextPlanChangesFailedNotificationBody =>
      'Open Lotti to see what happened and try again.';

  @override
  String get dailyOsNextPlanChangesFailedNotificationTitle =>
      'Your plan changes didn\'t finish';

  @override
  String get dailyOsNextPlanChangesReadyNotificationBody =>
      'The proposed changes are waiting for your review.';

  @override
  String get dailyOsNextPlanChangesReadyNotificationTitle =>
      'Your plan changes are ready';

  @override
  String get dailyOsNextPlanFailedNotificationBody =>
      'Open Lotti to see what happened and try again.';

  @override
  String get dailyOsNextPlanFailedNotificationTitle =>
      'Your day plan didn\'t finish';

  @override
  String get dailyOsNextPlanReadyNotificationBody =>
      'The draft is waiting for your review.';

  @override
  String get dailyOsNextPlanReadyNotificationTitle => 'Your day plan is ready';

  @override
  String get dailyOsNextPlanViewActivity => 'Activity';

  @override
  String get dailyOsNextPlanViewAgenda => 'Agenda';

  @override
  String get dailyOsNextPlanViewDay => 'Dia';

  @override
  String get dailyOsNextReconcileBadgeMatched => 'COMBINADO';

  @override
  String get dailyOsNextReconcileBadgeNew => 'NOVO';

  @override
  String get dailyOsNextReconcileBadgeUpdate => 'ATUALIZAR';

  @override
  String get dailyOsNextReconcileBuildDayCta => 'Construa meu dia';

  @override
  String get dailyOsNextReconcileDecideOverline => 'VALE A PENA DECIDIR';

  @override
  String dailyOsNextReconcileDecisionProgress(int decided, int total) {
    return '$decided de $total avaliados';
  }

  @override
  String get dailyOsNextReconcileDefaultBehaviorHint =>
      'Revise os cartões antes de construir o seu dia. As ações escolhidas contribuem para o plano; as cartas deixadas sozinhas permanecem como estão.';

  @override
  String dailyOsNextReconcileError(String detail) {
    return 'Algo deu errado: $detail';
  }

  @override
  String get dailyOsNextReconcileHeadline => 'Aqui está o que ouvi.';

  @override
  String get dailyOsNextReconcileHeardEmpty =>
      'Os cartões de captura aparecerão aqui assim que a análise terminar.';

  @override
  String get dailyOsNextReconcileHeardOverline => 'OUVI';

  @override
  String get dailyOsNextReconcileLowConfidence => 'baixa confiança';

  @override
  String get dailyOsNextReconcileProcessing =>
      'Ouvindo e combinando com o seu dia…';

  @override
  String get dailyOsNextReconcileReRecord => 'Regravar';

  @override
  String get dailyOsNextReconcileVoiceHint =>
      'Revise as decisões antes de construir o seu dia';

  @override
  String get dailyOsNextRefineAccept => 'Aceitar';

  @override
  String get dailyOsNextRefineCurrentPlan => 'PLANO ATUAL';

  @override
  String get dailyOsNextRefineDiffAdded => 'ADICIONADO';

  @override
  String get dailyOsNextRefineDiffDropped => 'CAIU';

  @override
  String get dailyOsNextRefineDiffMoved => 'MOVIDO';

  @override
  String get dailyOsNextRefineHeadlineDiffReady =>
      'Aqui está o que eu mudaria.';

  @override
  String get dailyOsNextRefineHeadlineIdle => 'O que deveria mudar?';

  @override
  String get dailyOsNextRefineHeadlineThinking => 'Reformulando seu plano…';

  @override
  String get dailyOsNextRefineKeepTalking => 'Continue falando';

  @override
  String get dailyOsNextRefineLooksGood => 'Parece bom';

  @override
  String get dailyOsNextRefineNoChanges =>
      'Nenhuma mudança de plano voltou. Reformule-o e tente novamente.';

  @override
  String get dailyOsNextRefineOverline => '🎤 REFINAMENTO';

  @override
  String get dailyOsNextRefineRevert => 'Reverter';

  @override
  String get dailyOsNextRefineStatusAccepted => 'Trancado.';

  @override
  String get dailyOsNextRefineStatusDiffReady => 'Aqui está o que mudou.';

  @override
  String get dailyOsNextRefineStatusIdle => 'Toque para falar.';

  @override
  String get dailyOsNextRefineStatusListening => 'Ouvindo…';

  @override
  String get dailyOsNextRefineStatusThinking => '✦ Reelaborando o plano…';

  @override
  String get dailyOsNextRefineTitle => 'Refinar o plano';

  @override
  String get dailyOsNextRenameFailed =>
      'Não foi possível renomear. Tente novamente.';

  @override
  String get dailyOsNextReviewAddBuffer => 'Adicionar buffer';

  @override
  String get dailyOsNextReviewAddBufferPrompt =>
      'Adicione um buffer realista entre os blocos planejados, especialmente em torno de transições e após trabalhos exigentes.';

  @override
  String get dailyOsNextReviewAdjust => 'Ajustar';

  @override
  String get dailyOsNextReviewLooksGood => 'Parece bom';

  @override
  String get dailyOsNextReviewMoveLighter => 'Mova-se com mais leveza';

  @override
  String get dailyOsNextReviewMoveLighterPrompt =>
      'Mova o trabalho mais leve ou de menor energia para mais tarde e mantenha a janela de foco mais forte para a tarefa mais exigente.';

  @override
  String get dailyOsNextReviewTooMuch => 'Demais';

  @override
  String get dailyOsNextReviewTooMuchPrompt =>
      'Este plano é demais para hoje. Reduza a carga, proteja o espaço para respirar e guarde apenas os blocos mais importantes.';

  @override
  String get dailyOsNextReviewWhyTitle => 'Por que eles chegaram';

  @override
  String get dailyOsNextShutdownCarryoverDrop => 'Soltar';

  @override
  String get dailyOsNextShutdownCarryoverDropped => 'Caiu';

  @override
  String get dailyOsNextShutdownCarryoverOverline => 'VAI EM FRENTE';

  @override
  String get dailyOsNextShutdownCarryoverPickDate => 'Escolha uma data';

  @override
  String get dailyOsNextShutdownCarryoverScheduled => 'Agendado';

  @override
  String get dailyOsNextShutdownCloseDay => 'Fechar o dia';

  @override
  String get dailyOsNextShutdownCompletedOverline => 'O QUE VOCÊ FEZ';

  @override
  String get dailyOsNextShutdownMetricEnergy => 'ENERGIA';

  @override
  String dailyOsNextShutdownMetricEnergyDelta(String delta) {
    return '$delta vs. semana';
  }

  @override
  String get dailyOsNextShutdownMetricFlow => 'SESSÕES DE FLUXO';

  @override
  String get dailyOsNextShutdownMetricFocus => 'TEMPO DE FOCO';

  @override
  String get dailyOsNextShutdownMetricSwitches => 'INTERRUPTORES DE CONTEXTO';

  @override
  String dailyOsNextShutdownMetricSwitchesAvg(String avg) {
    return 'média $avg esta semana';
  }

  @override
  String get dailyOsNextShutdownReflectionOverline =>
      '💬 REFLEXÃO DE UMA LINHA';

  @override
  String get dailyOsNextShutdownReflectionPlaceholder =>
      'por exemplo, a manhã foi nítida, a tarde arrastada depois do café com Sarah demorou muito.';

  @override
  String get dailyOsNextShutdownReflectionPrompt =>
      'Como hoje pousou? (Isso alimenta o rascunho de amanhã.)';

  @override
  String get dailyOsNextShutdownReflectionSpeak => 'Fale';

  @override
  String get dailyOsNextShutdownReflectionSubmit => 'Pular';

  @override
  String get dailyOsNextShutdownReflectionThanks =>
      'Entendi - alimentação amanhã.';

  @override
  String get dailyOsNextShutdownSaveAndClose => 'Salvar e fechar';

  @override
  String get dailyOsNextShutdownTitle => 'Encerre o dia';

  @override
  String get dailyOsNextShutdownTomorrowOverline => '✦ PARA AMANHÃ';

  @override
  String dailyOsNextStateDueOnDate(String date) {
    return 'Vencimento em $date';
  }

  @override
  String get dailyOsNextStateDueToday => 'Vencimento hoje';

  @override
  String dailyOsNextStateInProgress(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Em andamento · $count sessões',
      one: 'Em andamento · 1 sessão',
      zero: 'Em andamento',
    );
    return '$_temp0';
  }

  @override
  String dailyOsNextStateOverdue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Atrasado · $days dias',
      one: 'Atrasado · 1 dia',
      zero: 'Overdue',
    );
    return '$_temp0';
  }

  @override
  String dailyOsNextStateOverdueOnDate(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Atrasado em $days dias em $date',
      one: 'Atrasado em 1 dia em $date',
      zero: 'Atrasado em $date',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextStateRecurringMissed => 'Recorrente · perdido';

  @override
  String get dailyOsNextTimelineActual => 'Real';

  @override
  String get dailyOsNextTimelineArrange => 'Organizar blocos';

  @override
  String get dailyOsNextTimelineBoth => 'Planejado e real';

  @override
  String get dailyOsNextTimelinePlanned => 'Plano';

  @override
  String dailyOsNextTimelineSessionOf(int index, int total) {
    return 'Sessão $index de $total';
  }

  @override
  String get dailyOsNextTimelineShowBoth => 'Mostrar o plano e o real juntos';

  @override
  String get dailyOsNextTimelineShowPaged => 'Mostrar plano deslizante e real';

  @override
  String get dailyOsNextTimelineSwipeHint =>
      'Deslize para real · aperte verticalmente para ampliar';

  @override
  String get dailyOsNextTimelineTracked => 'rastreado';

  @override
  String dailyOsNextTimeSpentEarlierSessions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessões anteriores',
      one: '1 sessão anterior',
    );
    return '$_temp0';
  }

  @override
  String get dailyOsNextTimeSpentShowLess => 'Mostrar menos';

  @override
  String dailyOsNextTimeSpentSummary(String duration, int completedCount) {
    return '$duration · $completedCount concluído';
  }

  @override
  String get dailyOsNextTimeSpentTitle => 'HOJE ATÉ AGORA';

  @override
  String get dailyOsNextTimeSpentTitlePast => 'TEMPO GASTO';

  @override
  String get dailyOsNextTriageConfirmDefer => 'Adiado';

  @override
  String get dailyOsNextTriageConfirmDone => 'Marcado como concluído';

  @override
  String get dailyOsNextTriageConfirmDoNow => 'Feito agora';

  @override
  String get dailyOsNextTriageConfirmDrop => 'Caiu';

  @override
  String get dailyOsNextTriageConfirmToday => 'Adicionado a hoje';

  @override
  String get dailyOsNextTriageDefer => 'Adiar';

  @override
  String get dailyOsNextTriageDone => 'Concluído';

  @override
  String get dailyOsNextTriageDoNow => 'Faça agora';

  @override
  String get dailyOsNextTriageDrop => 'Soltar';

  @override
  String get dailyOsNextTriageToday => 'Hoje';

  @override
  String get dailyOsOnboardingCoachCapture =>
      'Diga o que está chamando sua atenção.';

  @override
  String get dailyOsOnboardingCoachDrafting =>
      'O planejador está criando novas tarefas e adaptando o trabalho ao seu dia.';

  @override
  String get dailyOsOnboardingCoachReconcile =>
      'Escolha o que pertence hoje. Novos itens se tornam tarefas quando você constrói o dia.';

  @override
  String get dailyOsOnboardingSpotlightAction => 'Experimente';

  @override
  String get dailyOsOnboardingSpotlightDismiss => 'Agora não';

  @override
  String get dailyOsOnboardingSpotlightMessage =>
      'Toque aqui e diga o que você está pensando – vou transformar isso em uma tarefa e construir o seu dia em torno disso.';

  @override
  String get dailyOsOnboardingSpotlightTitle =>
      'Transforme a conversa em um plano';

  @override
  String get dailyOsSettingsChooseModelDescription =>
      'Substitua apenas o modelo de pensamento do planejador.';

  @override
  String get dailyOsSettingsChooseModelTitle =>
      'Escolha a substituição do modelo';

  @override
  String get dailyOsSettingsChooseProfileDescription =>
      'Substitua o perfil de inferência completo deste planejador.';

  @override
  String get dailyOsSettingsChooseProfileTitle =>
      'Escolha o perfil diário do sistema operacional';

  @override
  String get dailyOsSettingsDataDisclosure =>
      'O Daily OS envia tarefas relevantes, capturas, planos, preferências aprendidas e outros contextos de planejamento montados ao provedor selecionado para processamento.';

  @override
  String get dailyOsSettingsDefaultProfileDescription =>
      'Usado pelo Daily OS, a menos que a instância do planejador tenha uma substituição.';

  @override
  String get dailyOsSettingsDefaultProfileMissing => 'Escolha um perfil';

  @override
  String get dailyOsSettingsDefaultRestored =>
      'Padrão diário do sistema operacional restaurado';

  @override
  String get dailyOsSettingsDirectOverrideActive =>
      'A substituição direta do modelo está ativa.';

  @override
  String get dailyOsSettingsInferenceTitle => 'Perfil de inferência padrão';

  @override
  String get dailyOsSettingsInstanceCurrentSetup =>
      'Configuração atual do planejador';

  @override
  String get dailyOsSettingsInstanceOverrideDescription =>
      'Use o perfil padrão do Daily OS, escolha uma substituição de perfil ou substitua apenas o modelo de pensamento deste planejador.';

  @override
  String get dailyOsSettingsInstanceOverrideTitle =>
      'Inferência diária do sistema operacional';

  @override
  String get dailyOsSettingsLocalDisclosure =>
      'O endpoint selecionado está neste dispositivo.';

  @override
  String dailyOsSettingsModelChanged(String model) {
    return 'O sistema operacional diário agora usa $model';
  }

  @override
  String get dailyOsSettingsNameNudgeAction => 'Adicionar nome';

  @override
  String get dailyOsSettingsNameNudgeBody =>
      'Adicionar um nome preferido torna os check-ins mais pessoais. Você pode continuar planejando sem ele.';

  @override
  String get dailyOsSettingsNameNudgeTitle =>
      'Como o Daily OS deve abordar você?';

  @override
  String dailyOsSettingsProfileChanged(String profile) {
    return 'O sistema operacional diário agora usa $profile';
  }

  @override
  String get dailyOsSettingsProfileOverrideActive =>
      'Substituição de perfil ativa';

  @override
  String dailyOsSettingsRemoteDisclosure(String provider, String host) {
    return 'O Daily OS envia o contexto de planejamento montado para $provider em $host para processamento remoto.';
  }

  @override
  String get dailyOsSettingsSetupAction =>
      'Configurar o sistema operacional diário';

  @override
  String get dailyOsSettingsSetupRequiredBody =>
      'O Daily OS precisa da escolha do seu provedor antes de poder processar seu contexto de planejamento.';

  @override
  String get dailyOsSettingsSetupRequiredTitle =>
      'Escolha um perfil de inferência';

  @override
  String get dailyOsSettingsSubtitle =>
      'Escolha como o Daily OS aborda você e qual perfil de inferência planeja seus dias.';

  @override
  String get dailyOsSettingsTitle => 'SO diário';

  @override
  String get dailyOsSettingsTreeSubtitle =>
      'Provedor de planejamento, personalização e IA';

  @override
  String get dailyOsSettingsUseDefault =>
      'Usar o padrão diário do sistema operacional';

  @override
  String get dailyOsSettingsUseDefaultDescription =>
      'Siga o perfil selecionado nas configurações diárias do sistema operacional.';

  @override
  String get dailyOsTodayButton => 'Hoje';

  @override
  String get dashboardActiveLabel => 'Ativo';

  @override
  String get dashboardActiveSwitchDescription => 'Exibido na lista de painéis';

  @override
  String get dashboardAddChartsTitle => 'Gráficos';

  @override
  String get dashboardAddHabitButton => 'Hábitos';

  @override
  String get dashboardAddHabitTitle => 'Gráficos de hábitos';

  @override
  String get dashboardAddHealthButton => 'Saúde';

  @override
  String get dashboardAddHealthTitle => 'Gráficos de saúde';

  @override
  String get dashboardAddMeasurementButton => 'Medições';

  @override
  String get dashboardAddMeasurementTitle => 'Adicionar gráficos de medição';

  @override
  String get dashboardAddMeasurementTooltip => 'Adicionar medição';

  @override
  String get dashboardAddSurveyButton => 'Pesquisas';

  @override
  String get dashboardAddSurveyTitle => 'Gráficos de pesquisa';

  @override
  String get dashboardAddWorkoutButton => 'Exercícios';

  @override
  String get dashboardAddWorkoutTitle => 'Gráficos de treino';

  @override
  String get dashboardAggregationApplyImmediately =>
      'Escolha um resumo. As alterações aplicam-se imediatamente.';

  @override
  String get dashboardAggregationDailyAverage => 'Média diária';

  @override
  String get dashboardAggregationDailyMax => 'Máximo diário';

  @override
  String get dashboardAggregationDailyTotal => 'Total diário';

  @override
  String get dashboardAggregationHourlyTotal => 'Total por hora';

  @override
  String get dashboardAggregationLabel => 'Tipo de agregação:';

  @override
  String get dashboardAggregationTitle => 'Tipo de agregação';

  @override
  String get dashboardAvailableChartsDescription =>
      'Escolha um tipo, selecione um ou mais gráficos e adicione-os.';

  @override
  String get dashboardAvailableChartsTitle => 'Adicione gráficos por tipo';

  @override
  String get dashboardCategoryLabel => 'Categoria';

  @override
  String get dashboardChartNoData => 'Não há dados neste intervalo';

  @override
  String get dashboardConfigurationDescription =>
      'Salve o painel e copie sua configuração JSON.';

  @override
  String get dashboardConfigurationTitle => 'Exportar configuração';

  @override
  String get dashboardCopyHint => 'Salvar e copiar configuração do painel';

  @override
  String get dashboardCopyLabel => 'Salvar e copiar JSON';

  @override
  String get dashboardCurrentChartsDescription =>
      'Arraste para reordenar. Os gráficos de medição podem ser selecionados para alterar sua agregação.';

  @override
  String get dashboardCurrentChartsTitle => 'Gráficos neste painel';

  @override
  String get dashboardDeleteConfirm => 'Sim, excluir este painel';

  @override
  String get dashboardDeleteHint => 'Excluir painel';

  @override
  String get dashboardDeleteQuestion => 'Deseja excluir este painel?';

  @override
  String get dashboardDescriptionLabel => 'Descrição (opcional)';

  @override
  String get dashboardEditAggregationLabel => 'Editar agregação';

  @override
  String get dashboardHealthBloodPressure => 'Pressão Arterial';

  @override
  String get dashboardHealthDiastolic => 'Diastólica';

  @override
  String get dashboardHealthSystolic => 'Sistólica';

  @override
  String dashboardMeasurementAddButtonWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Adicionar $count gráficos',
      one: 'Adicionar 1 gráfico',
    );
    return '$_temp0';
  }

  @override
  String dashboardMeasurementAggregationFor(String name) {
    return 'Modo gráfico para $name';
  }

  @override
  String get dashboardMeasurementAggregationHelp =>
      'Selecione gráficos de medição. Ajuste o modo de gráfico nas linhas selecionadas antes de adicionar.';

  @override
  String get dashboardNameLabel => 'Nome do painel';

  @override
  String get dashboardNoChartsAdded =>
      'Nenhum gráfico adicionado ainda. Adicione um abaixo.';

  @override
  String get dashboardNoHabitsForCharts =>
      'Crie primeiro um hábito para adicionar gráficos de hábitos.';

  @override
  String get dashboardNoMeasurablesForCharts =>
      'Crie primeiro um mensurável para adicionar gráficos de medição.';

  @override
  String get dashboardNotFound => 'Painel não encontrado';

  @override
  String get dashboardPrivateLabel => 'Privado';

  @override
  String get dashboardRemoveChartLabel => 'Remover gráfico';

  @override
  String get dashboardReorderChartLabel => 'Reordenar gráfico';

  @override
  String get dashboardTakeSurveyTooltip => 'Faça uma pesquisa';

  @override
  String get defaultLanguage => 'Idioma padrão';

  @override
  String get deleteButton => 'Excluir';

  @override
  String get deleteDeviceLabel => 'Remover da sincronização';

  @override
  String get demoAiNudgeBody =>
      'O mundo de demonstração inclui fornecedores de IA fictícios, por isso as ações de IA não podem realmente funcionar aqui. Liga a tua própria conta de IA para usar IA real dentro da demonstração. A tua chave fica neste mundo de demonstração, a menos que a copies ao sair.';

  @override
  String get demoAiNudgeCancel => 'Agora não';

  @override
  String get demoAiNudgeConfirm => 'Configurar IA real';

  @override
  String get demoAiNudgeTitle => 'A IA da demonstração é a fingir';

  @override
  String get demoAiSetupSuccessBody =>
      'Este mundo de demonstração usa agora a tua conta de IA real. A tua chave fica aqui, a menos que a copies ao sair.';

  @override
  String get demoAiSetupSuccessTitle => 'A IA real está ativa';

  @override
  String get demoBannerExit => 'Sair';

  @override
  String get demoBannerLabel => 'Mundo demo';

  @override
  String get demoBannerSubtitle => 'O teu diário permanece intacto';

  @override
  String get demoCopyBody =>
      'Escolhe as tarefas e entradas a copiar para o teu diário.';

  @override
  String get demoCopyConfirm => 'Copiar e sair';

  @override
  String get demoCopyFailedToast =>
      'Não foi possível copiar o teu trabalho da demonstração — está tudo no mundo de demonstração, por isso podes tentar novamente.';

  @override
  String get demoCopyProgress => 'A copiar o teu trabalho…';

  @override
  String get demoCopySectionAiSetup => 'Configuração de IA';

  @override
  String get demoCopySectionEntries => 'Entradas do diário';

  @override
  String get demoCopySectionTasks => 'Tarefas';

  @override
  String get demoCopySelectAll => 'Selecionar tudo';

  @override
  String get demoCopyTitle => 'Levar o meu trabalho';

  @override
  String demoCopyToast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens copiados para o teu diário',
      one: '1 item copiado para o teu diário',
    );
    return '$_temp0';
  }

  @override
  String get demoDeleteFailedToast =>
      'Não foi possível eliminar os dados da demonstração — tenta novamente.';

  @override
  String get demoEnterFailedToast =>
      'Não foi possível abrir o mundo de demonstração — tenta novamente.';

  @override
  String get demoEnteringProgress => 'A preparar o mundo de demonstração…';

  @override
  String get demoExitCandidatesError =>
      'Não foi possível verificar o teu trabalho para copiar. Podes sair da demonstração na mesma.';

  @override
  String get demoExitConfirm => 'Sair da demo';

  @override
  String get demoExitFailedToast =>
      'Não foi possível concluir a saída da demonstração — tenta novamente.';

  @override
  String get demoExitSheetBody =>
      'O teu mundo de demonstração fica guardado — podes voltar quando quiseres.';

  @override
  String get demoExitSheetTitle => 'Sair da demo?';

  @override
  String get demoExitTakeWork => 'Levar o meu trabalho…';

  @override
  String demoMediaDownloadCount(int completed, int total) {
    return '$completed de $total';
  }

  @override
  String get demoMediaDownloadProgress =>
      'A transferir imagens de demonstração';

  @override
  String get demoMediaDownloadRetry =>
      'Não foi possível transferir algumas imagens de demonstração. Será feita nova tentativa no próximo arranque.';

  @override
  String get demoOnboardingExplore => 'Explorar com dados de exemplo';

  @override
  String get demoSettingsDeleteConfirm =>
      'Apagar o mundo de demonstração e todos os seus dados?';

  @override
  String get demoSettingsDeleteTitle => 'Apagar dados da demo';

  @override
  String get demoSettingsDeleteToast => 'Dados da demo apagados';

  @override
  String get demoSettingsExitTitle => 'Sair da demo';

  @override
  String get demoSettingsHealthImportUnavailable =>
      'A importação de dados de saúde não está disponível no mundo de demonstração';

  @override
  String get demoSettingsRealAiActiveSubtitle =>
      'A IA real está configurada neste mundo de demonstração';

  @override
  String get demoSettingsRealAiSubtitle =>
      'Usa a tua própria conta de IA dentro do mundo de demonstração';

  @override
  String get demoSettingsRealAiTitle => 'Ativar IA real na demonstração';

  @override
  String get demoSettingsResetConfirm =>
      'Repor o mundo de demonstração? Todas as tuas alterações aí serão perdidas.';

  @override
  String get demoSettingsResetTitle => 'Repor dados da demo';

  @override
  String get demoSettingsResumeTitle => 'Voltar ao mundo de demonstração';

  @override
  String get demoSettingsSyncUnavailable =>
      'A sincronização não está disponível no mundo de demonstração';

  @override
  String get demoSettingsTrySubtitle =>
      'Explora o Lotti com dados de exemplo — o teu diário permanece intacto';

  @override
  String get demoSettingsTryTitle => 'Experimentar o mundo de demonstração';

  @override
  String get demoTryButton => 'Experimentar a demo';

  @override
  String get designSystemActionVariantTitle => 'Com ação';

  @override
  String get designSystemActivatedLabel => 'Ativado';

  @override
  String get designSystemAvatarAwayLabel => 'Longe';

  @override
  String get designSystemAvatarBusyLabel => 'Ocupado';

  @override
  String get designSystemAvatarConnectedLabel => 'Conectado';

  @override
  String get designSystemAvatarEnabledLabel => 'Habilitado';

  @override
  String get designSystemAvatarSizeMatrixTitle => 'Matriz de tamanho';

  @override
  String get designSystemAvatarStatusMatrixTitle => 'Matriz de status';

  @override
  String get designSystemBackLabel => 'Voltar';

  @override
  String get designSystemBreadcrumbCurrentLabel => 'Pão ralado';

  @override
  String get designSystemBreadcrumbDesignSystemLabel => 'Sistema de projeto';

  @override
  String get designSystemBreadcrumbHomeLabel => 'Página inicial';

  @override
  String get designSystemBreadcrumbMobileLabel => 'Móvel';

  @override
  String get designSystemBreadcrumbProjectsLabel => 'Projetos';

  @override
  String get designSystemBreadcrumbSampleLabel => 'Pão ralado';

  @override
  String get designSystemBreadcrumbTrailTitle => 'Trilha de pão ralado';

  @override
  String get designSystemCalendarPickerLabel => 'Seletor de calendário';

  @override
  String get designSystemCalendarViewsTitle => 'Visualizações de calendário';

  @override
  String get designSystemCalloutInfoSample =>
      'Um tom informativo: a borda e o ícone carregam a cor, a mensagem mantém o contraste alto.';

  @override
  String get designSystemCaptionDescriptionSample =>
      'A remoção de todos os usuários cancelou a publicação deste projeto. Adicione usuários para publicá-lo novamente.';

  @override
  String get designSystemCaptionIconLeftLabel => 'Ícone esquerdo';

  @override
  String get designSystemCaptionIconTopLabel => 'Ícone superior';

  @override
  String get designSystemCaptionNoIconLabel => 'Nenhum ícone';

  @override
  String get designSystemCaptionTitleSample => 'Título da legenda';

  @override
  String get designSystemCaptionVariantsTitle => 'Variantes de legenda';

  @override
  String get designSystemCaptionWithActionsLabel => 'Com ações';

  @override
  String get designSystemCaptionWithoutActionsLabel => 'Sem ações';

  @override
  String get designSystemCheckboxLabel => 'Caixa de seleção';

  @override
  String get designSystemContextMenuDeleteLabel => 'Excluir';

  @override
  String get designSystemContextMenuVariantsTitle =>
      'Variantes do menu de contexto';

  @override
  String get designSystemCountdownVariantTitle => 'Com contagem regressiva';

  @override
  String get designSystemDateCardsTitle => 'Cartões de data';

  @override
  String get designSystemDefaultLabel => 'Padrão';

  @override
  String get designSystemDisabledLabel => 'Desativado';

  @override
  String get designSystemDividerLabelText => 'Etiqueta divisória';

  @override
  String get designSystemDropdownComboboxTitle => 'Caixa de combinação';

  @override
  String get designSystemDropdownFieldLabel => 'Etiqueta';

  @override
  String get designSystemDropdownInputLabel => 'Entrada';

  @override
  String get designSystemDropdownListTitle => 'Lista suspensa';

  @override
  String get designSystemDropdownMultiselectInputLabel => 'Selecione equipes';

  @override
  String get designSystemDropdownMultiselectTitle => 'Seleção múltipla';

  @override
  String get designSystemDropdownOptionAnalytics => 'Análise';

  @override
  String get designSystemDropdownOptionBackend => 'Back-end';

  @override
  String get designSystemDropdownOptionDesign => 'Projeto';

  @override
  String get designSystemDropdownOptionFrontend => 'Interface';

  @override
  String get designSystemDropdownOptionGrowth => 'Crescimento';

  @override
  String get designSystemDropdownOptionMobile => 'Móvel';

  @override
  String get designSystemDropdownOptionQa => 'Controle de qualidade';

  @override
  String get designSystemErrorLabel => 'Erro';

  @override
  String get designSystemFileUploadClickLabel => 'Clique para carregar';

  @override
  String get designSystemFileUploadCompleteLabel => 'Completo';

  @override
  String get designSystemFileUploadDefaultLabel => 'Padrão';

  @override
  String get designSystemFileUploadDragLabel => 'ou arraste e solte';

  @override
  String get designSystemFileUploadDropZoneSectionTitle => 'Zona de lançamento';

  @override
  String get designSystemFileUploadErrorLabel => 'Erro';

  @override
  String get designSystemFileUploadFailedText => 'Falha no upload';

  @override
  String get designSystemFileUploadHintText =>
      'SVG, PNG, JPG ou GIF (máx. 800×400px)';

  @override
  String get designSystemFileUploadHoverLabel => 'Passe o mouse';

  @override
  String get designSystemFileUploadItemSectionTitle => 'Itens de arquivo';

  @override
  String get designSystemFileUploadRetryLabel => 'Tentar novamente';

  @override
  String get designSystemFileUploadUploadingLabel => 'Enviando';

  @override
  String get designSystemFilledLabel => 'Preenchido';

  @override
  String get designSystemHeaderApiDocumentationLabel => 'Documentação da API';

  @override
  String get designSystemHeaderBackActionLabel => 'Voltar';

  @override
  String get designSystemHeaderDesktopSectionTitle => 'Área de trabalho';

  @override
  String get designSystemHeaderHelpActionLabel => 'Ajuda';

  @override
  String get designSystemHeaderMobileSectionTitle => 'Móvel';

  @override
  String get designSystemHeaderNotificationsActionLabel => 'Notificações';

  @override
  String get designSystemHeaderSearchActionLabel => 'Pesquisar';

  @override
  String get designSystemHorizontalLabel => 'Horizontais';

  @override
  String get designSystemHoverLabel => 'Passe o mouse';

  @override
  String get designSystemInfoLabel => 'Informações';

  @override
  String get designSystemInputErrorSample => 'Este campo é obrigatório';

  @override
  String get designSystemInputHelperSample => 'Digite seu nome';

  @override
  String get designSystemInputHintSample => 'Espaço reservado...';

  @override
  String get designSystemInputLabelSample => 'Etiqueta';

  @override
  String get designSystemInputVariantsTitle => 'Variantes de entrada';

  @override
  String get designSystemInputWithErrorLabel => 'Com erro';

  @override
  String get designSystemInputWithHelperLabel => 'Com texto auxiliar';

  @override
  String get designSystemInputWithIconsLabel => 'Com ícones';

  @override
  String get designSystemListItemActivatedLabel => 'Ativado';

  @override
  String get designSystemListItemOneLineLabel => 'Uma linha';

  @override
  String get designSystemListItemSubtitleSample => 'Legenda';

  @override
  String get designSystemListItemTitleSample => 'Título';

  @override
  String get designSystemListItemTwoLinesLabel => 'Duas linhas';

  @override
  String get designSystemListItemVariantsTitle => 'Listar variantes de itens';

  @override
  String get designSystemListItemWithDividerLabel => 'Com divisória';

  @override
  String get designSystemMediumLabel => 'Médio';

  @override
  String designSystemMyDailyDurationHoursMinutesCompact(
    int hours,
    int minutes,
  ) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get designSystemNavigationCollapsedLabel => 'Recolhido';

  @override
  String get designSystemNavigationDailyFilterSectionTitle => 'Filtro Diário';

  @override
  String get designSystemNavigationExpandedLabel => 'Expandido';

  @override
  String get designSystemNavigationFilterByBlockLabel => 'Filtrar por bloco';

  @override
  String get designSystemNavigationHikingLabel => 'Caminhadas';

  @override
  String get designSystemNavigationHolidayLabel => 'Feriado';

  @override
  String get designSystemNavigationInsightsLabel => 'Informações';

  @override
  String get designSystemNavigationLottiTasksLabel => 'Tarefas Lotti';

  @override
  String get designSystemNavigationMyDailyLabel => 'Meu Diário';

  @override
  String get designSystemNavigationNewLabel => 'Novo';

  @override
  String get designSystemNavigationPlaceholderLabel => 'Espaço reservado';

  @override
  String get designSystemNavigationSidebarSectionTitle =>
      'Variantes da barra lateral';

  @override
  String get designSystemNavigationSubComponentsSectionTitle =>
      'Subcomponentes';

  @override
  String get designSystemNavigationTabBarSectionTitle =>
      'Variantes da barra de guias';

  @override
  String get designSystemPressedLabel => 'Pressionado';

  @override
  String get designSystemProgressBarChunkyLabel => 'Robusto';

  @override
  String get designSystemProgressBarLabelAndPercentageLabel =>
      'Etiqueta + Porcentagem';

  @override
  String get designSystemProgressBarLabelOnlyLabel => 'Apenas etiqueta';

  @override
  String get designSystemProgressBarOffLabel => 'Desligado';

  @override
  String get designSystemProgressBarPercentageOnlyLabel => 'Porcentagem';

  @override
  String get designSystemProgressBarQuestBarLabel => 'Barra de missões';

  @override
  String get designSystemProgressBarQuestLabel => 'Etiqueta de mega prêmio';

  @override
  String get designSystemProgressBarSampleLabel =>
      'Etiqueta da barra de progresso';

  @override
  String get designSystemRadioButtonLabel => 'Botão de rádio';

  @override
  String get designSystemScrollbarSizesTitle => 'Tamanhos da barra de rolagem';

  @override
  String get designSystemSearchClearLabel => 'Limpar pesquisa';

  @override
  String get designSystemSearchFilledText => 'Pesquisa lotti';

  @override
  String get designSystemSearchHintLabel => 'Digite usuário';

  @override
  String get designSystemSelectedLabel => 'Selecionado';

  @override
  String get designSystemSizeScaleTitle => 'Escala de tamanho';

  @override
  String get designSystemSmallLabel => 'Pequeno';

  @override
  String get designSystemSpinnerPlainLabel => 'Simples';

  @override
  String get designSystemSpinnerSkeletonPulseLabel => 'Pulso';

  @override
  String get designSystemSpinnerSkeletonsTitle => 'Esqueletos';

  @override
  String get designSystemSpinnerSkeletonWaveLabel => 'Onda';

  @override
  String get designSystemSpinnerSpinnersTitle => 'Fiandeiros';

  @override
  String get designSystemSpinnerTrackLabel => 'Com pista';

  @override
  String designSystemSplitButtonDropdownSemantics(String label) {
    return 'Abra as opções de $label';
  }

  @override
  String get designSystemStateMatrixTitle => 'Matriz Estadual';

  @override
  String get designSystemSuccessLabel => 'Sucesso';

  @override
  String get designSystemTabBarTitle => 'Barra de guias';

  @override
  String get designSystemTabPendingLabel => 'Pendente';

  @override
  String get designSystemTaskListBlockedLabel => 'Bloqueado';

  @override
  String get designSystemTaskListDefaultLabel => 'Padrão';

  @override
  String get designSystemTaskListHoverLabel => 'Passe o mouse';

  @override
  String get designSystemTaskListItemSectionTitle =>
      'Variantes de itens da lista de tarefas';

  @override
  String get designSystemTaskListOnHoldLabel => 'Em espera';

  @override
  String get designSystemTaskListOpenLabel => 'Abrir';

  @override
  String get designSystemTaskListPressedLabel => 'Pressionado';

  @override
  String get designSystemTaskListSampleTime => '8h00-9h30';

  @override
  String get designSystemTaskListSampleTitle => 'Teste de usuário';

  @override
  String get designSystemTaskListWithDividerLabel => 'Com divisória';

  @override
  String get designSystemTextareaErrorSample => 'Este campo é obrigatório';

  @override
  String get designSystemTextareaHelperSample => 'Digite sua mensagem aqui';

  @override
  String get designSystemTextareaHintSample => 'Digite algo...';

  @override
  String get designSystemTextareaLabelSample => 'Etiqueta';

  @override
  String get designSystemTextareaVariantsTitle => 'Variantes de área de texto';

  @override
  String get designSystemTextareaWithCounterLabel => 'Com contador';

  @override
  String get designSystemTextareaWithErrorLabel => 'Com erro';

  @override
  String get designSystemTextareaWithHelperLabel => 'Com texto auxiliar';

  @override
  String get designSystemTimePickerFormatsTitle => 'Formatos de hora';

  @override
  String get designSystemTimePickerTwelveHourLabel => '12 horas';

  @override
  String get designSystemTimePickerTwentyFourHourLabel => '24 horas';

  @override
  String get designSystemTitleOnlyVariantTitle => 'Variante apenas de título';

  @override
  String get designSystemToastDetailsLabel => 'Detalhes da notificação';

  @override
  String get designSystemToggleLabel => 'Alternar rótulo';

  @override
  String get designSystemTooltipIconMessageSample =>
      'Informações úteis sobre este campo';

  @override
  String get designSystemTooltipIconVariantsTitle =>
      'Ícone de dica de ferramenta';

  @override
  String get designSystemUndoLabel => 'Desfazer';

  @override
  String get designSystemVariantMatrixTitle => 'Matriz Variante';

  @override
  String get designSystemVerticalLabel => 'Verticais';

  @override
  String get designSystemWarningLabel => 'Aviso';

  @override
  String get designSystemWeeklyCalendarLabel => 'Calendário Semanal';

  @override
  String get designSystemWithLabelLabel => 'Com etiqueta';

  @override
  String get desktopEmptyStateSelectDashboard =>
      'Selecione um painel para visualizar detalhes';

  @override
  String get desktopEmptyStateSelectProject =>
      'Selecione um projeto para ver detalhes';

  @override
  String get desktopEmptyStateSelectTask =>
      'Selecione uma tarefa para ver detalhes';

  @override
  String deviceDeletedSuccess(String deviceName) {
    return '$deviceName removido da sincronização';
  }

  @override
  String get deviceDeleteFailedGeneric =>
      'Não foi possível remover o dispositivo. Verifique sua conexão e tente novamente.';

  @override
  String deviceDeleteQuestion(String deviceName) {
    return 'Remover $deviceName da sua conta de sincronização? O dispositivo será desconectado e precisará ser pareado novamente antes de poder sincronizar.';
  }

  @override
  String get doneButton => 'Concluído';

  @override
  String get editLinkTypeCounterpartLabel => 'Linked task';

  @override
  String get editLinkTypeFailedMessage =>
      'Couldn\'t update the relationship. Please try again.';

  @override
  String get editLinkTypeTitle => 'Edit relationship';

  @override
  String get editLinkTypeTooltip => 'Edit relationship';

  @override
  String get editMenuTitle => 'Editar';

  @override
  String get editorDiscardChanges => 'Descartar alterações';

  @override
  String get editorInsertDivider => 'Inserir divisória';

  @override
  String get editorMoreFormatting => 'Mais formatação';

  @override
  String get editorPlaceholder => 'Insira notas...';

  @override
  String get embeddingSelectAll => 'Selecionar tudo';

  @override
  String get embeddingUnselectAll => 'Desmarcar tudo';

  @override
  String get enhancedPromptFormPreconfiguredPromptDescription =>
      'Escolha entre modelos de prompt prontos';

  @override
  String get enterCategoryName => 'Insira o nome da categoria';

  @override
  String get entryActions => 'Ações';

  @override
  String get entryLabelsActionSubtitle =>
      'Atribua rótulos para organizar esta entrada';

  @override
  String get entryLabelsActionTitle => 'Etiquetas';

  @override
  String get entryLabelsEditTooltip => 'Editar rótulos';

  @override
  String get entryLabelsHeaderTitle => 'Etiquetas';

  @override
  String get entryLabelsNoLabels => 'Nenhum rótulo atribuído';

  @override
  String get entryTypeLabelAiResponse => 'Resposta de IA';

  @override
  String get entryTypeLabelChecklist => 'Lista de verificação';

  @override
  String get entryTypeLabelChecklistItem => 'Fazer';

  @override
  String get entryTypeLabelHabitCompletionEntry => 'Hábito';

  @override
  String get entryTypeLabelJournalAudio => 'Áudio';

  @override
  String get entryTypeLabelJournalEntry => 'Texto';

  @override
  String get entryTypeLabelJournalEvent => 'Evento';

  @override
  String get entryTypeLabelJournalImage => 'Foto';

  @override
  String get entryTypeLabelMeasurementEntry => 'Medido';

  @override
  String get entryTypeLabelQuantitativeEntry => 'Saúde';

  @override
  String get entryTypeLabelSurveyEntry => 'Pesquisa';

  @override
  String get entryTypeLabelTask => 'Tarefa';

  @override
  String get entryTypeLabelWorkoutEntry => 'Treino';

  @override
  String get eventNameLabel => 'Evento:';

  @override
  String get eventsAddCoverPhoto => 'Adicionar foto de capa';

  @override
  String get eventsAddLabel => 'Adicionar';

  @override
  String get eventsChangeCover => 'Alterar capa';

  @override
  String get eventsDeleteEvent => 'Excluir evento';

  @override
  String get eventsFilterAll => 'Todos';

  @override
  String eventsMetricPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotos',
      one: '1 foto',
    );
    return '$_temp0';
  }

  @override
  String eventsMetricTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tarefas',
      one: '1 tarefa',
    );
    return '$_temp0';
  }

  @override
  String get eventsNewEvent => 'Novo evento';

  @override
  String get eventsPageTitle => 'Eventos';

  @override
  String get eventsPhotosSection => 'Fotos';

  @override
  String get eventsRecapAwaitingContent =>
      'Adicione uma foto ou nota e a recapitulação aparecerá aqui.';

  @override
  String get eventsRecapUnavailable =>
      'Não foi possível carregar a recapitulação.';

  @override
  String get eventsRegenerateSummary => 'Regenerar resumo';

  @override
  String get eventsSearchHint => 'Pesquisar eventos';

  @override
  String get eventsSectionUpcoming => 'Próximos';

  @override
  String get eventsStatusCancelled => 'Cancelado';

  @override
  String get eventsStatusCompleted => 'Concluído';

  @override
  String get eventsStatusMissed => 'Perdido';

  @override
  String get eventsStatusOngoing => 'Em andamento';

  @override
  String get eventsStatusPlanned => 'Planejado';

  @override
  String get eventsStatusPostponed => 'Adiado';

  @override
  String get eventsStatusRescheduled => 'Reprogramado';

  @override
  String get eventsStatusTentative => 'Provisório';

  @override
  String get eventsSummaryTitle => 'Resumo';

  @override
  String get eventsTasksEmpty =>
      'Vincule uma tarefa de preparação ou acompanhamento';

  @override
  String get eventsTasksSection => 'Tarefas';

  @override
  String get eventsTimelineEmpty =>
      'Adicione fotos, notas ou uma mensagem de voz';

  @override
  String get eventsTimelineSection => 'Linha do tempo';

  @override
  String get eventsTitleHint => 'Título do evento';

  @override
  String get eventsVoiceNote => 'Nota de voz';

  @override
  String get favoriteLabel => 'Favorito';

  @override
  String get fileMenuNewEllipsis => 'Novo ...';

  @override
  String get fileMenuNewEntry => 'Nova entrada';

  @override
  String get fileMenuNewScreenshot => 'Captura de tela';

  @override
  String get fileMenuNewTask => 'Tarefa';

  @override
  String get fileMenuTitle => 'Arquivo';

  @override
  String get filterSelectionNoMatches => 'Nenhuma correspondência';

  @override
  String get geminiThinkingModeHighDescription =>
      'Raciocínio mais profundo; pode aumentar a latência e o custo.';

  @override
  String get geminiThinkingModeHighLabel => 'Alto';

  @override
  String get geminiThinkingModeLowDescription =>
      'Baixo raciocínio para solicitações rápidas do dia a dia.';

  @override
  String get geminiThinkingModeLowLabel => 'Baixo';

  @override
  String get geminiThinkingModeMediumDescription =>
      'Raciocínio equilibrado para respostas mais cuidadosas.';

  @override
  String get geminiThinkingModeMediumLabel => 'Médio';

  @override
  String get geminiThinkingModeMinimalDescription =>
      'Configuração mais rápida; Gêmeos ainda pode pensar brevemente em instruções complexas.';

  @override
  String get geminiThinkingModeMinimalLabel => 'Mínimo';

  @override
  String get generateCoverArt => 'Gerar capa';

  @override
  String get generateCoverArtSubtitle =>
      'Criar imagem a partir da descrição de voz';

  @override
  String goalAttainmentLabel(int percent) {
    return '$percent% da meta';
  }

  @override
  String get goalBannerActionFailed => 'Isso não foi salvo — tente novamente.';

  @override
  String get goalBannerDismissTooltip => 'Dispensar';

  @override
  String get goalBannerRateTooltip => 'Avaliar este banner';

  @override
  String get goalBannerRatingSkip => 'Ignorar';

  @override
  String get goalBannerRatingTitle => 'O que achaste deste banner?';

  @override
  String goalBannerSemanticLabel(String goalTitle) {
    return 'Banner da meta $goalTitle';
  }

  @override
  String get goalCreateFailed =>
      'Não foi possível guardar a meta — tenta novamente.';

  @override
  String get goalCreateHabitCountLabel => 'Vezes por semana (cada hábito)';

  @override
  String get goalCreateHabitCountRange =>
      'A contagem semanal deve ficar entre 1 e 7.';

  @override
  String get goalCreateHabitsLabel => 'Hábitos a acompanhar';

  @override
  String get goalCreateHabitsLoadFailed =>
      'Não foi possível carregar seus hábitos agora — tente novamente em instantes.';

  @override
  String get goalCreateNameLabel => 'Nome';

  @override
  String get goalCreateSaveButton => 'Criar agente';

  @override
  String get goalCreateStatementLabel => 'Descrição da meta';

  @override
  String get goalCreateStepsTargetLabel => 'Média de passos por dia';

  @override
  String get goalCreateTypeHabits => 'Rotina de hábitos';

  @override
  String get goalCreateTypeSteps => 'Passos diários (semana móvel)';

  @override
  String get goalCreateValidationMissing =>
      'Dá um nome à meta e pelo menos um critério.';

  @override
  String get goalDetailHealthUnavailable =>
      'Não foi possível carregar a saúde desta meta agora.';

  @override
  String get goalDetailNoReport =>
      'Ainda sem relatório — o agente reporta após a primeira mudança relevante.';

  @override
  String get goalDetailNotFound => 'Este agente de meta não existe mais.';

  @override
  String get goalDetailTimelineTitle => 'Interações';

  @override
  String get goalNudgeStatusDismissed => 'Dispensado';

  @override
  String get goalNudgeStatusExpired => 'Expirado';

  @override
  String get goalNudgeStatusRetired => 'Retirado';

  @override
  String get goalNudgeStatusSuperseded => 'Substituído';

  @override
  String get goalPendingProposalBadge => 'Proposta a aguardar revisão';

  @override
  String get goalStatusAchieved => 'Alcançado';

  @override
  String get goalStatusAtRisk => 'Em risco';

  @override
  String get goalStatusInsufficientData => 'Sem dados';

  @override
  String get goalStatusOffTrack => 'Fora do caminho';

  @override
  String get goalStatusOnTrack => 'No bom caminho';

  @override
  String get goalStatusRecovering => 'A recuperar';

  @override
  String get goalWindowCalendarMonth => 'mês de calendário';

  @override
  String get goalWindowCalendarWeek => 'semana de calendário';

  @override
  String goalWindowRollingDays(int count) {
    return '$count dias corridos';
  }

  @override
  String get goalWindowSingleDay => 'um único dia';

  @override
  String get goMenuTitle => 'Vá';

  @override
  String get habitActiveFromLabel => 'Data de início';

  @override
  String get habitActiveSwitchDescription => 'Exibido na página Hábitos';

  @override
  String get habitArchivedLabel => 'Arquivado';

  @override
  String get habitCategoryHint => 'Selecione uma categoria';

  @override
  String get habitCategoryLabel => 'Categoria';

  @override
  String get habitCloseCompletionLabel => 'Fechar a conclusão do hábito';

  @override
  String habitCompleteSemanticLabel(String habit) {
    return 'Registrar $habit';
  }

  @override
  String get habitCompletionStatusCompleted => 'Concluído';

  @override
  String get habitCompletionStatusFailed => 'Falha';

  @override
  String get habitCompletionStatusOpen => 'Abrir';

  @override
  String get habitCompletionStatusSkipped => 'Ignorado';

  @override
  String get habitDashboardHint => 'Selecione um painel';

  @override
  String get habitDashboardLabel => 'Painel (opcional)';

  @override
  String habitDayStatusSemantic(String habit, String status) {
    return '$habit, $status';
  }

  @override
  String get habitDeleteConfirm => 'Sim, excluir este hábito';

  @override
  String get habitDeleteQuestion => 'Quer eliminar esse hábito?';

  @override
  String habitHeatmapDaySemantic(String date, int done, int total) {
    return '$date, $done de $total concluído';
  }

  @override
  String get habitLogOtherDayHint => 'Segure para registrar outro dia';

  @override
  String get habitNotRecordedLabel => 'Não registrado';

  @override
  String get habitPriorityLabel => 'Prioridade';

  @override
  String get habitsAboveGoal => 'No caminho certo';

  @override
  String habitsActiveHabitsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hábitos ativos',
      one: '1 hábito ativo',
    );
    return '$_temp0';
  }

  @override
  String get habitsAllDoneToday => 'Tudo feito hoje';

  @override
  String get habitsChartUseDynamicBaseline => 'Usar linha de base dinâmica';

  @override
  String get habitsChartUseZeroBaseline => 'Usar linha de base zero';

  @override
  String get habitsCompletedHeader => 'Concluído';

  @override
  String get habitsCompletionRateTitle => 'Taxa de conclusão';

  @override
  String get habitsConsistencyTitle => 'Consistência';

  @override
  String habitsDayFailedPercent(int percent) {
    return '$percent% de falhas registradas';
  }

  @override
  String habitsDaySkippedPercent(int percent) {
    return '$percent% ignorados';
  }

  @override
  String habitsDaySuccessfulPercent(int percent) {
    return '$percent% de sucesso';
  }

  @override
  String get habitsDoneTodayLabel => 'Feito hoje';

  @override
  String get habitSectionOptionsTitle => 'Opções';

  @override
  String get habitSectionScheduleTitle => 'Cronograma';

  @override
  String get habitsFilterAll => 'tudo';

  @override
  String get habitsFilterCompleted => 'feito';

  @override
  String get habitsFilterOpenNow => 'devido';

  @override
  String get habitsFilterPendingLater => 'mais tarde';

  @override
  String get habitsGoalLineLabel => 'Objetivo';

  @override
  String get habitsHeatmapEmpty =>
      'Adicione um hábito para começar a construir sua consistência';

  @override
  String get habitsHeatmapLess => 'Menos';

  @override
  String get habitsHeatmapMore => 'Mais';

  @override
  String get habitShowAlertAtLabel => 'Mostrar alerta em';

  @override
  String get habitShowFromLabel => 'Mostrar de';

  @override
  String habitsLaggardHint(String habit, int kept, int active) {
    return '$habit — mantido $kept de $active';
  }

  @override
  String get habitsOpenHeader => 'Vencimento agora';

  @override
  String get habitsPendingLaterHeader => 'Mais tarde hoje';

  @override
  String habitsPointsToGoal(int points) {
    String _temp0 = intl.Intl.pluralLogic(
      points,
      locale: localeName,
      other: '$points pontos para a meta',
      one: '1 ponto para a meta',
    );
    return '$_temp0';
  }

  @override
  String get habitsRecordButton => 'Gravar';

  @override
  String get habitsRollingAverageLabel => 'Média de 7 dias';

  @override
  String get habitsStartStreakToday => 'Comece uma sequência hoje';

  @override
  String habitsStreakLongCount(int count) {
    return '$count em uma sequência de 7 dias';
  }

  @override
  String habitsStreakShortCount(int count) {
    return '$count em uma sequência de 3 dias';
  }

  @override
  String get habitsTapForBreakdown => 'Toque em um dia para o detalhamento';

  @override
  String habitsToGoCount(int count) {
    return '$count para ir';
  }

  @override
  String habitStreakDaysSemantic(int count) {
    return 'sequência de $count dias';
  }

  @override
  String get habitsVsPreviousWeek => 'versus semana anterior';

  @override
  String get helpMenuCommandPalette => 'Paleta de comandos…';

  @override
  String get helpMenuKeyboardShortcuts => 'Atalhos de teclado…';

  @override
  String get helpMenuTitle => 'Ajuda';

  @override
  String get imageGenerationError => 'Falha ao gerar imagem';

  @override
  String get imageGenerationGenerating => 'Gerando imagem...';

  @override
  String get imageGenerationProviderRejectedTitle =>
      'O provedor de imagem rejeitou esta solicitação';

  @override
  String imageGenerationWithReferences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Usando $count imagens de referência',
      one: 'Usando 1 imagem de referência',
      zero: 'Sem imagens de referência',
    );
    return '$_temp0';
  }

  @override
  String get imagePromptGenerationCardTitle => 'Prompt de imagem AI';

  @override
  String get imagePromptGenerationCopiedSnackbar =>
      'Prompt de imagem copiado para a área de transferência';

  @override
  String get imagePromptGenerationCopyButton => 'Copiar prompt';

  @override
  String get imagePromptGenerationCopyTooltip =>
      'Copiar prompt de imagem para a área de transferência';

  @override
  String get imagePromptGenerationExpandTooltip => 'Mostrar prompt completo';

  @override
  String get imagePromptGenerationFullPromptLabel =>
      'Prompt de imagem completo:';

  @override
  String get images => 'Imagens';

  @override
  String get imageViewerDownloadFailed => 'Não foi possível salvar a imagem';

  @override
  String get imageViewerDownloadingTooltip => 'Salvando imagem';

  @override
  String get imageViewerDownloadPermissionDenied =>
      'Acesso à foto negado – ative-o nas configurações';

  @override
  String imageViewerDownloadSaved(String fileName) {
    return '$fileName salvo';
  }

  @override
  String get imageViewerDownloadSavedToGallery => 'Salvo em fotos';

  @override
  String get imageViewerDownloadTooltip => 'Baixar imagem';

  @override
  String get imageViewerNextTooltip => 'Próxima imagem';

  @override
  String get imageViewerPreviousTooltip => 'Imagem anterior';

  @override
  String get inactiveLabel => 'Inativo';

  @override
  String get inactiveSwitchDescription =>
      'Pode ser escolhido para novas entradas quando ativado';

  @override
  String get inferenceProfileChooseModelTitle => 'Escolha um modelo';

  @override
  String get inferenceProfileChooseTitle => 'Escolha um perfil de inferência';

  @override
  String get inferenceProfileCreateTitle => 'Criar perfil';

  @override
  String get inferenceProfileDescriptionLabel => 'Descrição';

  @override
  String get inferenceProfileDesktopOnly => 'Somente área de trabalho';

  @override
  String get inferenceProfileDesktopOnlyDescription =>
      'Disponível apenas em plataformas desktop (por exemplo, para modelos locais)';

  @override
  String inferenceProfileDetailLoadError(String error) {
    return 'Não foi possível carregar o perfil: $error';
  }

  @override
  String get inferenceProfileDetailNotFound => 'Perfil não encontrado';

  @override
  String get inferenceProfileEditTitle => 'Editar perfil';

  @override
  String get inferenceProfileImageGeneration => 'Geração de imagem';

  @override
  String get inferenceProfileImageRecognition => 'Reconhecimento de imagem';

  @override
  String get inferenceProfileModelUnavailable =>
      'Modelo indisponível – seu fornecedor pode ter sido removido';

  @override
  String get inferenceProfileNameLabel => 'Nome do perfil';

  @override
  String get inferenceProfileNameRequired => 'Um nome de perfil é obrigatório';

  @override
  String get inferenceProfilePinnedHostHelper =>
      'Quando definido, apenas este dispositivo executa automaticamente a inferência para entradas de áudio sincronizadas que usam este perfil.';

  @override
  String get inferenceProfilePinnedHostLabel => 'Dispositivo fixado';

  @override
  String get inferenceProfilePinnedHostNoEligibleNodes =>
      'Nenhum dispositivo conhecido anuncia os provedores que este perfil usa. Abra as configurações do nó de sincronização no dispositivo de destino.';

  @override
  String get inferenceProfilePinnedHostNoneHelper =>
      'As entradas de áudio sincronizadas não são transcritas automaticamente quando nenhum dispositivo está fixado.';

  @override
  String get inferenceProfilePinnedHostNoneLabel =>
      'Não fixado (sem acionamento automático)';

  @override
  String get inferenceProfilePinnedHostThisDeviceSuffix => '(este dispositivo)';

  @override
  String get inferenceProfileSaveButton => 'Salvar';

  @override
  String get inferenceProfileSelectModel => 'Escolha um modelo…';

  @override
  String get inferenceProfileSelectProfile => 'Escolha um perfil…';

  @override
  String get inferenceProfilesEmpty => 'Ainda não há perfis de inferência';

  @override
  String inferenceProfileSkillModelRequired(String slotName) {
    return 'Requer que o modelo $slotName seja definido';
  }

  @override
  String get inferenceProfileSkillsSection => 'Habilidades Automatizadas';

  @override
  String inferenceProfileSkillUsesModel(String slotName) {
    return 'Usa o modelo $slotName';
  }

  @override
  String get inferenceProfilesTitle => 'Perfis de inferência';

  @override
  String get inferenceProfileThinking => 'Pensando';

  @override
  String get inferenceProfileThinkingHighEnd => 'Pensando (sofisticado)';

  @override
  String get inferenceProfileThinkingRequired =>
      'É necessário um modelo de pensamento';

  @override
  String get inferenceProfileTranscription => 'Transcrição';

  @override
  String get inferenceProfileUnavailable => 'Perfil de inferência indisponível';

  @override
  String get inputDataTypeAudioFilesDescription =>
      'Use arquivos de áudio como entrada';

  @override
  String get inputDataTypeAudioFilesName => 'Arquivos de áudio';

  @override
  String get inputDataTypeImagesDescription => 'Use imagens como entrada';

  @override
  String get inputDataTypeImagesName => 'Imagens';

  @override
  String get inputDataTypeTaskDescription => 'Use a tarefa atual como entrada';

  @override
  String get inputDataTypeTaskName => 'Tarefa';

  @override
  String get inputDataTypeTasksListDescription =>
      'Use uma lista de tarefas como entrada';

  @override
  String get inputDataTypeTasksListName => 'Lista de tarefas';

  @override
  String get insightsChartCompareCaption => 'Este período versus o anterior';

  @override
  String get insightsChartCompareCaptionPartial =>
      'Este período até agora versus o anterior';

  @override
  String get insightsChartCompareHint => 'Comparação mostrada na tabela abaixo';

  @override
  String get insightsChartCumulativeCaption =>
      'Executando total ao longo do intervalo';

  @override
  String get insightsChartCumulativeShort =>
      'Ainda não há dias suficientes para um total acumulado';

  @override
  String get insightsChartDailyCaption => 'Hora por dia';

  @override
  String get insightsChartHourlyCaption => 'Tempo por hora';

  @override
  String get insightsChartPerDay => 'Por dia';

  @override
  String get insightsChartPerHour => 'Por hora';

  @override
  String get insightsChartPerWeek => 'Por semana';

  @override
  String get insightsChartRunningTotal => 'Total em execução';

  @override
  String get insightsChartTitle => 'Tempo por categoria';

  @override
  String get insightsChartWeeklyCaption => 'Tempo por semana';

  @override
  String get insightsChooseFocusCategories => 'Escolha categorias de foco';

  @override
  String get insightsCompare => 'Comparar';

  @override
  String get insightsCompareFullPeriod => 'período completo';

  @override
  String get insightsComparePrevious => 'Anterior';

  @override
  String get insightsCompareSameDays => 'mesmos dias';

  @override
  String get insightsCompareTooltip => 'Compare com o período anterior';

  @override
  String get insightsCompareVs => 'contra';

  @override
  String get insightsDeletedCategory => 'Categoria excluída';

  @override
  String get insightsDeltaNew => 'novo';

  @override
  String get insightsEmptyBody =>
      'O tempo que você acompanha nas entradas e tarefas aparecerá aqui.';

  @override
  String get insightsEmptyChart => 'Não há dados neste intervalo';

  @override
  String get insightsEmptyPreviousPeriod => 'Mostrar o período anterior';

  @override
  String get insightsEmptyShowYear => 'Ver este ano';

  @override
  String get insightsEmptyTitle => 'Nenhum tempo monitorado neste intervalo';

  @override
  String get insightsFocusCategoriesEmpty => 'Nenhuma categoria ativa ainda.';

  @override
  String get insightsFocusCategoriesTitle => 'Categorias de foco';

  @override
  String get insightsKpiFocus => 'FOCO';

  @override
  String get insightsKpiFocusHelp => 'Categorias que você está assistindo';

  @override
  String get insightsKpiOther => 'OUTRO';

  @override
  String get insightsKpiOtherHelp => 'Todo o resto';

  @override
  String insightsKpiTopCategory(String category, String share) {
    return 'A maioria em $category · $share';
  }

  @override
  String get insightsKpiTotal => 'TOTAL';

  @override
  String get insightsLoadError =>
      'Não foi possível carregar os dados de horário';

  @override
  String get insightsOtherCategories => 'Outro';

  @override
  String get insightsPartialWeek => 'semana parcial';

  @override
  String get insightsPeriodDay => 'Dia';

  @override
  String get insightsPeriodJump => 'Ir para um encontro';

  @override
  String get insightsPeriodMonth => 'Mês';

  @override
  String get insightsPeriodNext => 'Próximo período';

  @override
  String get insightsPeriodPrevious => 'Período anterior';

  @override
  String get insightsPeriodQuarter => 'Trimestre';

  @override
  String get insightsPeriodToDateSuffix => 'até agora';

  @override
  String get insightsPeriodWeek => 'Semana';

  @override
  String get insightsPeriodYear => 'Ano';

  @override
  String get insightsRangeMonthToDate => 'Este mês até agora';

  @override
  String get insightsRangeMtd => 'Este mês';

  @override
  String get insightsRangeYearToDate => 'Este ano até agora';

  @override
  String get insightsRangeYtd => 'Este ano';

  @override
  String get insightsRefreshError =>
      'Não foi possível atualizar — mostrando os últimos dados carregados';

  @override
  String get insightsTableAvgPerDay => 'Média/dia';

  @override
  String get insightsTableCategory => 'CATEGORIA';

  @override
  String get insightsTableCompareNote =>
      'A mudança é em relação ao período anterior';

  @override
  String get insightsTableCurrent => 'ATUAL';

  @override
  String get insightsTableDelta => 'Mudança';

  @override
  String get insightsTablePrevious => 'ANTERIOR';

  @override
  String get insightsTableShare => 'COMPARTILHE';

  @override
  String get insightsTableTotal => 'TOTAL';

  @override
  String get insightsTimeAnalysisTitle => 'Análise de Tempo';

  @override
  String get insightsUncategorized => 'Sem categoria';

  @override
  String get journalCopyImageLabel => 'Copiar imagem';

  @override
  String get journalDateFromLabel => 'Data de:';

  @override
  String get journalDateInvalid => 'Período inválido';

  @override
  String get journalDateLabel => 'Data';

  @override
  String get journalDateNowButton => 'Agora';

  @override
  String get journalDateSaveButton => 'Salvar';

  @override
  String get journalDateTimeRangeTitle => 'Data e hora';

  @override
  String get journalDateToLabel => 'Data para:';

  @override
  String get journalDeleteConfirm => 'Sim, excluir esta entrada';

  @override
  String get journalDeleteHint => 'Excluir entrada';

  @override
  String get journalDeleteQuestion =>
      'Deseja excluir este lançamento contábil manual?';

  @override
  String get journalDurationLabel => 'Duração';

  @override
  String get journalEndDateLabel => 'Data de término';

  @override
  String get journalEndsAnotherDayHint =>
      'Escolha uma data de término separada';

  @override
  String get journalEndsAnotherDayLabel => 'Termina em outro dia';

  @override
  String get journalEndTimeLabel => 'Hora de término';

  @override
  String get journalEntryExpandLabel => 'Expandir entrada';

  @override
  String get journalFilterEntryTypesTitle => 'Tipos de entrada';

  @override
  String get journalFilterFlagged => 'Sinalizado';

  @override
  String get journalFilterPrivate => 'Privado';

  @override
  String get journalFilterShowTitle => 'Mostrar';

  @override
  String get journalFilterStarred => 'Com estrela';

  @override
  String get journalFilterTitle => 'Filtrar diário';

  @override
  String get journalHideLinkHint => 'Ocultar link';

  @override
  String get journalHideMapHint => 'Ocultar mapa';

  @override
  String get journalLinkedEntriesActivityFilterAudio => 'Áudio';

  @override
  String get journalLinkedEntriesActivityFilterCode => 'Código';

  @override
  String get journalLinkedEntriesActivityFilterImages => 'Imagens';

  @override
  String get journalLinkedEntriesActivityFilterTimer => 'Temporizador';

  @override
  String get journalLinkedEntriesFilterModalTitle => 'Filtrar e classificar';

  @override
  String get journalLinkedEntriesShowFlaggedOnly =>
      'Mostrar apenas entradas sinalizadas';

  @override
  String get journalLinkedEntriesShowHidden => 'Mostrar entradas ocultas';

  @override
  String get journalLinkedEntriesSortLabel => 'Classificar por';

  @override
  String get journalLinkedEntriesSortNewestFirst => 'O mais novo primeiro';

  @override
  String get journalLinkedEntriesSortOldestFirst => 'Mais antigo primeiro';

  @override
  String get journalLinkedFromLabel => 'Vinculado de:';

  @override
  String get journalLinkFromHint => 'Link de';

  @override
  String get journalLinkToHint => 'Link para';

  @override
  String journalOvernightNextDay(String date) {
    return 'Termina em $date (dia seguinte)';
  }

  @override
  String get journalPrivateTooltip => 'apenas privado';

  @override
  String get journalSearchHint => 'Pesquisar diário...';

  @override
  String get journalSetEndDateTimeNowSemantic =>
      'Defina a data e hora de término para agora';

  @override
  String get journalSetStartDateTimeNowSemantic =>
      'Defina a data e hora de início para agora';

  @override
  String get journalShareHint => 'Compartilhar';

  @override
  String get journalShowLinkHint => 'Mostrar link';

  @override
  String get journalShowMapHint => 'Mostrar mapa';

  @override
  String get journalStartDateLabel => 'Data de início';

  @override
  String get journalStartTimeLabel => 'Hora de início';

  @override
  String get journalTodayButton => 'Hoje';

  @override
  String get journalToggleFlaggedTitle => 'Sinalizado';

  @override
  String get journalTogglePrivateTitle => 'Privado';

  @override
  String get journalToggleStarredTitle => 'Favorito';

  @override
  String get journalUnlinkConfirm => 'Sim, desvincular entrada';

  @override
  String get journalUnlinkHint => 'Desvincular';

  @override
  String get journalUnlinkQuestion =>
      'Tem certeza de que deseja desvincular esta entrada?';

  @override
  String get keyboardCommandActivate => 'Ativar item em foco';

  @override
  String get keyboardCommandCategoryCreation => 'Criação';

  @override
  String get keyboardCommandCategoryEditing => 'Edição';

  @override
  String get keyboardCommandCategoryGeneral => 'Geral';

  @override
  String get keyboardCommandCategoryListsAndControls => 'Listas e controles';

  @override
  String get keyboardCommandCategoryNavigation => 'Navegação';

  @override
  String get keyboardCommandCategoryView => 'Ver';

  @override
  String get keyboardCommandCreateInContext => 'Criar na visualização atual';

  @override
  String get keyboardCommandFocusSearch => 'Pesquisa de foco';

  @override
  String get keyboardCommandMoveDown => 'Mover o item em foco para baixo';

  @override
  String get keyboardCommandMoveUp => 'Mover o item em foco para cima';

  @override
  String keyboardCommandNavigate(String destination) {
    return 'Vá para $destination';
  }

  @override
  String get keyboardCommandNextRegion => 'Focar próximo painel';

  @override
  String get keyboardCommandOpenPalette => 'Abrir paleta de comandos';

  @override
  String get keyboardCommandPageDown => 'Descer uma página';

  @override
  String get keyboardCommandPageUp => 'Subir uma página';

  @override
  String get keyboardCommandPreviousRegion => 'Focar painel anterior';

  @override
  String get keyboardCommandRefresh => 'Atualizar visualização atual';

  @override
  String get keyboardCommandRename => 'Renomear item em foco';

  @override
  String get keyboardCommandSelectFirst => 'Selecione o primeiro item';

  @override
  String get keyboardCommandSelectLast => 'Selecione o último item';

  @override
  String get keyboardCommandSelectNext => 'Selecione o próximo item';

  @override
  String get keyboardCommandSelectPrevious => 'Selecione o item anterior';

  @override
  String get keyboardCommandToggle => 'Alternar item em foco';

  @override
  String get keyboardKeyAlt => 'Alt.';

  @override
  String get keyboardKeyArrowDown => 'Seta para baixo';

  @override
  String get keyboardKeyArrowLeft => 'Seta para a esquerda';

  @override
  String get keyboardKeyArrowRight => 'Seta para a direita';

  @override
  String get keyboardKeyArrowUp => 'Seta para cima';

  @override
  String get keyboardKeyControl => 'Ctrl';

  @override
  String get keyboardKeyDelete => 'Excluir';

  @override
  String get keyboardKeyEnd => 'Fim';

  @override
  String get keyboardKeyEnter => 'Entrar';

  @override
  String get keyboardKeyEscape => 'Fuga';

  @override
  String get keyboardKeyHome => 'Página inicial';

  @override
  String get keyboardKeyMinus => 'Menos';

  @override
  String get keyboardKeyOr => 'ou';

  @override
  String get keyboardKeyPageDown => 'Página para baixo';

  @override
  String get keyboardKeyPageUp => 'Página para cima';

  @override
  String get keyboardKeyPlus => 'Mais';

  @override
  String get keyboardKeyShift => 'Mudança';

  @override
  String get keyboardKeySpace => 'Espaço';

  @override
  String get keyboardResizeDividerLabel => 'Redimensionar painéis';

  @override
  String keyboardResizeDividerValue(int value, int min, int max) {
    return 'Redimensionar painéis, $value pixels. Intervalo de $min a $max pixels.';
  }

  @override
  String get keyboardShortcutsNoResults =>
      'Nenhum atalho corresponde à sua pesquisa';

  @override
  String get keyboardShortcutsSearchHint => 'Atalhos de pesquisa…';

  @override
  String get keyboardShortcutsSubtitle =>
      'Cada comando da área de trabalho e sua combinação atual de teclado.';

  @override
  String get keyboardShortcutsTitle => 'Atalhos de teclado';

  @override
  String knowledgeGraphAgeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dias atrás',
      one: '1 dia atrás',
    );
    return '$_temp0';
  }

  @override
  String knowledgeGraphAgeMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count meses atrás',
      one: '1 mês atrás',
    );
    return '$_temp0';
  }

  @override
  String get knowledgeGraphAgeToday => 'hoje';

  @override
  String knowledgeGraphAgeWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count semanas atrás',
      one: '1 semana atrás',
    );
    return '$_temp0';
  }

  @override
  String get knowledgeGraphAgeYesterday => 'ontem';

  @override
  String get knowledgeGraphBack => 'Voltar';

  @override
  String get knowledgeGraphCloseDetails => 'Fechar detalhes';

  @override
  String get knowledgeGraphDensity => 'Densidade';

  @override
  String get knowledgeGraphDensityBalanced => 'Equilibrada';

  @override
  String get knowledgeGraphDensityCalm => 'Calma';

  @override
  String get knowledgeGraphDensityExplore => 'Explorar';

  @override
  String get knowledgeGraphEmpty => 'Ainda não há links para explorar';

  @override
  String get knowledgeGraphEntryLoadError =>
      'Não foi possível carregar esta entrada';

  @override
  String get knowledgeGraphEntryNotFound => 'Entrada não encontrada';

  @override
  String get knowledgeGraphError =>
      'Não foi possível carregar o gráfico de conhecimento';

  @override
  String get knowledgeGraphFilterCategories => 'Categorias';

  @override
  String get knowledgeGraphFilterRecency => 'Recência';

  @override
  String get knowledgeGraphFilterRelations => 'Relações';

  @override
  String get knowledgeGraphFilters => 'Filtros';

  @override
  String get knowledgeGraphFilterTaskStatus => 'Estado da tarefa';

  @override
  String get knowledgeGraphFilterTypes => 'Tipos';

  @override
  String get knowledgeGraphForward => 'Avançar';

  @override
  String get knowledgeGraphLast30Days => 'Últimos 30 dias';

  @override
  String get knowledgeGraphLast7Days => 'Últimos 7 dias';

  @override
  String get knowledgeGraphLast90Days => 'Últimos 90 dias';

  @override
  String knowledgeGraphLinkedSection(int count) {
    return 'VINCULADO · $count';
  }

  @override
  String get knowledgeGraphMoreBelow => 'Mais abaixo';

  @override
  String get knowledgeGraphMoreLinks => 'mais links';

  @override
  String knowledgeGraphNodeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nós',
      one: '1 nó',
    );
    return '$_temp0';
  }

  @override
  String get knowledgeGraphNodeTypeAiSummary => 'Resumo de IA';

  @override
  String get knowledgeGraphNodeTypeAudioNote => 'Nota de áudio';

  @override
  String get knowledgeGraphNodeTypeChecklist => 'Lista de verificação';

  @override
  String get knowledgeGraphNodeTypeChecklistItem =>
      'Item da lista de verificação';

  @override
  String get knowledgeGraphNodeTypeNote => 'Nota';

  @override
  String get knowledgeGraphNodeTypePhoto => 'Foto';

  @override
  String get knowledgeGraphNodeTypeProject => 'Projeto';

  @override
  String get knowledgeGraphNodeTypeRating => 'Avaliação';

  @override
  String get knowledgeGraphNodeTypeTask => 'Tarefa';

  @override
  String get knowledgeGraphOneHop => '1 salto';

  @override
  String get knowledgeGraphOpenDetails => 'Abrir detalhes';

  @override
  String get knowledgeGraphOpenPhoto => 'Ver foto em tela cheia';

  @override
  String knowledgeGraphPhotosSection(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'FOTOGRAFIAS · $count',
      one: 'FOTOGRAFIA · 1',
    );
    return '$_temp0';
  }

  @override
  String get knowledgeGraphRecenter => 'Recentrador';

  @override
  String get knowledgeGraphRecentToOlder => 'recente → mais antigo';

  @override
  String get knowledgeGraphRelationAiSource => 'Fonte de IA';

  @override
  String get knowledgeGraphRelationAssociation => 'Entrada vinculada';

  @override
  String get knowledgeGraphRelationChecklist => 'lista de verificação';

  @override
  String get knowledgeGraphRelationInProject => 'em projeto';

  @override
  String get knowledgeGraphRelationLinkedTask => 'tarefa vinculada';

  @override
  String get knowledgeGraphRelationNoteLog => 'nota / registro';

  @override
  String get knowledgeGraphRelationRating => 'classificação';

  @override
  String get knowledgeGraphSummarySection => 'RESUMO';

  @override
  String get knowledgeGraphTitle => 'Gráfico de conhecimento';

  @override
  String get knowledgeGraphTooltip => 'Explorar links';

  @override
  String get knowledgeGraphTopologyOverview => 'Visão geral da topologia';

  @override
  String get knowledgeGraphTwoHops => '2 saltos';

  @override
  String get knowledgeGraphViewConnections => 'Ligações';

  @override
  String get knowledgeGraphViewGraph => 'Grafo';

  @override
  String knowledgeGraphWalkHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nós',
      one: '1 node',
    );
    return 'Toque em um nó para caminhar · $_temp0';
  }

  @override
  String get linkBlocksCycleErrorMessage =>
      'This would create a blocking cycle — choose a different task.';

  @override
  String linkCreatedMessage(String relation, String title) {
    return '$relation: $title';
  }

  @override
  String get linkCreatedUndo => 'Undo';

  @override
  String get linkCreateFailedMessage =>
      'Couldn\'t create the link. Please try again.';

  @override
  String get linkDirectionLabel => 'This task…';

  @override
  String get linkedTaskImageBadge => 'Da tarefa vinculada';

  @override
  String get linkedTasksBlockedBySectionTitle => 'Blocked by';

  @override
  String get linkedTasksEmptyAction => 'Link a task…';

  @override
  String get linkedTasksEmptyHint => 'Conecte esta tarefa a outra tarefa.';

  @override
  String get linkedTasksMenuTooltip => 'Opções de tarefas vinculadas';

  @override
  String get linkedTasksTitle => 'Tarefas Vinculadas';

  @override
  String get linkExistingTask => 'Vincular tarefa existente…';

  @override
  String get linkExistingTaskTitle => 'Link existing task';

  @override
  String get linkPhraseBasic => 'Relates to';

  @override
  String get linkPhraseBlocksInverse => 'Is blocked by';

  @override
  String get linkPhraseBlocksPrimary => 'Blocks';

  @override
  String get linkPhraseDuplicatesInverse => 'Is duplicated by';

  @override
  String get linkPhraseDuplicatesPrimary => 'Duplicates';

  @override
  String get linkPhraseFixesInverse => 'Is fixed by';

  @override
  String get linkPhraseFixesPrimary => 'Fixes';

  @override
  String get linkPhraseFollowsUpInverse => 'Has follow-up';

  @override
  String get linkPhraseFollowsUpPrimary => 'Follows up on';

  @override
  String get linkPhraseSupersedesInverse => 'Is superseded by';

  @override
  String get linkPhraseSupersedesPrimary => 'Supersedes';

  @override
  String linkPickerCreateTaskSemanticLabel(String title) {
    return 'Create task: $title';
  }

  @override
  String linkSummaryBasic(Object target) {
    return 'Esta tarefa relaciona-se com $target';
  }

  @override
  String linkSummaryBlocksInverse(Object target) {
    return 'Esta tarefa está bloqueada por $target';
  }

  @override
  String linkSummaryBlocksPrimary(Object target) {
    return 'Esta tarefa bloqueia $target';
  }

  @override
  String linkSummaryDuplicatesInverse(Object target) {
    return 'Esta tarefa está duplicada por $target';
  }

  @override
  String linkSummaryDuplicatesPrimary(Object target) {
    return 'Esta tarefa duplica $target';
  }

  @override
  String linkSummaryFixesInverse(Object target) {
    return 'Esta tarefa está corrigida por $target';
  }

  @override
  String linkSummaryFixesPrimary(Object target) {
    return 'Esta tarefa corrige $target';
  }

  @override
  String linkSummaryFollowsUpInverse(Object target) {
    return 'Esta tarefa tem como seguimento $target';
  }

  @override
  String linkSummaryFollowsUpPrimary(Object target) {
    return 'Esta tarefa dá seguimento a $target';
  }

  @override
  String get linkSummaryNewTaskBasic =>
      'Esta tarefa relaciona-se com a nova tarefa';

  @override
  String get linkSummaryNewTaskBlocksInverse =>
      'A nova tarefa bloqueia esta tarefa';

  @override
  String get linkSummaryNewTaskBlocksPrimary =>
      'Esta tarefa bloqueia a nova tarefa';

  @override
  String get linkSummaryNewTaskDuplicatesInverse =>
      'A nova tarefa duplica esta tarefa';

  @override
  String get linkSummaryNewTaskDuplicatesPrimary =>
      'Esta tarefa duplica a nova tarefa';

  @override
  String get linkSummaryNewTaskFixesInverse =>
      'A nova tarefa corrige esta tarefa';

  @override
  String get linkSummaryNewTaskFixesPrimary =>
      'Esta tarefa corrige a nova tarefa';

  @override
  String get linkSummaryNewTaskFollowsUpInverse =>
      'A nova tarefa dá seguimento a esta tarefa';

  @override
  String get linkSummaryNewTaskFollowsUpPrimary =>
      'Esta tarefa dá seguimento à nova tarefa';

  @override
  String get linkSummaryNewTaskSupersedesInverse =>
      'A nova tarefa substitui esta tarefa';

  @override
  String get linkSummaryNewTaskSupersedesPrimary =>
      'Esta tarefa substitui a nova tarefa';

  @override
  String linkSummarySupersedesInverse(Object target) {
    return 'Esta tarefa está substituída por $target';
  }

  @override
  String linkSummarySupersedesPrimary(Object target) {
    return 'Esta tarefa substitui $target';
  }

  @override
  String get linkTaskButton => 'Link';

  @override
  String get logbookEmptyHint => 'Create your first entry to start journaling.';

  @override
  String get logbookEmptyTitle => 'Your logbook is empty';

  @override
  String get logbookNewEntriesHint => 'New entries will open here.';

  @override
  String get logbookNoMatchesHint =>
      'Adjust your search or filters to see more.';

  @override
  String get logbookNoMatchesTitle => 'No entries match';

  @override
  String get loggingDomainAgentRuntime => 'Tempo de execução do agente';

  @override
  String get loggingDomainAgentWorkflow => 'Fluxo de trabalho do agente';

  @override
  String get loggingDomainAi => 'IA';

  @override
  String get loggingDomainCalendar => 'Calendário e horário';

  @override
  String get loggingDomainChat => 'Bate-papo';

  @override
  String get loggingDomainDailyOs => 'SO diário';

  @override
  String get loggingDomainDatabase => 'Banco de dados';

  @override
  String get loggingDomainGeneral => 'Geral';

  @override
  String get loggingDomainHabits => 'Hábitos';

  @override
  String get loggingDomainHealth => 'Saúde';

  @override
  String get loggingDomainLabels => 'Etiquetas';

  @override
  String get loggingDomainLocation => 'Localização';

  @override
  String get loggingDomainNavigation => 'Navegação';

  @override
  String get loggingDomainNotifications => 'Notificações';

  @override
  String get loggingDomainOnboarding => 'Integração e FTUE';

  @override
  String get loggingDomainPersistence => 'Persistência';

  @override
  String get loggingDomainRatings => 'Avaliações';

  @override
  String get loggingDomainScreenshots => 'Capturas de tela';

  @override
  String get loggingDomainSettings => 'Configurações';

  @override
  String get loggingDomainSpeech => 'Fala e áudio';

  @override
  String get loggingDomainSync => 'Sincronizar';

  @override
  String get loggingDomainTasks => 'Tarefas e listas de verificação';

  @override
  String get loggingDomainTheming => 'Tema';

  @override
  String get loggingDomainWhatsNew => 'O que há de novo';

  @override
  String get maintenanceDeleteAgentDb => 'Excluir banco de dados de agentes';

  @override
  String get maintenanceDeleteAgentDbDescription =>
      'Exclua o banco de dados de agentes e reinicie o aplicativo';

  @override
  String get maintenanceDeleteDatabaseConfirm => 'Sim, excluir banco de dados';

  @override
  String maintenanceDeleteDatabaseQuestion(String databaseName) {
    return 'Tem certeza de que deseja excluir o banco de dados $databaseName?';
  }

  @override
  String get maintenanceDeleteEditorDb => 'Excluir banco de dados do editor';

  @override
  String get maintenanceDeleteEditorDbDescription =>
      'Excluir banco de dados de rascunhos do editor';

  @override
  String get maintenanceDeleteSyncDb =>
      'Excluir banco de dados de sincronização';

  @override
  String get maintenanceDeleteSyncDbDescription =>
      'Excluir banco de dados de sincronização';

  @override
  String get maintenanceGenerateEmbeddings => 'Gerar incorporações';

  @override
  String get maintenanceGenerateEmbeddingsConfirm => 'Sim, gerar';

  @override
  String get maintenanceGenerateEmbeddingsDescription =>
      'Gere embeddings para entradas em categorias selecionadas';

  @override
  String get maintenanceGenerateEmbeddingsMessage =>
      'Selecione categorias para gerar incorporações.';

  @override
  String maintenanceGenerateEmbeddingsProgress(
    int processed,
    int total,
    int embedded,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$processed / $total entradas ($embedded incorporado)',
      one: '$processed / $total entrada ($embedded incorporado)',
    );
    return '$_temp0';
  }

  @override
  String get maintenancePopulatePhaseAgentEntities =>
      'Entidades agentes de processamento...';

  @override
  String get maintenancePopulatePhaseAgentLinks =>
      'Processando links de agente...';

  @override
  String get maintenancePopulatePhaseJournal =>
      'Processando lançamentos contábeis manuais...';

  @override
  String get maintenancePopulatePhaseLinks => 'Processando links de entrada...';

  @override
  String get maintenancePopulateSequenceLog =>
      'Preencher log de sequência de sincronização';

  @override
  String maintenancePopulateSequenceLogComplete(int count) {
    return '$count entradas indexadas';
  }

  @override
  String get maintenancePopulateSequenceLogConfirm => 'Sim, preencher';

  @override
  String get maintenancePopulateSequenceLogDescription =>
      'Indexar entradas existentes para suporte de preenchimento';

  @override
  String get maintenancePopulateSequenceLogMessage =>
      'Isso verificará todas as entradas do diário e as adicionará ao log da sequência de sincronização. Isso permite respostas de preenchimento para entradas criadas antes da adição desse recurso.';

  @override
  String get maintenancePurgeDeleted => 'Limpar itens excluídos';

  @override
  String get maintenancePurgeDeletedConfirm => 'Sim, limpe tudo';

  @override
  String get maintenancePurgeDeletedDescription =>
      'Limpar todos os itens excluídos permanentemente';

  @override
  String get maintenancePurgeDeletedMessage =>
      'Tem certeza de que deseja limpar todos os itens excluídos? Esta ação não pode ser desfeita.';

  @override
  String get maintenancePurgeSentOutbox =>
      'Limpar itens antigos enviados da caixa de saída';

  @override
  String get maintenancePurgeSentOutboxConfirm => 'Sim, purgar';

  @override
  String get maintenancePurgeSentOutboxDescription =>
      'Exclua linhas da caixa de saída enviadas com mais de 7 dias e recupere o disco';

  @override
  String get maintenancePurgeSentOutboxQuestion =>
      'Limpar itens da caixa de saída enviados há mais de 7 dias? Isso exclui linhas já enviadas em partes e executa VACUUM para recuperar o disco. Os itens pendentes e com erro são mantidos.';

  @override
  String get maintenanceRecreateFts5 => 'Recrie o índice de texto completo';

  @override
  String get maintenanceRecreateFts5Confirm => 'Sim, recriar índice';

  @override
  String get maintenanceRecreateFts5Description =>
      'Recrie o índice de pesquisa de texto completo';

  @override
  String get maintenanceRecreateFts5Message =>
      'Tem certeza de que deseja recriar o índice de texto completo? Isso pode levar algum tempo.';

  @override
  String get maintenanceReSync => 'Histórico de mensagens';

  @override
  String get maintenanceReSyncAgentEntities => 'Entidades de agente';

  @override
  String get maintenanceReSyncAgentLinks => 'Links de agente';

  @override
  String get maintenanceReSyncCompleteDescription =>
      'Seus outros dispositivos vão recebê-las quando a sincronização estiver em dia.';

  @override
  String get maintenanceReSyncCompleteTitle => 'Mensagens em fila';

  @override
  String get maintenanceReSyncCustom => 'Personalizado';

  @override
  String get maintenanceReSyncDescription =>
      'Coloque mensagens na fila para seus outros dispositivos';

  @override
  String get maintenanceReSyncEntityTypes => 'Tipos de entidade';

  @override
  String get maintenanceReSyncEverything => 'Tudo';

  @override
  String get maintenanceReSyncFailed =>
      'Não foi possível colocar as mensagens em fila. Tente novamente.';

  @override
  String get maintenanceReSyncInvalidRange =>
      'O início deve ser anterior ao fim';

  @override
  String get maintenanceReSyncJournalEntities => 'Entidades de diário';

  @override
  String get maintenanceReSyncLast30Days => 'Últimos 30 dias';

  @override
  String maintenanceReSyncPartialDescription(int failed) {
    String _temp0 = intl.Intl.pluralLogic(
      failed,
      locale: localeName,
      other: 'Falharam $failed itens. Tenta novamente apenas esses itens.',
      one: 'Falhou 1 item. Tenta novamente apenas esse item.',
    );
    return '$_temp0';
  }

  @override
  String maintenanceReSyncPartialTitle(int succeeded, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'mensagens',
      one: 'mensagem',
    );
    return '$succeeded de $total $_temp0 em fila';
  }

  @override
  String get maintenanceReSyncRetryFailed =>
      'Tentar novamente os itens com falha';

  @override
  String get maintenanceReSyncSelectAtLeastOne =>
      'Selecione pelo menos um tipo de entidade';

  @override
  String get maintenanceReSyncSending => 'Preparando mensagens';

  @override
  String get maintenanceReSyncStart => 'Começar';

  @override
  String get maintenanceSyncDefinitions =>
      'Sincronize mensuráveis, painéis, hábitos, categorias, configurações de IA';

  @override
  String get maintenanceSyncDefinitionsDescription =>
      'Sincronize mensuráveis, painéis, hábitos, categorias e configurações de IA';

  @override
  String get manageLinks => 'Gerenciar links…';

  @override
  String get matrixStatsConflicts => 'Conflitos';

  @override
  String get matrixStatsCopyDiagnostics => 'Copiar diagnósticos';

  @override
  String get matrixStatsCopyDiagnosticsTooltip =>
      'Copie os diagnósticos de sincronização para a área de transferência';

  @override
  String get matrixStatsDbApplied => 'BD aplicado';

  @override
  String get matrixStatsDbApply => 'Aplicar BD';

  @override
  String get matrixStatsDbIgnoredVectorClock => 'BD ignorado (VectorClock)';

  @override
  String get matrixStatsDbMissingBase => 'BD sem base';

  @override
  String matrixStatsDbMissingBaseValue(Object count) {
    return 'BD sem base: $count';
  }

  @override
  String get matrixStatsDiagnostics => 'Diagnósticos';

  @override
  String matrixStatsDroppedByType(Object type) {
    return 'Descartado ($type)';
  }

  @override
  String get matrixStatsEntryLinkNoops => 'Operações sem efeito de EntryLink';

  @override
  String get matrixStatsForceRescan => 'Forçar nova verificação';

  @override
  String get matrixStatsForceRescanTooltip =>
      'Force uma nova verificação e atualize agora';

  @override
  String get matrixStatsLastIgnored => 'Últimos ignorados:';

  @override
  String get matrixStatsLegendTooltip =>
      'Legenda:\n• dbApplied = linhas gravadas no banco de dados\n• dbIgnoredByVectorClock = dados recebidos mais antigos ou idênticos ignorados pelo banco de dados\n• conflictsCreated = relógios vetoriais simultâneos registrados\n• dbMissingBase = ignorado enquanto se espera uma dependência ausente\n• dbEntryLinkNoop = vínculo já existe, nada gravado\n• droppedByType.<type> = descartes por tipo após novas tentativas ou ao ignorar mensagens antigas\n• queueActive = eventos recebidos ainda por aplicar\n• signalConnectivity = impulsos de sincronização após a conexão voltar';

  @override
  String get matrixStatsQueueActive => 'Fila (ativa)';

  @override
  String get matrixStatsRefresh => 'Atualizar';

  @override
  String get matrixStatsRefreshDiagnosticsTooltip => 'Atualizar diagnósticos';

  @override
  String get matrixStatsRetryNow => 'Tentar novamente agora';

  @override
  String get matrixStatsRetryNowTooltip =>
      'Tente novamente as falhas pendentes agora';

  @override
  String get matrixStatsSignals => 'Sinais';

  @override
  String get matrixStatsSignalsConnectivity => 'Sinais (conectividade)';

  @override
  String get matrixStatsTopKpis => 'Principais KPIs';

  @override
  String get measurableDeleteConfirm => 'Sim, excluir este mensurável';

  @override
  String get measurableDeleteQuestion =>
      'Deseja excluir este tipo de dados mensuráveis?';

  @override
  String get measurableNotFound => 'Mensurável não encontrado';

  @override
  String get measurementCommentHint => 'Adicione uma nota (opcional)';

  @override
  String get measurementCommentSemantic => 'Comentário, opcional';

  @override
  String measurementObservedAtChangeSemantic(String dateTime) {
    return 'Observado em $dateTime. Alterar data e hora.';
  }

  @override
  String get measurementQuickAddLabel => 'Registro rápido';

  @override
  String measurementQuickLogSemantic(String value) {
    return 'Registrar $value imediatamente';
  }

  @override
  String get measurementSaveError =>
      'Não foi possível salvar esta medida. Tente novamente.';

  @override
  String get measurementSetObservedAtNowSemantic =>
      'Definir data e hora observadas para agora';

  @override
  String get measurementTimeLabel => 'Hora';

  @override
  String measurementValueSemantic(String measurable) {
    return 'Valor para $measurable';
  }

  @override
  String get mediaShowInFileExplorerAction =>
      'Mostrar no Explorador de Arquivos';

  @override
  String get mediaShowInFilesAction => 'Mostrar em arquivos';

  @override
  String get mediaShowInFinderAction => 'Mostrar no Finder';

  @override
  String get modalityAudioDescription =>
      'Capacidades de processamento de áudio';

  @override
  String get modalityAudioName => 'Áudio';

  @override
  String get modalityImageDescription =>
      'Capacidades de processamento de imagem';

  @override
  String get modalityImageName => 'Imagem';

  @override
  String get modalityTextDescription =>
      'Conteúdo e processamento baseado em texto';

  @override
  String get modalityTextName => 'Texto';

  @override
  String get modelAddPageTitle => 'Adicionar modelo';

  @override
  String get modelEditBackTooltip => 'Voltar';

  @override
  String get modelEditDescriptionHint => 'Descreva este modelo';

  @override
  String get modelEditDescriptionLabel => 'Descrição';

  @override
  String get modelEditDisplayNameHint => 'Um nome amigável para este modelo';

  @override
  String get modelEditDisplayNameLabel => 'Nome de exibição';

  @override
  String get modelEditFunctionCallingDescription =>
      'Este modelo suporta chamadas de funções e ferramentas.';

  @override
  String get modelEditFunctionCallingLabel => 'Chamada de função';

  @override
  String get modelEditGeminiThinkingModeLabel => 'Modo de pensamento de Gêmeos';

  @override
  String get modelEditInputModalitiesHint => 'Selecione os tipos de entrada';

  @override
  String get modelEditInputModalitiesLabel => 'Modalidades de entrada';

  @override
  String get modelEditLoadError => 'Falha ao carregar a configuração do modelo';

  @override
  String get modelEditMaxTokensHint =>
      'Opcional – deixe em branco para ilimitado';

  @override
  String get modelEditMaxTokensLabel => 'Máximo de tokens de conclusão';

  @override
  String get modelEditModalityNoneSelected => 'Nenhum selecionado';

  @override
  String get modelEditOutputModalitiesHint => 'Selecione os tipos de saída';

  @override
  String get modelEditOutputModalitiesLabel => 'Modalidades de saída';

  @override
  String get modelEditPageTitle => 'Editar modelo';

  @override
  String get modelEditProviderHint => 'Selecione um provedor';

  @override
  String get modelEditProviderLabel => 'Provedor';

  @override
  String get modelEditProviderModelIdHint => 'por exemplo gpt-4-turbo';

  @override
  String get modelEditProviderModelIdLabel => 'ID do modelo do provedor';

  @override
  String get modelEditReasoningDescription =>
      'Este modelo usa pensamento estendido/cadeia de pensamento.';

  @override
  String get modelEditReasoningLabel => 'Modelo de raciocínio';

  @override
  String get modelEditSaveButton => 'Salvar';

  @override
  String get modelEditSectionCapabilities => 'Capacidades';

  @override
  String get modelEditSectionIdentity => 'Identidade';

  @override
  String modelManagementSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count modelo$_temp0 selecionado';
  }

  @override
  String get multiSelectAddButton => 'Adicionar';

  @override
  String multiSelectAddButtonWithCount(int count) {
    return 'Adicionar ($count)';
  }

  @override
  String get multiSelectNoItemsFound => 'Nenhum item encontrado';

  @override
  String get navSidebarManualBrowserHint => 'Abre no seu navegador';

  @override
  String get navSidebarManualLabel => 'Manuais';

  @override
  String navTabMoreSemanticsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mais, $count destinos adicionais',
      one: 'Mais, 1 destino adicional',
    );
    return '$_temp0';
  }

  @override
  String get navTabTitleCalendar => 'DailyOS';

  @override
  String get navTabTitleEvents => 'Eventos';

  @override
  String get navTabTitleHabits => 'Hábitos';

  @override
  String get navTabTitleInsights => 'Informações';

  @override
  String get navTabTitleJournal => 'Diário de bordo';

  @override
  String get navTabTitleMore => 'Mais';

  @override
  String get navTabTitleProjects => 'Projetos';

  @override
  String get navTabTitleSettings => 'Configurações';

  @override
  String get navTabTitleTasks => 'Tarefas';

  @override
  String nestedAiResponsesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count Respostas de IA$_temp0';
  }

  @override
  String get noDefaultLanguage => 'Nenhum idioma padrão';

  @override
  String get noTasksFound => 'Nenhuma tarefa encontrada';

  @override
  String get noTasksToLink => 'Nenhuma tarefa disponível para vincular';

  @override
  String get notificationBellEmptySemantics =>
      'Notificações, sem alertas não lidos';

  @override
  String get notificationBellTooltip => 'Notificações';

  @override
  String notificationBellUnseenSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'alerts',
      one: 'alert',
    );
    return 'Notificações, $count não lidas $_temp0';
  }

  @override
  String get notificationInboxDismiss => 'Ignorar notificação';

  @override
  String get notificationInboxEmpty => 'Vocês estão todos em dia.';

  @override
  String get notificationInboxError =>
      'Não foi possível carregar as notificações.';

  @override
  String get notificationInboxTitle => 'Notificações';

  @override
  String get notificationSuggestionAttentionBodyFallback =>
      'Abra a tarefa para revisar.';

  @override
  String notificationSuggestionAttentionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sugestões precisam de sua atenção',
      one: '1 sugestão precisa de sua atenção',
    );
    return '$_temp0';
  }

  @override
  String get onboardingApiKeyConnect => 'Conectar';

  @override
  String get onboardingApiKeyConnecting => 'Conectando…';

  @override
  String get onboardingApiKeyEnterKeyHint =>
      'Insira uma chave válida para continuar.';

  @override
  String get onboardingApiKeyError =>
      'Não foi possível conectar. Verifique sua chave e tente novamente.';

  @override
  String get onboardingApiKeyField => 'Chave de API';

  @override
  String get onboardingApiKeyGetKeyAt => 'Obtenha uma chave em';

  @override
  String get onboardingApiKeyHide => 'Ocultar chave';

  @override
  String get onboardingApiKeyInvalid =>
      'Essa chave foi rejeitada. Verifique novamente e cole novamente.';

  @override
  String get onboardingApiKeyLocalNote =>
      'Funciona no seu dispositivo – sem necessidade de chave.';

  @override
  String get onboardingApiKeyNoKeyHelp =>
      'Novo aqui? Faça login, crie uma chave de API e cole-a – grátis para começar.';

  @override
  String get onboardingApiKeyReveal => 'Mostrar chave';

  @override
  String get onboardingApiKeyTitle => 'Cole sua chave de API';

  @override
  String onboardingApiKeyUnreachable(String providerName) {
    return 'Não foi possível entrar em contato com $providerName. Verifique a chave ou sua conexão e tente novamente.';
  }

  @override
  String get onboardingApiKeyVerifying => 'Verificando…';

  @override
  String get onboardingCaptureCategoryPrompt => 'Onde isso deveria pousar?';

  @override
  String get onboardingCaptureListening => 'Ouvindo… toque quando terminar';

  @override
  String get onboardingCaptureOrbLabel => 'Registre seu pensamento';

  @override
  String get onboardingCaptureRatherType => 'Em vez disso, digite?';

  @override
  String get onboardingCaptureReassurance =>
      'Você poderá editar tudo a seguir.';

  @override
  String get onboardingCaptureThinking =>
      'Transformando suas palavras em uma tarefa…';

  @override
  String get onboardingCaptureTypePrompt => 'Digite seu pensamento';

  @override
  String get onboardingCategoryAddOwn => 'Adicione o seu próprio';

  @override
  String get onboardingCategoryContinue => 'Continuar';

  @override
  String get onboardingCategoryExplanation =>
      'Cada área da sua vida ganha seu próprio espaço. Escolha qualquer um que combine – ou adicione o seu próprio.';

  @override
  String get onboardingCategoryFamily => 'Família';

  @override
  String get onboardingCategoryFitness => 'Fitness';

  @override
  String get onboardingCategoryFriends => 'Amigos';

  @override
  String get onboardingCategoryTitle => 'Onde sua IA deve funcionar?';

  @override
  String get onboardingCategoryWhy => 'Por que áreas?';

  @override
  String onboardingCategoryWhyDetail(String provider) {
    return 'Cada área pode usar sua própria IA. $provider fornecerá energia às áreas que você escolher aqui. Mais tarde, você poderá atribuir IAs diferentes a áreas diferentes.';
  }

  @override
  String get onboardingCategoryWork => 'Trabalho';

  @override
  String get onboardingConnectGeminiName => 'Gêmeos';

  @override
  String get onboardingConnectGeminiTagline => 'Estados Unidos';

  @override
  String get onboardingConnectLessOptions => 'Menos opções';

  @override
  String get onboardingConnectMistralName => 'Mistral';

  @override
  String get onboardingConnectMistralTagline => 'União Europeia';

  @override
  String get onboardingConnectMoreOptions => 'Mais opções';

  @override
  String get onboardingConnectNotSure => 'Melious.ai é o padrão recomendado.';

  @override
  String get onboardingConnectOllamaName => 'Ollama';

  @override
  String get onboardingConnectOpenAiName => 'OpenAI';

  @override
  String get onboardingConnectQwenName => 'Qwen';

  @override
  String get onboardingConnectQwenTagline => 'China';

  @override
  String get onboardingConnectTitle =>
      'Escolha o cérebro de IA para suas tarefas';

  @override
  String get onboardingFirstTaskCreatedHint =>
      'Toque na sua tarefa para abri-la';

  @override
  String get onboardingFirstTaskCreatedTitle =>
      'Sua primeira tarefa está pronta';

  @override
  String get onboardingFirstTaskGuidance =>
      'Toque para falar e dizer o que precisa ser feito - Lotti transforma isso em uma tarefa real.';

  @override
  String get onboardingFirstTaskSuggestionDentist =>
      'Marque uma consulta no dentista';

  @override
  String get onboardingFirstTaskSuggestionMeeting =>
      'Prepare-se para a reunião de segunda-feira';

  @override
  String get onboardingFirstTaskSuggestionPlanWeek => 'Planeje minha semana';

  @override
  String get onboardingFirstTaskSuggestionsLabel =>
      'Não está pronto para conversar? Comece com um destes:';

  @override
  String get onboardingFirstTaskTitle => 'Crie sua primeira tarefa';

  @override
  String get onboardingMetricsActiveDays => 'Dias ativos';

  @override
  String get onboardingMetricsActiveDaysInFirstSeven =>
      'Dias ativos nos primeiros 7';

  @override
  String get onboardingMetricsBaselineCohort =>
      'Coorte de linha de base (pré-FTUE)';

  @override
  String get onboardingMetricsInstallFirstSeenUtc =>
      'Instalar visto pela primeira vez (UTC)';

  @override
  String get onboardingMetricsNo => 'não';

  @override
  String get onboardingMetricsReachedRealAha => 'Alcançado real aha';

  @override
  String get onboardingMetricsYes => 'sim';

  @override
  String get onboardingRecordingStyleAnalogue => 'Analógico - medidor VU';

  @override
  String get onboardingRecordingStyleContinue => 'Continuar';

  @override
  String get onboardingRecordingStyleExplanation =>
      'Escolha uma aparência para o microfone. Você pode alterá-lo a qualquer momento em Configurações.';

  @override
  String get onboardingRecordingStyleModern => 'Moderno - orbe de energia';

  @override
  String get onboardingRecordingStyleTitle => 'Como deve ser a gravação?';

  @override
  String get onboardingRecordingStyleTryVoice => 'Tente com sua voz';

  @override
  String get onboardingSuccessContinue => 'Comece';

  @override
  String get onboardingSuccessSubtitle =>
      'Seu cérebro de IA está conectado e pronto para transformar suas palavras em tarefas.';

  @override
  String get onboardingSuccessTitle => 'Você está pronto';

  @override
  String get onboardingWelcomeConnectButton => 'Escolha seu cérebro de IA';

  @override
  String get onboardingWelcomeMessage =>
      'Conecte seu cérebro de IA, diga um pensamento e observe-o se tornar uma tarefa estruturada.';

  @override
  String get onboardingWelcomeSkipButton => 'Olhe ao redor primeiro';

  @override
  String get onboardingWelcomeTitle =>
      'Fale. Lotti transforma isso em um plano.';

  @override
  String get optionalCategoryLabel => 'Categoria (opcional)';

  @override
  String get outboxActionRemove => 'Remover';

  @override
  String get outboxActionRetry => 'Tentar novamente';

  @override
  String get outboxFailedReassurance =>
      'Ainda salvo neste dispositivo – ele será sincronizado assim que o problema for resolvido.';

  @override
  String get outboxFilterFailed => 'Falha';

  @override
  String get outboxFilterWaiting => 'Esperando';

  @override
  String get outboxMonitorAttachmentLabel => 'Anexo';

  @override
  String get outboxMonitorDelete => 'excluir';

  @override
  String get outboxMonitorDeleteConfirmLabel => 'Excluir';

  @override
  String get outboxMonitorDeleteConfirmMessage =>
      'Tem certeza de que deseja excluir este item de sincronização? Esta ação não pode ser desfeita.';

  @override
  String get outboxMonitorDeleteFailed =>
      'Falha na exclusão. Por favor, tente novamente.';

  @override
  String get outboxMonitorDeleteSuccess => 'Item excluído';

  @override
  String get outboxMonitorEmptyDescription =>
      'Não há itens de sincronização nesta visualização.';

  @override
  String get outboxMonitorEmptyTitle => 'A caixa de saída está limpa';

  @override
  String get outboxMonitorFetchFailed =>
      'Não foi possível carregar a caixa de saída. Puxe para atualizar e tente novamente.';

  @override
  String get outboxMonitorLabelError => 'erro';

  @override
  String get outboxMonitorLabelPending => 'pendente';

  @override
  String get outboxMonitorLabelSent => 'enviado';

  @override
  String get outboxMonitorLabelSuccess => 'sucesso';

  @override
  String get outboxMonitorNoAttachment => 'sem apego';

  @override
  String get outboxMonitorPayloadSizeLabel => 'Tamanho';

  @override
  String get outboxMonitorRetries => 'novas tentativas';

  @override
  String get outboxMonitorRetriesLabel => 'Novas tentativas';

  @override
  String get outboxMonitorRetry => 'tente novamente';

  @override
  String get outboxMonitorRetryConfirmLabel => 'Tente novamente agora';

  @override
  String get outboxMonitorRetryConfirmMessage =>
      'Tentar novamente este item de sincronização agora?';

  @override
  String get outboxMonitorRetryFailed =>
      'Falha na nova tentativa. Por favor, tente novamente.';

  @override
  String get outboxMonitorRetryQueued => 'Nova tentativa agendada';

  @override
  String get outboxMonitorSubjectLabel => 'Assunto';

  @override
  String get outboxMonitorVolumeChartTitle => 'Volume de sincronização diária';

  @override
  String get outboxRemoveConfirmMessage =>
      'Esta alteração ainda não foi sincronizada. Removê-lo aqui significa que ele não alcançará seus outros dispositivos. Ele permanece neste dispositivo.';

  @override
  String get outboxRemoveConfirmTitle => 'Remover da fila?';

  @override
  String get outboxRetryAll => 'Tentar tudo novamente';

  @override
  String get outboxShowDetails => 'Mostrar detalhes técnicos';

  @override
  String get outboxStatusFailed => 'Não foi possível enviar';

  @override
  String get outboxStatusSending => 'Enviando';

  @override
  String get outboxStatusSent => 'Enviado';

  @override
  String get outboxStatusWaiting => 'Esperando para enviar';

  @override
  String outboxSummaryFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens não puderam ser enviados',
      one: '1 item não pôde ser enviado',
    );
    return '$_temp0';
  }

  @override
  String outboxSummaryOffline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens serão enviados quando você se reconectar',
      one: '1 item será enviado quando você se reconectar',
    );
    return '$_temp0';
  }

  @override
  String outboxSummarySending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Enviando $count itens…',
      one: 'Enviando 1 item…',
    );
    return '$_temp0';
  }

  @override
  String get outboxSummarySynced => 'Tudo está sincronizado';

  @override
  String outboxSummaryWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens aguardando envio',
      one: '1 item aguardando envio',
    );
    return '$_temp0';
  }

  @override
  String outboxTriedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tentei $count vezes',
      one: 'Tentei uma vez',
    );
    return '$_temp0';
  }

  @override
  String get panasCompletionText => 'Obrigado por preencher o PANAS!';

  @override
  String get panasCompletionTitle => 'Concluído';

  @override
  String get panasEmotionActive => 'Ativo';

  @override
  String get panasEmotionAfraid => 'Com medo';

  @override
  String get panasEmotionAlert => 'Alerta';

  @override
  String get panasEmotionAshamed => 'Envergonhado';

  @override
  String get panasEmotionAttentive => 'Atento';

  @override
  String get panasEmotionDetermined => 'Determinado';

  @override
  String get panasEmotionDistressed => 'Angustiado';

  @override
  String get panasEmotionEnthusiastic => 'Entusiasmado';

  @override
  String get panasEmotionExcited => 'Animado';

  @override
  String get panasEmotionGuilty => 'Culpado';

  @override
  String get panasEmotionHostile => 'Hostil';

  @override
  String get panasEmotionInspired => 'Inspirado';

  @override
  String get panasEmotionInterested => 'Interessado';

  @override
  String get panasEmotionIrritable => 'Irritável';

  @override
  String get panasEmotionJittery => 'Nervoso';

  @override
  String get panasEmotionNervous => 'Nervoso';

  @override
  String get panasEmotionProud => 'Orgulhoso';

  @override
  String get panasEmotionScared => 'Assustado';

  @override
  String get panasEmotionStrong => 'Forte';

  @override
  String get panasEmotionUpset => 'Chateado';

  @override
  String get panasInstructionFootnote =>
      'Watson, D., Clark, LA e Tellegen, A. (1988). Desenvolvimento e validação de medidas breves de afeto positivo e negativo: As escalas PANAS. Jornal de Personalidade e Psicologia Social, 54(6), 1063–1070.';

  @override
  String get panasInstructionText =>
      'Indique até que ponto você se sente assim agora, ou seja, no momento presente.\n\n1 - Muito pouco ou nada,\n2 – Um pouco,\n3—Moderadamente,\n4 – Bastante,\n5—Extremamente';

  @override
  String get panasInstructionTitle =>
      'O Cronograma de Afetos Positivos e Negativos (PANAS; Watson et al., 1988)';

  @override
  String get panasScaleALittle => 'Um pouco';

  @override
  String get panasScaleExtremely => 'Extremamente';

  @override
  String get panasScaleModerately => 'Moderadamente';

  @override
  String get panasScaleQuiteABit => 'Um pouco';

  @override
  String get panasScaleVerySlightlyOrNotAtAll => 'Muito pouco ou nada';

  @override
  String get privateLabel => 'Privado';

  @override
  String get privateSwitchDescription =>
      'Visível apenas quando entradas privadas são mostradas';

  @override
  String get projectAgentNotProvisioned =>
      'Nenhum agente de projeto foi provisionado para este projeto ainda.';

  @override
  String get projectAgentSectionTitle => 'Agente';

  @override
  String projectCountSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count projetos',
      one: '$count projeto',
    );
    return '$_temp0';
  }

  @override
  String get projectCreateButton => 'Novo Projeto';

  @override
  String get projectCreateTitle => 'Criar projeto';

  @override
  String get projectDetailTitle => 'Detalhes do projeto';

  @override
  String get projectErrorCreateFailed => 'Erro ao criar projeto.';

  @override
  String get projectErrorLoadFailed => 'Falha ao carregar dados do projeto.';

  @override
  String get projectErrorLoadProjects => 'Erro ao carregar projetos';

  @override
  String get projectErrorUpdateFailed =>
      'Falha ao atualizar o projeto. Por favor, tente novamente.';

  @override
  String get projectFilterLabel => 'Projeto';

  @override
  String get projectHealthBandAtRisk => 'Em risco';

  @override
  String get projectHealthBandBlocked => 'Bloqueado';

  @override
  String get projectHealthBandOnTrack => 'No caminho certo';

  @override
  String get projectHealthBandSurviving => 'Sobrevivendo';

  @override
  String get projectHealthBandWatch => 'Assistir';

  @override
  String get projectHealthSectionTitle => 'Saúde do projeto';

  @override
  String projectHealthSummary(int projectCount, int taskCount) {
    String _temp0 = intl.Intl.pluralLogic(
      projectCount,
      locale: localeName,
      other: '$projectCount projetos',
      one: '$projectCount projeto',
    );
    String _temp1 = intl.Intl.pluralLogic(
      taskCount,
      locale: localeName,
      other: '$taskCount tarefas',
      one: '$taskCount tarefa',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get projectHealthTitle => 'Projetos';

  @override
  String projectLinkedTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tarefas vinculadas',
      one: '$count tarefas vinculadas',
    );
    return '$_temp0';
  }

  @override
  String get projectLinkedTasks => 'Tarefas Vinculadas';

  @override
  String get projectManageTooltip => 'Gerenciar projetos';

  @override
  String get projectNoLinkedTasks => 'Nenhuma tarefa vinculada ainda';

  @override
  String get projectNoProjects => 'Ainda não há projetos';

  @override
  String get projectNotFound => 'Projeto não encontrado';

  @override
  String get projectPickerLabel => 'Projeto';

  @override
  String get projectPickerUnassigned => 'Nenhum projeto';

  @override
  String get projectRecommendationDismissTooltip => 'Dispensar';

  @override
  String get projectRecommendationResolveTooltip => 'Marcar como resolvido';

  @override
  String get projectRecommendationsTitle => 'Próximas etapas recomendadas';

  @override
  String get projectRecommendationUpdateError =>
      'Não foi possível atualizar a recomendação. Por favor, tente novamente.';

  @override
  String get projectsFilterStatusLabel => 'Estado:';

  @override
  String get projectsFilterTooltip => 'Filtrar projetos';

  @override
  String get projectShowcaseAiReportTitle => 'Relatório de IA';

  @override
  String projectShowcaseBlockedLegend(int count) {
    return '$count bloqueado';
  }

  @override
  String projectShowcaseBlockedTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tarefas bloqueadas',
      one: '$count tarefas bloqueadas',
    );
    return '$_temp0';
  }

  @override
  String projectShowcaseCompletedLegend(int count) {
    return '$count concluído';
  }

  @override
  String get projectShowcaseDescriptionTitle => 'Descrição';

  @override
  String projectShowcaseDueDate(String date) {
    return 'Vencimento em $date';
  }

  @override
  String get projectShowcaseHealthScoreDescription =>
      'Essa pontuação é baseada na velocidade da tarefa, nos bloqueadores e no tempo restante até o prazo final.';

  @override
  String get projectShowcaseHealthScoreTitle => 'Pontuação de saúde';

  @override
  String get projectShowcaseNoResults =>
      'Nenhum projeto corresponde à sua pesquisa.';

  @override
  String get projectShowcaseOneOnOneReviewsTab => 'Avaliações individuais';

  @override
  String get projectShowcaseOngoing => 'Em andamento';

  @override
  String get projectShowcaseProjectTasksTab => 'Tarefas do Projeto';

  @override
  String get projectShowcaseSearchHint => 'Pesquisar projetos';

  @override
  String projectShowcaseSessionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessões',
      one: '$count sessão',
    );
    return '$_temp0';
  }

  @override
  String projectShowcaseTasksCompleted(int completed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$completed/$total tarefas concluídas',
      one: '$completed/$total tarefas concluídas',
    );
    return '$_temp0';
  }

  @override
  String projectShowcaseUpdatedHoursAgo(int hours) {
    return 'Atualizado há ${hours}h ↻';
  }

  @override
  String projectShowcaseUpdatedMinutesAgo(int minutes) {
    return 'Atualizado há ${minutes}m ↻';
  }

  @override
  String get projectShowcaseUsefulness => 'Utilidade';

  @override
  String get projectShowcaseViewBlocker => 'Ver bloqueador';

  @override
  String get projectStatusActive => 'Ativo';

  @override
  String get projectStatusArchived => 'Arquivado';

  @override
  String get projectStatusChangeTitle => 'Alterar status';

  @override
  String get projectStatusCompleted => 'Concluído';

  @override
  String get projectStatusMonitoring => 'Monitoramento';

  @override
  String get projectStatusOnHold => 'Em espera';

  @override
  String get projectStatusOpen => 'Abrir';

  @override
  String get projectSummaryOutdated => 'Resumo desatualizado.';

  @override
  String projectSummaryOutdatedScheduled(String date, String time) {
    return 'Resumo desatualizado. Próxima atualização $date às $time.';
  }

  @override
  String get projectTargetDateLabel => 'Data prevista';

  @override
  String get projectTitleLabel => 'Título do projeto';

  @override
  String get projectTitleRequired => 'O título do projeto não pode ficar vazio';

  @override
  String get promptDefaultModelBadge => 'Padrão';

  @override
  String get promptGenerationCardTitle => 'Prompt de codificação AI';

  @override
  String get promptGenerationCopiedSnackbar =>
      'Prompt copiado para a área de transferência';

  @override
  String get promptGenerationCopyButton => 'Copiar prompt';

  @override
  String get promptGenerationCopyTooltip =>
      'Copiar prompt para a área de transferência';

  @override
  String get promptGenerationExpandTooltip => 'Mostrar prompt completo';

  @override
  String get promptGenerationFullPromptLabel => 'Alerta completo:';

  @override
  String get promptSelectionModalTitle => 'Selecione o prompt pré-configurado';

  @override
  String get provisionedSyncCopiedToClipboard =>
      'Copiado para a área de transferência';

  @override
  String get provisionedSyncDisconnect =>
      'Parar de sincronizar este dispositivo';

  @override
  String get provisionedSyncDone => 'Ligado';

  @override
  String get provisionedSyncError => 'Esse código não funcionou';

  @override
  String get provisionedSyncErrorConfigurationFailed =>
      'Algo deu errado ao conectar. Tente de novo; se continuar falhando, verifique se o outro dispositivo ainda sincroniza.';

  @override
  String get provisionedSyncErrorLoginFailed =>
      'O servidor não aceitou as credenciais desse código. Um código deixa de funcionar quando a palavra-passe da conta muda — obtém um código novo no teu outro dispositivo, ou tenta novamente se foi só a ligação.';

  @override
  String get provisionedSyncImportButton => 'Continuar';

  @override
  String get provisionedSyncImportHint =>
      'Cole aqui o código de emparelhamento';

  @override
  String get provisionedSyncImportTitle => 'Configurar a sincronização';

  @override
  String get provisionedSyncJoiningRoom =>
      'Configurando o armazenamento compartilhado…';

  @override
  String get provisionedSyncLoggingIn =>
      'Conectando à sua conta de sincronização…';

  @override
  String get provisionedSyncPasteClipboard => 'Colar da área de transferência';

  @override
  String get provisionedSyncRetry => 'Tentar novamente';

  @override
  String get provisionedSyncRotatingPassword => 'Protegendo este dispositivo…';

  @override
  String get provisionedSyncSubtitle => 'Emparelha e gere os teus dispositivos';

  @override
  String get provisionedSyncSummaryHomeserver => 'Servidor de sincronização';

  @override
  String get provisionedSyncSummaryUser => 'Conta de sincronização';

  @override
  String get provisionedSyncTitle => 'Dispositivos';

  @override
  String get queueCatchUpNowButton => 'Acompanhe agora';

  @override
  String get queueCatchUpNowDone =>
      'Catch-up chutado – a fila está se esgotando.';

  @override
  String queueCatchUpNowError(String reason) {
    return 'Falha na atualização: $reason';
  }

  @override
  String get queueDepthCardEmpty => 'Fila vazia – o trabalhador está em dia.';

  @override
  String get queueDepthCardLoading => 'Lendo profundidade da fila…';

  @override
  String get queueDepthCardTitle => 'Fila de entrada';

  @override
  String get queueFetchAllHistoryCancel => 'Cancelar';

  @override
  String queueFetchAllHistoryCancelled(int events) {
    String _temp0 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: '$events events',
      one: '1 event',
      zero: 'no events',
    );
    return 'Cancelado — $_temp0 buscados até agora.';
  }

  @override
  String get queueFetchAllHistoryClose => 'Fechar';

  @override
  String get queueFetchAllHistoryDescription =>
      'Coloca todo o histórico visível da sala na fila. É seguro cancelar; uma execução posterior é retomada de onde a paginação parou.';

  @override
  String queueFetchAllHistoryDone(int events, int pages) {
    String _temp0 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages páginas',
      one: '1 page',
    );
    String _temp1 = intl.Intl.pluralLogic(
      pages,
      locale: localeName,
      other: '$pages páginas',
      one: '1 page',
    );
    String _temp2 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: 'Buscado $events eventos em $_temp0.',
      one: 'Buscado 1 evento em $_temp1.',
      zero: 'Nenhum evento obtido.',
    );
    return '$_temp2';
  }

  @override
  String queueFetchAllHistoryError(String reason) {
    return 'Busca interrompida: $reason';
  }

  @override
  String get queueFetchAllHistoryErrorUnknown => 'Fetch parou inesperadamente.';

  @override
  String queueFetchAllHistoryProgress(int events, int pages) {
    String _temp0 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: 'Página $pages · $events eventos obtidos',
      one: 'Página $pages · 1 evento obtido',
    );
    return '$_temp0';
  }

  @override
  String get queueFetchAllHistoryTitle => 'Buscando histórico';

  @override
  String queueSkippedBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ignorado',
      one: '1 ignorado',
    );
    return '$_temp0';
  }

  @override
  String queueSkippedCardBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count eventos de sincronização dos quais a fila desistiu. Toque em tentar novamente para tentar novamente.',
      one:
          '1 evento de sincronização do qual a fila desistiu. Toque em tentar novamente para tentar novamente.',
    );
    return '$_temp0';
  }

  @override
  String get queueSkippedCardTitle => 'Eventos ignorados';

  @override
  String get queueSkippedRetryAll => 'Tentar novamente eventos ignorados';

  @override
  String queueSkippedRetryAllDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eventos na fila para nova tentativa.',
      one: '1 evento na fila para nova tentativa.',
      zero: 'Nenhum evento ignorado para nova tentativa.',
    );
    return '$_temp0';
  }

  @override
  String queueSkippedRetryAllError(String reason) {
    return 'Falha na nova tentativa: $reason';
  }

  @override
  String get referenceImageContinue => 'Continuar';

  @override
  String referenceImageContinueWithCount(int count) {
    return 'Continuar ($count)';
  }

  @override
  String get referenceImageLoadError =>
      'Falha ao carregar imagens. Por favor, tente novamente.';

  @override
  String referenceImageSelectionSubtitle(int maxImages) {
    return 'Escolha até $maxImages imagens para orientar o estilo visual da IA';
  }

  @override
  String get referenceImageSelectionTitle => 'Selecione imagens de referência';

  @override
  String get referenceImageSkip => 'Pular';

  @override
  String get saveButton => 'Salvar';

  @override
  String get saveButtonLabel => 'Salvar';

  @override
  String get saveLabel => 'Salvar';

  @override
  String get saveShortcutTooltip => 'Salvar — Ctrl+S (⌘S no Mac)';

  @override
  String get saveSuccessful => 'Salvo com sucesso';

  @override
  String get searchHint => 'Pesquisar...';

  @override
  String get searchModeFullText => 'Texto Completo';

  @override
  String get searchModeVector => 'Vetor';

  @override
  String get searchTasksHint => 'Pesquisar tarefas…';

  @override
  String get selectButton => 'Selecione';

  @override
  String get selectColor => 'Selecione uma cor';

  @override
  String get selectLanguage => 'Selecione o idioma';

  @override
  String get sessionRatingCardLabel => 'Classificação da sessão';

  @override
  String get sessionRatingChallengeJustRight => 'Certo';

  @override
  String get sessionRatingChallengeTooEasy => 'Muito fácil';

  @override
  String get sessionRatingChallengeTooHard => 'Muito desafiador';

  @override
  String get sessionRatingDifficultyLabel => 'Este trabalho pareceu...';

  @override
  String get sessionRatingEditButton => 'Editar classificação';

  @override
  String get sessionRatingEnergyQuestion => 'Quão energizado você se sentiu?';

  @override
  String get sessionRatingFocusQuestion => 'Quão focado você estava?';

  @override
  String get sessionRatingNoteHint => 'Nota rápida (opcional)';

  @override
  String get sessionRatingProductivityQuestion =>
      'Quão produtiva foi esta sessão?';

  @override
  String get sessionRatingRateAction => 'Avaliar sessão';

  @override
  String get sessionRatingSaveButton => 'Salvar';

  @override
  String get sessionRatingSaveError =>
      'Falha ao salvar a classificação. Por favor, tente novamente.';

  @override
  String get sessionRatingSkipButton => 'Pular';

  @override
  String get sessionRatingTitle => 'Avalie esta sessão';

  @override
  String get sessionRatingViewAction => 'Ver classificação';

  @override
  String get settingsAboutAppInformation => 'Informações do aplicativo';

  @override
  String get settingsAboutAppTagline => 'Seu diário pessoal';

  @override
  String get settingsAboutBuildType => 'Tipo de construção';

  @override
  String get settingsAboutDailyOsPersonalizationTitle =>
      'Personalização diária do sistema operacional';

  @override
  String get settingsAboutDailyOsUserNameHelper =>
      'Usado para a saudação diária do sistema operacional e sincronizado em seus dispositivos.';

  @override
  String get settingsAboutDailyOsUserNameLabel => 'Seu nome';

  @override
  String get settingsAboutJournalEntries => 'Lançamentos de diário';

  @override
  String get settingsAboutPlatform => 'Plataforma';

  @override
  String get settingsAboutTitle => 'Sobre Lotti';

  @override
  String get settingsAboutVersion => 'Versão';

  @override
  String get settingsAboutYourData => 'Seus dados';

  @override
  String get settingsAdvancedAboutSubtitle =>
      'Saiba mais sobre o aplicativo Lotti';

  @override
  String get settingsAdvancedHealthImportSubtitle =>
      'Importe dados relacionados à saúde de fontes externas';

  @override
  String get settingsAdvancedMaintenanceSubtitle =>
      'Execute tarefas de manutenção para otimizar o desempenho do aplicativo';

  @override
  String get settingsAdvancedManualLanguageSubtitle =>
      'Escolha em qual idioma abrir o Manual Lotti';

  @override
  String get settingsAdvancedOutboxSubtitle =>
      'Gerenciar itens de sincronização';

  @override
  String get settingsAdvancedSubtitle => 'Configurações avançadas e manutenção';

  @override
  String get settingsAdvancedTitle => 'Configurações avançadas';

  @override
  String get settingsAgentsInstancesSubtitle => 'Agentes em execução';

  @override
  String get settingsAgentsPendingWakesSubtitle => 'Despertadores programados';

  @override
  String get settingsAgentsSoulsSubtitle =>
      'Personalidades de agentes de longa vida';

  @override
  String get settingsAgentsTemplatesSubtitle =>
      'Projetos de agente compartilhado';

  @override
  String get settingsAiModelsSubtitle =>
      'Linhas e recursos do modelo por provedor';

  @override
  String get settingsAiModelsTitle => 'Modelos';

  @override
  String get settingsAiProfilesSubtitle => 'Provedores e modelos';

  @override
  String get settingsAiProfilesTitle => 'Perfis de inferência';

  @override
  String get settingsAiProvidersSubtitle =>
      'Provedores e chaves de IA conectada';

  @override
  String get settingsAiProvidersTitle => 'Provedores';

  @override
  String get settingsAiSubtitle =>
      'Configurar provedores, modelos e prompts de IA';

  @override
  String get settingsAiTitle => 'Configurações de IA';

  @override
  String get settingsAiUsageSubtitle =>
      'Custo, energia e CO₂e das chamadas de IA';

  @override
  String get settingsAiUsageTitle => 'Uso e impacto';

  @override
  String get settingsBeamPageEditModelTitle => 'Editar modelo';

  @override
  String get settingsBeamPageEditProfileTitle => 'Editar perfil';

  @override
  String get settingsCategoriesCreateTitle => 'Criar categoria';

  @override
  String get settingsCategoriesDetailsLabel => 'Editar categoria';

  @override
  String get settingsCategoriesEmptyState => 'Nenhuma categoria ainda';

  @override
  String get settingsCategoriesEmptyStateHint =>
      'Crie uma categoria para organizar suas entradas';

  @override
  String get settingsCategoriesErrorLoading => 'Erro ao carregar categorias';

  @override
  String get settingsCategoriesNameLabel => 'Nome da categoria';

  @override
  String settingsCategoriesNoMatchQuery(String query) {
    return 'Nenhuma categoria corresponde a \"$query\"';
  }

  @override
  String get settingsCategoriesSearchHint => 'Categorias de pesquisa…';

  @override
  String get settingsCategoriesSubtitle => 'Categorias com configurações de IA';

  @override
  String settingsCategoriesTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tarefas',
      one: '$count tarefa',
    );
    return '$_temp0';
  }

  @override
  String get settingsCategoriesTitle => 'Categorias';

  @override
  String get settingsCelebrationsChecklistDescription =>
      'Um estalo e faíscas quando você marca um item';

  @override
  String get settingsCelebrationsChecklistTitle =>
      'Itens da lista de verificação';

  @override
  String get settingsCelebrationsCustomizeTitle => 'Personalizar';

  @override
  String get settingsCelebrationsCustomizeTooltip => 'Personalize este estilo';

  @override
  String get settingsCelebrationsEnabledDescription =>
      'Chave mestre para conclusão floresce. Off oculta todas as animações; a sensação ao toque mantém seu próprio interruptor.';

  @override
  String get settingsCelebrationsEnabledTitle => 'Animações de celebração';

  @override
  String get settingsCelebrationsGroupLook => 'Olha';

  @override
  String get settingsCelebrationsGroupMotion => 'Movimento';

  @override
  String get settingsCelebrationsGroupShape => 'Forma';

  @override
  String get settingsCelebrationsHabitsDescription =>
      'Brilho e faíscas quando você completa um hábito';

  @override
  String get settingsCelebrationsHabitsTitle => 'Hábitos';

  @override
  String get settingsCelebrationsHapticsDescription =>
      'Um breve zumbido quando você termina algo – independente da animação.';

  @override
  String get settingsCelebrationsHapticsTitle => 'Háptica de conclusão';

  @override
  String get settingsCelebrationsKnobClearCenter => 'Folga central';

  @override
  String get settingsCelebrationsKnobCount => 'Partículas';

  @override
  String get settingsCelebrationsKnobDescClearCenter =>
      'Espaço vazio no centro';

  @override
  String get settingsCelebrationsKnobDescCount => 'Quantas partículas voam';

  @override
  String get settingsCelebrationsKnobDescFallout =>
      'Quão longe as faíscas descem';

  @override
  String get settingsCelebrationsKnobDescFanSpread => 'Largura do ventilador';

  @override
  String get settingsCelebrationsKnobDescGlow => 'Força do brilho';

  @override
  String get settingsCelebrationsKnobDescGravity =>
      'Com que rapidez as partículas caem';

  @override
  String get settingsCelebrationsKnobDescHalo => 'Força do halo';

  @override
  String get settingsCelebrationsKnobDescInnerRing => 'Tamanho do anel interno';

  @override
  String get settingsCelebrationsKnobDescLaunch => 'Atraso antes da explosão';

  @override
  String get settingsCelebrationsKnobDescPop => 'Quando eles estouram';

  @override
  String get settingsCelebrationsKnobDescReach =>
      'Quão longe as partículas viajam';

  @override
  String get settingsCelebrationsKnobDescRise =>
      'Como as partículas altas sobem';

  @override
  String get settingsCelebrationsKnobDescSize =>
      'Qual é o tamanho de cada partícula';

  @override
  String get settingsCelebrationsKnobDescSpeedSpread =>
      'Variação na velocidade das partículas';

  @override
  String get settingsCelebrationsKnobDescSpin => 'Quão rápido as peças giram';

  @override
  String get settingsCelebrationsKnobDescSpread => 'Largura do spray';

  @override
  String get settingsCelebrationsKnobDescSway => 'Quanto as peças balançam';

  @override
  String get settingsCelebrationsKnobDescSwell => 'Quanto eles crescem';

  @override
  String get settingsCelebrationsKnobDescTrail => 'Comprimento de cada trilha';

  @override
  String get settingsCelebrationsKnobDescTwinkle => 'Quanta partículas piscam';

  @override
  String get settingsCelebrationsKnobDescUpward => 'Quão fortemente eles sobem';

  @override
  String get settingsCelebrationsKnobDescWobble => 'Quanto as peças oscilam';

  @override
  String get settingsCelebrationsKnobFallout => 'Precipitação';

  @override
  String get settingsCelebrationsKnobFanSpread => 'Propagação de fãs';

  @override
  String get settingsCelebrationsKnobGlow => 'Brilho';

  @override
  String get settingsCelebrationsKnobGravity => 'Gravidade';

  @override
  String get settingsCelebrationsKnobHalo => 'auréola';

  @override
  String get settingsCelebrationsKnobInnerRing => 'Anel interno';

  @override
  String get settingsCelebrationsKnobLaunch => 'Hora de lançamento';

  @override
  String get settingsCelebrationsKnobPop => 'Ponto pop';

  @override
  String get settingsCelebrationsKnobReach => 'Alcance';

  @override
  String get settingsCelebrationsKnobRise => 'Altura de subida';

  @override
  String get settingsCelebrationsKnobSize => 'Tamanho';

  @override
  String get settingsCelebrationsKnobSpeedSpread => 'Variação de velocidade';

  @override
  String get settingsCelebrationsKnobSpin => 'Girar';

  @override
  String get settingsCelebrationsKnobSpread => 'Espalhe arco';

  @override
  String get settingsCelebrationsKnobSway => 'Balançar';

  @override
  String get settingsCelebrationsKnobSwell => 'Inchar';

  @override
  String get settingsCelebrationsKnobTrail => 'Comprimento da trilha';

  @override
  String get settingsCelebrationsKnobTwinkle => 'Brilha';

  @override
  String get settingsCelebrationsKnobUpward => 'Subir';

  @override
  String get settingsCelebrationsKnobWobble => 'Oscilação';

  @override
  String get settingsCelebrationsPlaygroundHint =>
      'Toque na linha destacada para visualizar';

  @override
  String get settingsCelebrationsPlaygroundLiveNote =>
      'As alterações são salvas e aplicadas em qualquer lugar instantaneamente';

  @override
  String get settingsCelebrationsPreviewChecklistItem => 'Verifique-me';

  @override
  String get settingsCelebrationsPreviewDescription =>
      'Toque em um controle para reproduzir o estilo selecionado.';

  @override
  String get settingsCelebrationsPreviewDone => 'Concluído';

  @override
  String get settingsCelebrationsPreviewHabit => 'Hábito';

  @override
  String get settingsCelebrationsPreviewSample1 => 'Caminhada matinal';

  @override
  String get settingsCelebrationsPreviewSample2 => 'Concluir o relatório';

  @override
  String get settingsCelebrationsPreviewSample3 => 'Regue as plantas';

  @override
  String get settingsCelebrationsPreviewTitle => 'Experimente';

  @override
  String get settingsCelebrationsReplay => 'Repetir';

  @override
  String get settingsCelebrationsResetToast =>
      'Estilo redefinido para o padrão';

  @override
  String get settingsCelebrationsResetToDefault => 'Redefinir para o padrão';

  @override
  String get settingsCelebrationsResetUndo => 'Desfazer';

  @override
  String get settingsCelebrationsSectionDescription =>
      'Faça um floreio ao terminar algo. Desligar um mantém a conclusão e sua sensação tátil – apenas pula a animação.';

  @override
  String get settingsCelebrationsSectionTitle => 'Celebrações de conclusão';

  @override
  String get settingsCelebrationsStyleDescription =>
      'Toque em um cartão para visualizar um estilo de celebração e personalizá-lo.';

  @override
  String get settingsCelebrationsStyleTitle => 'Estilo';

  @override
  String get settingsCelebrationsSubtitle => 'Celebrações de conclusão';

  @override
  String get settingsCelebrationsTasksDescription =>
      'Brilho e faíscas quando você move uma tarefa para Concluído';

  @override
  String get settingsCelebrationsTasksTitle => 'Tarefas';

  @override
  String get settingsCelebrationsTitle => 'Animações';

  @override
  String get settingsCelebrationsVariantBubbles => 'Bolhas';

  @override
  String get settingsCelebrationsVariantCombine => 'Combine dois';

  @override
  String get settingsCelebrationsVariantCombineDescription =>
      'Dois estilos aleatórios, em camadas, de cada vez';

  @override
  String get settingsCelebrationsVariantConfetti => 'Confete';

  @override
  String get settingsCelebrationsVariantEmbers => 'Brasas';

  @override
  String get settingsCelebrationsVariantFireworks => 'Fogos de artifício';

  @override
  String get settingsCelebrationsVariantRandom => 'Aleatório';

  @override
  String get settingsCelebrationsVariantRandomDescription =>
      'Um estilo novo em cada finalização';

  @override
  String get settingsCelebrationsVariantSparks => 'Faíscas';

  @override
  String get settingsConflictsTitle => 'Conflitos de sincronização';

  @override
  String get settingsDashboardDetailsLabel => 'Editar painel';

  @override
  String get settingsDashboardSaveLabel => 'Salvar';

  @override
  String get settingsDashboardsCreateTitle => 'Criar painel';

  @override
  String get settingsDashboardsEmptyState => 'Ainda não há painéis';

  @override
  String get settingsDashboardsEmptyStateHint =>
      'Toque no botão + para criar seu primeiro painel.';

  @override
  String get settingsDashboardsErrorLoading => 'Erro ao carregar painéis';

  @override
  String settingsDashboardsNoMatchQuery(String query) {
    return 'Nenhum painel corresponde a \"$query\"';
  }

  @override
  String get settingsDashboardsSearchHint => 'Painéis de pesquisa…';

  @override
  String get settingsDashboardsSubtitle =>
      'Personalize as visualizações do seu painel';

  @override
  String get settingsDashboardsTitle => 'Painéis';

  @override
  String get settingsDefinitionsSubtitle =>
      'Hábitos, categorias, rótulos, painéis e mensuráveis';

  @override
  String get settingsDefinitionsTitle => 'Definições';

  @override
  String get settingsFlagsEmptySearch =>
      'Nenhuma sinalização corresponde à sua pesquisa';

  @override
  String get settingsFlagsSearchHint => 'Sinalizadores de pesquisa';

  @override
  String get settingsFlagsSubtitle =>
      'Configurar sinalizadores e opções de recursos';

  @override
  String get settingsFlagsTitle => 'Sinalizadores de configuração';

  @override
  String get settingsHabitsCreateTitle => 'Crie hábito';

  @override
  String get settingsHabitsDeleteTooltip => 'Excluir hábito';

  @override
  String get settingsHabitsDescriptionLabel => 'Descrição (opcional)';

  @override
  String get settingsHabitsDetailsLabel => 'Editar hábito';

  @override
  String get settingsHabitsEmptyState => 'Ainda não há hábitos';

  @override
  String get settingsHabitsEmptyStateHint =>
      'Toque no botão + para criar seu primeiro hábito.';

  @override
  String get settingsHabitsErrorLoading => 'Erro ao carregar hábitos';

  @override
  String get settingsHabitsNameLabel => 'Nome do hábito';

  @override
  String settingsHabitsNoMatchQuery(String query) {
    return 'Nenhum hábito corresponde a \"$query\"';
  }

  @override
  String get settingsHabitsPrivateLabel => 'Privado:';

  @override
  String get settingsHabitsSaveLabel => 'Salvar';

  @override
  String get settingsHabitsSearchHint => 'Hábitos de pesquisa…';

  @override
  String get settingsHabitsSubtitle => 'Gerencie seus hábitos e rotinas';

  @override
  String get settingsHabitsTitle => 'Hábitos';

  @override
  String get settingsHealthImportAccessHint =>
      'Não foi possível ler alguns dados. Se você desativou o acesso do Lotti nas configurações de privacidade de saúde do seu dispositivo, o Lotti não pode solicitá-lo de novo — reative-o lá.';

  @override
  String get settingsHealthImportActivity => 'Atividade';

  @override
  String get settingsHealthImportActivityDescription =>
      'Passos, andares subidos e distância percorrida a pé';

  @override
  String get settingsHealthImportAll => 'Importar tudo';

  @override
  String get settingsHealthImportBloodPressure => 'Pressão arterial';

  @override
  String get settingsHealthImportBloodPressureDescription =>
      'Valores sistólicos e diastólicos';

  @override
  String get settingsHealthImportBodyMeasurement => 'Medidas corporais';

  @override
  String get settingsHealthImportBodyMeasurementDescription =>
      'Peso, gordura corporal, IMC e altura';

  @override
  String get settingsHealthImportDataSectionTitle => 'Dados para importar';

  @override
  String get settingsHealthImportFromDate => 'Começar';

  @override
  String get settingsHealthImportHeartRate => 'Frequência cardíaca';

  @override
  String get settingsHealthImportHeartRateDescription =>
      'Em repouso, caminhando e variabilidade';

  @override
  String get settingsHealthImportOpenSettings => 'Abrir configurações';

  @override
  String settingsHealthImportQuickRange(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Últimos $days dias',
      one: 'Último dia',
    );
    return '$_temp0';
  }

  @override
  String get settingsHealthImportRangeSectionTitle => 'Período';

  @override
  String get settingsHealthImportSleep => 'Sono';

  @override
  String get settingsHealthImportSleepDescription =>
      'Tempo na cama e fases do sono';

  @override
  String get settingsHealthImportStatusFailed =>
      'Falha na importação — verifique os registros';

  @override
  String settingsHealthImportStatusImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dados importados',
      one: '1 dado importado',
      zero: 'Nenhum dado novo',
    );
    return '$_temp0';
  }

  @override
  String get settingsHealthImportStatusNoDataOrAccess =>
      'Sem dados — verifique o acesso do Lotti no seu app de saúde';

  @override
  String get settingsHealthImportStatusPermissionDenied =>
      'Acesso negado — permita o Lotti no seu app de saúde';

  @override
  String get settingsHealthImportStatusRunning => 'Importando…';

  @override
  String get settingsHealthImportStatusUnsupportedType =>
      'Esse tipo de dado não é mais suportado';

  @override
  String get settingsHealthImportSubtitle =>
      'Importe do Apple Saúde ou Health Connect';

  @override
  String get settingsHealthImportTitle => 'Importação de Saúde';

  @override
  String get settingsHealthImportToDate => 'Fim';

  @override
  String get settingsHealthImportUnavailable =>
      'Os dados de saúde só estão disponíveis no iOS e no Android';

  @override
  String get settingsHealthImportWorkout => 'Treinos';

  @override
  String get settingsHealthImportWorkoutDescription =>
      'Treinos com distância e energia gasta';

  @override
  String get settingsKeyboardShortcutsSubtitle =>
      'Aprenda as combinações de teclado para navegação e edição mais rápidas na área de trabalho';

  @override
  String get settingsKeyboardShortcutsTitle => 'Atalhos de teclado';

  @override
  String get settingsLabelsCategoriesAdd => 'Adicionar categoria';

  @override
  String get settingsLabelsCategoriesHeading => 'Categorias aplicáveis';

  @override
  String get settingsLabelsCategoriesNone => 'Aplica-se a todas as categorias';

  @override
  String get settingsLabelsCategoriesRemoveTooltip => 'Remover';

  @override
  String get settingsLabelsColorHeading => 'Cor';

  @override
  String get settingsLabelsColorSubheading => 'Predefinições rápidas';

  @override
  String get settingsLabelsCreateTitle => 'Criar etiqueta';

  @override
  String get settingsLabelsDeleteConfirmAction => 'Excluir';

  @override
  String settingsLabelsDeleteConfirmMessage(Object labelName) {
    return 'Tem certeza de que deseja excluir \"$labelName\"? As tarefas com este rótulo perderão a atribuição.';
  }

  @override
  String get settingsLabelsDeleteConfirmTitle => 'Excluir rótulo';

  @override
  String settingsLabelsDeleteSuccess(Object labelName) {
    return 'Rótulo \"$labelName\" excluído';
  }

  @override
  String get settingsLabelsDescriptionHint =>
      'Explique quando aplicar este rótulo';

  @override
  String get settingsLabelsDescriptionLabel => 'Descrição (opcional)';

  @override
  String get settingsLabelsEditTitle => 'Editar rótulo';

  @override
  String get settingsLabelsEmptyState => 'Ainda não há rótulos';

  @override
  String get settingsLabelsEmptyStateHint =>
      'Toque no botão + para criar sua primeira etiqueta.';

  @override
  String get settingsLabelsErrorLoading => 'Falha ao carregar rótulos';

  @override
  String get settingsLabelsNameHint =>
      'Bug, bloqueador de lançamento, sincronização…';

  @override
  String get settingsLabelsNameLabel => 'Nome da etiqueta';

  @override
  String settingsLabelsNoMatchCreate(String query) {
    return 'Criar rótulo \"$query\"';
  }

  @override
  String settingsLabelsNoMatchQuery(String query) {
    return 'Nenhum rótulo corresponde a \"$query\"';
  }

  @override
  String get settingsLabelsPrivateDescription =>
      'Visível apenas quando entradas privadas são mostradas';

  @override
  String get settingsLabelsPrivateTitle => 'Privado';

  @override
  String get settingsLabelsSearchHint => 'Pesquisar rótulos…';

  @override
  String get settingsLabelsSubtitle =>
      'Organize tarefas com etiquetas coloridas';

  @override
  String get settingsLabelsTitle => 'Etiquetas';

  @override
  String settingsLabelsUsageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tarefas',
      one: '1 tarefa',
    );
    return '$_temp0';
  }

  @override
  String get settingsLoggingDomainsSubtitle =>
      'Controlar quais domínios gravam no log';

  @override
  String get settingsLoggingDomainsTitle => 'Registrando Domínios';

  @override
  String get settingsLoggingGlobalToggle => 'Habilitar registro em log';

  @override
  String get settingsLoggingGlobalToggleSubtitle =>
      'Chave mestre para todos os registros';

  @override
  String get settingsLoggingSlowQueries => 'Consultas lentas ao banco de dados';

  @override
  String get settingsLoggingSlowQueriesSubtitle =>
      'Grava consultas lentas em slow_queries-YYYY-MM-DD.log';

  @override
  String get settingsMaintenanceOnboardingAnimationGallerySubtitle =>
      'Compare animações de boas-vindas + conecte a página ao vivo (depuração)';

  @override
  String get settingsMaintenanceOnboardingAnimationGalleryTitle =>
      'Galeria de animação de integração';

  @override
  String get settingsMaintenanceOnboardingWelcomeSubtitle =>
      'Visualize os blocos de boas-vindas + provedor do FTUE (depuração)';

  @override
  String get settingsMaintenanceOnboardingWelcomeTitle =>
      'Mostrar boas-vindas à integração';

  @override
  String get settingsMaintenanceTitle => 'Manutenção';

  @override
  String get settingsManualLanguageCzechTitle => 'Tcheco';

  @override
  String get settingsManualLanguageDanishTitle => 'Dinamarquês';

  @override
  String get settingsManualLanguageDutchTitle => 'Holandês';

  @override
  String get settingsManualLanguageEnglishTitle => 'Inglês';

  @override
  String get settingsManualLanguageFollowSystemSubtitle =>
      'Use o idioma do seu dispositivo no Lotti. No Manual, use esse idioma quando houver suporte; caso contrário, use o inglês.';

  @override
  String get settingsManualLanguageFollowSystemTitle => 'Siga o sistema';

  @override
  String get settingsManualLanguageFrenchTitle => 'Francês';

  @override
  String get settingsManualLanguageGermanTitle => 'Alemão';

  @override
  String get settingsManualLanguageItalianTitle => 'Italiano';

  @override
  String get settingsManualLanguagePortugueseTitle => 'Português';

  @override
  String get settingsManualLanguageRomanianTitle => 'Romeno';

  @override
  String get settingsManualLanguageSpanishTitle => 'Espanhol';

  @override
  String get settingsManualLanguageSwedishTitle => 'Sueco';

  @override
  String get settingsManualLanguageTitle => 'Idioma';

  @override
  String get settingsMatrixAcceptVerificationLabel =>
      'Outro dispositivo mostra emojis, continue';

  @override
  String get settingsMatrixCancel => 'Cancelar';

  @override
  String get settingsMatrixContinueVerificationLabel =>
      'Aceite em outro dispositivo para continuar';

  @override
  String get settingsMatrixDiagnosticCopied =>
      'Informações de diagnóstico copiadas para a área de transferência';

  @override
  String get settingsMatrixDiagnosticCopyButton =>
      'Copiar para a área de transferência';

  @override
  String get settingsMatrixDiagnosticDialogTitle =>
      'Sincronizar informações de diagnóstico';

  @override
  String get settingsMatrixDiagnosticShowButton => 'Detalhes técnicos';

  @override
  String get settingsMatrixLastUpdated => 'Última atualização:';

  @override
  String get settingsMatrixMaintenanceSubtitle =>
      'Manutenção e recuperação do Matrix';

  @override
  String get settingsMatrixMaintenanceTitle => 'Manutenção';

  @override
  String get settingsMatrixMetrics => 'Métricas de sincronização';

  @override
  String get settingsMatrixNextPage => 'Próxima página';

  @override
  String get settingsMatrixPreviousPage => 'Página anterior';

  @override
  String get settingsMatrixSentMessagesLabel => 'Mensagens enviadas:';

  @override
  String settingsMatrixSentMessageType(String eventType) {
    return 'Enviado ($eventType)';
  }

  @override
  String get settingsMatrixStartVerificationLabel => 'Iniciar verificação';

  @override
  String get settingsMatrixStatsTitle => 'Estatísticas da Matriz';

  @override
  String get settingsMatrixTitle => 'Configurações de sincronização';

  @override
  String get settingsMatrixVerificationCancelledLabel =>
      'Cancelado em outro dispositivo...';

  @override
  String get settingsMatrixVerificationSuccessConfirm => 'Entendi';

  @override
  String get settingsMatrixVerifyLabel => 'Verifique';

  @override
  String get settingsMeasurableAggregationHelper =>
      'Como as entradas de um dia se combinam nos gráficos';

  @override
  String get settingsMeasurableAggregationLabel => 'Tipo de agregação padrão';

  @override
  String get settingsMeasurableDeleteTooltip => 'Excluir tipo mensurável';

  @override
  String get settingsMeasurableDescriptionLabel => 'Descrição (opcional)';

  @override
  String get settingsMeasurableDetailsLabel => 'Editar mensurável';

  @override
  String get settingsMeasurableNameLabel => 'Nome mensurável';

  @override
  String get settingsMeasurablePrivateLabel => 'Privado:';

  @override
  String get settingsMeasurableSaveLabel => 'Salvar';

  @override
  String get settingsMeasurablesCreateTitle => 'Crie mensuráveis';

  @override
  String get settingsMeasurablesEmptyState => 'Ainda não há mensuráveis';

  @override
  String get settingsMeasurablesEmptyStateHint =>
      'Mensuráveis são números que você acompanha ao longo do tempo – peso, água, passos.';

  @override
  String get settingsMeasurablesErrorLoading => 'Erro ao carregar mensuráveis';

  @override
  String settingsMeasurablesNoMatchQuery(String query) {
    return 'Nenhum mensurável corresponde a \"$query\"';
  }

  @override
  String get settingsMeasurablesSearchHint => 'Pesquisar mensuráveis…';

  @override
  String get settingsMeasurablesSubtitle =>
      'Configurar tipos de dados mensuráveis';

  @override
  String get settingsMeasurablesTitle => 'Mensuráveis';

  @override
  String get settingsMeasurableUnitLabel => 'Abreviatura da unidade (opcional)';

  @override
  String get settingsOnboardingActionSubtitle =>
      'Reabra o fluxo de boas-vindas – conecte seu cérebro de IA e crie uma tarefa';

  @override
  String get settingsOnboardingMetricsSubtitle =>
      'Funil FTUE – instalação, ativação, retenção (depuração)';

  @override
  String get settingsOnboardingMetricsTitle => 'Métricas de integração';

  @override
  String get settingsOnboardingReplayTitle => 'Integração de repetição';

  @override
  String get settingsOnboardingStartTitle => 'Comece a integração';

  @override
  String get settingsOnboardingStatusActivated =>
      'Você criou sua primeira tarefa de IA';

  @override
  String get settingsOnboardingStatusLoading => 'Carregando…';

  @override
  String get settingsOnboardingStatusNotActivated => 'Ainda não começou';

  @override
  String get settingsOnboardingStatusTitle => 'Estado';

  @override
  String get settingsOnboardingSubtitle =>
      'Repita o fluxo de boas-vindas a qualquer momento';

  @override
  String get settingsOnboardingTestResetConfirm => 'Redefinir';

  @override
  String get settingsOnboardingTestResetConfirmQuestion =>
      'Limpar histórico e métricas de solicitações de integração? Os planos do Daily OS existentes permanecem, portanto, use um perfil limpo para testar o passo a passo completo do Daily OS na primeira execução.';

  @override
  String get settingsOnboardingTestResetSubtitle =>
      'Limpar histórico e métricas de prompts; os planos diários existentes do sistema operacional permanecem (depuração)';

  @override
  String get settingsOnboardingTestResetTitle =>
      'Redefinir o estado do teste de integração';

  @override
  String get settingsOnboardingTitle => 'Integração';

  @override
  String get settingsOptionsTitle => 'Opções';

  @override
  String get settingsRecordingStyleExplanation =>
      'Escolha a aparência do microfone enquanto você grava.';

  @override
  String get settingsRecordingStyleSubtitle =>
      'Medidor VU ou orbe de energia durante a gravação';

  @override
  String get settingsRecordingStyleTitle => 'Estilo de gravação';

  @override
  String get settingsResetGeminiConfirm => 'Redefinir';

  @override
  String get settingsResetGeminiConfirmQuestion =>
      'Isso mostrará a caixa de diálogo de configuração do Gemini novamente. Continuar?';

  @override
  String get settingsResetGeminiSubtitle =>
      'Mostrar a caixa de diálogo de configuração do Gemini AI novamente';

  @override
  String get settingsResetGeminiTitle =>
      'Caixa de diálogo Redefinir configuração do Gemini';

  @override
  String get settingsResetHintsConfirm => 'Confirmar';

  @override
  String get settingsResetHintsConfirmQuestion =>
      'Redefinir dicas no aplicativo exibidas no aplicativo?';

  @override
  String settingsResetHintsResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Redefinir $count dicas',
      one: 'Redefinir uma dica',
      zero: 'Redefinir zero dicas',
    );
    return '$_temp0';
  }

  @override
  String get settingsResetHintsSubtitle =>
      'Dicas claras e de integração únicas';

  @override
  String get settingsResetHintsTitle => 'Redefinir dicas no aplicativo';

  @override
  String get settingsSpeechSubtitle => 'Voz e leitura em voz alta';

  @override
  String get settingsSpeechTitle => 'Discurso';

  @override
  String get settingsSyncConflictsSubtitle =>
      'Resolve conflitos de sincronização';

  @override
  String get settingsSyncNodeProfileCapabilitiesEmpty =>
      'Nenhum detectado — o acionamento automático da inferência de áudio sincronizado não terá como alvo este dispositivo.';

  @override
  String get settingsSyncNodeProfileCapabilitiesLabel =>
      'Capacidades de IA detectadas';

  @override
  String get settingsSyncNodeProfileCapabilityMlxAudio => 'Áudio MLX (local)';

  @override
  String get settingsSyncNodeProfileCapabilityOllamaLlm => 'Ollama LLM';

  @override
  String get settingsSyncNodeProfileCapabilityOmlxLlm => 'oMLX LLM';

  @override
  String get settingsSyncNodeProfileCapabilityVoxtral => 'Voxtral (local)';

  @override
  String get settingsSyncNodeProfileCapabilityWhisper => 'Sussurro (local)';

  @override
  String get settingsSyncNodeProfileDisplayNameHelper =>
      'Visível para seus outros dispositivos ao escolher em qual deles fixar um perfil.';

  @override
  String get settingsSyncNodeProfileDisplayNameLabel =>
      'Nome de exibição do dispositivo';

  @override
  String get settingsSyncNodeProfileKnownNodesEmpty =>
      'Nenhum outro dispositivo publicou um perfil ainda.';

  @override
  String get settingsSyncNodeProfileKnownNodesTitle =>
      'Dispositivos de sincronização conhecidos';

  @override
  String get settingsSyncNodeProfileSaveButton => 'Salvar';

  @override
  String get settingsSyncNodeProfileSubtitle =>
      'Nome e capacidades do dispositivo';

  @override
  String get settingsSyncNodeProfileTitle => 'Este dispositivo';

  @override
  String get settingsSyncOutboxTitle => 'Sincronizar caixa de saída';

  @override
  String get settingsSyncStatsSubtitle =>
      'Inspecione as métricas do pipeline de sincronização';

  @override
  String get settingsSyncSubtitle =>
      'Configurar sincronização e visualizar estatísticas';

  @override
  String get settingsThemingAutomatic => 'Automático';

  @override
  String get settingsThemingDark => 'Aparência escura';

  @override
  String get settingsThemingLight => 'Aparência clara';

  @override
  String get settingsThemingSubtitle =>
      'Personalize a aparência e os temas do aplicativo';

  @override
  String get settingsThemingTitle => 'Tema';

  @override
  String get settingsV2CategoryEmptyBody =>
      'Escolha uma subconfiguração à esquerda.';

  @override
  String get settingsV2DetailRootCrumb => 'Configurações';

  @override
  String get settingsV2EmptyStateBody =>
      'Escolha uma seção à esquerda para começar.';

  @override
  String get settingsV2ResizeHandleLabel =>
      'Redimensionar árvore de configurações';

  @override
  String get settingsV2UnimplementedTitle => 'Painel ainda não implementado';

  @override
  String get settingsWhatsNewSubtitle =>
      'Veja as últimas atualizações e recursos';

  @override
  String get settingsWhatsNewTitle => 'Novidades';

  @override
  String get sidebarActiveSectionTitle => 'Atividade';

  @override
  String get sidebarActivityCollapseTooltip => 'Recolher atividade';

  @override
  String get sidebarActivityExpandTooltip => 'Expandir atividade';

  @override
  String get sidebarAudioRecordingStatusLabel => 'Gravação';

  @override
  String get sidebarRunningTimerLabel => 'Temporizador em execução';

  @override
  String get sidebarRunningTimerStopTooltip => 'Parar cronômetro';

  @override
  String get sidebarTimerStatusLabel => 'Temporizador';

  @override
  String get sidebarToggleCollapseLabel => 'Recolher barra lateral';

  @override
  String get sidebarToggleExpandLabel => 'Expandir barra lateral';

  @override
  String sidebarWakesActiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ativo',
      one: '1 ativo',
    );
    return '$_temp0';
  }

  @override
  String get sidebarWakesCancelTooltip => 'Cancelar agente';

  @override
  String get sidebarWakesHeader => 'Agentes';

  @override
  String get sidebarWakesNow => 'agora';

  @override
  String get sidebarWakesOpenList => 'Lista aberta';

  @override
  String get sidebarWakesOpenTask => 'Tarefa aberta';

  @override
  String sidebarWakesQueuedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count na fila',
      one: '1 na fila',
    );
    return '$_temp0';
  }

  @override
  String get sidebarWakesQueuedLabel => 'Na fila';

  @override
  String get sidebarWakesWorkingLabel => 'Trabalhando';

  @override
  String get skillsSectionTitle => 'Habilidades';

  @override
  String get speechDictionaryHelper =>
      'Termos separados por ponto e vírgula (máximo de 50 caracteres) para melhor reconhecimento de fala';

  @override
  String get speechDictionaryHint =>
      'macOS; Kirkjubæjarklaustur; Código Claude';

  @override
  String get speechDictionaryLabel => 'Dicionário de Fala';

  @override
  String get speechDictionarySectionDescription =>
      'Adicione termos que muitas vezes são digitados incorretamente pelo reconhecimento de fala (nomes, lugares, termos técnicos)';

  @override
  String get speechDictionarySectionTitle => 'Reconhecimento de fala';

  @override
  String speechDictionaryWarning(Object count) {
    return 'Dicionário grande ($count termos) pode aumentar os custos da API';
  }

  @override
  String get speechModalSelectLanguage => 'Selecione o idioma';

  @override
  String get speechModalTitle => 'Reconhecimento de fala';

  @override
  String get speechNoAudioRecorded => 'No audio was recorded. Try again.';

  @override
  String get speechSettingsModelDescription => 'Modelo de fala no dispositivo';

  @override
  String get speechSettingsModelDownloadsOnce => 'Baixa uma vez';

  @override
  String get speechSettingsModelLabel => 'Modelo';

  @override
  String get speechSettingsRecommendedBadge => 'Recomendado';

  @override
  String get speechSettingsSpeedDescription =>
      'Quão rápido os resumos são lidos';

  @override
  String get speechSettingsSpeedLabel => 'Velocidade de leitura';

  @override
  String get speechSettingsVoiceDescription =>
      'Escolha a voz que lê resumos em voz alta';

  @override
  String get speechSettingsVoiceLabel => 'Voz';

  @override
  String get speechVoiceGenderFemale => 'Feminino';

  @override
  String get speechVoiceGenderMale => 'Masculino';

  @override
  String get speechVoicePreviewTooltip => 'Visualizar voz';

  @override
  String get surveyBackButton => 'Voltar';

  @override
  String get surveyCancelConfirmation => 'Cancelar pesquisa?';

  @override
  String get surveyChooseOneOption => 'Escolha uma opção';

  @override
  String get surveyChooseOneOrMoreOptions => 'Escolha uma ou mais opções';

  @override
  String get surveyDiscardConfirmation => 'Descartar resultados e desistir?';

  @override
  String get surveyInputNumberValidation => 'Digite um número';

  @override
  String get surveyNextButton => 'Próximo';

  @override
  String get surveyNoButton => 'Não';

  @override
  String get surveyProgressOf => 'de';

  @override
  String get surveyTapToAnswer => 'Toque para responder';

  @override
  String get surveyValueAnd => 'e';

  @override
  String get surveyValueBetween => 'Deve estar entre';

  @override
  String get surveyYesButton => 'Sim';

  @override
  String get syncAddDeviceAction => 'Adicionar dispositivo';

  @override
  String get syncAddDeviceConnected =>
      'O novo dispositivo entrou — conclui a verificação por emojis antes de enviar.';

  @override
  String get syncAddDeviceCopyCode => 'Copiar código de emparelhamento';

  @override
  String get syncAddDeviceGenerateFailed =>
      'Não foi possível criar um código de emparelhamento. Tente novamente.';

  @override
  String get syncAddDeviceHideCode => 'Ocultar o código de emparelhamento';

  @override
  String get syncAddDeviceIntro =>
      'Instala o Lotti lá, abre Definições → Sincronização → Dispositivos e escolhe «Configurar a sincronização».';

  @override
  String get syncAddDeviceRevealCode =>
      'Mostrar o código de emparelhamento como texto';

  @override
  String get syncAddDeviceRosterError =>
      'Não foi possível verificar se o novo dispositivo entrou.';

  @override
  String get syncAddDeviceSecurityNote =>
      'Este código é uma chave da tua conta — mostra-o apenas ao teu próprio dispositivo novo.';

  @override
  String get syncAddDeviceSendMessages => 'Enviar histórico de mensagens';

  @override
  String get syncAddDeviceSendSettings => 'Enviar configurações';

  @override
  String get syncAddDeviceSendSettingsReady =>
      'Novo dispositivo verificado — pronto para enviar.';

  @override
  String get syncAddDeviceStepScanTitle => 'Escaneie isto no novo dispositivo';

  @override
  String get syncAddDeviceTimelineJoined =>
      'Juntou-se — confirma os emojis nos dois ecrãs';

  @override
  String get syncAddDeviceTimelineVerified =>
      'Verificado — pronto para a passagem';

  @override
  String get syncAddDeviceTimelineWaiting => 'À espera do dispositivo novo…';

  @override
  String get syncAddDeviceUnavailable =>
      'Configure a sincronização neste dispositivo antes de adicionar outro.';

  @override
  String get syncAddDeviceUnlockHint =>
      'Desbloqueia depois de os emojis coincidirem — antes disso, o dispositivo novo nem os conseguiria decifrar.';

  @override
  String get syncDeleteConfigConfirm => 'Parar de sincronizar';

  @override
  String get syncDeleteConfigQuestion =>
      'Parar de sincronizar este dispositivo?';

  @override
  String get syncDeviceRemovalInProgress => 'A remover o dispositivo…';

  @override
  String syncDevicesCount(num count, String server) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dispositivos em $server',
      one: '1 dispositivo em $server',
    );
    return '$_temp0';
  }

  @override
  String syncDevicesJustJoined(String deviceName) {
    return '$deviceName acabou de se juntar e está verificado';
  }

  @override
  String get syncDevicesJustJoinedHint =>
      'Passa-lhe agora as tuas definições e o histórico de mensagens.';

  @override
  String get syncDevicesKeylessHint =>
      'O pareamento nunca foi concluído — só pode ser removido.';

  @override
  String syncDevicesLastSeen(String date) {
    return 'Visto pela última vez em $date';
  }

  @override
  String get syncDevicesLoadFailed =>
      'Não foi possível carregar a lista de dispositivos.';

  @override
  String get syncDevicesOnlyThisDevice =>
      'Nenhum outro dispositivo está conectado.';

  @override
  String syncDevicesPaired(String date) {
    return 'Pareado em $date';
  }

  @override
  String syncDevicesPausedBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count dispositivos não verificados não conseguem ler as novas entradas — exclua-os ou verifique-os abaixo.',
      one:
          '1 dispositivo não verificado não consegue ler as novas entradas — exclua-o ou verifique-o abaixo.',
    );
    return '$_temp0';
  }

  @override
  String syncDevicesPausedBannerDeleteOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count dispositivos não verificados não conseguem ler as novas entradas — exclua-os abaixo.',
      one:
          '1 dispositivo não verificado não consegue ler as novas entradas — exclua-o abaixo.',
    );
    return '$_temp0';
  }

  @override
  String syncDevicesPausedBannerVerifyOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count dispositivos não verificados não conseguem ler as novas entradas — verifique-os abaixo.',
      one:
          '1 dispositivo não verificado não consegue ler as novas entradas — verifique-o abaixo.',
    );
    return '$_temp0';
  }

  @override
  String get syncDevicesStaleHint => 'Provavelmente não está mais em uso';

  @override
  String get syncDevicesSyncResumed =>
      'Todos os dispositivos pareados conseguem ler suas entradas novamente.';

  @override
  String get syncDevicesThisDeviceChip => 'Este dispositivo';

  @override
  String get syncDevicesUnverifiedChip => 'Não verificado';

  @override
  String get syncDevicesVerifiedChip => 'Verificado';

  @override
  String get syncDisconnectExplanation =>
      'Suas entradas continuam neste dispositivo. Ele sai da conta de sincronização e precisará de um novo código para sincronizar de novo. Seus outros dispositivos não são afetados.';

  @override
  String get syncDisconnectFailed =>
      'Não foi possível parar a sincronização deste dispositivo. Verifique sua conexão e tente novamente.';

  @override
  String get syncEntitiesConfirm => 'Iniciar sincronização';

  @override
  String get syncEntitiesMessage =>
      'Escolha as entidades que deseja sincronizar.';

  @override
  String get syncEntitiesSuccessDescription => 'Tudo está atualizado.';

  @override
  String get syncEntitiesSuccessTitle => 'Sincronização concluída';

  @override
  String syncListCountSummary(String label, int itemCount) {
    String _temp0 = intl.Intl.pluralLogic(
      itemCount,
      locale: localeName,
      other: '$itemCount itens',
      one: '1 item',
      zero: '0 itens',
    );
    return '$label · $_temp0';
  }

  @override
  String get syncListPayloadKindLabel => 'Carga útil';

  @override
  String get syncListUnknownPayload => 'Carga útil desconhecida';

  @override
  String get syncNotLoggedInToast => 'A sincronização não está logada';

  @override
  String get syncPairBack => 'Voltar';

  @override
  String get syncPairCameraDenied =>
      'O Lotti precisa de acesso à câmera para escanear. Permita nas configurações do sistema ou digite o código manualmente.';

  @override
  String get syncPairCameraRetry => 'Tentar a câmera novamente';

  @override
  String get syncPairCheckAgain => 'Verificar novamente';

  @override
  String get syncPairCheckCode =>
      'O dispositivo novo mostra o mesmo código antes de se ligar — compara-os.';

  @override
  String get syncPairCheckCodeLabel => 'Código de verificação';

  @override
  String get syncPairClipboardEmpty =>
      'Não há nada para colar. Copie primeiro o código de emparelhamento no seu outro dispositivo.';

  @override
  String get syncPairClipboardUnavailable =>
      'Não foi possível ler a área de transferência. Cole o código diretamente no campo.';

  @override
  String get syncPairConnectButton => 'Os códigos coincidem — ligar';

  @override
  String get syncPairDiscardCode => 'Não coincidem';

  @override
  String get syncPairedFirstDeviceBody =>
      'É o primeiro da tua conta. Adiciona outro quando quiseres — tudo o que escreveres aqui estará à espera dele.';

  @override
  String get syncPairedFirstDeviceTitle =>
      'A sincronização está configurada neste dispositivo';

  @override
  String get syncPairedSettingsStep =>
      'Categorias, hábitos, painéis e configuração de IA — enviados do teu outro dispositivo depois de os emojis coincidirem.';

  @override
  String get syncPairedSettingsStepFallback =>
      'Se você a fechou, no outro dispositivo abra Configurações → Configurações de sincronização → Manutenção, execute a sincronização das configurações e depois escolha Histórico de mensagens.';

  @override
  String get syncPairedSettingsStepTitle => 'Recebe as tuas definições';

  @override
  String get syncPairedStepsLeft =>
      'Faltam dois passos para este dispositivo poder ler o teu diário.';

  @override
  String get syncPairedVerifyFallback =>
      'Ainda sem emojis? Verifique novamente — ou abra Dispositivos e inicie por lá.';

  @override
  String get syncPairedVerifyStep =>
      'Os dois dispositivos vão mostrar sete emojis. Até coincidirem, este dispositivo só vê texto cifrado.';

  @override
  String get syncPairedVerifyStepDone =>
      'Emojis conferem — este dispositivo pode ler suas entradas';

  @override
  String get syncPairedVerifyStepTitle => 'Confirma os emojis';

  @override
  String get syncPairedVerifyWaiting => 'Aguardando os emojis aparecerem…';

  @override
  String get syncPairEnterManually => 'Colar o código em alternativa';

  @override
  String get syncPairEnterNewCode => 'Introduzir um código novo';

  @override
  String get syncPairErrorMalformed =>
      'Isto não parece um código de emparelhamento. Verifique se copiou tudo — no outro dispositivo, toque de novo em Copiar código de emparelhamento.';

  @override
  String get syncPairErrorVersion =>
      'Este código veio de outra versão do Lotti. Atualize os dois dispositivos e tente de novo.';

  @override
  String get syncPairFirstDeviceHint =>
      'Ainda não há outro dispositivo de onde copiar — o teu primeiro código vem da ferramenta de aprovisionamento do teu servidor de sincronização.';

  @override
  String get syncPairFirstDeviceTitle =>
      'A configurar o teu primeiro dispositivo?';

  @override
  String get syncPairGoToDevices => 'Ir para Dispositivos';

  @override
  String get syncPairMismatchWarning =>
      'Códigos diferentes significam que este não vem do teu dispositivo. Não te ligues — obtém um código novo no teu próprio dispositivo.';

  @override
  String get syncPairOnlyOwnCode =>
      'O código é uma chave da tua conta. Usa apenas um do teu próprio dispositivo — o código de outra pessoa envia-lhe tudo o que escreves.';

  @override
  String get syncPairOpenManual => 'Abrir o guia do primeiro dispositivo';

  @override
  String get syncPairPasteTitle => 'Cole o código de emparelhamento';

  @override
  String get syncPairRetryThisCode => 'Tentar de novo este código';

  @override
  String get syncPairReviewIntro =>
      'O teu outro dispositivo mostra um código de verificação sob o QR. Tem de ser exatamente este:';

  @override
  String get syncPairReviewTitle => 'Compara antes de te ligares';

  @override
  String get syncPairSameCodeQuestion => 'O mesmo código nos dois ecrãs?';

  @override
  String get syncPairScanHint =>
      'Aponta para o QR em «Adicionar dispositivo» no teu outro dispositivo.';

  @override
  String get syncPairScanLink => 'Tens câmara? Lê antes o QR';

  @override
  String get syncPairScannerRejected =>
      'Esse é o código que você recusou. Escaneie o que o seu próprio dispositivo mostra, ou cole-o abaixo.';

  @override
  String get syncPairScanTitle => 'Ler o código de emparelhamento';

  @override
  String get syncPairShowEmoji => 'Mostrar os emojis';

  @override
  String get syncPairWhereToFind =>
      'Está no teu outro dispositivo, em «Adicionar dispositivo» — copia-o lá e cola-o aqui.';

  @override
  String get syncPayloadAgentBundle => 'Pacote de agente';

  @override
  String get syncPayloadAgentEntity => 'Entidade agente';

  @override
  String get syncPayloadAgentLink => 'Link do agente';

  @override
  String get syncPayloadAiConfig => 'Configuração de IA';

  @override
  String get syncPayloadAiConfigDelete => 'Exclusão de configuração de IA';

  @override
  String get syncPayloadBackfillRequest => 'Solicitação de preenchimento';

  @override
  String get syncPayloadBackfillResponse => 'Resposta de preenchimento';

  @override
  String get syncPayloadConfigFlag => 'Sinalizador de configuração';

  @override
  String get syncPayloadConsumptionEvent => 'Consumo de IA';

  @override
  String get syncPayloadDailyOsUserName => 'Nome diário do sistema operacional';

  @override
  String get syncPayloadEntityDefinition => 'Definição de entidade';

  @override
  String get syncPayloadEntryLink => 'Link de entrada';

  @override
  String get syncPayloadJournalEntity => 'Lançamento de diário';

  @override
  String get syncPayloadMediaRequest => 'Pedido de multimédia';

  @override
  String get syncPayloadNotification => 'Notificação';

  @override
  String get syncPayloadNotificationStateUpdate =>
      'Atualização do estado da notificação';

  @override
  String get syncPayloadOutboxBundle => 'Pacote de caixa de saída';

  @override
  String get syncPayloadSavedTaskFilter => 'Filtro de tarefa salva';

  @override
  String get syncPayloadSavedTaskFilterDelete =>
      'Exclusão de filtro de tarefa salva';

  @override
  String get syncPayloadSyncNodeProfile => 'Perfil do nó de sincronização';

  @override
  String get syncPayloadThemingSelection => 'Seleção de tema';

  @override
  String syncQueueCountMillions(String value) {
    return '${value}M';
  }

  @override
  String syncQueueCountThousands(String value) {
    return '${value}K';
  }

  @override
  String syncQueueIncomingSemanticLabel(int count) {
    return 'Caixa de entrada: $count';
  }

  @override
  String syncQueueOutgoingSemanticLabel(int count) {
    return 'Caixa de saída: $count';
  }

  @override
  String syncReauthExplanation(String deviceName) {
    return 'O servidor de sincronização não aceitou a palavra-passe guardada. Introduz a palavra-passe atual da tua conta de sincronização para remover $deviceName.';
  }

  @override
  String get syncReauthInvalidPassword =>
      'Essa palavra-passe não funcionou. Verifica-a e tenta de novo.';

  @override
  String get syncReauthPasswordLabel =>
      'Palavra-passe da conta de sincronização';

  @override
  String get syncReauthTitle => 'Confirma que és tu';

  @override
  String get syncSetupCta => 'Configurar sincronização';

  @override
  String get syncSetupEmptyFootnote =>
      'Corre no teu próprio servidor de sincronização · nada sai dos teus dispositivos sem cifra';

  @override
  String get syncSetupEmptyHint =>
      'O teu diário em todos os teus dispositivos. Cifrado de ponta a ponta, só entre os teus dispositivos — sem conta na nuvem.';

  @override
  String get syncSetupEmptyTitle => 'Sincroniza os teus dispositivos';

  @override
  String get syncStepAiSettings => 'Configurações de IA';

  @override
  String get syncStepBackfillAgentEntityClocks =>
      'Preencher relógios da entidade do agente';

  @override
  String get syncStepBackfillAgentLinkClocks =>
      'Relógios de link do agente de preenchimento';

  @override
  String get syncStepCategories => 'Categorias';

  @override
  String get syncStepComplete => 'Completo';

  @override
  String get syncStepDashboards => 'Painéis';

  @override
  String get syncStepHabits => 'Hábitos';

  @override
  String get syncStepLabels => 'Etiquetas';

  @override
  String get syncStepMeasurables => 'Mensuráveis';

  @override
  String get syncStepSavedTaskFilters => 'Filtros de tarefas salvas';

  @override
  String get syncVerifiedCelebrationBody =>
      'A partir de agora, tudo o que escreveres sincroniza — cifrado de ponta a ponta, de máquina para máquina.';

  @override
  String get syncVerifiedCelebrationTitle =>
      'Os teus dispositivos confiam um no outro';

  @override
  String get syncVerifyModalTitle => 'Confirma o dispositivo';

  @override
  String get syncVerifyPromptLine1 => 'Os dois ecrãs mostram sete emojis.';

  @override
  String get syncVerifyPromptQuestion => 'Os mesmos emojis, pela mesma ordem?';

  @override
  String get syncVerifyStaleConfirm => 'Verificar mesmo assim';

  @override
  String syncVerifyStaleMessage(String deviceName) {
    return '$deviceName não dá sinal há algum tempo. A verificação só funciona enquanto estiver ligado, online e com o Lotti aberto — caso contrário, a verificação de emojis espera por uma resposta que nunca chega.';
  }

  @override
  String get syncVerifyStaleTitle => 'Este dispositivo pode estar offline';

  @override
  String get syncVerifyTheyDiffer => 'São diferentes — cancelar';

  @override
  String get syncVerifyTheyMatch => 'Coincidem';

  @override
  String get syncWizardStepCheck => 'Verificar';

  @override
  String get syncWizardStepConnect => 'Ligar';

  @override
  String get syncWizardStepGetCode => 'Obter código';

  @override
  String syncWizardStepStatus(int step, String label) {
    return 'Passo $step de 3: $label';
  }

  @override
  String get taskActionBarAudioRecordingActive =>
      'Gravação de áudio em andamento';

  @override
  String get taskActionBarMoreActions => 'Mais ações';

  @override
  String get taskActionBarOpenRunningTimer => 'Abrir cronômetro em execução';

  @override
  String get taskActionBarStopTracking => 'Parar o monitoramento do tempo';

  @override
  String get taskActionBarTrackTime => 'Monitorar o tempo';

  @override
  String get taskAgentAssignHint => 'Redige etapas e resumos com IA integrada.';

  @override
  String get taskAgentAttributionUnavailable => 'Atribuição indisponível';

  @override
  String get taskAgentAutomaticUpdatesLabel => 'Atualizações automáticas';

  @override
  String get taskAgentAutomaticUpdatesNeedsSetup =>
      'Escolha uma configuração de IA antes de ativar as atualizações automáticas.';

  @override
  String get taskAgentCancelTimerTooltip =>
      'Cancelar atualização automática pendente';

  @override
  String get taskAgentChangeSetupTooltip => 'Alterar configuração de IA';

  @override
  String get taskAgentChooseModel => 'Escolha um modelo de pensamento';

  @override
  String get taskAgentChooseProfile => 'Escolha um perfil de inferência';

  @override
  String taskAgentCountdownTooltip(String countdown) {
    return 'Próxima execução automática em $countdown';
  }

  @override
  String get taskAgentCreateChipLabel => 'Atribuir agente';

  @override
  String taskAgentCreateError(String error) {
    return 'Falha ao criar agente: $error';
  }

  @override
  String get taskAgentCurrentSetupHeader => 'Configuração atual';

  @override
  String get taskAgentCurrentSetupLabel => 'Configuração atual';

  @override
  String get taskAgentDirectModelOverride => 'Substituição direta do modelo';

  @override
  String get taskAgentDisableConfirmAction => 'Desligue';

  @override
  String get taskAgentDisableConfirmBody =>
      'O relatório atual permanece visível, mas este agente não pode ser executado até que você escolha uma configuração.';

  @override
  String get taskAgentDisableConfirmTitle => 'Desativar a IA para este agente?';

  @override
  String get taskAgentInferenceProfileLabel => 'Perfil de inferência';

  @override
  String get taskAgentModelPickerTitle => 'Escolha o modelo de pensamento';

  @override
  String taskAgentNextUpdateIn(String countdown) {
    return 'Próxima atualização em $countdown';
  }

  @override
  String taskAgentNextUpdateInShort(String countdown) {
    return 'em $countdown';
  }

  @override
  String get taskAgentNoAiSetup => 'Sem configuração de IA';

  @override
  String get taskAgentNoAiSetupDescription =>
      'Pausa a inferência do agente até você escolher um perfil ou modelo.';

  @override
  String get taskAgentNoModelsAvailable =>
      'Nenhum modelo de pensamento compatível disponível';

  @override
  String get taskAgentNoProfilesAvailable =>
      'Nenhum perfil disponível neste dispositivo';

  @override
  String get taskAgentNoProfileSelected => 'Sem configuração de IA';

  @override
  String get taskAgentNoProfileSelectedDescription =>
      'Escolha uma configuração salva ou um modelo de pensamento antes que este agente possa ser executado.';

  @override
  String taskAgentProfileChangedToast(String profile) {
    return 'Usar $profile para cada atualização futura do agente até que você o altere.';
  }

  @override
  String get taskAgentProfileDefaultBadge => 'Perfil padrão';

  @override
  String get taskAgentReportOutdatedTitle => 'Este resumo está desatualizado';

  @override
  String get taskAgentReportUpToDate => 'O resumo está atualizado';

  @override
  String get taskAgentRouteVia => 'através de';

  @override
  String get taskAgentRunNowTooltip => 'Corra agora';

  @override
  String get taskAgentSavingSetup => 'Salvando a configuração do agente';

  @override
  String taskAgentSetupAndReportSemantics(String identity) {
    return 'Este relatório e a configuração atual usam $identity. Ative para alterar a configuração.';
  }

  @override
  String get taskAgentSetupBroken =>
      'A configuração de IA selecionada não está disponível';

  @override
  String taskAgentSetupChangedToast(String model) {
    return 'Usando $model para cada atualização futura do agente até que você o altere.';
  }

  @override
  String get taskAgentSetupChoiceHelp =>
      'Escolha um perfil para seus padrões ou substitua apenas o modelo de pensamento.';

  @override
  String get taskAgentSetupOriginCategory =>
      'Copiado da categoria padrão quando este agente foi criado';

  @override
  String get taskAgentSetupOriginDisabled => 'Desativado';

  @override
  String get taskAgentSetupOriginLegacy => 'Configuração legada';

  @override
  String get taskAgentSetupOriginTemplate => 'Copiado do modelo';

  @override
  String get taskAgentSetupOriginUser => 'Você escolheu isso para este agente';

  @override
  String get taskAgentSetupPersistenceDescription =>
      'As alterações se aplicam a todas as atualizações futuras até que você as altere.';

  @override
  String taskAgentSetupSemantics(String identity) {
    return 'Configuração atual: $identity. Ative para alterar a configuração.';
  }

  @override
  String get taskAgentSetupTitle => 'Configuração do agente';

  @override
  String get taskAgentSkipScheduledUpdate => 'Ignorar uma vez';

  @override
  String get taskAgentStatusOutOfDate => 'Desatualizado';

  @override
  String get taskAgentStatusUpToDate => 'Atualizado';

  @override
  String get taskAgentThinkingModelLabel => 'Modelo de pensamento';

  @override
  String get taskAgentThisReportHeader => 'Este relatório';

  @override
  String get taskAgentTurnOffSetup => 'Desative a IA para este agente';

  @override
  String get taskAgentUpdateNow => 'Atualizar agora';

  @override
  String get taskAgentUpdatesOnChange => 'Atualiza quando esta tarefa muda';

  @override
  String get taskAgentUseCategoryDefault => 'Copiar categoria padrão';

  @override
  String get taskAgentUseCategoryDefaultDescription =>
      'Copia a configuração atual da categoria. Alterações posteriores de categoria não afetarão este agente.';

  @override
  String get taskAgentUseProfileDefault => 'Usar perfil padrão';

  @override
  String taskBlockedByChipLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Blocked by $count tasks',
      one: 'Blocked by 1 task',
    );
    return '$_temp0';
  }

  @override
  String taskBlockedByChipTooltip(int count, String title) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tap to see $count blockers',
      one: 'Blocked by $title',
    );
    return '$_temp0';
  }

  @override
  String get taskBlockedByUnresolvedLabel => 'Blocker not synced yet';

  @override
  String taskBlockedReason(String title) {
    return 'Blocked by: $title';
  }

  @override
  String get taskBlockerPickerTitle => 'What\'s blocking this?';

  @override
  String get taskCategoryAllLabel => 'tudo';

  @override
  String get taskCategoryLabel => 'Categoria:';

  @override
  String get taskCategoryUnassignedLabel => 'não atribuído';

  @override
  String get taskDueDateLabel => 'Data de vencimento';

  @override
  String taskDueDateWithDate(String date) {
    return 'Vencimento: $date';
  }

  @override
  String taskDueInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dias',
      one: '1 dia',
    );
    return 'Vencimento em $_temp0';
  }

  @override
  String get taskDueToday => 'Vencimento hoje';

  @override
  String get taskDueTomorrow => 'Vencimento amanhã';

  @override
  String get taskDueYesterday => 'Vencimento para ontem';

  @override
  String get taskEditTitleLabel => 'Editar título da tarefa';

  @override
  String get taskEstimateLabel => 'Estimativa:';

  @override
  String get taskEstimateModalTitle => 'Estimativa';

  @override
  String taskEstimateProgressLabel(String tracked, String estimate) {
    return '$tracked de $estimate';
  }

  @override
  String taskEstimateTooltip(String tracked, String estimate) {
    return 'Tempo monitorado: $tracked de $estimate estimado';
  }

  @override
  String get taskFirstRunAddChecklist => 'Adicionar uma lista de verificação';

  @override
  String get taskFirstRunAddChecklistHint =>
      'Adiciona uma lista de etapas marcáveis.';

  @override
  String get taskFirstRunAssignAgent => 'Atribuir um agente';

  @override
  String get taskFirstRunRecordAudio => 'Gravar uma nota de voz';

  @override
  String get taskFirstRunRecordAudioHint =>
      'Abre o gravador sem iniciar a gravação.';

  @override
  String get taskFirstRunWriteNote => 'Escrever uma nota';

  @override
  String get taskFirstRunWriteNoteHint =>
      'Adiciona uma nota vinculada para detalhes e ideias.';

  @override
  String taskLabelsMoreCount(int count) {
    return '+$count';
  }

  @override
  String get taskLabelsShowFewer => 'Mostrar menos';

  @override
  String get taskLanguageArabic => 'Árabe';

  @override
  String get taskLanguageBengali => 'bengali';

  @override
  String get taskLanguageBulgarian => 'Búlgaro';

  @override
  String get taskLanguageChinese => 'Chinês';

  @override
  String get taskLanguageCroatian => 'Croata';

  @override
  String get taskLanguageCzech => 'Tcheco';

  @override
  String get taskLanguageDanish => 'Dinamarquês';

  @override
  String get taskLanguageDutch => 'Holandês';

  @override
  String get taskLanguageEnglish => 'Inglês';

  @override
  String get taskLanguageEstonian => 'Estónio';

  @override
  String get taskLanguageFinnish => 'Finlandês';

  @override
  String get taskLanguageFrench => 'Francês';

  @override
  String get taskLanguageGerman => 'Alemão';

  @override
  String get taskLanguageGreek => 'Grego';

  @override
  String get taskLanguageHebrew => 'Hebraico';

  @override
  String get taskLanguageHindi => 'Hindi';

  @override
  String get taskLanguageHungarian => 'Húngaro';

  @override
  String get taskLanguageIgbo => 'Ibo';

  @override
  String get taskLanguageIndonesian => 'Indonésio';

  @override
  String get taskLanguageItalian => 'Italiano';

  @override
  String get taskLanguageJapanese => 'Japonês';

  @override
  String get taskLanguageKorean => 'Coreano';

  @override
  String get taskLanguageLabel => 'Idioma';

  @override
  String get taskLanguageLatvian => 'Letão';

  @override
  String get taskLanguageLithuanian => 'Lituano';

  @override
  String get taskLanguageNigerianPidgin => 'Pidgin nigeriano';

  @override
  String get taskLanguageNorwegian => 'Norueguês';

  @override
  String get taskLanguagePolish => 'Polonês';

  @override
  String get taskLanguagePortuguese => 'Português';

  @override
  String get taskLanguageRomanian => 'Romeno';

  @override
  String get taskLanguageRussian => 'Russo';

  @override
  String get taskLanguageSelectedLabel => 'Atualmente selecionado';

  @override
  String get taskLanguageSerbian => 'Sérvio';

  @override
  String get taskLanguageSetAction => 'Definir idioma';

  @override
  String get taskLanguageSlovak => 'Eslovaco';

  @override
  String get taskLanguageSlovenian => 'Esloveno';

  @override
  String get taskLanguageSpanish => 'Espanhol';

  @override
  String get taskLanguageSwahili => 'suaíli';

  @override
  String get taskLanguageSwedish => 'Sueco';

  @override
  String get taskLanguageThai => 'Tailandês';

  @override
  String get taskLanguageTurkish => 'Turco';

  @override
  String get taskLanguageTwi => 'Twi';

  @override
  String get taskLanguageUkrainian => 'Ucraniano';

  @override
  String get taskLanguageVietnamese => 'Vietnamita';

  @override
  String get taskLanguageYoruba => 'Iorubá';

  @override
  String get taskNoDueDateLabel => 'Sem data de vencimento';

  @override
  String get taskNoEstimateLabel => 'Sem estimativa';

  @override
  String taskOverdueByDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dias',
      one: '1 dia',
    );
    return 'Atrasado há $_temp0';
  }

  @override
  String get taskPriorityHigh => 'Alto';

  @override
  String get taskPriorityLow => 'Baixo';

  @override
  String get taskPriorityMedium => 'Médio';

  @override
  String taskPriorityTooltip(String priority) {
    return 'Prioridade: $priority';
  }

  @override
  String get taskPriorityUrgent => 'Urgente';

  @override
  String get tasksAddLabelButton => 'Adicionar rótulo';

  @override
  String get tasksAgentFilterAll => 'Todos';

  @override
  String get tasksAgentFilterHasAgent => 'Tem agente';

  @override
  String get tasksAgentFilterNoAgent => 'Nenhum agente';

  @override
  String get tasksAgentFilterTitle => 'Agente';

  @override
  String tasksCompactFilterCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filtros',
      one: '$count filtro',
    );
    return '$_temp0';
  }

  @override
  String get tasksCompactHeaderExpandHint => 'Mostrar pesquisa e filtros';

  @override
  String tasksCompactSearchContext(String query) {
    return '«$query»';
  }

  @override
  String get taskSetCategoryLabel => 'Definir categoria';

  @override
  String get taskSetDueDateLabel => 'Definir prazo';

  @override
  String get taskSetEstimateLabel => 'Adicionar estimativa';

  @override
  String get tasksFilterApplyTitle => 'Aplicar filtro';

  @override
  String get tasksFilterClearAll => 'Limpar tudo';

  @override
  String get tasksFilterTitle => 'Filtrar tarefas';

  @override
  String get taskShowcaseAudio => 'Áudio';

  @override
  String taskShowcaseCompletedCount(int completed, int total) {
    return '$completed / $total concluído';
  }

  @override
  String taskShowcaseDueDate(String date) {
    return 'Vencimento: $date';
  }

  @override
  String get taskShowcaseJumpToSection => 'Ir para a seção';

  @override
  String get taskShowcaseLinked => 'Vinculado';

  @override
  String get taskShowcaseNoResults =>
      'Nenhuma tarefa corresponde à sua pesquisa.';

  @override
  String get taskShowcaseReadMore => 'Leia mais';

  @override
  String taskShowcaseRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gravações',
      one: '1 gravação',
    );
    return '$_temp0';
  }

  @override
  String taskShowcaseTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tarefas',
      one: '1 tarefa',
    );
    return '$_temp0';
  }

  @override
  String get taskShowcaseTaskDescription => 'Descrição da tarefa';

  @override
  String get taskShowcaseTimeTracker => 'Rastreador de tempo';

  @override
  String get taskShowcaseTodo => 'Tudo';

  @override
  String get taskShowcaseTodos => 'Todos';

  @override
  String get tasksLabelFilterAll => 'Todos';

  @override
  String get tasksLabelFilterTitle => 'Etiqueta';

  @override
  String get tasksLabelFilterUnlabeled => 'Sem rótulo';

  @override
  String get tasksLabelsDialogClose => 'Fechar';

  @override
  String get tasksLabelsSheetApply => 'Aplicar';

  @override
  String get tasksLabelsSheetSearchHint => 'Pesquisar rótulos…';

  @override
  String get tasksLabelsUpdateFailed => 'Falha ao atualizar rótulos';

  @override
  String get tasksPriorityFilterAll => 'Todos';

  @override
  String get tasksPriorityFilterTitle => 'Prioridade';

  @override
  String get tasksPriorityP0 => 'Urgente';

  @override
  String get tasksPriorityP0Description => 'Urgente (o mais rápido possível)';

  @override
  String get tasksPriorityP1 => 'Alto';

  @override
  String get tasksPriorityP1Description => 'Alto (em breve)';

  @override
  String get tasksPriorityP2 => 'Médio';

  @override
  String get tasksPriorityP2Description => 'Médio (padrão)';

  @override
  String get tasksPriorityP3 => 'Baixo';

  @override
  String get tasksPriorityP3Description => 'Baixo (sempre)';

  @override
  String get tasksPriorityPickerTitle => 'Selecione prioridade';

  @override
  String get tasksQuickFilterUnassignedLabel => 'Não atribuído';

  @override
  String get tasksSavedFilterDeleteConfirmTooltip =>
      'Toque novamente para excluir';

  @override
  String get tasksSavedFilterDeleteTooltip => 'Excluir filtro salvo';

  @override
  String get tasksSavedFilterDragHandleSemantics => 'Arraste para reordenar';

  @override
  String get tasksSavedFilterRenameSemantics => 'Renomear filtro salvo';

  @override
  String get tasksSavedFiltersAllShort => 'Todos';

  @override
  String get tasksSavedFiltersAllTasks => 'Todas as tarefas';

  @override
  String get tasksSavedFiltersCustom => 'Personalizado';

  @override
  String get tasksSavedFiltersDeleteConfirmAction => 'Excluir';

  @override
  String tasksSavedFiltersDeleteConfirmMessage(String name) {
    return 'Excluir o filtro salvo \'$name\'? Isso não pode ser desfeito.';
  }

  @override
  String tasksSavedFiltersDeleteConfirmNamed(String name) {
    return 'Confirme a exclusão de $name';
  }

  @override
  String tasksSavedFiltersDeleteNamed(String name) {
    return 'Excluir $name';
  }

  @override
  String get tasksSavedFiltersDone => 'Concluído';

  @override
  String get tasksSavedFiltersEdit => 'Editar';

  @override
  String get tasksSavedFiltersFilterNameLabel => 'Nome do filtro';

  @override
  String get tasksSavedFiltersGroupSemantics => 'Filtros de tarefas';

  @override
  String get tasksSavedFiltersManageTooltip => 'Gerenciar filtros de tarefas';

  @override
  String get tasksSavedFiltersRailButton => 'Vistas';

  @override
  String tasksSavedFiltersRenameNamed(String name) {
    return 'Renomear $name';
  }

  @override
  String get tasksSavedFiltersReorderHelper =>
      'Arraste para definir a ordem. Os primeiros cinco filtros aparecem na barra lateral.';

  @override
  String get tasksSavedFiltersSaveAsNewButtonLabel => 'Salvar como novo…';

  @override
  String get tasksSavedFiltersSaveAsNewDescription =>
      'Mantenha o filtro existente inalterado e crie um separado.';

  @override
  String get tasksSavedFiltersSaveAsNewTitle => 'Salvar como um novo filtro';

  @override
  String get tasksSavedFiltersSaveButtonLabel => 'Salvar filtro…';

  @override
  String get tasksSavedFiltersSaveChoiceIntro =>
      'Escolha se deseja atualizar o filtro salvo ou criar um separado.';

  @override
  String get tasksSavedFiltersSaveChoiceTitle => 'Salvar filtro';

  @override
  String get tasksSavedFiltersSaveCurrentAs => 'Salvar filtro atual…';

  @override
  String get tasksSavedFiltersSaveError =>
      'Não foi possível salvar este filtro. Tente novamente.';

  @override
  String get tasksSavedFiltersSavePageHelper =>
      'Dê um nome curto a este filtro. Você pode reordená-lo posteriormente em Filtros de tarefas.';

  @override
  String get tasksSavedFiltersSavePopupCancel => 'Cancelar';

  @override
  String get tasksSavedFiltersSavePopupHint =>
      'por exemplo Bloqueado ou em espera';

  @override
  String get tasksSavedFiltersSavePopupSave => 'Salvar';

  @override
  String get tasksSavedFiltersSavePopupTitle => 'Nomeie este filtro';

  @override
  String get tasksSavedFiltersSheetTitle => 'Filtros de tarefas';

  @override
  String get tasksSavedFiltersShowLess => 'Mostrar menos';

  @override
  String tasksSavedFiltersShowMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mais filtros salvos',
      one: 'mais 1 filtro salvo',
    );
    return '$_temp0';
  }

  @override
  String tasksSavedFiltersTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tarefas',
      one: '1 tarefa',
    );
    return '$_temp0';
  }

  @override
  String get tasksSavedFiltersUpdateButtonLabel => 'Atualizar filtro';

  @override
  String get tasksSavedFiltersUpdateExistingDescription =>
      'Substitua os critérios salvos pela configuração de filtro atual.';

  @override
  String get tasksSavedFiltersUpdateExistingTitle =>
      'Atualizar filtro existente';

  @override
  String get tasksSavedFilterToastDeleted => 'Filtro excluído';

  @override
  String tasksSavedFilterToastSaved(String name) {
    return '\'$name\' salvo';
  }

  @override
  String tasksSavedFilterToastUpdated(String name) {
    return '\'$name\' atualizado';
  }

  @override
  String get tasksSearchModeLabel => 'Modo de pesquisa';

  @override
  String get tasksShowCreationDate => 'Mostrar data de criação nos cartões';

  @override
  String get tasksShowDueDate => 'Mostrar data de vencimento nos cartões';

  @override
  String get tasksSortByCreationDate => 'Criado';

  @override
  String get tasksSortByDueDate => 'Data de vencimento';

  @override
  String get tasksSortByLabel => 'Classificar por';

  @override
  String get tasksSortByPriority => 'Prioridade';

  @override
  String get taskStatusAll => 'Todos';

  @override
  String get taskStatusBlocked => 'Bloqueado';

  @override
  String get taskStatusDone => 'Concluído';

  @override
  String get taskStatusGroomed => 'Preparado';

  @override
  String get taskStatusInProgress => 'Em andamento';

  @override
  String get taskStatusLabel => 'Estado:';

  @override
  String get taskStatusOnHold => 'Em espera';

  @override
  String get taskStatusOpen => 'Abrir';

  @override
  String get taskStatusRejected => 'Rejeitado';

  @override
  String get taskTitleEmpty => 'Sem título';

  @override
  String get taskTitlePrompt => 'Dá um nome a esta tarefa';

  @override
  String get taskUntitled => '(sem título)';

  @override
  String get thinkingDisclosureCopied => 'Raciocínio copiado';

  @override
  String get thinkingDisclosureCopy => 'Copie o raciocínio';

  @override
  String get thinkingDisclosureHide => 'Ocultar raciocínio';

  @override
  String get thinkingDisclosureShow => 'Mostrar raciocínio';

  @override
  String get thinkingDisclosureStateCollapsed => 'entrou em colapso';

  @override
  String get thinkingDisclosureStateExpanded => 'expandido';

  @override
  String get timeEntryItemEnd => 'Fim';

  @override
  String get timeEntryItemRunning => 'Correndo';

  @override
  String get timeEntryItemStart => 'Começar';

  @override
  String transcriptLanguageLabel(String language) {
    return 'Language: $language';
  }

  @override
  String transcriptModelLabel(String provider, String model) {
    return 'Model: $provider, $model';
  }

  @override
  String get unlinkButton => 'Desvincular';

  @override
  String get unlinkTaskConfirm =>
      'Tem certeza de que deseja desvincular esta tarefa?';

  @override
  String unlinkTaskConfirmNamed(String title) {
    return 'Unlink “$title”? The task itself is not deleted.';
  }

  @override
  String get unlinkTaskFailedMessage =>
      'Couldn\'t unlink the task. Please try again.';

  @override
  String get unlinkTaskTitle => 'Desvincular tarefa';

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
  String get viewMenuTitle => 'Ver';

  @override
  String get viewMenuZoomIn => 'Ampliar';

  @override
  String get viewMenuZoomOut => 'Diminuir zoom';

  @override
  String get viewMenuZoomReset => 'Tamanho real';

  @override
  String get whatsNewBadgeNew => 'NOVO';

  @override
  String get whatsNewDoneButton => 'Concluído';

  @override
  String get whatsNewSkipButton => 'Pular';
}

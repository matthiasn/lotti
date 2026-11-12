import 'dart:convert';

import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/workflow/agent_message_recording.dart';
import 'package:lotti/features/agents/workflow/agent_tool_arg_parsing.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/util/think_blocks.dart';
import 'package:lotti/features/front_agent/model/front_closed_task_card.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_due_section.dart';
import 'package:lotti/features/front_agent/model/front_logged_time_chart.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/front_agent/model/front_reference_links.dart';
import 'package:lotti/features/front_agent/model/front_reply_surface.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_contract.dart';
import 'package:lotti/features/front_agent/workflow/front_dispatch_validator.dart';
import 'package:lotti/features/front_agent/workflow/front_reply_reader.dart';
import 'package:lotti/features/front_agent/workflow/front_reply_stream.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:openai_dart/openai_dart.dart';

/// Finds open tasks for a phrase the index does not show; the rows it
/// returns become valid destinations for the rest of the turn.
typedef FrontCorpusMatcher =
    Future<List<FrontIndexRow>> Function(String phrase);

/// Lists the open tasks in one due window — today, overdue, upcoming, or
/// all of them — narrowed to the categories the query names; the rows
/// become valid destinations for the rest of the turn.
typedef FrontDueTaskLister =
    Future<FrontDueTasks> Function(FrontDueQuery query);

/// Sums the time logged in one period, per category, inside the turn's
/// scope — the categories the query names by name, the rest as one — and
/// lists the tasks it went to, which become valid destinations for the rest
/// of the turn.
typedef FrontLoggedTimeSummarizer =
    Future<FrontLoggedTime> Function(FrontTimeQuery query);

/// Lists every task completed or rejected in one window of days inside the
/// turn's scope, narrowed to the categories named; the rows become valid
/// destinations for the rest of the turn.
typedef FrontClosedTaskLister =
    Future<FrontClosedTasks> Function(
      FrontPullRequestQuery window,
      Set<String> categoryIds,
    );

/// Counts the pull requests opened and merged in one window of days
/// through the tasks inside the turn's scope, from what the device stores.
typedef FrontPullRequestSummarizer =
    Future<FrontPullRequests> Function(FrontPullRequestQuery query);

/// One candidate offered by `ask_user`.
typedef FrontAskOption = ({FrontDestinationKind kind, String id, String label});

/// The clarifying question a turn ended with.
typedef FrontAskUser = ({String question, List<FrontAskOption> options});

/// [ConversationStrategy] for a front-agent turn (the goal-strategy shape):
/// every tool call is validated and ACCUMULATED; nothing is persisted
/// mid-conversation. The workflow reads the accumulators after the loop and
/// writes the outputs in one transaction.
///
/// Two calls end the turn — `dispatch` and `ask_user` — as does her answer,
/// which is the message she writes, not a call ([acceptAnswer]) — and
/// the five lookups are capped by count, not by removing them from the list:
/// a shrinking tool list changes the request prefix and voids the provider's
/// cache, which a routing turn exists to keep warm.
class FrontAgentStrategy extends ConversationStrategy
    with AgentMessageRecording {
  FrontAgentStrategy({
    required this.syncService,
    required this.domainLogger,
    required this.agentId,
    required this.threadId,
    required this.runKey,
    required this.input,
    required this.index,
    required this.now,
    this.corpusMatcher,
    this.dueTaskLister,
    this.loggedTimeSummarizer,
    this.closedTaskLister,
    this.pullRequestSummarizer,
    this.conversationTasks = const [],
    this.onAnswerProgress,
  });

  /// Told what her answer says and draws so far, each time more of the
  /// message she is writing arrives; null when nothing shows it live.
  final void Function(String text, List<Map<String, Object?>> components)?
  onAnswerProgress;

  @override
  final AgentSyncService syncService;
  @override
  final DomainLogger domainLogger;
  @override
  final String agentId;
  @override
  final String threadId;
  @override
  final String runKey;

  /// The pending user message, exactly as the spans index into it.
  final String input;

  /// The turn's clock, as `<current_local_time>` showed it to the model: a
  /// dictated start counts back from here, not from when the dispatch lands.
  final DateTime now;
  final FrontRoutingIndex index;

  /// The tasks this conversation named, open or closed, as
  /// `<conversation_tasks>` listed them: what a follow-up may follow up on
  /// and a question may offer, though a closed one is never a destination.
  final List<FrontIndexRow> conversationTasks;

  /// Null when no FTS is wired (tests, evals without a journal): the tool
  /// then answers that it is unavailable.
  final FrontCorpusMatcher? corpusMatcher;

  /// Null when no journal is wired (tests, evals): the tool then answers
  /// that it is unavailable.
  final FrontDueTaskLister? dueTaskLister;

  /// Null when no journal is wired (tests, evals): the tool then answers
  /// that it is unavailable.
  final FrontLoggedTimeSummarizer? loggedTimeSummarizer;

  /// Null when no journal is wired (tests, evals): the tool then answers
  /// that it is unavailable.
  final FrontClosedTaskLister? closedTaskLister;

  /// Null when no journal is wired (tests, evals): the tool then answers
  /// that it is unavailable.
  final FrontPullRequestSummarizer? pullRequestSummarizer;

  FrontDispatch? _dispatch;
  FrontAskUser? _askUser;
  String? _replyToUser;
  int _tldrReads = 0;
  int _corpusMatches = 0;
  int _dueLists = 0;
  int _timeSummaries = 0;
  int _closedLists = 0;
  int _pullRequestSummaries = 0;
  int _rejectedDispatches = 0;
  final _lookupRows = <FrontIndexRow>[];
  FrontLoggedTimeChart? _loggedTimeChart;
  FrontPullRequestChart? _pullRequestChart;
  List<FrontClosedTaskCard>? _closedTaskCards;
  FrontDueSection? _dueSection;
  List<FrontIndexRow> _dueRows = const [];
  List<Map<String, Object?>> _replyComponents = const [];

  FrontDispatch? get dispatch => _dispatch;
  FrontAskUser? get askUser => _askUser;
  String? get replyToUser => _replyToUser;

  /// What her reply charts: the days a `summarize_logged_time` this turn
  /// found time in, and the scope it summed; null when none did.
  FrontLoggedTimeChart? get loggedTimeChart => _loggedTimeChart;

  /// What her reply charts of pull requests: the days a
  /// `summarize_pull_requests` this turn found some opened in; null when
  /// none did.
  FrontPullRequestChart? get pullRequestChart => _pullRequestChart;

  /// The cards her reply draws: every task a `list_closed_tasks` this turn
  /// found, whatever her words name; null when it found none.
  List<FrontClosedTaskCard>? get closedTaskCards => _closedTaskCards;

  /// The window a `list_due_tasks` this turn read and found tasks in, which
  /// her reply's list of them is labelled with; null when none found any.
  FrontDueSection? get dueSection => _dueSection;

  /// What her reply draws, in order, as the catalog components she
  /// composed — with any list of task links in her words made cards, and
  /// whatever a lookup found that she did not place after them (see
  /// [readFrontReply]). Empty until her answer was taken ([acceptAnswer]).
  List<Map<String, Object?>> get replyComponents => _replyComponents;

  /// Whether the turn has ended: on a dispatch, a question, or her answer.
  bool get hasTerminalOutput =>
      _dispatch != null || _askUser != null || _replyToUser != null;

  /// How many `dispatch` calls failed validation this turn.
  int get rejectedDispatches => _rejectedDispatches;

  /// How many lookup calls ran (refused ones excluded).
  int get lookupCalls =>
      _tldrReads +
      _corpusMatches +
      _dueLists +
      _timeSummaries +
      _closedLists +
      _pullRequestSummaries;

  /// How many of those looked something up to answer with — due or closed
  /// tasks, logged time, pull requests. Reading a TLDR or matching the
  /// corpus serves routing as much as answering, so those are not counted.
  int get answerLookupCalls =>
      _dueLists + _timeSummaries + _closedLists + _pullRequestSummaries;

  @override
  Future<ConversationAction> processToolCalls({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required ConversationManager manager,
  }) async {
    await recordAssistantMessage();

    for (final call in toolCalls) {
      final toolName = call.function.name;
      Map<String, dynamic> args;
      try {
        args = parseAgentToolArguments(call.function.arguments);
      } catch (e) {
        domainLogger.log(
          LogDomain.agentWorkflow,
          'Failed to parse tool call arguments for $toolName '
          '(rawBytes=${utf8.encode(call.function.arguments).length}, '
          'errorType=${e.runtimeType})',
          subDomain: 'FrontAgentStrategy',
          level: InsightLevel.warn,
        );
        await _reject(
          call,
          manager,
          'Error: invalid arguments format — expected a JSON object. '
          'Detail: ${e.runtimeType}',
        );
        continue;
      }

      await recordActionMessage(toolName: toolName);

      switch (toolName) {
        case FrontAgentToolNames.dispatch:
          await _handleDispatch(call, args, manager);
        case FrontAgentToolNames.readTldr:
          await _handleReadTldr(call, args, manager);
        case FrontAgentToolNames.matchToCorpus:
          await _handleMatchToCorpus(call, args, manager);
        case FrontAgentToolNames.listDueTasks:
          await _handleListDueTasks(call, args, manager);
        case FrontAgentToolNames.summarizeLoggedTime:
          await _handleSummarizeLoggedTime(call, args, manager);
        case FrontAgentToolNames.listClosedTasks:
          await _handleListClosedTasks(call, args, manager);
        case FrontAgentToolNames.summarizePullRequests:
          await _handleSummarizePullRequests(call, args, manager);
        case FrontAgentToolNames.askUser:
          await _handleAskUser(call, args, manager);
        default:
          await _reject(call, manager, 'Error: unknown tool "$toolName".');
      }
    }

    // What this round looked up is drawn now, before the call that writes
    // about it starts — wherever that call is started from.
    showLookups();
    return hasTerminalOutput
        ? ConversationAction.complete
        : ConversationAction.continueConversation;
  }

  @override
  bool shouldContinue(ConversationManager manager) =>
      !hasTerminalOutput && manager.canContinue();

  /// The turn is bounded by the repair instruction the workflow sends, not
  /// by a nag here.
  @override
  String? getContinuationPrompt(ConversationManager manager) => null;

  bool _destinationExists(FrontDestinationKind kind, String id) =>
      index.contains(kind, id) ||
      _lookupRows.any((row) => row.kind == kind && row.id == id);

  /// A task a new task may follow up on: one she may route to, or one the
  /// conversation named.
  bool _followUpExists(String id) =>
      _destinationExists(FrontDestinationKind.task, id) ||
      conversationTasks.any((row) => row.id == id);

  /// A category a new task may be put in: listed, and chosen when the
  /// conversation is narrowed — the chips narrow, never widen.
  bool _categoryExists(String id) {
    final category = index.category(id);
    return category != null &&
        (category.chosen || !index.categories.any((c) => c.chosen));
  }

  Future<void> _handleDispatch(
    ChatCompletionMessageToolCall call,
    Map<String, dynamic> args,
    ConversationManager manager,
  ) async {
    if (_dispatch != null) {
      await _reject(
        call,
        manager,
        'Error: dispatch may be called at most once per turn.',
      );
      return;
    }
    if (_askUser != null) {
      await _reject(
        call,
        manager,
        'Error: the turn already ended with ask_user; do not dispatch and '
        'ask in the same turn.',
      );
      return;
    }
    final (:dispatch, :error) = validateFrontDispatch(
      args: args,
      input: input,
      destinationExists: _destinationExists,
      categoryExists: _categoryExists,
      followUpExists: _followUpExists,
      now: now,
    );
    if (dispatch == null) {
      _rejectedDispatches++;
      await _reject(call, manager, error!);
      return;
    }
    _dispatch = dispatch;
    await _accept(
      call,
      manager,
      'Dispatched ${dispatch.segments.length} '
      'segment(s).',
    );
  }

  Future<void> _handleReadTldr(
    ChatCompletionMessageToolCall call,
    Map<String, dynamic> args,
    ConversationManager manager,
  ) async {
    if (_tldrReads >= frontTldrReadsPerTurn) {
      await _reject(call, manager, frontTldrExhaustedAnswer);
      return;
    }
    final raw = args['ids'];
    final ids = raw is List
        ? raw.whereType<String>().toList()
        : const <String>[];
    if (ids.isEmpty || ids.length > frontTldrIdsPerRead) {
      await _reject(
        call,
        manager,
        'Error: read_tldr needs 1 to $frontTldrIdsPerRead ids as listed, '
        'e.g. "task:<id>".',
      );
      return;
    }
    _tldrReads++;
    final buffer = StringBuffer();
    for (final ref in ids) {
      final row = _rowByRef(ref);
      buffer
        ..write(ref)
        ..write(': ');
      if (row == null) {
        buffer.writeln('not listed');
      } else {
        final tldr = row.tldr?.trim();
        buffer.writeln(tldr == null || tldr.isEmpty ? 'no TL;DR yet' : tldr);
      }
    }
    await _accept(call, manager, buffer.toString().trimRight());
  }

  /// A listed row by its `kind:id` reference, or null.
  FrontIndexRow? _rowByRef(String ref) {
    final colon = ref.indexOf(':');
    if (colon <= 0) return null;
    final kind = FrontDestinationKind.fromWireName(ref.substring(0, colon));
    if (kind == null) return null;
    final id = ref.substring(colon + 1);
    return index.row(kind, id) ??
        _lookupRows
            .where((row) => row.kind == kind && row.id == id)
            .firstOrNull;
  }

  Future<void> _handleMatchToCorpus(
    ChatCompletionMessageToolCall call,
    Map<String, dynamic> args,
    ConversationManager manager,
  ) async {
    if (_corpusMatches >= frontCorpusMatchesPerTurn) {
      await _reject(call, manager, frontCorpusMatchExhaustedAnswer);
      return;
    }
    final phrase = _trimmed(args['phrase']);
    if (phrase.isEmpty) {
      await _reject(call, manager, 'Error: match_to_corpus needs a phrase.');
      return;
    }
    final matcher = corpusMatcher;
    if (matcher == null) {
      await _reject(
        call,
        manager,
        'Corpus matching is unavailable this turn; decide from the index '
        'or ask the user.',
      );
      return;
    }
    _corpusMatches++;
    final rows = await matcher(phrase);
    _lookupRows.addAll(rows);
    if (rows.isEmpty) {
      await _accept(call, manager, 'No open task matches "$phrase".');
      return;
    }
    final buffer = StringBuffer();
    for (final row in rows) {
      buffer
        ..write(row.kind.wireName)
        ..write(':')
        ..write(row.id)
        ..write(' | ')
        ..write(row.title);
      if (row.status != null) buffer.write(' | ${row.status}');
      buffer.writeln();
    }
    await _accept(call, manager, buffer.toString().trimRight());
  }

  Future<void> _handleListDueTasks(
    ChatCompletionMessageToolCall call,
    Map<String, dynamic> args,
    ConversationManager manager,
  ) async {
    if (_dueLists >= frontDueListsPerTurn) {
      await _reject(call, manager, frontDueListExhaustedAnswer);
      return;
    }
    final window = FrontDueWindow.fromWire(args['which']);
    if (window == null) {
      await _reject(
        call,
        manager,
        'Error: list_due_tasks needs which: one of '
        '${FrontDueWindow.values.map((w) => w.name).join(', ')}.',
      );
      return;
    }
    final raw = args['daysAhead'] ?? 0;
    final daysAhead = raw is num && raw == raw.roundToDouble()
        ? raw.toInt()
        : null;
    if (daysAhead == null ||
        daysAhead < 0 ||
        daysAhead > frontDueMaxDaysAhead) {
      await _reject(
        call,
        manager,
        'Error: list_due_tasks needs daysAhead, a whole number from 0 '
        '(today) to $frontDueMaxDaysAhead.',
      );
      return;
    }
    final categoryIds = await _namedCategories(call, args, manager);
    if (categoryIds == null) return;
    final lister = dueTaskLister;
    if (lister == null) {
      await _reject(
        call,
        manager,
        'Due tasks are unavailable this turn; say so in your answer.',
      );
      return;
    }
    _dueLists++;
    final due = await lister((
      window: window,
      daysAhead: daysAhead,
      categoryIds: categoryIds,
    ));
    _lookupRows.addAll(due.rows);
    _dueRows = due.rows;
    if (due.rows.isNotEmpty) {
      _dueSection = FrontDueSection(
        window: due.window,
        today: due.today,
        through: due.through,
      );
    }
    await _accept(call, manager, due.render());
  }

  Future<void> _handleSummarizeLoggedTime(
    ChatCompletionMessageToolCall call,
    Map<String, dynamic> args,
    ConversationManager manager,
  ) async {
    if (_timeSummaries >= frontTimeSummariesPerTurn) {
      await _reject(call, manager, frontTimeSummaryExhaustedAnswer);
      return;
    }
    final window = frontPullRequestQuery(
      args,
      now,
      maxDays: frontLoggedTimeMaxDays,
    );
    if (window == null) {
      await _reject(
        call,
        manager,
        'Error: summarize_logged_time needs exactly one of: period (one of '
        '${FrontTimePeriod.values.map((p) => p.wireName).join(', ')}), '
        'pastDays (1 to $frontLoggedTimeMaxDays), or from and through '
        '(YYYY-MM-DD, through not before from, at most '
        '$frontLoggedTimeMaxDays days).',
      );
      return;
    }
    final categoryIds = await _namedCategories(call, args, manager);
    if (categoryIds == null) return;
    final summarizer = loggedTimeSummarizer;
    if (summarizer == null) {
      await _reject(
        call,
        manager,
        'Logged time is unavailable this turn; say so in your answer.',
      );
      return;
    }
    _timeSummaries++;
    final logged = await summarizer((
      period: window.period,
      range: window.range,
      categoryIds: categoryIds,
    ));
    final withTasks = args['tasks'] == true;
    final projectId = args['projectId'] is String
        ? args['projectId'] as String
        : null;
    final taskId = args['taskId'] is String ? args['taskId'] as String : null;
    // Only the tasks she was shown can be linked by title in her reply.
    if (withTasks) {
      final (:shown, omitted: _) = logged.listed(
        projectId: projectId,
        taskId: taskId,
      );
      _lookupRows.addAll([for (final task in shown) task.row]);
    }
    if (logged.byCategory.isNotEmpty) _loggedTimeChart = logged.chart;
    await _accept(
      call,
      manager,
      logged.render(
        withTasks: withTasks,
        projectId: projectId,
        taskId: taskId,
      ),
    );
  }

  Future<void> _handleListClosedTasks(
    ChatCompletionMessageToolCall call,
    Map<String, dynamic> args,
    ConversationManager manager,
  ) async {
    if (_closedLists >= frontClosedListsPerTurn) {
      await _reject(call, manager, frontClosedListExhaustedAnswer);
      return;
    }
    final window = frontPullRequestQuery(args, now);
    if (window == null) {
      await _reject(
        call,
        manager,
        'Error: list_closed_tasks needs exactly one of: period (one of '
        '${FrontTimePeriod.values.map((p) => p.wireName).join(', ')}), '
        'pastDays (1 to $frontPullRequestMaxDays), or from and through '
        '(YYYY-MM-DD, at most $frontPullRequestMaxDays days).',
      );
      return;
    }
    final categoryIds = await _namedCategories(call, args, manager);
    if (categoryIds == null) return;
    final lister = closedTaskLister;
    if (lister == null) {
      await _reject(
        call,
        manager,
        'Closed tasks are unavailable this turn; say so in your answer.',
      );
      return;
    }
    _closedLists++;
    final closed = await lister(window, categoryIds);
    _lookupRows.addAll([for (final task in closed.tasks) task.row]);
    if (closed.tasks.isNotEmpty) _closedTaskCards = closed.cards;
    await _accept(call, manager, closed.render());
  }

  Future<void> _handleSummarizePullRequests(
    ChatCompletionMessageToolCall call,
    Map<String, dynamic> args,
    ConversationManager manager,
  ) async {
    if (_pullRequestSummaries >= frontPullRequestSummariesPerTurn) {
      await _reject(call, manager, frontPullRequestSummaryExhaustedAnswer);
      return;
    }
    final query = frontPullRequestQuery(args, now);
    if (query == null) {
      await _reject(
        call,
        manager,
        'Error: summarize_pull_requests needs exactly one of: period (one of '
        '${FrontTimePeriod.values.map((p) => p.wireName).join(', ')}), '
        'pastDays (1 to $frontPullRequestMaxDays), or from and through '
        '(YYYY-MM-DD, at most $frontPullRequestMaxDays days).',
      );
      return;
    }
    final summarizer = pullRequestSummarizer;
    if (summarizer == null) {
      await _reject(
        call,
        manager,
        'Pull requests are unavailable this turn; say so in your answer.',
      );
      return;
    }
    _pullRequestSummaries++;
    final summary = await summarizer(query);
    if (summary.hasChart) _pullRequestChart = summary.chart;
    await _accept(call, manager, summary.render());
  }

  /// The categories a tool call's `categoryIds` names — those the user named
  /// in the question — or null once the call is rejected: an id not listed
  /// under ## Categories, or one outside the conversation's chips.
  Future<Set<String>?> _namedCategories(
    ChatCompletionMessageToolCall call,
    Map<String, dynamic> args,
    ConversationManager manager,
  ) async {
    final categoryIds = <String>{};
    final rawCategories = args['categoryIds'] ?? const <Object?>[];
    if (rawCategories is! List) {
      await _reject(
        call,
        manager,
        'Error: categoryIds is a list of ids from ## Categories.',
      );
      return null;
    }
    for (final id in rawCategories) {
      final category = id is String ? index.category(id) : null;
      if (category == null) {
        await _reject(
          call,
          manager,
          'Error: $id is not a category id listed under ## Categories; '
          'leave categoryIds out when no listed category is named.',
        );
        return null;
      }
      if (index.categories.any((c) => c.chosen) && !category.chosen) {
        await _reject(
          call,
          manager,
          '${category.name} is outside the categories this conversation is '
          'narrowed to; say so in your answer.',
        );
        return null;
      }
      categoryIds.add(category.id);
    }
    return categoryIds;
  }

  /// Her words with every task or project they name by id made a link —
  /// and, for what this turn's lookups returned, by title: the prompt asks
  /// for links, this keeps a recited id from reaching the user and a listed
  /// task from being words alone (see [linkFrontReferences]).
  String _linked(String words) => linkFrontReferences(
    words,
    [...index.rows, ..._lookupRows],
    titled: _lookupRows,
  );

  Future<void> _handleAskUser(
    ChatCompletionMessageToolCall call,
    Map<String, dynamic> args,
    ConversationManager manager,
  ) async {
    if (_askUser != null) {
      await _reject(
        call,
        manager,
        'Error: ask_user may be called at most once per turn.',
      );
      return;
    }
    if (_dispatch != null) {
      await _reject(
        call,
        manager,
        'Error: the turn already ended with dispatch; do not dispatch and '
        'ask in the same turn.',
      );
      return;
    }
    final question = _trimmed(args['question']);
    if (question.isEmpty) {
      await _reject(call, manager, 'Error: ask_user needs a question.');
      return;
    }
    final rawOptions = args['options'];
    final options = <FrontAskOption>[];
    if (rawOptions is List) {
      for (final item in rawOptions) {
        if (item is! Map) continue;
        final kind = FrontDestinationKind.fromWireName(item['kind']);
        final id = _trimmed(item['id']);
        final label = _trimmed(item['label']);
        if (kind == null || !kind.needsId || id.isEmpty || label.isEmpty) {
          await _reject(
            call,
            manager,
            'Error: every ask_user option needs a kind '
            '(task|project|goal|person), a listed id and a label.',
          );
          return;
        }
        if (!_destinationExists(kind, id) &&
            !(kind == FrontDestinationKind.task && _followUpExists(id))) {
          await _reject(
            call,
            manager,
            'Error: option ${kind.wireName}:$id is not in <routing_index>, '
            '<conversation_tasks> or a lookup result this turn.',
          );
          return;
        }
        options.add((kind: kind, id: id, label: label));
      }
    }
    if (options.length > frontAskUserMaxOptions) {
      await _reject(
        call,
        manager,
        'Error: ask_user offers at most $frontAskUserMaxOptions options.',
      );
      return;
    }
    _askUser = (question: _linked(question), options: options);
    await _accept(call, manager, 'Question delivered.');
  }

  /// Takes [content], the message she ended the turn with, as her answer:
  /// UI blocks, then prose (see `parseFrontReplyStream`).
  ///
  /// Her prose is what is said; her blocks are checked against what the turn
  /// saw and composed into what is drawn (`readFrontReply`). A block that
  /// cannot be read, or a component that cannot be drawn, is left out and
  /// logged — never a reason to lose her answer. Returns false, leaving the
  /// turn open for the repair round, when there is nothing to take: no
  /// prose, a question already asked, or an answer already taken.
  bool acceptAnswer(String content) {
    if (_askUser != null || _replyToUser != null) return false;
    final streamed = parseFrontReplyStream(content);
    final FrontReply reply;
    try {
      reply = _read(streamed);
    } on FrontReplyException {
      if (streamed.components.isNotEmpty || streamed.errors.isNotEmpty) {
        _logFormatFailure('her answer had UI but no prose');
      }
      return false;
    }
    _replyToUser = reply.text;
    _replyComponents = reply.components;
    final unread = streamed.errors.length + reply.dropped.length;
    if (unread > 0) {
      // Counted, so a model that keeps writing what cannot be drawn shows up
      // in the logs rather than as a card that quietly never appears.
      _logFormatFailure(
        'her answer left out $unread part(s): ${streamed.errors.length} '
        'block(s) unreadable, ${reply.dropped.length} component(s) not '
        'drawable',
      );
    }
    return true;
  }

  /// Her message while she is still writing it: what it says and draws so
  /// far goes to [onAnswerProgress], read as [acceptAnswer] will read it but
  /// taking nothing — the message may yet turn out to be a remark beside a
  /// lookup. Nothing is reported before it has a word or a component.
  @override
  void onContent(String content) {
    final progress = onAnswerProgress;
    if (progress == null || _askUser != null || _replyToUser != null) return;
    final streamed = parseFrontReplyStream(
      stripThinkBlocks(content) ?? '',
      complete: false,
    );
    if (streamed.prose.isEmpty && streamed.components.isEmpty) return;
    final reply = _read(streamed, proseRequired: false);
    progress(reply.text, reply.components);
  }

  /// Shows, through [onAnswerProgress], what the turn's lookups found —
  /// the tasks due, a chart, the closed tasks — before she has written a
  /// word about it: most of a lookup answer's wait is the call that writes
  /// it, and what it will be about is already known. Returns whether there
  /// was something to show.
  bool showLookups() {
    final progress = onAnswerProgress;
    if (progress == null || hasTerminalOutput) return false;
    final found = _read(
      (prose: '', components: const [], errors: const []),
      proseRequired: false,
    ).components;
    if (found.isEmpty) return false;
    progress('', found);
    return true;
  }

  /// [streamed] checked against what the turn saw (`readFrontReply`).
  FrontReply _read(FrontStreamedReply streamed, {bool proseRequired = true}) {
    final closed = _closedTaskCards;
    return readFrontReply(
      prose: streamed.prose,
      components: streamed.components,
      visible: frontVisibleRows([...index.rows, ..._lookupRows]),
      available: {
        if (closed != null) FrontReplyComponents.closedTasks,
        if (_loggedTimeChart != null) FrontReplyComponents.loggedTimeChart,
        if (_pullRequestChart != null) FrontReplyComponents.pullRequestChart,
      },
      dueRows: _dueRows,
      closedTaskIds: {...?closed?.map((card) => card.id)},
      link: _linked,
      proseRequired: proseRequired,
    );
  }

  /// Logs that her answer did not follow the reply format. Never its words:
  /// they are the user's conversation.
  void _logFormatFailure(String what) => domainLogger.log(
    LogDomain.agentWorkflow,
    'front reply format: $what',
    subDomain: 'FrontAgentStrategy',
    level: InsightLevel.warn,
  );

  String _trimmed(Object? value) => value is String ? value.trim() : '';

  Future<void> _accept(
    ChatCompletionMessageToolCall call,
    ConversationManager manager,
    String response,
  ) async {
    manager.addToolResponse(toolCallId: call.id, response: response);
    await recordToolResultMessage(toolName: call.function.name);
  }

  Future<void> _reject(
    ChatCompletionMessageToolCall call,
    ConversationManager manager,
    String error,
  ) async {
    manager.addToolResponse(toolCallId: call.id, response: error);
    await recordToolResultMessage(
      toolName: call.function.name,
      errorMessage: error,
    );
  }
}

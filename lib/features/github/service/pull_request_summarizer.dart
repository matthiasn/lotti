import 'package:clock/clock.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/github/domain/pull_request_summary_input.dart';
import 'package:lotti/features/github/repository/pull_request_repository.dart';
import 'package:lotti/services/domain_logging.dart';

/// The model a summary is written with: the thinking slot of the profile
/// that drives the task's agent.
typedef PullRequestSummaryModel = ({
  String modelId,
  AiConfigInferenceProvider provider,
});

/// Writes one completion of [prompt] under [systemMessage] with [model], for
/// task [taskId]'s pull request; its text, trimmed.
typedef PullRequestSummaryGenerate =
    Future<String> Function({
      required String prompt,
      required String systemMessage,
      required PullRequestSummaryModel model,
      required String taskId,
      required String? categoryId,
    });

/// What a summary is asked for. Prompt text, so English.
const pullRequestSummarySystemMessage =
    'You summarise a finished GitHub pull request for an assistant that '
    'tracks the task it belongs to. In one or two sentences, at most 300 '
    'characters, say what the pull request changed and how it ended — '
    'merged, or closed without merging. Plain text: no preamble, no '
    'Markdown, no repetition of the title.';

/// Summarises a task's merged and closed pull requests, so that a task
/// context can show each as a short TL;DR rather than its full description.
///
/// A summary is an AI response entry linked from the pull request entry and
/// syncs like any journal entry, so a second device reuses it rather than
/// asking again. It is written from `pullRequestSummaryInput` and stores that
/// text as its prompt: while the pull request's content is unchanged a
/// summary exists, and nothing is asked; a restamp, or a change of checks or
/// reviews, changes none of it.
///
/// It asks only with the consent the rest of the app asks with: the task's
/// category has automatic inference switched on. And only with the model of
/// the task's own agent — the data it sends is what the pull request entry
/// already holds.
class PullRequestSummarizer {
  PullRequestSummarizer({
    required PullRequestRepository repository,
    required Future<bool> Function(String taskId) automationAllowed,
    required this._modelFor,
    required this._generate,
    this._logger,
  }) : _entries = repository,
       _allowed = automationAllowed;

  final PullRequestRepository _entries;
  final Future<bool> Function(String taskId) _allowed;
  final Future<PullRequestSummaryModel?> Function(String taskId) _modelFor;
  final PullRequestSummaryGenerate _generate;
  final DomainLogger? _logger;

  /// Entries being summarised on this device now.
  final Set<String> _running = {};

  /// Summarises entry [entryId]'s pull request if a task context shows it as
  /// a summary and no summary matches its content yet; returns whether one
  /// was stored. Never throws: it runs after a refresh, which does not wait
  /// for it.
  ///
  /// A request while one for the same entry runs is dropped: that one reads
  /// the entry again before storing, and the next refresh asks again.
  Future<bool> summarize(String entryId) async {
    if (!_running.add(entryId)) return false;
    try {
      return await _summarize(entryId);
    } on Exception catch (error, stackTrace) {
      _logger?.error(
        LogDomain.ai,
        error,
        stackTrace: stackTrace,
        subDomain: 'pullRequestSummary',
      );
      return false;
    } finally {
      _running.remove(entryId);
    }
  }

  Future<bool> _summarize(String entryId) async {
    final entry = await _entries.liveEntry(entryId);
    final snapshot = entry?.data.snapshot;
    if (entry == null || snapshot == null || !isSettledPullRequest(snapshot)) {
      return false;
    }
    final input = pullRequestSummaryInput(entry.data.ref, snapshot);
    if (await _entries.summaryOf(entryId, input) != null) return false;

    final ref = entry.data.ref;
    final holders = [
      ...?(await _entries.holdersOf([ref]))[ref.key],
    ]..sort();
    String? taskId;
    PullRequestSummaryModel? model;
    for (final holder in holders) {
      if (!await _allowed(holder)) continue;
      model = await _modelFor(holder);
      if (model != null) {
        taskId = holder;
        break;
      }
    }
    if (taskId == null || model == null) return false;

    final start = clock.now();
    final text = await _generate(
      prompt: input,
      systemMessage: pullRequestSummarySystemMessage,
      model: model,
      taskId: taskId,
      categoryId: entry.meta.categoryId,
    );
    if (text.isEmpty) return false;

    // Read again: the pull request may have been unlinked, or have changed,
    // while the model wrote.
    final current = await _entries.liveEntry(entryId);
    final currentSnapshot = current?.data.snapshot;
    if (current == null ||
        currentSnapshot == null ||
        pullRequestSummaryInput(current.data.ref, currentSnapshot) != input) {
      return false;
    }
    return _entries.addSummary(
      current,
      AiResponseData(
        model: model.modelId,
        systemMessage: pullRequestSummarySystemMessage,
        prompt: input,
        thoughts: '',
        response: text,
        type: AiResponseType.pullRequestSummary,
        tldr: text,
      ),
      start: start,
    );
  }
}

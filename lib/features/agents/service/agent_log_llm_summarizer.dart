import 'package:lotti/features/agents/projection/compaction_summary.dart';
import 'package:lotti/features/agents/projection/input_capture.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/service/text_chunker.dart';

/// The LLM edge of input-log compaction (ADR 0017): distills folded
/// [RenderedSource]s into rolling summary prose with a one-shot generation
/// call, using the **wake's resolved model** (passed in by the workflow so the
/// agent summarizes its own memory with the same brain it thinks with).
///
/// Kept separate from `AgentLogCompactor` so the compactor stays
/// deterministically testable; the workflow adapts [summarize] onto the
/// `AgentSummarizer` typedef after resolving the wake's inference profile.
///
/// **Cadence & caching.** This is only invoked when the uncovered tail crosses
/// the compaction trigger watermark (then folds down to the retain watermark),
/// so summarization is infrequent — roughly once per `trigger − retain` tokens
/// of new activity — and the summary block in the prompt prefix stays
/// byte-stable between folds (prefix-cache friendly).
///
/// **Convergence.** Two devices folding the same region will produce different
/// prose (LLM nondeterminism) and therefore two checkpoints; that is fine —
/// `selectActiveSummary` picks deterministically among complete checkpoints
/// (ADR 0017), so both devices converge on the same one.
class AgentLogLlmSummarizer {
  /// Creates the summarizer over the app's inference repository.
  AgentLogLlmSummarizer({
    required CloudInferenceRepository inferenceRepository,
    this.maxInputTokensPerCall = 12000,
    this.maxSummaryTokens = 2048,
  }) : _inference = inferenceRepository;

  final CloudInferenceRepository _inference;

  /// Upper bound on the rendered entry text fed to a single generation call.
  /// Larger fold sets (e.g. the first compaction of a long-lived task) are
  /// distilled in chronological chunks, rolling the summary forward through
  /// each call — the same rolling shape the checkpoint chain itself uses.
  final int maxInputTokensPerCall;

  /// Completion cap for the distilled summary. Generous by design: the summary
  /// is the *only* prompt representation of everything older than the retain
  /// window, it lives in the prefix-cached stable block (so extra length is
  /// nearly free between folds), and an over-tight cap is the dominant
  /// lossiness bottleneck — each fold would re-compress months of history
  /// through it. The system prompt still pushes for the shortest summary that
  /// loses nothing.
  final int maxSummaryTokens;

  /// Low temperature: this is faithful distillation, not creative writing.
  static const double _temperature = 0.3;

  static const String _systemMessage =
      'You maintain the long-term working memory of a personal task '
      'assistant. Fold the new log entries into the running summary. Preserve '
      'durable facts: decisions, progress and outcomes, time spent and dates, '
      "names, numbers, open questions, and the user's stated preferences. "
      'Drop filler and transient detail. Write in the dominant language of '
      'the entries. Be as short as possible but as long as necessary — never '
      'pad, but never drop a durable fact to save space; a long history '
      'deserves a longer summary (up to roughly 800 words). Respond with ONLY '
      'the updated summary text — no preamble, no headings.';

  /// Distills [sources] (chronological fold set) into updated summary prose,
  /// folding in [priorSummary] when present. Throws on an empty model response
  /// — the caller (`maybeCompact` via the workflow) treats a throw as a
  /// non-fatal "no compaction this wake", which is strictly safer than
  /// persisting an empty checkpoint that would erase folded memory.
  Future<String> summarize({
    required List<RenderedSource> sources,
    required String model,
    required AiConfigInferenceProvider provider,
    String? priorSummary,
  }) async {
    var rolling = priorSummary?.trim();
    for (final chunk in _chunkByTokens(sources)) {
      rolling = await _distill(
        chunk: chunk,
        priorSummary: rolling,
        model: model,
        provider: provider,
      );
    }
    final result = rolling ?? '';
    if (result.isEmpty) {
      throw StateError('summarizer produced no summary text');
    }
    return result;
  }

  /// Splits [sources] into chronological chunks whose rendered text fits
  /// [maxInputTokensPerCall] (always at least one source per chunk — a single
  /// oversized entry still goes through whole; entries are never split).
  List<List<RenderedSource>> _chunkByTokens(List<RenderedSource> sources) {
    final chunks = <List<RenderedSource>>[];
    var current = <RenderedSource>[];
    var currentTokens = 0;
    for (final source in sources) {
      final tokens = TextChunker.estimateTokens(
        renderCompactedSourceLine(source),
      );
      if (current.isNotEmpty &&
          currentTokens + tokens > maxInputTokensPerCall) {
        chunks.add(current);
        current = <RenderedSource>[];
        currentTokens = 0;
      }
      current.add(source);
      currentTokens += tokens;
    }
    if (current.isNotEmpty) chunks.add(current);
    return chunks;
  }

  Future<String> _distill({
    required List<RenderedSource> chunk,
    required String? priorSummary,
    required String model,
    required AiConfigInferenceProvider provider,
  }) async {
    final lines = [
      for (final source in chunk) renderCompactedSourceLine(source),
    ].join('\n');
    final prior = (priorSummary == null || priorSummary.isEmpty)
        ? '(none yet)'
        : priorSummary;
    final prompt =
        'Running summary so far:\n'
        '$prior\n\n'
        'New entries to fold in, oldest first:\n'
        '$lines\n\n'
        'Update the running summary to cover the new entries.';

    final stream = _inference.generate(
      prompt,
      model: model,
      temperature: _temperature,
      baseUrl: provider.baseUrl,
      apiKey: provider.apiKey,
      systemMessage: _systemMessage,
      maxCompletionTokens: maxSummaryTokens,
      provider: provider,
    );

    final buffer = StringBuffer();
    await for (final response in stream) {
      final choices = response.choices;
      if (choices == null || choices.isEmpty) continue;
      final content = choices.first.delta?.content;
      if (content != null) buffer.write(content);
    }
    final text = buffer.toString().trim();
    if (text.isEmpty) {
      throw StateError('summarizer model returned an empty response');
    }
    return text;
  }
}

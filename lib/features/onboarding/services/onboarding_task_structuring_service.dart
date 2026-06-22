import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';

/// The structured result of turning a raw spoken transcript into a task.
///
/// [title] is always non-empty; [checklistItems] may be empty for a single
/// simple action that implies no sub-steps.
@immutable
class OnboardingStructuredTask {
  const OnboardingStructuredTask({
    required this.title,
    required this.checklistItems,
  });

  final String title;
  final List<String> checklistItems;

  @override
  bool operator ==(Object other) =>
      other is OnboardingStructuredTask &&
      other.title == title &&
      listEquals(other.checklistItems, checklistItems);

  @override
  int get hashCode => Object.hash(title, Object.hashAll(checklistItems));

  @override
  String toString() =>
      'OnboardingStructuredTask(title: $title, items: $checklistItems)';
}

/// Why a structuring attempt failed, used both to drive the title-only soft
/// landing and as the low-cardinality `reason` on the `structuring_failed`
/// funnel event.
enum OnboardingStructuringFailure {
  /// The transcript was empty/whitespace — nothing to structure.
  emptyTranscript,

  /// No connected provider/model could be resolved for the category.
  noModel,

  /// The inference request threw (network, auth, quota, timeout).
  requestFailed,

  /// The provider returned an empty completion.
  emptyResponse,

  /// The completion could not be parsed into a `{title, items}` shape.
  parseError,
}

/// Raised when a transcript could not be structured. The [failure] reason is
/// safe to record as a funnel dimension; [cause] (if any) is for logs only.
class OnboardingStructuringException implements Exception {
  const OnboardingStructuringException(this.failure, {this.cause});

  final OnboardingStructuringFailure failure;
  final Object? cause;

  @override
  String toString() => 'OnboardingStructuringException(${failure.name})';
}

/// Single-shot transform: a raw spoken transcript → `{title, checklist[]}`.
///
/// This is the net-new "magic" of the onboarding aha. There is no `SkillType`
/// for it and it is deliberately *not* routed through the heavyweight
/// prompt-config/entity inference pipeline — it is one chat completion on the
/// connected provider's thinking model, parsed into a small value object. The
/// caller materialises the result into a real task separately so the failure
/// path can soft-land on a title-only task.
class OnboardingTaskStructuringService {
  OnboardingTaskStructuringService({
    required this._cloudInferenceRepository,
    required this._aiConfigRepository,
    required this._categoryRepository,
    DomainLogger? logger,
  }) : _logger = logger ?? getIt<DomainLogger>();

  final CloudInferenceRepository _cloudInferenceRepository;
  final AiConfigRepository _aiConfigRepository;
  final CategoryRepository _categoryRepository;
  final DomainLogger _logger;

  /// Structuring is deterministic-leaning; reasoning models only accept 1.0.
  static const double _temperature = 0.3;
  static const int _maxItems = 8;
  static const int _maxTitleLength = 120;
  static const int _maxItemLength = 100;

  /// Internal LLM instruction — not user-visible, so it stays in code rather
  /// than the ARB files (mirrors `built_in_skills.dart`'s `systemInstructions`).
  static const String systemPrompt = '''
You convert a short spoken note into a single actionable task.
Return ONLY minified JSON, with no prose and no code fences, shaped exactly:
{"title":"<concise imperative task title>","items":["<step>","<step>"]}
Rules:
- title: imperative and specific, at most ~10 words, no trailing punctuation.
- items: the concrete sub-steps the note implies, in order; use [] when the
  note is a single simple action with no sub-steps. At most 8 items.
- Write the title and items in the same language as the note.
- Never invent details, names, dates, or steps the note does not imply.''';

  /// Structures [transcript] using the chat model bound to [categoryId]'s
  /// connected provider.
  ///
  /// Throws [OnboardingStructuringException] on every failure mode so the
  /// caller can record the reason and soft-land on a title-only task.
  Future<OnboardingStructuredTask> structure({
    required String transcript,
    required String categoryId,
  }) async {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      throw const OnboardingStructuringException(
        OnboardingStructuringFailure.emptyTranscript,
      );
    }

    final resolved = await _resolveModel(categoryId);

    final buffer = StringBuffer();
    try {
      final stream = _cloudInferenceRepository.generate(
        trimmed,
        model: resolved.model.providerModelId,
        temperature: resolved.model.isReasoningModel ? 1.0 : _temperature,
        baseUrl: resolved.provider.baseUrl,
        apiKey: resolved.provider.apiKey,
        systemMessage: systemPrompt,
        maxCompletionTokens: resolved.model.maxCompletionTokens,
        provider: resolved.provider,
        geminiThinkingMode: resolved.model.geminiThinkingMode,
      );
      await for (final chunk in stream) {
        buffer.write(chunk.choices?.firstOrNull?.delta?.content ?? '');
      }
    } catch (error, stackTrace) {
      _logger.error(
        LogDomain.onboarding,
        error,
        stackTrace: stackTrace,
        subDomain: 'structure',
      );
      throw OnboardingStructuringException(
        OnboardingStructuringFailure.requestFailed,
        cause: error,
      );
    }

    final raw = buffer.toString();
    if (raw.trim().isEmpty) {
      throw const OnboardingStructuringException(
        OnboardingStructuringFailure.emptyResponse,
      );
    }
    return _parse(raw);
  }

  /// Resolves category → `defaultProfileId` → profile.`thinkingModelId` →
  /// model → provider. Any missing link is a [OnboardingStructuringFailure.noModel].
  Future<({AiConfigModel model, AiConfigInferenceProvider provider})>
  _resolveModel(String categoryId) async {
    final category = await _categoryRepository.getCategoryById(categoryId);
    final profileId = category?.defaultProfileId;
    if (profileId == null) {
      throw const OnboardingStructuringException(
        OnboardingStructuringFailure.noModel,
      );
    }

    final profile = await _aiConfigRepository.getConfigById(profileId);
    if (profile is! AiConfigInferenceProfile) {
      throw const OnboardingStructuringException(
        OnboardingStructuringFailure.noModel,
      );
    }

    final model = await _aiConfigRepository.getConfigById(
      profile.thinkingModelId,
    );
    if (model is! AiConfigModel) {
      throw const OnboardingStructuringException(
        OnboardingStructuringFailure.noModel,
      );
    }

    final provider = await _aiConfigRepository.getConfigById(
      model.inferenceProviderId,
    );
    if (provider is! AiConfigInferenceProvider) {
      throw const OnboardingStructuringException(
        OnboardingStructuringFailure.noModel,
      );
    }

    return (model: model, provider: provider);
  }

  OnboardingStructuredTask _parse(String raw) {
    final decoded = _decodeJsonObject(raw);
    if (decoded == null) {
      throw const OnboardingStructuringException(
        OnboardingStructuringFailure.parseError,
      );
    }

    final title = (decoded['title'] as Object?)?.toString().trim() ?? '';
    if (title.isEmpty) {
      throw const OnboardingStructuringException(
        OnboardingStructuringFailure.parseError,
      );
    }

    final items = <String>[];
    final rawItems = decoded['items'];
    if (rawItems is List) {
      for (final entry in rawItems) {
        final text = _itemText(entry);
        if (text != null && text.isNotEmpty) {
          items.add(_clamp(text, _maxItemLength));
        }
        if (items.length >= _maxItems) break;
      }
    }

    return OnboardingStructuredTask(
      title: _clamp(title, _maxTitleLength),
      checklistItems: items,
    );
  }

  /// Accepts either a bare string item or an object carrying a text field, so
  /// minor provider formatting differences don't drop the checklist.
  String? _itemText(Object? entry) {
    if (entry is String) return entry.trim();
    if (entry is Map) {
      final value = entry['title'] ?? entry['text'] ?? entry['name'];
      return value?.toString().trim();
    }
    return null;
  }

  /// Decodes the first `{…}` block out of [raw] into a map, so leading prose
  /// or ```json fences a provider might add don't break parsing. Returns null
  /// when no object is present or the slice isn't valid JSON.
  Map<dynamic, dynamic>? _decodeJsonObject(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final decoded = jsonDecode(raw.substring(start, end + 1));
      if (decoded is Map) return decoded;
      // A successfully parsed `{…}` slice is always a Map; this is defensive.
      return null; // coverage:ignore-line
    } catch (_) {
      return null;
    }
  }

  String _clamp(String value, int max) =>
      value.length <= max ? value : value.substring(0, max).trimRight();
}

/// Riverpod handle for [OnboardingTaskStructuringService], reading the same
/// AI/category repositories the rest of the app uses.
final onboardingTaskStructuringServiceProvider =
    Provider<OnboardingTaskStructuringService>(
      (ref) => OnboardingTaskStructuringService(
        cloudInferenceRepository: ref.watch(cloudInferenceRepositoryProvider),
        aiConfigRepository: ref.watch(aiConfigRepositoryProvider),
        categoryRepository: ref.watch(categoryRepositoryProvider),
      ),
    );

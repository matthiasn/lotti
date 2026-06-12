// Data models for the tiered agent evaluation harness (ADR 0029).
//
// These are plain, JSON-serialisable value objects with NO dependency on the
// app's entity types, so the eval dataset is easy to author, diff, and review.
// Adapters map a scenario onto the real seeding factories at execution time
// (Phase 1); the scenario itself stays decoupled. Token accounting reuses the
// production `InferenceUsage` type verbatim so Level 2 numbers match what
// `WakeTokenUsageEntity` records in the app.
//
// See docs/adr/0029-agent-evaluation-harness.md.

import 'package:lotti/features/ai/model/inference_usage.dart';

/// Parses a nullable ISO-8601 date string.
DateTime? _parseDate(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

/// Which agent a scenario targets.
enum AgentKind {
  taskAgent,
  planningAgent;

  static AgentKind fromName(String name) =>
      AgentKind.values.firstWhere((k) => k.name == name);
}

/// Coarse model capability class used for tuning and reporting.
enum EvalModelClass {
  localSmall,
  localReasoning,
  frontierFast,
  frontierReasoning;

  static EvalModelClass fromName(String name) =>
      EvalModelClass.values.firstWhere((c) => c.name == name);
}

/// How a scenario should be used in the eval lifecycle.
enum EvalScenarioSplit {
  /// Committed scenarios that developers may inspect and tune against.
  development,

  /// Private or otherwise protected scenarios used to measure generalisation.
  holdout,

  /// Regression sentinels for high-value or previously broken behaviours.
  canary;

  static EvalScenarioSplit fromName(String name) =>
      EvalScenarioSplit.values.firstWhere((s) => s.name == name);
}

/// Where a scenario came from.
enum EvalScenarioSource {
  handAuthored,
  synthetic,
  productionReplay,
  adversarial;

  static EvalScenarioSource fromName(String name) =>
      EvalScenarioSource.values.firstWhere((s) => s.name == name);
}

/// Human review state for scenario evidence.
enum EvalScenarioReviewStatus {
  /// Structurally valid metadata that is not tuning-ready evidence.
  needsReview,

  /// A human reviewer checked the scenario and its expected evidence.
  reviewed,

  /// A reviewer resolved disagreement or conflict in the scenario evidence.
  adjudicated;

  static EvalScenarioReviewStatus fromJsonValue(String value) {
    if (value == 'needs_review') return EvalScenarioReviewStatus.needsReview;
    for (final status in EvalScenarioReviewStatus.values) {
      if (status.name == value || status.jsonValue == value) return status;
    }
    throw FormatException('metadata.review.status is unknown: $value');
  }

  String get jsonValue => switch (this) {
    EvalScenarioReviewStatus.needsReview => 'needs_review',
    EvalScenarioReviewStatus.reviewed => 'reviewed',
    EvalScenarioReviewStatus.adjudicated => 'adjudicated',
  };
}

/// Canonical adversarial failure modes used by model-class tuning readiness.
const kDefaultAdversarialStressTags = <String>{
  'ambiguous-reference',
  'scope-boundary',
  'stale-state',
  'tool-recovery',
};

/// Non-secret, digest-bound review metadata for scenario governance.
class EvalScenarioReview {
  const EvalScenarioReview({
    required this.status,
    required this.reviewer,
    required this.reviewedAt,
    required this.subjectDigest,
    required this.rationale,
    this.sourceDigest,
    this.sourceLabel,
    this.generator,
  });

  factory EvalScenarioReview.fromJson(Map<String, dynamic> json) =>
      EvalScenarioReview(
        status: EvalScenarioReviewStatus.fromJsonValue(
          _requiredString(json, 'status'),
        ),
        reviewer: _requiredString(json, 'reviewer'),
        reviewedAt: _requiredString(json, 'reviewedAt'),
        subjectDigest: _requiredString(json, 'subjectDigest'),
        rationale: _requiredString(json, 'rationale'),
        sourceDigest: _optionalString(json, 'sourceDigest'),
        sourceLabel: _optionalString(json, 'sourceLabel'),
        generator: _optionalString(json, 'generator'),
      );

  final EvalScenarioReviewStatus status;
  final String reviewer;
  final String reviewedAt;
  final String subjectDigest;
  final String rationale;
  final String? sourceDigest;
  final String? sourceLabel;
  final String? generator;

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String) return value;
    throw FormatException('metadata.review.$key must be a string');
  }

  static String? _optionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null || value is String) return value as String?;
    throw FormatException('metadata.review.$key must be a string');
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'status': status.jsonValue,
    'reviewer': reviewer,
    'reviewedAt': reviewedAt,
    'subjectDigest': subjectDigest,
    'rationale': rationale,
    if (sourceDigest != null) 'sourceDigest': sourceDigest,
    if (sourceLabel != null) 'sourceLabel': sourceLabel,
    if (generator != null) 'generator': generator,
  };
}

/// Governance metadata that keeps aggregate eval scores interpretable.
class EvalScenarioMetadata {
  const EvalScenarioMetadata({
    this.capabilityIds = const <String>[],
    this.split = EvalScenarioSplit.development,
    this.source = EvalScenarioSource.handAuthored,
    this.isAdversarial = false,
    this.tags = const <String>{},
    this.review,
  });

  factory EvalScenarioMetadata.fromJson(Map<String, dynamic> json) =>
      EvalScenarioMetadata(
        capabilityIds: ((json['capabilityIds'] as List<dynamic>?) ?? const [])
            .map((e) => e as String)
            .toList(),
        split: EvalScenarioSplit.fromName(
          (json['split'] as String?) ?? EvalScenarioSplit.development.name,
        ),
        source: EvalScenarioSource.fromName(
          (json['source'] as String?) ?? EvalScenarioSource.handAuthored.name,
        ),
        isAdversarial: (json['isAdversarial'] as bool?) ?? false,
        tags: ((json['tags'] as List<dynamic>?) ?? const [])
            .map((e) => e as String)
            .toSet(),
        review: json['review'] == null
            ? null
            : EvalScenarioReview.fromJson(
                json['review'] as Map<String, dynamic>,
              ),
      );

  final List<String> capabilityIds;
  final EvalScenarioSplit split;
  final EvalScenarioSource source;
  final bool isAdversarial;
  final Set<String> tags;
  final EvalScenarioReview? review;

  String? get primaryCapabilityId =>
      capabilityIds.isEmpty ? null : capabilityIds.first;

  List<String> get secondaryCapabilityIds =>
      capabilityIds.length <= 1 ? const <String>[] : capabilityIds.sublist(1);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'capabilityIds': capabilityIds,
    'split': split.name,
    'source': source.name,
    'isAdversarial': isAdversarial,
    'tags': (tags.toList()..sort()),
    if (review != null) 'review': review!.toJson(),
  };
}

/// The simulated user input that drives a wake.
///
/// Planner production capture transcripts are represented by
/// [MockedAppState.captures]. This field stays as a concise human-readable
/// scenario summary and as a fixture-target fallback for older pure tests.
class UserInput {
  const UserInput({
    required this.transcript,
    this.triggerTokens = const <String>{},
  });

  factory UserInput.fromJson(Map<String, dynamic> json) => UserInput(
    transcript: json['transcript'] as String,
    triggerTokens: ((json['triggerTokens'] as List<dynamic>?) ?? const [])
        .map((e) => e as String)
        .toSet(),
  );

  final String transcript;
  final Set<String> triggerTokens;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'transcript': transcript,
    'triggerTokens': (triggerTokens.toList()..sort()),
  };
}

/// A checklist item on a mocked task.
class MockChecklistItem {
  const MockChecklistItem({
    required this.id,
    required this.title,
    this.isChecked = false,
  });

  factory MockChecklistItem.fromJson(Map<String, dynamic> json) =>
      MockChecklistItem(
        id: json['id'] as String,
        title: json['title'] as String,
        isChecked: (json['isChecked'] as bool?) ?? false,
      );

  final String id;
  final String title;
  final bool isChecked;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'isChecked': isChecked,
  };
}

/// A mocked task in the app state. `status` mirrors the real journal task
/// status strings (e.g. `OPEN`, `IN PROGRESS`, `GROOMED`, `BLOCKED`, `ON HOLD`,
/// `DONE`, `REJECTED`).
class MockTask {
  const MockTask({
    required this.id,
    required this.title,
    required this.status,
    this.due,
    this.estimateMinutes,
    this.categoryId,
    this.labelIds = const <String>[],
    this.aiSuppressedLabelIds = const <String>{},
    this.checklist = const <MockChecklistItem>[],
  });

  factory MockTask.fromJson(Map<String, dynamic> json) => MockTask(
    id: json['id'] as String,
    title: json['title'] as String,
    status: json['status'] as String,
    due: _parseDate(json['due']),
    estimateMinutes: (json['estimateMinutes'] as num?)?.toInt(),
    categoryId: json['categoryId'] as String?,
    labelIds: ((json['labelIds'] as List<dynamic>?) ?? const [])
        .map((e) => e as String)
        .toList(),
    aiSuppressedLabelIds:
        ((json['aiSuppressedLabelIds'] as List<dynamic>?) ?? const [])
            .map((e) => e as String)
            .toSet(),
    checklist: ((json['checklist'] as List<dynamic>?) ?? const [])
        .map((e) => MockChecklistItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final String id;
  final String title;
  final String status;
  final DateTime? due;
  final int? estimateMinutes;
  final String? categoryId;
  final List<String> labelIds;
  final Set<String> aiSuppressedLabelIds;
  final List<MockChecklistItem> checklist;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'status': status,
    if (due != null) 'due': due!.toIso8601String(),
    if (estimateMinutes != null) 'estimateMinutes': estimateMinutes,
    if (categoryId != null) 'categoryId': categoryId,
    'labelIds': labelIds,
    'aiSuppressedLabelIds': aiSuppressedLabelIds.toList(),
    'checklist': checklist.map((c) => c.toJson()).toList(),
  };
}

/// A block already present on the day's plan (the planner refines around these).
class MockDayBlock {
  const MockDayBlock({
    required this.id,
    required this.categoryId,
    required this.start,
    required this.end,
    this.taskId,
    this.title,
    this.type = 'manual',
    this.state = 'drafted',
    this.reason,
    this.note,
  });

  factory MockDayBlock.fromJson(Map<String, dynamic> json) => MockDayBlock(
    id: json['id'] as String,
    categoryId: json['categoryId'] as String,
    start: DateTime.parse(json['start'] as String),
    end: DateTime.parse(json['end'] as String),
    taskId: json['taskId'] as String?,
    title: json['title'] as String?,
    type: (json['type'] as String?) ?? 'manual',
    state: (json['state'] as String?) ?? 'drafted',
    reason: json['reason'] as String?,
    note: json['note'] as String?,
  );

  final String id;
  final String categoryId;
  final DateTime start;
  final DateTime end;
  final String? taskId;
  final String? title;
  final String type;
  final String state;
  final String? reason;
  final String? note;

  int get durationMinutes => end.difference(start).inMinutes;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'categoryId': categoryId,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    if (taskId != null) 'taskId': taskId,
    if (title != null) 'title': title,
    'type': type,
    'state': state,
    if (reason != null) 'reason': reason,
    if (note != null) 'note': note,
  };
}

/// One parsed item extracted from a mocked Daily OS capture.
///
/// The strings mirror production enum names (`newTask`, `matched`, `update`;
/// `low`, `medium`, `high`) while keeping the scenario catalog decoupled from
/// generated app entity classes.
class MockParsedCaptureItem {
  const MockParsedCaptureItem({
    required this.id,
    required this.title,
    required this.categoryId,
    this.kind = 'newTask',
    this.confidence = 'high',
    this.confidenceScore = 1,
    this.lowConfidence = false,
    this.spokenPhrase,
    this.matchedTaskId,
    this.estimateMinutes,
    this.timeAnchor,
    this.proposedUpdate,
    this.createdAt,
    this.deletedAt,
  });

  factory MockParsedCaptureItem.fromJson(Map<String, dynamic> json) =>
      MockParsedCaptureItem(
        id: json['id'] as String,
        title: json['title'] as String,
        categoryId: json['categoryId'] as String,
        kind: (json['kind'] as String?) ?? 'newTask',
        confidence: (json['confidence'] as String?) ?? 'high',
        confidenceScore: ((json['confidenceScore'] as num?) ?? 1).toDouble(),
        lowConfidence: (json['lowConfidence'] as bool?) ?? false,
        spokenPhrase: json['spokenPhrase'] as String?,
        matchedTaskId: json['matchedTaskId'] as String?,
        estimateMinutes: (json['estimateMinutes'] as num?)?.toInt(),
        timeAnchor: json['timeAnchor'] as String?,
        proposedUpdate: json['proposedUpdate'] as String?,
        createdAt: _parseDate(json['createdAt']),
        deletedAt: _parseDate(json['deletedAt']),
      );

  final String id;
  final String title;
  final String categoryId;
  final String kind;
  final String confidence;
  final double confidenceScore;
  final bool lowConfidence;
  final String? spokenPhrase;
  final String? matchedTaskId;
  final int? estimateMinutes;
  final String? timeAnchor;
  final String? proposedUpdate;
  final DateTime? createdAt;
  final DateTime? deletedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'categoryId': categoryId,
    'kind': kind,
    'confidence': confidence,
    'confidenceScore': confidenceScore,
    'lowConfidence': lowConfidence,
    if (spokenPhrase != null) 'spokenPhrase': spokenPhrase,
    if (matchedTaskId != null) 'matchedTaskId': matchedTaskId,
    if (estimateMinutes != null) 'estimateMinutes': estimateMinutes,
    if (timeAnchor != null) 'timeAnchor': timeAnchor,
    if (proposedUpdate != null) 'proposedUpdate': proposedUpdate,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
  };
}

/// A mocked submitted Daily OS capture transcript.
class MockCapture {
  const MockCapture({
    required this.id,
    required this.transcript,
    this.capturedAt,
    this.createdAt,
    this.dayId,
    this.audioRef,
    this.deletedAt,
    this.parsedItems = const <MockParsedCaptureItem>[],
  });

  factory MockCapture.fromJson(Map<String, dynamic> json) => MockCapture(
    id: json['id'] as String,
    transcript: json['transcript'] as String,
    capturedAt: _parseDate(json['capturedAt']),
    createdAt: _parseDate(json['createdAt']),
    dayId: json['dayId'] as String?,
    audioRef: json['audioRef'] as String?,
    deletedAt: _parseDate(json['deletedAt']),
    parsedItems: ((json['parsedItems'] as List<dynamic>?) ?? const [])
        .map((e) => MockParsedCaptureItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final String id;
  final String transcript;
  final DateTime? capturedAt;
  final DateTime? createdAt;
  final String? dayId;
  final String? audioRef;
  final DateTime? deletedAt;
  final List<MockParsedCaptureItem> parsedItems;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'transcript': transcript,
    if (capturedAt != null) 'capturedAt': capturedAt!.toIso8601String(),
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (dayId != null) 'dayId': dayId,
    if (audioRef != null) 'audioRef': audioRef,
    if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
    'parsedItems': parsedItems.map((item) => item.toJson()).toList(),
  };
}

/// A mocked journal log entry linked to a task.
///
/// Task-agent wakes read these through the same `logEntries` task context that
/// production builds from linked journal text/audio entries. Use `entryType:
/// "audio"` for transcript-only recordings and `entryType: "text"` for typed
/// notes.
class MockTaskLogEntry {
  const MockTaskLogEntry({
    required this.id,
    required this.transcript,
    this.taskId,
    this.createdAt,
    this.durationMinutes = 1,
    this.entryType = 'audio',
    this.language = 'en',
  });

  factory MockTaskLogEntry.fromJson(Map<String, dynamic> json) =>
      MockTaskLogEntry(
        id: json['id'] as String,
        taskId: json['taskId'] as String?,
        transcript: json['transcript'] as String,
        createdAt: _parseDate(json['createdAt']),
        durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 1,
        entryType: (json['entryType'] as String?) ?? 'audio',
        language: (json['language'] as String?) ?? 'en',
      );

  final String id;
  final String? taskId;
  final String transcript;
  final DateTime? createdAt;
  final int durationMinutes;
  final String entryType;
  final String language;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    if (taskId != null) 'taskId': taskId,
    'transcript': transcript,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (durationMinutes != 1) 'durationMinutes': durationMinutes,
    if (entryType != 'audio') 'entryType': entryType,
    if (language != 'en') 'language': language,
  };
}

/// A category-scoped checklist correction example presented to the task agent.
///
/// This mirrors the production `ChecklistCorrectionExample` shape without
/// depending on generated app entity classes in the scenario catalog.
class MockCorrectionExample {
  const MockCorrectionExample({
    required this.before,
    required this.after,
    this.capturedAt,
  });

  factory MockCorrectionExample.fromJson(Map<String, dynamic> json) =>
      MockCorrectionExample(
        before: json['before'] as String,
        after: json['after'] as String,
        capturedAt: _parseDate(json['capturedAt']),
      );

  final String before;
  final String after;
  final DateTime? capturedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'before': before,
    'after': after,
    if (capturedAt != null) 'capturedAt': capturedAt!.toIso8601String(),
  };
}

/// A mocked category definition available to production prompt builders.
class MockCategoryDefinition {
  const MockCategoryDefinition({
    required this.id,
    required this.name,
    this.color = '#0000FF',
    this.private = false,
    this.active = true,
    this.isAvailableForDayPlan,
    this.deletedAt,
    this.correctionExamples = const <MockCorrectionExample>[],
  });

  factory MockCategoryDefinition.fromJson(Map<String, dynamic> json) =>
      MockCategoryDefinition(
        id: json['id'] as String,
        name: json['name'] as String,
        color: (json['color'] as String?) ?? '#0000FF',
        private: (json['private'] as bool?) ?? false,
        active: (json['active'] as bool?) ?? true,
        isAvailableForDayPlan: json['isAvailableForDayPlan'] as bool?,
        deletedAt: _parseDate(json['deletedAt']),
        correctionExamples:
            ((json['correctionExamples'] as List<dynamic>?) ?? const [])
                .map(
                  (e) =>
                      MockCorrectionExample.fromJson(e as Map<String, dynamic>),
                )
                .toList(),
      );

  final String id;
  final String name;
  final String color;
  final bool private;
  final bool active;
  final bool? isAvailableForDayPlan;
  final DateTime? deletedAt;
  final List<MockCorrectionExample> correctionExamples;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'color': color,
    'private': private,
    'active': active,
    if (isAvailableForDayPlan != null)
      'isAvailableForDayPlan': isAvailableForDayPlan,
    if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
    'correctionExamples': correctionExamples.map((e) => e.toJson()).toList(),
  };
}

/// A mocked label definition available to production label-context builders.
class MockLabelDefinition {
  const MockLabelDefinition({
    required this.id,
    required this.name,
    required this.color,
    this.applicableCategoryIds,
    this.deletedAt,
  });

  factory MockLabelDefinition.fromJson(Map<String, dynamic> json) =>
      MockLabelDefinition(
        id: json['id'] as String,
        name: json['name'] as String,
        color: json['color'] as String,
        applicableCategoryIds: (json['applicableCategoryIds'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
        deletedAt: _parseDate(json['deletedAt']),
      );

  final String id;
  final String name;
  final String color;
  final List<String>? applicableCategoryIds;
  final DateTime? deletedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'color': color,
    if (applicableCategoryIds != null)
      'applicableCategoryIds': applicableCategoryIds,
    if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
  };
}

/// One item in a mocked proposal set already present before the wake starts.
///
/// This is intentionally plain data rather than `ChangeItem`, so scenario JSON
/// stays independent of production entity classes.
class MockProposalItem {
  const MockProposalItem({
    required this.toolName,
    required this.args,
    required this.humanSummary,
    this.status = 'pending',
    this.groupId,
  });

  factory MockProposalItem.fromJson(Map<String, dynamic> json) =>
      MockProposalItem(
        toolName: json['toolName'] as String,
        args: (json['args'] as Map<String, dynamic>?) ?? const {},
        humanSummary: json['humanSummary'] as String,
        status: (json['status'] as String?) ?? 'pending',
        groupId: json['groupId'] as String?,
      );

  final String toolName;
  final Map<String, dynamic> args;
  final String humanSummary;
  final String status;
  final String? groupId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'toolName': toolName,
    'args': args,
    'humanSummary': humanSummary,
    'status': status,
    if (groupId != null) 'groupId': groupId,
  };
}

/// One mocked `ChangeSetEntity` row already present before the wake starts.
///
/// The task-agent workflow reads these through `ProposalLedger.pendingSets`,
/// then production `ChangeSetBuilder` may deduplicate, merge, or retire them.
class MockProposalSet {
  const MockProposalSet({
    required this.id,
    required this.items,
    this.targetId,
    this.status = 'pending',
    this.createdAt,
    this.resolvedAt,
    this.deletedAt,
  });

  factory MockProposalSet.fromJson(Map<String, dynamic> json) =>
      MockProposalSet(
        id: json['id'] as String,
        targetId: json['targetId'] as String?,
        status: (json['status'] as String?) ?? 'pending',
        items: ((json['items'] as List<dynamic>?) ?? const [])
            .map((e) => MockProposalItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: _parseDate(json['createdAt']),
        resolvedAt: _parseDate(json['resolvedAt']),
        deletedAt: _parseDate(json['deletedAt']),
      );

  final String id;
  final String? targetId;
  final String status;
  final List<MockProposalItem> items;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final DateTime? deletedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    if (targetId != null) 'targetId': targetId,
    'status': status,
    'items': items.map((i) => i.toJson()).toList(),
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (resolvedAt != null) 'resolvedAt': resolvedAt!.toIso8601String(),
    if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
  };
}

/// One mocked `ChangeDecisionEntity` row attached to a proposal item.
///
/// Production rejected-history stickiness is decision-driven: the task workflow
/// reads rejected verdicts from the proposal ledger, not from raw tool calls.
class MockProposalDecision {
  const MockProposalDecision({
    required this.id,
    required this.changeSetId,
    required this.itemIndex,
    required this.toolName,
    required this.verdict,
    this.actor = 'user',
    this.targetId,
    this.createdAt,
    this.reason,
    this.humanSummary,
    this.args = const {},
  });

  factory MockProposalDecision.fromJson(Map<String, dynamic> json) =>
      MockProposalDecision(
        id: json['id'] as String,
        changeSetId: json['changeSetId'] as String,
        itemIndex: (json['itemIndex'] as num).toInt(),
        toolName: json['toolName'] as String,
        verdict: json['verdict'] as String,
        actor: (json['actor'] as String?) ?? 'user',
        targetId: json['targetId'] as String?,
        createdAt: _parseDate(json['createdAt']),
        reason: json['reason'] as String?,
        humanSummary: json['humanSummary'] as String?,
        args: (json['args'] as Map<String, dynamic>?) ?? const {},
      );

  final String id;
  final String changeSetId;
  final int itemIndex;
  final String toolName;
  final String verdict;
  final String actor;
  final String? targetId;
  final DateTime? createdAt;
  final String? reason;
  final String? humanSummary;
  final Map<String, dynamic> args;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'changeSetId': changeSetId,
    'itemIndex': itemIndex,
    'toolName': toolName,
    'verdict': verdict,
    'actor': actor,
    if (targetId != null) 'targetId': targetId,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (reason != null) 'reason': reason,
    if (humanSummary != null) 'humanSummary': humanSummary,
    'args': args,
  };
}

/// The mocked state of the app a scenario presents to the agent.
class MockedAppState {
  const MockedAppState({
    required this.now,
    this.tasks = const <MockTask>[],
    this.captures = const <MockCapture>[],
    this.taskLogEntries = const <MockTaskLogEntry>[],
    this.existingBlocks = const <MockDayBlock>[],
    this.proposalSets = const <MockProposalSet>[],
    this.proposalDecisions = const <MockProposalDecision>[],
    this.capacityMinutes = 480,
    this.categoryIds = const <String>[],
    this.categories = const <MockCategoryDefinition>[],
    this.labels = const <MockLabelDefinition>[],
  });

  factory MockedAppState.fromJson(Map<String, dynamic> json) => MockedAppState(
    now: DateTime.parse(json['now'] as String),
    tasks: ((json['tasks'] as List<dynamic>?) ?? const [])
        .map((e) => MockTask.fromJson(e as Map<String, dynamic>))
        .toList(),
    captures: ((json['captures'] as List<dynamic>?) ?? const [])
        .map((e) => MockCapture.fromJson(e as Map<String, dynamic>))
        .toList(),
    taskLogEntries: ((json['taskLogEntries'] as List<dynamic>?) ?? const [])
        .map((e) => MockTaskLogEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
    existingBlocks: ((json['existingBlocks'] as List<dynamic>?) ?? const [])
        .map((e) => MockDayBlock.fromJson(e as Map<String, dynamic>))
        .toList(),
    proposalSets: ((json['proposalSets'] as List<dynamic>?) ?? const [])
        .map((e) => MockProposalSet.fromJson(e as Map<String, dynamic>))
        .toList(),
    proposalDecisions:
        ((json['proposalDecisions'] as List<dynamic>?) ?? const [])
            .map(
              (e) => MockProposalDecision.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
    capacityMinutes: (json['capacityMinutes'] as num?)?.toInt() ?? 480,
    categoryIds: ((json['categoryIds'] as List<dynamic>?) ?? const [])
        .map((e) => e as String)
        .toList(),
    categories: ((json['categories'] as List<dynamic>?) ?? const [])
        .map((e) => MockCategoryDefinition.fromJson(e as Map<String, dynamic>))
        .toList(),
    labels: ((json['labels'] as List<dynamic>?) ?? const [])
        .map((e) => MockLabelDefinition.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final DateTime now;
  final List<MockTask> tasks;
  final List<MockCapture> captures;
  final List<MockTaskLogEntry> taskLogEntries;
  final List<MockDayBlock> existingBlocks;
  final List<MockProposalSet> proposalSets;
  final List<MockProposalDecision> proposalDecisions;
  final int capacityMinutes;
  final List<String> categoryIds;
  final List<MockCategoryDefinition> categories;
  final List<MockLabelDefinition> labels;

  /// All task IDs known to the scenario — used to detect hallucinated refs.
  Set<String> get knownTaskIds => tasks.map((t) => t.id).toSet();

  /// Category IDs the agent is allowed to operate in.
  ///
  /// `categoryIds` stays as the explicit allowlist for existing scenarios. When
  /// a scenario provides richer category definitions without the legacy list,
  /// active non-deleted category fixture IDs become the allowlist.
  Set<String> get allowedCategoryIds {
    final explicit = categoryIds.toSet();
    if (explicit.isNotEmpty) return explicit;
    return {
      for (final category in categories)
        if (category.deletedAt == null && category.active) category.id,
    };
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'now': now.toIso8601String(),
    'tasks': tasks.map((t) => t.toJson()).toList(),
    'captures': captures.map((c) => c.toJson()).toList(),
    'taskLogEntries': taskLogEntries.map((e) => e.toJson()).toList(),
    'existingBlocks': existingBlocks.map((b) => b.toJson()).toList(),
    'proposalSets': proposalSets.map((p) => p.toJson()).toList(),
    'proposalDecisions': proposalDecisions.map((d) => d.toJson()).toList(),
    'capacityMinutes': capacityMinutes,
    'categoryIds': categoryIds,
    'categories': categories.map((c) => c.toJson()).toList(),
    'labels': labels.map((l) => l.toJson()).toList(),
  };
}

/// Scenario-specific expected durable state.
///
/// These checks are intentionally matcher-based rather than exact full-state
/// equality: multiple valid plans or proposal summaries can satisfy the same
/// user goal, while forbidden matchers still catch collateral damage.
class ExpectedDurableState {
  const ExpectedDurableState({
    this.proposalCount,
    this.plannedBlockCount,
    this.parsedCaptureItemCount,
    this.mutatedEntryCount,
    this.reportContains = const <String>{},
    this.observationContains = const <String>{},
    this.allowedMutatedEntryIds = const <String>{},
    this.requiredMutatedEntryIds = const <String>{},
    this.forbiddenMutatedEntryIds = const <String>{},
    this.requiredProposals = const <ExpectedProposalState>[],
    this.requiredProposalAnyOf = const <ExpectedProposalStateAnyOf>[],
    this.proposalCounts = const <ExpectedProposalCount>[],
    this.forbiddenProposals = const <ExpectedProposalState>[],
    this.requiredPlannedBlocks = const <ExpectedPlannedBlockState>[],
    this.requiredPlannedBlockAnyOf = const <ExpectedPlannedBlockStateAnyOf>[],
    this.plannedBlockCounts = const <ExpectedPlannedBlockCount>[],
    this.forbiddenPlannedBlocks = const <ExpectedPlannedBlockState>[],
    this.requiredParsedCaptureItems = const <ExpectedParsedCaptureState>[],
    this.requiredParsedCaptureAnyOf = const <ExpectedParsedCaptureStateAnyOf>[],
    this.parsedCaptureCounts = const <ExpectedParsedCaptureCount>[],
    this.forbiddenParsedCaptureItems = const <ExpectedParsedCaptureState>[],
  });

  factory ExpectedDurableState.fromJson(
    Map<String, dynamic> json,
  ) => ExpectedDurableState(
    proposalCount: (json['proposalCount'] as num?)?.toInt(),
    plannedBlockCount: (json['plannedBlockCount'] as num?)?.toInt(),
    parsedCaptureItemCount: (json['parsedCaptureItemCount'] as num?)?.toInt(),
    mutatedEntryCount: (json['mutatedEntryCount'] as num?)?.toInt(),
    reportContains: ((json['reportContains'] as List<dynamic>?) ?? const [])
        .map((e) => e as String)
        .toSet(),
    observationContains:
        ((json['observationContains'] as List<dynamic>?) ?? const [])
            .map((e) => e as String)
            .toSet(),
    allowedMutatedEntryIds:
        ((json['allowedMutatedEntryIds'] as List<dynamic>?) ?? const [])
            .map((e) => e as String)
            .toSet(),
    requiredMutatedEntryIds:
        ((json['requiredMutatedEntryIds'] as List<dynamic>?) ?? const [])
            .map((e) => e as String)
            .toSet(),
    forbiddenMutatedEntryIds:
        ((json['forbiddenMutatedEntryIds'] as List<dynamic>?) ?? const [])
            .map((e) => e as String)
            .toSet(),
    requiredProposals:
        ((json['requiredProposals'] as List<dynamic>?) ?? const [])
            .map(
              (e) => ExpectedProposalState.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
    requiredProposalAnyOf:
        ((json['requiredProposalAnyOf'] as List<dynamic>?) ?? const [])
            .map(
              (e) => ExpectedProposalStateAnyOf.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList(),
    proposalCounts: ((json['proposalCounts'] as List<dynamic>?) ?? const [])
        .map((e) => ExpectedProposalCount.fromJson(e as Map<String, dynamic>))
        .toList(),
    forbiddenProposals:
        ((json['forbiddenProposals'] as List<dynamic>?) ?? const [])
            .map(
              (e) => ExpectedProposalState.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
    requiredPlannedBlocks:
        ((json['requiredPlannedBlocks'] as List<dynamic>?) ?? const [])
            .map(
              (e) => ExpectedPlannedBlockState.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList(),
    requiredPlannedBlockAnyOf:
        ((json['requiredPlannedBlockAnyOf'] as List<dynamic>?) ?? const [])
            .map(
              (e) => ExpectedPlannedBlockStateAnyOf.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList(),
    plannedBlockCounts:
        ((json['plannedBlockCounts'] as List<dynamic>?) ?? const [])
            .map(
              (e) =>
                  ExpectedPlannedBlockCount.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
    forbiddenPlannedBlocks:
        ((json['forbiddenPlannedBlocks'] as List<dynamic>?) ?? const [])
            .map(
              (e) => ExpectedPlannedBlockState.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList(),
    requiredParsedCaptureItems:
        ((json['requiredParsedCaptureItems'] as List<dynamic>?) ?? const [])
            .map(
              (e) => ExpectedParsedCaptureState.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList(),
    requiredParsedCaptureAnyOf:
        ((json['requiredParsedCaptureAnyOf'] as List<dynamic>?) ?? const [])
            .map(
              (e) => ExpectedParsedCaptureStateAnyOf.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList(),
    parsedCaptureCounts:
        ((json['parsedCaptureCounts'] as List<dynamic>?) ?? const [])
            .map(
              (e) => ExpectedParsedCaptureCount.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList(),
    forbiddenParsedCaptureItems:
        ((json['forbiddenParsedCaptureItems'] as List<dynamic>?) ?? const [])
            .map(
              (e) => ExpectedParsedCaptureState.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList(),
  );

  final int? proposalCount;
  final int? plannedBlockCount;
  final int? parsedCaptureItemCount;
  final int? mutatedEntryCount;
  final Set<String> reportContains;
  final Set<String> observationContains;
  final Set<String> allowedMutatedEntryIds;
  final Set<String> requiredMutatedEntryIds;
  final Set<String> forbiddenMutatedEntryIds;
  final List<ExpectedProposalState> requiredProposals;
  final List<ExpectedProposalStateAnyOf> requiredProposalAnyOf;
  final List<ExpectedProposalCount> proposalCounts;
  final List<ExpectedProposalState> forbiddenProposals;
  final List<ExpectedPlannedBlockState> requiredPlannedBlocks;
  final List<ExpectedPlannedBlockStateAnyOf> requiredPlannedBlockAnyOf;
  final List<ExpectedPlannedBlockCount> plannedBlockCounts;
  final List<ExpectedPlannedBlockState> forbiddenPlannedBlocks;
  final List<ExpectedParsedCaptureState> requiredParsedCaptureItems;
  final List<ExpectedParsedCaptureStateAnyOf> requiredParsedCaptureAnyOf;
  final List<ExpectedParsedCaptureCount> parsedCaptureCounts;
  final List<ExpectedParsedCaptureState> forbiddenParsedCaptureItems;

  bool get isEmpty =>
      proposalCount == null &&
      plannedBlockCount == null &&
      parsedCaptureItemCount == null &&
      mutatedEntryCount == null &&
      reportContains.isEmpty &&
      observationContains.isEmpty &&
      allowedMutatedEntryIds.isEmpty &&
      requiredMutatedEntryIds.isEmpty &&
      forbiddenMutatedEntryIds.isEmpty &&
      requiredProposals.isEmpty &&
      requiredProposalAnyOf.isEmpty &&
      proposalCounts.isEmpty &&
      forbiddenProposals.isEmpty &&
      requiredPlannedBlocks.isEmpty &&
      requiredPlannedBlockAnyOf.isEmpty &&
      plannedBlockCounts.isEmpty &&
      forbiddenPlannedBlocks.isEmpty &&
      requiredParsedCaptureItems.isEmpty &&
      requiredParsedCaptureAnyOf.isEmpty &&
      parsedCaptureCounts.isEmpty &&
      forbiddenParsedCaptureItems.isEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (proposalCount != null) 'proposalCount': proposalCount,
    if (plannedBlockCount != null) 'plannedBlockCount': plannedBlockCount,
    if (parsedCaptureItemCount != null)
      'parsedCaptureItemCount': parsedCaptureItemCount,
    if (mutatedEntryCount != null) 'mutatedEntryCount': mutatedEntryCount,
    if (reportContains.isNotEmpty)
      'reportContains': reportContains.toList()..sort(),
    if (observationContains.isNotEmpty)
      'observationContains': observationContains.toList()..sort(),
    if (allowedMutatedEntryIds.isNotEmpty)
      'allowedMutatedEntryIds': allowedMutatedEntryIds.toList()..sort(),
    if (requiredMutatedEntryIds.isNotEmpty)
      'requiredMutatedEntryIds': requiredMutatedEntryIds.toList()..sort(),
    if (forbiddenMutatedEntryIds.isNotEmpty)
      'forbiddenMutatedEntryIds': forbiddenMutatedEntryIds.toList()..sort(),
    if (requiredProposals.isNotEmpty)
      'requiredProposals': requiredProposals.map((e) => e.toJson()).toList(),
    if (requiredProposalAnyOf.isNotEmpty)
      'requiredProposalAnyOf': requiredProposalAnyOf
          .map((e) => e.toJson())
          .toList(),
    if (proposalCounts.isNotEmpty)
      'proposalCounts': proposalCounts.map((e) => e.toJson()).toList(),
    if (forbiddenProposals.isNotEmpty)
      'forbiddenProposals': forbiddenProposals.map((e) => e.toJson()).toList(),
    if (requiredPlannedBlocks.isNotEmpty)
      'requiredPlannedBlocks': requiredPlannedBlocks
          .map((e) => e.toJson())
          .toList(),
    if (requiredPlannedBlockAnyOf.isNotEmpty)
      'requiredPlannedBlockAnyOf': requiredPlannedBlockAnyOf
          .map((e) => e.toJson())
          .toList(),
    if (plannedBlockCounts.isNotEmpty)
      'plannedBlockCounts': plannedBlockCounts.map((e) => e.toJson()).toList(),
    if (forbiddenPlannedBlocks.isNotEmpty)
      'forbiddenPlannedBlocks': forbiddenPlannedBlocks
          .map((e) => e.toJson())
          .toList(),
    if (requiredParsedCaptureItems.isNotEmpty)
      'requiredParsedCaptureItems': requiredParsedCaptureItems
          .map((e) => e.toJson())
          .toList(),
    if (requiredParsedCaptureAnyOf.isNotEmpty)
      'requiredParsedCaptureAnyOf': requiredParsedCaptureAnyOf
          .map((e) => e.toJson())
          .toList(),
    if (parsedCaptureCounts.isNotEmpty)
      'parsedCaptureCounts': parsedCaptureCounts
          .map((e) => e.toJson())
          .toList(),
    if (forbiddenParsedCaptureItems.isNotEmpty)
      'forbiddenParsedCaptureItems': forbiddenParsedCaptureItems
          .map((e) => e.toJson())
          .toList(),
  };
}

class ExpectedProposalStateAnyOf {
  const ExpectedProposalStateAnyOf({required this.anyOf});

  factory ExpectedProposalStateAnyOf.fromJson(Map<String, dynamic> json) =>
      ExpectedProposalStateAnyOf(
        anyOf: ((json['anyOf'] as List<dynamic>?) ?? const [])
            .map(
              (e) => ExpectedProposalState.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      );

  final List<ExpectedProposalState> anyOf;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'anyOf': anyOf.map((e) => e.toJson()).toList(),
  };
}

class ExpectedProposalCount {
  const ExpectedProposalCount({
    required this.matcher,
    this.minCount,
    this.maxCount,
    this.exactCount,
  });

  factory ExpectedProposalCount.fromJson(Map<String, dynamic> json) =>
      ExpectedProposalCount(
        matcher: ExpectedProposalState.fromJson(
          json['matcher'] as Map<String, dynamic>,
        ),
        minCount: (json['minCount'] as num?)?.toInt(),
        maxCount: (json['maxCount'] as num?)?.toInt(),
        exactCount: (json['exactCount'] as num?)?.toInt(),
      );

  final ExpectedProposalState matcher;
  final int? minCount;
  final int? maxCount;
  final int? exactCount;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'matcher': matcher.toJson(),
    if (minCount != null) 'minCount': minCount,
    if (maxCount != null) 'maxCount': maxCount,
    if (exactCount != null) 'exactCount': exactCount,
  };
}

class ExpectedProposalState {
  const ExpectedProposalState({
    this.toolName,
    this.targetId,
    this.status,
    this.changeSetStatus,
    this.argsContain = const <String, dynamic>{},
    this.humanSummaryContains = const <String>{},
  });

  factory ExpectedProposalState.fromJson(Map<String, dynamic> json) =>
      ExpectedProposalState(
        toolName: json['toolName'] as String?,
        targetId: json['targetId'] as String?,
        status: json['status'] as String?,
        changeSetStatus: json['changeSetStatus'] as String?,
        argsContain: (json['argsContain'] as Map<String, dynamic>?) ?? const {},
        humanSummaryContains:
            ((json['humanSummaryContains'] as List<dynamic>?) ?? const [])
                .map((e) => e as String)
                .toSet(),
      );

  final String? toolName;
  final String? targetId;
  final String? status;
  final String? changeSetStatus;
  final Map<String, dynamic> argsContain;
  final Set<String> humanSummaryContains;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (toolName != null) 'toolName': toolName,
    if (targetId != null) 'targetId': targetId,
    if (status != null) 'status': status,
    if (changeSetStatus != null) 'changeSetStatus': changeSetStatus,
    if (argsContain.isNotEmpty) 'argsContain': argsContain,
    if (humanSummaryContains.isNotEmpty)
      'humanSummaryContains': humanSummaryContains.toList()..sort(),
  };
}

class ExpectedPlannedBlockState {
  const ExpectedPlannedBlockState({
    this.id,
    this.taskId,
    this.categoryId,
    this.minDurationMinutes,
    this.maxDurationMinutes,
    this.startAtOrAfter,
    this.endAtOrBefore,
  });

  factory ExpectedPlannedBlockState.fromJson(Map<String, dynamic> json) =>
      ExpectedPlannedBlockState(
        id: json['id'] as String?,
        taskId: json['taskId'] as String?,
        categoryId: json['categoryId'] as String?,
        minDurationMinutes: (json['minDurationMinutes'] as num?)?.toInt(),
        maxDurationMinutes: (json['maxDurationMinutes'] as num?)?.toInt(),
        startAtOrAfter: json['startAtOrAfter'] == null
            ? null
            : DateTime.parse(json['startAtOrAfter'] as String),
        endAtOrBefore: json['endAtOrBefore'] == null
            ? null
            : DateTime.parse(json['endAtOrBefore'] as String),
      );

  final String? id;
  final String? taskId;
  final String? categoryId;
  final int? minDurationMinutes;
  final int? maxDurationMinutes;
  final DateTime? startAtOrAfter;
  final DateTime? endAtOrBefore;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (id != null) 'id': id,
    if (taskId != null) 'taskId': taskId,
    if (categoryId != null) 'categoryId': categoryId,
    if (minDurationMinutes != null) 'minDurationMinutes': minDurationMinutes,
    if (maxDurationMinutes != null) 'maxDurationMinutes': maxDurationMinutes,
    if (startAtOrAfter != null)
      'startAtOrAfter': startAtOrAfter!.toIso8601String(),
    if (endAtOrBefore != null)
      'endAtOrBefore': endAtOrBefore!.toIso8601String(),
  };
}

class ExpectedPlannedBlockStateAnyOf {
  const ExpectedPlannedBlockStateAnyOf({required this.anyOf});

  factory ExpectedPlannedBlockStateAnyOf.fromJson(Map<String, dynamic> json) =>
      ExpectedPlannedBlockStateAnyOf(
        anyOf: ((json['anyOf'] as List<dynamic>?) ?? const [])
            .map(
              (e) =>
                  ExpectedPlannedBlockState.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      );

  final List<ExpectedPlannedBlockState> anyOf;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'anyOf': anyOf.map((e) => e.toJson()).toList(),
  };
}

class ExpectedPlannedBlockCount {
  const ExpectedPlannedBlockCount({
    required this.matcher,
    this.minCount,
    this.maxCount,
    this.exactCount,
  });

  factory ExpectedPlannedBlockCount.fromJson(Map<String, dynamic> json) =>
      ExpectedPlannedBlockCount(
        matcher: ExpectedPlannedBlockState.fromJson(
          json['matcher'] as Map<String, dynamic>,
        ),
        minCount: (json['minCount'] as num?)?.toInt(),
        maxCount: (json['maxCount'] as num?)?.toInt(),
        exactCount: (json['exactCount'] as num?)?.toInt(),
      );

  final ExpectedPlannedBlockState matcher;
  final int? minCount;
  final int? maxCount;
  final int? exactCount;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'matcher': matcher.toJson(),
    if (minCount != null) 'minCount': minCount,
    if (maxCount != null) 'maxCount': maxCount,
    if (exactCount != null) 'exactCount': exactCount,
  };
}

class ExpectedParsedCaptureState {
  const ExpectedParsedCaptureState({
    this.id,
    this.captureId,
    this.kind,
    this.titleContains,
    this.categoryId,
    this.matchedTaskId,
    this.confidence,
    this.minConfidenceScore,
    this.maxConfidenceScore,
    this.lowConfidence,
  });

  factory ExpectedParsedCaptureState.fromJson(Map<String, dynamic> json) =>
      ExpectedParsedCaptureState(
        id: json['id'] as String?,
        captureId: json['captureId'] as String?,
        kind: json['kind'] as String?,
        titleContains: json['titleContains'] as String?,
        categoryId: json['categoryId'] as String?,
        matchedTaskId: json['matchedTaskId'] as String?,
        confidence: json['confidence'] as String?,
        minConfidenceScore: (json['minConfidenceScore'] as num?)?.toDouble(),
        maxConfidenceScore: (json['maxConfidenceScore'] as num?)?.toDouble(),
        lowConfidence: json['lowConfidence'] as bool?,
      );

  final String? id;
  final String? captureId;
  final String? kind;
  final String? titleContains;
  final String? categoryId;
  final String? matchedTaskId;
  final String? confidence;
  final double? minConfidenceScore;
  final double? maxConfidenceScore;
  final bool? lowConfidence;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (id != null) 'id': id,
    if (captureId != null) 'captureId': captureId,
    if (kind != null) 'kind': kind,
    if (titleContains != null) 'titleContains': titleContains,
    if (categoryId != null) 'categoryId': categoryId,
    if (matchedTaskId != null) 'matchedTaskId': matchedTaskId,
    if (confidence != null) 'confidence': confidence,
    if (minConfidenceScore != null) 'minConfidenceScore': minConfidenceScore,
    if (maxConfidenceScore != null) 'maxConfidenceScore': maxConfidenceScore,
    if (lowConfidence != null) 'lowConfidence': lowConfidence,
  };
}

class ExpectedParsedCaptureStateAnyOf {
  const ExpectedParsedCaptureStateAnyOf({required this.anyOf});

  factory ExpectedParsedCaptureStateAnyOf.fromJson(
    Map<String, dynamic> json,
  ) => ExpectedParsedCaptureStateAnyOf(
    anyOf: ((json['anyOf'] as List<dynamic>?) ?? const [])
        .map(
          (e) => ExpectedParsedCaptureState.fromJson(e as Map<String, dynamic>),
        )
        .toList(),
  );

  final List<ExpectedParsedCaptureState> anyOf;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'anyOf': anyOf.map((e) => e.toJson()).toList(),
  };
}

class ExpectedParsedCaptureCount {
  const ExpectedParsedCaptureCount({
    required this.matcher,
    this.minCount,
    this.maxCount,
    this.exactCount,
  });

  factory ExpectedParsedCaptureCount.fromJson(Map<String, dynamic> json) =>
      ExpectedParsedCaptureCount(
        matcher: ExpectedParsedCaptureState.fromJson(
          json['matcher'] as Map<String, dynamic>,
        ),
        minCount: (json['minCount'] as num?)?.toInt(),
        maxCount: (json['maxCount'] as num?)?.toInt(),
        exactCount: (json['exactCount'] as num?)?.toInt(),
      );

  final ExpectedParsedCaptureState matcher;
  final int? minCount;
  final int? maxCount;
  final int? exactCount;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'matcher': matcher.toJson(),
    if (minCount != null) 'minCount': minCount,
    if (maxCount != null) 'maxCount': maxCount,
    if (exactCount != null) 'exactCount': exactCount,
  };
}

/// A hard oracle for one wake inside a multi-wake cascade scenario.
///
/// This reuses the same raw-tool and durable-state matcher language as normal
/// scenario expectations, but scopes it to the output for one cascade wake.
class ExpectedCascadeWakeState {
  const ExpectedCascadeWakeState({
    required this.wakeIndex,
    this.maxTokenBudget,
    this.maxToolCalls,
    this.mustCallTools = const <String>{},
    this.mustNotCallTools = const <String>{},
    this.requiredToolCalls = const <ExpectedToolCallState>[],
    this.forbiddenToolCalls = const <ExpectedToolCallState>[],
    this.allowedFailedToolNames = const <String>{},
    this.maxAllowedToolResultFailures = 0,
    this.durableState = const ExpectedDurableState(),
  });

  factory ExpectedCascadeWakeState.fromJson(Map<String, dynamic> json) =>
      ExpectedCascadeWakeState(
        wakeIndex: (json['wakeIndex'] as num).toInt(),
        maxTokenBudget: (json['maxTokenBudget'] as num?)?.toInt(),
        maxToolCalls: (json['maxToolCalls'] as num?)?.toInt(),
        mustCallTools: ((json['mustCallTools'] as List<dynamic>?) ?? const [])
            .map((e) => e as String)
            .toSet(),
        mustNotCallTools:
            ((json['mustNotCallTools'] as List<dynamic>?) ?? const [])
                .map((e) => e as String)
                .toSet(),
        requiredToolCalls:
            ((json['requiredToolCalls'] as List<dynamic>?) ?? const [])
                .map(
                  (e) =>
                      ExpectedToolCallState.fromJson(e as Map<String, dynamic>),
                )
                .toList(),
        forbiddenToolCalls:
            ((json['forbiddenToolCalls'] as List<dynamic>?) ?? const [])
                .map(
                  (e) =>
                      ExpectedToolCallState.fromJson(e as Map<String, dynamic>),
                )
                .toList(),
        allowedFailedToolNames:
            ((json['allowedFailedToolNames'] as List<dynamic>?) ?? const [])
                .map((e) => e as String)
                .toSet(),
        maxAllowedToolResultFailures:
            (json['maxAllowedToolResultFailures'] as num?)?.toInt() ?? 0,
        durableState: json['durableState'] == null
            ? const ExpectedDurableState()
            : ExpectedDurableState.fromJson(
                json['durableState'] as Map<String, dynamic>,
              ),
      );

  final int wakeIndex;
  final int? maxTokenBudget;
  final int? maxToolCalls;
  final Set<String> mustCallTools;
  final Set<String> mustNotCallTools;
  final List<ExpectedToolCallState> requiredToolCalls;
  final List<ExpectedToolCallState> forbiddenToolCalls;
  final Set<String> allowedFailedToolNames;
  final int maxAllowedToolResultFailures;
  final ExpectedDurableState durableState;

  bool get hasOracle =>
      maxTokenBudget != null ||
      maxToolCalls != null ||
      mustCallTools.isNotEmpty ||
      mustNotCallTools.isNotEmpty ||
      requiredToolCalls.isNotEmpty ||
      forbiddenToolCalls.isNotEmpty ||
      allowedFailedToolNames.isNotEmpty ||
      maxAllowedToolResultFailures != 0 ||
      !durableState.isEmpty;

  EvalExpectations toExpectations() => EvalExpectations(
    maxTokenBudget: maxTokenBudget,
    maxToolCalls: maxToolCalls,
    mustCallTools: mustCallTools,
    mustNotCallTools: mustNotCallTools,
    requiredToolCalls: requiredToolCalls,
    forbiddenToolCalls: forbiddenToolCalls,
    allowedFailedToolNames: allowedFailedToolNames,
    maxAllowedToolResultFailures: maxAllowedToolResultFailures,
    durableState: durableState,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'wakeIndex': wakeIndex,
    if (maxTokenBudget != null) 'maxTokenBudget': maxTokenBudget,
    if (maxToolCalls != null) 'maxToolCalls': maxToolCalls,
    if (mustCallTools.isNotEmpty) 'mustCallTools': mustCallTools.toList(),
    if (mustNotCallTools.isNotEmpty)
      'mustNotCallTools': mustNotCallTools.toList(),
    if (requiredToolCalls.isNotEmpty)
      'requiredToolCalls': [
        for (final matcher in requiredToolCalls) matcher.toJson(),
      ],
    if (forbiddenToolCalls.isNotEmpty)
      'forbiddenToolCalls': [
        for (final matcher in forbiddenToolCalls) matcher.toJson(),
      ],
    if (allowedFailedToolNames.isNotEmpty)
      'allowedFailedToolNames': allowedFailedToolNames.toList()..sort(),
    if (maxAllowedToolResultFailures != 0)
      'maxAllowedToolResultFailures': maxAllowedToolResultFailures,
    if (!durableState.isEmpty) 'durableState': durableState.toJson(),
  };
}

/// Optional hard gates a scenario can assert at Level 1, independent of the
/// model's behaviour.
class EvalExpectations {
  const EvalExpectations({
    this.maxTokenBudget,
    this.maxToolCalls,
    this.mustCallTools = const <String>{},
    this.mustNotCallTools = const <String>{},
    this.requiredToolCalls = const <ExpectedToolCallState>[],
    this.forbiddenToolCalls = const <ExpectedToolCallState>[],
    this.allowedFailedToolNames = const <String>{},
    this.maxAllowedToolResultFailures = 0,
    this.durableState = const ExpectedDurableState(),
    this.cascadeWakes = const <ExpectedCascadeWakeState>[],
  });

  factory EvalExpectations.fromJson(Map<String, dynamic> json) =>
      EvalExpectations(
        maxTokenBudget: (json['maxTokenBudget'] as num?)?.toInt(),
        maxToolCalls: (json['maxToolCalls'] as num?)?.toInt(),
        mustCallTools: ((json['mustCallTools'] as List<dynamic>?) ?? const [])
            .map((e) => e as String)
            .toSet(),
        mustNotCallTools:
            ((json['mustNotCallTools'] as List<dynamic>?) ?? const [])
                .map((e) => e as String)
                .toSet(),
        requiredToolCalls:
            ((json['requiredToolCalls'] as List<dynamic>?) ?? const [])
                .map(
                  (e) =>
                      ExpectedToolCallState.fromJson(e as Map<String, dynamic>),
                )
                .toList(),
        forbiddenToolCalls:
            ((json['forbiddenToolCalls'] as List<dynamic>?) ?? const [])
                .map(
                  (e) =>
                      ExpectedToolCallState.fromJson(e as Map<String, dynamic>),
                )
                .toList(),
        allowedFailedToolNames:
            ((json['allowedFailedToolNames'] as List<dynamic>?) ?? const [])
                .map((e) => e as String)
                .toSet(),
        maxAllowedToolResultFailures:
            (json['maxAllowedToolResultFailures'] as num?)?.toInt() ?? 0,
        durableState: json['durableState'] == null
            ? const ExpectedDurableState()
            : ExpectedDurableState.fromJson(
                json['durableState'] as Map<String, dynamic>,
              ),
        cascadeWakes: ((json['cascadeWakes'] as List<dynamic>?) ?? const [])
            .map(
              (e) =>
                  ExpectedCascadeWakeState.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      );

  final int? maxTokenBudget;
  final int? maxToolCalls;
  final Set<String> mustCallTools;
  final Set<String> mustNotCallTools;
  final List<ExpectedToolCallState> requiredToolCalls;
  final List<ExpectedToolCallState> forbiddenToolCalls;
  final Set<String> allowedFailedToolNames;
  final int maxAllowedToolResultFailures;
  final ExpectedDurableState durableState;
  final List<ExpectedCascadeWakeState> cascadeWakes;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (maxTokenBudget != null) 'maxTokenBudget': maxTokenBudget,
    if (maxToolCalls != null) 'maxToolCalls': maxToolCalls,
    'mustCallTools': mustCallTools.toList(),
    'mustNotCallTools': mustNotCallTools.toList(),
    if (requiredToolCalls.isNotEmpty)
      'requiredToolCalls': [
        for (final matcher in requiredToolCalls) matcher.toJson(),
      ],
    if (forbiddenToolCalls.isNotEmpty)
      'forbiddenToolCalls': [
        for (final matcher in forbiddenToolCalls) matcher.toJson(),
      ],
    if (allowedFailedToolNames.isNotEmpty)
      'allowedFailedToolNames': allowedFailedToolNames.toList()..sort(),
    if (maxAllowedToolResultFailures != 0)
      'maxAllowedToolResultFailures': maxAllowedToolResultFailures,
    if (!durableState.isEmpty) 'durableState': durableState.toJson(),
    if (cascadeWakes.isNotEmpty)
      'cascadeWakes': [
        for (final wake in cascadeWakes) wake.toJson(),
      ],
  };
}

class ExpectedToolCallState {
  const ExpectedToolCallState({
    required this.toolName,
    this.argsContain = const <String, dynamic>{},
  });

  factory ExpectedToolCallState.fromJson(Map<String, dynamic> json) =>
      ExpectedToolCallState(
        toolName: json['toolName'] as String,
        argsContain: (json['argsContain'] as Map<String, dynamic>?) ?? const {},
      );

  final String toolName;
  final Map<String, dynamic> argsContain;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'toolName': toolName,
    if (argsContain.isNotEmpty) 'argsContain': argsContain,
  };
}

/// One row of the evaluation dataset: mocked state + user input + expectations.
class EvalScenario {
  const EvalScenario({
    required this.id,
    required this.title,
    required this.agentKind,
    required this.appState,
    required this.userInput,
    this.metadata = const EvalScenarioMetadata(),
    this.expectations = const EvalExpectations(),
  });

  factory EvalScenario.fromJson(Map<String, dynamic> json) => EvalScenario(
    id: json['id'] as String,
    title: json['title'] as String,
    agentKind: AgentKind.fromName(json['agentKind'] as String),
    appState: MockedAppState.fromJson(json['appState'] as Map<String, dynamic>),
    userInput: UserInput.fromJson(json['userInput'] as Map<String, dynamic>),
    metadata: json['metadata'] == null
        ? const EvalScenarioMetadata()
        : EvalScenarioMetadata.fromJson(
            json['metadata'] as Map<String, dynamic>,
          ),
    expectations: json['expectations'] == null
        ? const EvalExpectations()
        : EvalExpectations.fromJson(
            json['expectations'] as Map<String, dynamic>,
          ),
  );

  final String id;
  final String title;
  final AgentKind agentKind;
  final MockedAppState appState;
  final UserInput userInput;
  final EvalScenarioMetadata metadata;
  final EvalExpectations expectations;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'agentKind': agentKind.name,
    'appState': appState.toJson(),
    'userInput': userInput.toJson(),
    'metadata': metadata.toJson(),
    'expectations': expectations.toJson(),
  };
}

/// One tool call the agent made, with its raw arguments (keys match the real
/// tool schemas, e.g. `set_task_status` → `status`, `update_task_estimate` →
/// `minutes`, `draft_day_plan` → `blocks`).
class ToolCallRecord {
  const ToolCallRecord({required this.name, this.args = const {}});

  factory ToolCallRecord.fromJson(Map<String, dynamic> json) => ToolCallRecord(
    name: json['name'] as String,
    args: (json['args'] as Map<String, dynamic>?) ?? const {},
  );

  final String name;
  final Map<String, dynamic> args;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'args': args,
  };
}

/// One persisted tool execution result.
///
/// Raw tool calls say what the model attempted. Tool result records say what
/// production validation accepted or rejected before durable state changed.
class ToolResultRecord {
  const ToolResultRecord({
    required this.name,
    required this.success,
    this.error,
  });

  factory ToolResultRecord.fromJson(Map<String, dynamic> json) =>
      ToolResultRecord(
        name: json['name'] as String,
        success: (json['success'] as bool?) ?? true,
        error: json['error'] as String?,
      );

  final String name;
  final bool success;
  final String? error;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'success': success,
    if (error != null) 'error': error,
  };
}

/// A time block the planner drafted.
class PlannedBlockRecord {
  const PlannedBlockRecord({
    required this.id,
    required this.categoryId,
    required this.start,
    required this.end,
    this.taskId,
  });

  factory PlannedBlockRecord.fromJson(Map<String, dynamic> json) =>
      PlannedBlockRecord(
        id: json['id'] as String,
        categoryId: json['categoryId'] as String,
        start: DateTime.parse(json['start'] as String),
        end: DateTime.parse(json['end'] as String),
        taskId: json['taskId'] as String?,
      );

  final String id;
  final String categoryId;
  final DateTime start;
  final DateTime end;
  final String? taskId;

  int get durationMinutes => end.difference(start).inMinutes;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'categoryId': categoryId,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    if (taskId != null) 'taskId': taskId,
  };
}

/// One parsed capture item persisted by the planning agent.
class ParsedCaptureItemRecord {
  const ParsedCaptureItemRecord({
    required this.id,
    required this.captureId,
    required this.kind,
    required this.title,
    required this.categoryId,
    required this.confidence,
    required this.confidenceScore,
    required this.lowConfidence,
    this.spokenPhrase,
    this.matchedTaskId,
    this.estimateMinutes,
    this.timeAnchor,
    this.proposedUpdate,
  });

  factory ParsedCaptureItemRecord.fromJson(Map<String, dynamic> json) =>
      ParsedCaptureItemRecord(
        id: json['id'] as String,
        captureId: json['captureId'] as String,
        kind: json['kind'] as String,
        title: json['title'] as String,
        categoryId: json['categoryId'] as String,
        confidence: json['confidence'] as String,
        confidenceScore: (json['confidenceScore'] as num).toDouble(),
        lowConfidence: json['lowConfidence'] as bool,
        spokenPhrase: json['spokenPhrase'] as String?,
        matchedTaskId: json['matchedTaskId'] as String?,
        estimateMinutes: (json['estimateMinutes'] as num?)?.toInt(),
        timeAnchor: json['timeAnchor'] as String?,
        proposedUpdate: json['proposedUpdate'] as String?,
      );

  final String id;
  final String captureId;
  final String kind;
  final String title;
  final String categoryId;
  final String confidence;
  final double confidenceScore;
  final bool lowConfidence;
  final String? spokenPhrase;
  final String? matchedTaskId;
  final int? estimateMinutes;
  final String? timeAnchor;
  final String? proposedUpdate;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'captureId': captureId,
    'kind': kind,
    'title': title,
    'categoryId': categoryId,
    'confidence': confidence,
    'confidenceScore': confidenceScore,
    'lowConfidence': lowConfidence,
    if (spokenPhrase != null) 'spokenPhrase': spokenPhrase,
    if (matchedTaskId != null) 'matchedTaskId': matchedTaskId,
    if (estimateMinutes != null) 'estimateMinutes': estimateMinutes,
    if (timeAnchor != null) 'timeAnchor': timeAnchor,
    if (proposedUpdate != null) 'proposedUpdate': proposedUpdate,
  };
}

/// The report the task agent publishes at the end of a wake.
class AgentReportRecord {
  const AgentReportRecord({
    required this.oneLiner,
    required this.tldr,
    this.content = '',
  });

  factory AgentReportRecord.fromJson(Map<String, dynamic> json) =>
      AgentReportRecord(
        oneLiner: json['oneLiner'] as String,
        tldr: json['tldr'] as String,
        content: (json['content'] as String?) ?? '',
      );

  final String oneLiner;
  final String tldr;
  final String content;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'oneLiner': oneLiner,
    'tldr': tldr,
    'content': content,
  };
}

/// One persisted confirmable proposal item from a `ChangeSetEntity`.
///
/// Raw tool calls describe what the model attempted. Proposal records describe
/// what the app actually made durable for user confirmation after production
/// validation, deduplication, normalization, and policy checks.
class ProposalRecord {
  const ProposalRecord({
    required this.changeSetId,
    required this.changeSetStatus,
    required this.targetId,
    required this.itemIndex,
    required this.toolName,
    required this.args,
    required this.humanSummary,
    required this.status,
  });

  factory ProposalRecord.fromJson(Map<String, dynamic> json) => ProposalRecord(
    changeSetId: json['changeSetId'] as String,
    changeSetStatus: (json['changeSetStatus'] as String?) ?? 'pending',
    targetId: json['targetId'] as String,
    itemIndex: (json['itemIndex'] as num).toInt(),
    toolName: json['toolName'] as String,
    args: (json['args'] as Map<String, dynamic>?) ?? const {},
    humanSummary: json['humanSummary'] as String,
    status: json['status'] as String,
  );

  final String changeSetId;
  final String changeSetStatus;
  final String targetId;
  final int itemIndex;
  final String toolName;
  final Map<String, dynamic> args;
  final String humanSummary;
  final String status;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'changeSetId': changeSetId,
    'changeSetStatus': changeSetStatus,
    'targetId': targetId,
    'itemIndex': itemIndex,
    'toolName': toolName,
    'args': args,
    'humanSummary': humanSummary,
    'status': status,
  };
}

/// Runtime model/provider metadata resolved by the workflow for this wake.
///
/// `modelConfigId` is the saved `AiConfigModel.id` from the eval profile slot.
/// `providerModelId` is the provider-native model string actually sent to
/// `ConversationRepository.sendMessage(...)` and persisted on
/// `WakeTokenUsageEntity.modelId`.
class ResolvedModelRecord {
  const ResolvedModelRecord({
    required this.profileId,
    required this.modelConfigId,
    required this.providerModelId,
    required this.providerId,
    required this.providerType,
    this.providerEndpointOrigin,
    this.providerBaseUrlDigest,
    this.templateId,
    this.templateVersionId,
    this.wakeRunResolvedModelId,
    this.usageModelId,
  });

  factory ResolvedModelRecord.fromJson(Map<String, dynamic> json) =>
      ResolvedModelRecord(
        profileId: json['profileId'] as String,
        modelConfigId: json['modelConfigId'] as String,
        providerModelId: json['providerModelId'] as String,
        providerId: json['providerId'] as String,
        providerType: json['providerType'] as String,
        providerEndpointOrigin: json['providerEndpointOrigin'] as String?,
        providerBaseUrlDigest: json['providerBaseUrlDigest'] as String?,
        templateId: json['templateId'] as String?,
        templateVersionId: json['templateVersionId'] as String?,
        wakeRunResolvedModelId: json['wakeRunResolvedModelId'] as String?,
        usageModelId: json['usageModelId'] as String?,
      );

  final String profileId;
  final String modelConfigId;
  final String providerModelId;
  final String providerId;
  final String providerType;
  final String? providerEndpointOrigin;
  final String? providerBaseUrlDigest;
  final String? templateId;
  final String? templateVersionId;
  final String? wakeRunResolvedModelId;
  final String? usageModelId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'profileId': profileId,
    'modelConfigId': modelConfigId,
    'providerModelId': providerModelId,
    'providerId': providerId,
    'providerType': providerType,
    if (providerEndpointOrigin != null)
      'providerEndpointOrigin': providerEndpointOrigin,
    if (providerBaseUrlDigest != null)
      'providerBaseUrlDigest': providerBaseUrlDigest,
    if (templateId != null) 'templateId': templateId,
    if (templateVersionId != null) 'templateVersionId': templateVersionId,
    if (wakeRunResolvedModelId != null)
      'wakeRunResolvedModelId': wakeRunResolvedModelId,
    if (usageModelId != null) 'usageModelId': usageModelId,
  };
}

/// Profile/provider decision evidence for the wake.
///
/// This records the intended profile slot, the selected model/provider row, the
/// candidate rows seeded around it, and environment-key presence without
/// storing any secret values. `ResolvedModelRecord` proves what the workflow
/// reported at runtime; this record proves what the eval harness intended to
/// make selectable.
class ProviderDecisionRecord {
  const ProviderDecisionRecord({
    required this.profileName,
    required this.modelClass,
    required this.isLocal,
    required this.profileId,
    required this.selectedModelConfigId,
    required this.selectedProviderId,
    required this.selectedProviderType,
    required this.selectedProviderModelId,
    this.selectedProviderEndpointOrigin,
    this.selectedProviderBaseUrlDigest,
    this.candidateModelConfigIds = const <String>[],
    this.decoyModelConfigIds = const <String>[],
    this.legacyModelConfigIds = const <String>[],
    this.candidateProviderIds = const <String>[],
    this.envPresence = const <String, bool>{},
  });

  factory ProviderDecisionRecord.fromJson(Map<String, dynamic> json) =>
      ProviderDecisionRecord(
        profileName: json['profileName'] as String,
        modelClass: EvalModelClass.fromName(json['modelClass'] as String),
        isLocal: json['isLocal'] as bool,
        profileId: json['profileId'] as String,
        selectedModelConfigId: json['selectedModelConfigId'] as String,
        selectedProviderId: json['selectedProviderId'] as String,
        selectedProviderType: json['selectedProviderType'] as String,
        selectedProviderModelId: json['selectedProviderModelId'] as String,
        selectedProviderEndpointOrigin:
            json['selectedProviderEndpointOrigin'] as String?,
        selectedProviderBaseUrlDigest:
            json['selectedProviderBaseUrlDigest'] as String?,
        candidateModelConfigIds:
            ((json['candidateModelConfigIds'] as List<dynamic>?) ?? const [])
                .map((e) => e as String)
                .toList(),
        decoyModelConfigIds:
            ((json['decoyModelConfigIds'] as List<dynamic>?) ?? const [])
                .map((e) => e as String)
                .toList(),
        legacyModelConfigIds:
            ((json['legacyModelConfigIds'] as List<dynamic>?) ?? const [])
                .map((e) => e as String)
                .toList(),
        candidateProviderIds:
            ((json['candidateProviderIds'] as List<dynamic>?) ?? const [])
                .map((e) => e as String)
                .toList(),
        envPresence:
            ((json['envPresence'] as Map<String, dynamic>?) ?? const {}).map(
              (key, value) => MapEntry(key, value as bool),
            ),
      );

  final String profileName;
  final EvalModelClass modelClass;
  final bool isLocal;
  final String profileId;
  final String selectedModelConfigId;
  final String selectedProviderId;
  final String selectedProviderType;
  final String selectedProviderModelId;
  final String? selectedProviderEndpointOrigin;
  final String? selectedProviderBaseUrlDigest;
  final List<String> candidateModelConfigIds;
  final List<String> decoyModelConfigIds;
  final List<String> legacyModelConfigIds;
  final List<String> candidateProviderIds;
  final Map<String, bool> envPresence;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'profileName': profileName,
    'modelClass': modelClass.name,
    'isLocal': isLocal,
    'profileId': profileId,
    'selectedModelConfigId': selectedModelConfigId,
    'selectedProviderId': selectedProviderId,
    'selectedProviderType': selectedProviderType,
    'selectedProviderModelId': selectedProviderModelId,
    if (selectedProviderEndpointOrigin != null)
      'selectedProviderEndpointOrigin': selectedProviderEndpointOrigin,
    if (selectedProviderBaseUrlDigest != null)
      'selectedProviderBaseUrlDigest': selectedProviderBaseUrlDigest,
    'candidateModelConfigIds': candidateModelConfigIds.toList()..sort(),
    'decoyModelConfigIds': decoyModelConfigIds.toList()..sort(),
    'legacyModelConfigIds': legacyModelConfigIds.toList()..sort(),
    'candidateProviderIds': candidateProviderIds.toList()..sort(),
    'envPresence': {
      for (final key in envPresence.keys.toList()..sort())
        key: envPresence[key],
    },
  };
}

/// Run-level binding from an eval profile label to the concrete provider/model
/// execution target used for that run.
///
/// `EvalProfile` names are stable comparison slots. This record captures the
/// non-secret provider-native values behind those slots after live environment
/// overrides or scripted profile seeding have been applied.
class EvalProfileExecutionBinding {
  const EvalProfileExecutionBinding({
    required this.profileName,
    required this.modelClass,
    required this.isLocal,
    required this.profileId,
    required this.modelConfigId,
    required this.providerId,
    required this.providerType,
    required this.providerModelId,
    required this.providerEndpointOrigin,
    required this.providerBaseUrlDigest,
    required this.providerRequestTemperature,
  });

  factory EvalProfileExecutionBinding.fromJson(Map<String, dynamic> json) =>
      EvalProfileExecutionBinding(
        profileName: json['profileName'] as String,
        modelClass: EvalModelClass.fromName(json['modelClass'] as String),
        isLocal: json['isLocal'] as bool,
        profileId: json['profileId'] as String,
        modelConfigId: json['modelConfigId'] as String,
        providerId: json['providerId'] as String,
        providerType: json['providerType'] as String,
        providerModelId: json['providerModelId'] as String,
        providerEndpointOrigin:
            (json['providerEndpointOrigin'] as String?) ?? '',
        providerBaseUrlDigest: (json['providerBaseUrlDigest'] as String?) ?? '',
        providerRequestTemperature: (json['providerRequestTemperature'] as num)
            .toDouble(),
      );

  final String profileName;
  final EvalModelClass modelClass;
  final bool isLocal;
  final String profileId;
  final String modelConfigId;
  final String providerId;
  final String providerType;
  final String providerModelId;
  final String providerEndpointOrigin;
  final String providerBaseUrlDigest;
  final double providerRequestTemperature;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'profileName': profileName,
    'modelClass': modelClass.name,
    'isLocal': isLocal,
    'profileId': profileId,
    'modelConfigId': modelConfigId,
    'providerId': providerId,
    'providerType': providerType,
    'providerModelId': providerModelId,
    'providerEndpointOrigin': providerEndpointOrigin,
    'providerBaseUrlDigest': providerBaseUrlDigest,
    'providerRequestTemperature': providerRequestTemperature,
  };
}

/// Production workflow identifiers used inside the agent wake.
///
/// These differ from trace file names; recording them catches accidental
/// run/thread reuse across repeated eval trials.
class WorkflowRunRecord {
  const WorkflowRunRecord({
    required this.runKey,
    required this.threadId,
    this.matrixCellId,
  });

  factory WorkflowRunRecord.fromJson(Map<String, dynamic> json) =>
      WorkflowRunRecord(
        runKey: json['runKey'] as String,
        threadId: json['threadId'] as String,
        matrixCellId: json['matrixCellId'] as String?,
      );

  final String runKey;
  final String threadId;
  final String? matrixCellId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'runKey': runKey,
    'threadId': threadId,
    if (matrixCellId != null) 'matrixCellId': matrixCellId,
  };
}

/// Digests of the actual prompt/tool surface sent to the model.
///
/// The trace stores hashes instead of prompt text so run artifacts remain
/// compact and safer to share.
class RuntimePromptRecord {
  const RuntimePromptRecord({
    this.systemDigest,
    this.userDigest,
    this.toolSchemaDigest,
    this.toolCount = 0,
  });

  factory RuntimePromptRecord.fromJson(Map<String, dynamic> json) =>
      RuntimePromptRecord(
        systemDigest: json['systemDigest'] as String?,
        userDigest: json['userDigest'] as String?,
        toolSchemaDigest: json['toolSchemaDigest'] as String?,
        toolCount: (json['toolCount'] as num?)?.toInt() ?? 0,
      );

  final String? systemDigest;
  final String? userDigest;
  final String? toolSchemaDigest;
  final int toolCount;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (systemDigest != null) 'systemDigest': systemDigest,
    if (userDigest != null) 'userDigest': userDigest,
    if (toolSchemaDigest != null) 'toolSchemaDigest': toolSchemaDigest,
    'toolCount': toolCount,
  };
}

/// One model send attempt observed at the `ConversationRepository` seam.
///
/// This records the provider/model and prompt/tool digests for every
/// `sendMessage` call. It intentionally stores no prompt text, API keys, or
/// provider secret values.
class ModelInvocationRecord {
  const ModelInvocationRecord({
    required this.invocationIndex,
    required this.providerModelId,
    required this.providerId,
    required this.providerType,
    required this.runtimePrompt,
    this.providerEndpointOrigin,
    this.providerBaseUrlDigest,
    this.toolNames = const <String>[],
    this.forcedToolName,
  });

  factory ModelInvocationRecord.fromJson(Map<String, dynamic> json) =>
      ModelInvocationRecord(
        invocationIndex: (json['invocationIndex'] as num).toInt(),
        providerModelId: json['providerModelId'] as String,
        providerId: json['providerId'] as String,
        providerType: json['providerType'] as String,
        providerEndpointOrigin: json['providerEndpointOrigin'] as String?,
        providerBaseUrlDigest: json['providerBaseUrlDigest'] as String?,
        runtimePrompt: RuntimePromptRecord.fromJson(
          json['runtimePrompt'] as Map<String, dynamic>,
        ),
        toolNames: ((json['toolNames'] as List<dynamic>?) ?? const [])
            .map((e) => e as String)
            .toList(),
        forcedToolName: json['forcedToolName'] as String?,
      );

  final int invocationIndex;
  final String providerModelId;
  final String providerId;
  final String providerType;
  final String? providerEndpointOrigin;
  final String? providerBaseUrlDigest;
  final RuntimePromptRecord runtimePrompt;
  final List<String> toolNames;
  final String? forcedToolName;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'invocationIndex': invocationIndex,
    'providerModelId': providerModelId,
    'providerId': providerId,
    'providerType': providerType,
    if (providerEndpointOrigin != null)
      'providerEndpointOrigin': providerEndpointOrigin,
    if (providerBaseUrlDigest != null)
      'providerBaseUrlDigest': providerBaseUrlDigest,
    'runtimePrompt': runtimePrompt.toJson(),
    'toolNames': toolNames,
    if (forcedToolName != null) 'forcedToolName': forcedToolName,
  };
}

/// One provider API request observed inside a `sendMessage` invocation.
///
/// This records the concrete request loop, including continuation turns. It
/// stores only hashes, counts, model/provider ids, and tool names; it never
/// stores prompt text, tool arguments, API keys, or provider secret values.
class ProviderRequestRecord {
  const ProviderRequestRecord({
    required this.invocationIndex,
    required this.requestIndex,
    required this.turnIndex,
    required this.providerModelId,
    required this.providerId,
    required this.providerType,
    required this.messageDigest,
    required this.messageCount,
    required this.toolSchemaDigest,
    required this.toolCount,
    required this.toolNames,
    required this.temperature,
    required this.thoughtSignatureCount,
    this.providerEndpointOrigin,
    this.providerBaseUrlDigest,
    this.forcedToolName,
  });

  factory ProviderRequestRecord.fromJson(Map<String, dynamic> json) =>
      ProviderRequestRecord(
        invocationIndex: (json['invocationIndex'] as num).toInt(),
        requestIndex: (json['requestIndex'] as num).toInt(),
        turnIndex: (json['turnIndex'] as num).toInt(),
        providerModelId: json['providerModelId'] as String,
        providerId: json['providerId'] as String,
        providerType: json['providerType'] as String,
        providerEndpointOrigin: json['providerEndpointOrigin'] as String?,
        providerBaseUrlDigest: json['providerBaseUrlDigest'] as String?,
        messageDigest: json['messageDigest'] as String,
        messageCount: (json['messageCount'] as num).toInt(),
        toolSchemaDigest: json['toolSchemaDigest'] as String,
        toolCount: (json['toolCount'] as num).toInt(),
        toolNames: ((json['toolNames'] as List<dynamic>?) ?? const [])
            .map((e) => e as String)
            .toList(),
        forcedToolName: json['forcedToolName'] as String?,
        temperature: (json['temperature'] as num).toDouble(),
        thoughtSignatureCount: (json['thoughtSignatureCount'] as num).toInt(),
      );

  final int invocationIndex;
  final int requestIndex;
  final int turnIndex;
  final String providerModelId;
  final String providerId;
  final String providerType;
  final String? providerEndpointOrigin;
  final String? providerBaseUrlDigest;
  final String messageDigest;
  final int messageCount;
  final String toolSchemaDigest;
  final int toolCount;
  final List<String> toolNames;
  final String? forcedToolName;
  final double temperature;
  final int thoughtSignatureCount;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'invocationIndex': invocationIndex,
    'requestIndex': requestIndex,
    'turnIndex': turnIndex,
    'providerModelId': providerModelId,
    'providerId': providerId,
    'providerType': providerType,
    if (providerEndpointOrigin != null)
      'providerEndpointOrigin': providerEndpointOrigin,
    if (providerBaseUrlDigest != null)
      'providerBaseUrlDigest': providerBaseUrlDigest,
    'messageDigest': messageDigest,
    'messageCount': messageCount,
    'toolSchemaDigest': toolSchemaDigest,
    'toolCount': toolCount,
    'toolNames': toolNames,
    if (forcedToolName != null) 'forcedToolName': forcedToolName,
    'temperature': temperature,
    'thoughtSignatureCount': thoughtSignatureCount,
  };
}

/// Provider stream metadata observed for one provider request.
///
/// Response identity is kept separate from request identity so eval reports can
/// tell the difference between "we asked for this model" and "the provider
/// reported this model back." Lists are used because a malformed stream can
/// report inconsistent metadata across chunks; the verifier rejects that.
class ProviderResponseRecord {
  const ProviderResponseRecord({
    required this.invocationIndex,
    required this.requestIndex,
    required this.turnIndex,
    required this.providerType,
    required this.chunkCount,
    this.responseModelIds = const <String>[],
    this.systemFingerprints = const <String>[],
    this.providerNames = const <String>[],
    this.serviceTiers = const <String>[],
    this.responseModelUnavailableReason,
  });

  factory ProviderResponseRecord.fromJson(Map<String, dynamic> json) =>
      ProviderResponseRecord(
        invocationIndex: (json['invocationIndex'] as num).toInt(),
        requestIndex: (json['requestIndex'] as num).toInt(),
        turnIndex: (json['turnIndex'] as num).toInt(),
        providerType: json['providerType'] as String,
        chunkCount: (json['chunkCount'] as num?)?.toInt() ?? 0,
        responseModelIds:
            ((json['responseModelIds'] as List<dynamic>?) ?? const [])
                .map((e) => e as String)
                .toList(),
        systemFingerprints:
            ((json['systemFingerprints'] as List<dynamic>?) ?? const [])
                .map((e) => e as String)
                .toList(),
        providerNames: ((json['providerNames'] as List<dynamic>?) ?? const [])
            .map((e) => e as String)
            .toList(),
        serviceTiers: ((json['serviceTiers'] as List<dynamic>?) ?? const [])
            .map((e) => e as String)
            .toList(),
        responseModelUnavailableReason:
            json['responseModelUnavailableReason'] as String?,
      );

  final int invocationIndex;
  final int requestIndex;
  final int turnIndex;
  final String providerType;
  final int chunkCount;
  final List<String> responseModelIds;
  final List<String> systemFingerprints;
  final List<String> providerNames;
  final List<String> serviceTiers;
  final String? responseModelUnavailableReason;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'invocationIndex': invocationIndex,
    'requestIndex': requestIndex,
    'turnIndex': turnIndex,
    'providerType': providerType,
    'chunkCount': chunkCount,
    'responseModelIds': responseModelIds,
    'systemFingerprints': systemFingerprints,
    'providerNames': providerNames,
    'serviceTiers': serviceTiers,
    if (responseModelUnavailableReason != null)
      'responseModelUnavailableReason': responseModelUnavailableReason,
  };
}

/// The normalised output of one agent wake — the unit both the Level 1
/// assertions and the Claude Code judge evaluate. Produced identically by the
/// scripted and live targets.
class AgentRunOutput {
  const AgentRunOutput({
    required this.success,
    required this.usage,
    this.error,
    this.toolCalls = const <ToolCallRecord>[],
    this.toolResults = const <ToolResultRecord>[],
    this.plannedBlocks = const <PlannedBlockRecord>[],
    this.parsedCaptureItems = const <ParsedCaptureItemRecord>[],
    this.plannedCapacityMinutes,
    this.report,
    this.observations = const <String>[],
    this.proposals = const <ProposalRecord>[],
    this.resolvedModel,
    this.providerDecision,
    this.workflowRun,
    this.runtimePrompt,
    this.modelInvocations = const <ModelInvocationRecord>[],
    this.providerRequests = const <ProviderRequestRecord>[],
    this.providerResponses = const <ProviderResponseRecord>[],
    this.mutatedEntryIds = const <String>{},
    this.turnCount = 0,
    this.wallClockMs = 0,
  });

  factory AgentRunOutput.fromJson(Map<String, dynamic> json) => AgentRunOutput(
    success: json['success'] as bool,
    usage: InferenceUsage.fromJson(
      (json['usage'] as Map<String, dynamic>?) ?? const {},
    ),
    error: json['error'] as String?,
    toolCalls: ((json['toolCalls'] as List<dynamic>?) ?? const [])
        .map((e) => ToolCallRecord.fromJson(e as Map<String, dynamic>))
        .toList(),
    toolResults: ((json['toolResults'] as List<dynamic>?) ?? const [])
        .map((e) => ToolResultRecord.fromJson(e as Map<String, dynamic>))
        .toList(),
    plannedBlocks: ((json['plannedBlocks'] as List<dynamic>?) ?? const [])
        .map((e) => PlannedBlockRecord.fromJson(e as Map<String, dynamic>))
        .toList(),
    parsedCaptureItems:
        ((json['parsedCaptureItems'] as List<dynamic>?) ?? const [])
            .map(
              (e) => ParsedCaptureItemRecord.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList(),
    plannedCapacityMinutes: (json['plannedCapacityMinutes'] as num?)?.toInt(),
    report: json['report'] == null
        ? null
        : AgentReportRecord.fromJson(
            json['report'] as Map<String, dynamic>,
          ),
    observations: ((json['observations'] as List<dynamic>?) ?? const [])
        .map((e) => e as String)
        .toList(),
    proposals: ((json['proposals'] as List<dynamic>?) ?? const [])
        .map((e) => ProposalRecord.fromJson(e as Map<String, dynamic>))
        .toList(),
    resolvedModel: json['resolvedModel'] == null
        ? null
        : ResolvedModelRecord.fromJson(
            json['resolvedModel'] as Map<String, dynamic>,
          ),
    providerDecision: json['providerDecision'] == null
        ? null
        : ProviderDecisionRecord.fromJson(
            json['providerDecision'] as Map<String, dynamic>,
          ),
    workflowRun: json['workflowRun'] == null
        ? null
        : WorkflowRunRecord.fromJson(
            json['workflowRun'] as Map<String, dynamic>,
          ),
    runtimePrompt: json['runtimePrompt'] == null
        ? null
        : RuntimePromptRecord.fromJson(
            json['runtimePrompt'] as Map<String, dynamic>,
          ),
    modelInvocations: ((json['modelInvocations'] as List<dynamic>?) ?? const [])
        .map(
          (e) => ModelInvocationRecord.fromJson(
            e as Map<String, dynamic>,
          ),
        )
        .toList(),
    providerRequests: ((json['providerRequests'] as List<dynamic>?) ?? const [])
        .map(
          (e) => ProviderRequestRecord.fromJson(
            e as Map<String, dynamic>,
          ),
        )
        .toList(),
    providerResponses:
        ((json['providerResponses'] as List<dynamic>?) ?? const [])
            .map(
              (e) => ProviderResponseRecord.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList(),
    mutatedEntryIds: ((json['mutatedEntryIds'] as List<dynamic>?) ?? const [])
        .map((e) => e as String)
        .toSet(),
    turnCount: (json['turnCount'] as num?)?.toInt() ?? 0,
    wallClockMs: (json['wallClockMs'] as num?)?.toInt() ?? 0,
  );

  final bool success;
  final InferenceUsage usage;
  final String? error;
  final List<ToolCallRecord> toolCalls;
  final List<ToolResultRecord> toolResults;
  final List<PlannedBlockRecord> plannedBlocks;
  final List<ParsedCaptureItemRecord> parsedCaptureItems;
  final int? plannedCapacityMinutes;
  final AgentReportRecord? report;
  final List<String> observations;
  final List<ProposalRecord> proposals;
  final ResolvedModelRecord? resolvedModel;
  final ProviderDecisionRecord? providerDecision;
  final WorkflowRunRecord? workflowRun;
  final RuntimePromptRecord? runtimePrompt;
  final List<ModelInvocationRecord> modelInvocations;
  final List<ProviderRequestRecord> providerRequests;
  final List<ProviderResponseRecord> providerResponses;
  final Set<String> mutatedEntryIds;
  final int turnCount;
  final int wallClockMs;

  /// Names of the tools called, in order.
  List<String> get toolNames => toolCalls.map((t) => t.name).toList();

  Map<String, dynamic> toJson() => <String, dynamic>{
    'success': success,
    'usage': usage.toJson(),
    if (error != null) 'error': error,
    'toolCalls': toolCalls.map((t) => t.toJson()).toList(),
    'toolResults': toolResults.map((t) => t.toJson()).toList(),
    'plannedBlocks': plannedBlocks.map((b) => b.toJson()).toList(),
    'parsedCaptureItems': parsedCaptureItems.map((i) => i.toJson()).toList(),
    if (plannedCapacityMinutes != null)
      'plannedCapacityMinutes': plannedCapacityMinutes,
    if (report != null) 'report': report!.toJson(),
    'observations': observations,
    'proposals': proposals.map((p) => p.toJson()).toList(),
    if (resolvedModel != null) 'resolvedModel': resolvedModel!.toJson(),
    if (providerDecision != null)
      'providerDecision': providerDecision!.toJson(),
    if (workflowRun != null) 'workflowRun': workflowRun!.toJson(),
    if (runtimePrompt != null) 'runtimePrompt': runtimePrompt!.toJson(),
    'modelInvocations': modelInvocations.map((i) => i.toJson()).toList(),
    'providerRequests': providerRequests.map((r) => r.toJson()).toList(),
    'providerResponses': providerResponses.map((r) => r.toJson()).toList(),
    'mutatedEntryIds': (mutatedEntryIds.toList()..sort()),
    'turnCount': turnCount,
    'wallClockMs': wallClockMs,
  };
}

/// Prompt/directive variant for one eval matrix execution.
///
/// Profiles remain the model-class comparison unit. Directive variants are a
/// separate matrix axis so a run can compare prompt policy changes without
/// making them look like different model/provider profiles.
class EvalAgentDirectiveVariant {
  const EvalAgentDirectiveVariant({
    this.name = 'default',
    this.generalDirective = '',
    this.reportDirective = '',
  });

  factory EvalAgentDirectiveVariant.fromJson(Map<String, dynamic> json) =>
      EvalAgentDirectiveVariant(
        name: (json['name'] as String?) ?? 'default',
        generalDirective: (json['generalDirective'] as String?) ?? '',
        reportDirective: (json['reportDirective'] as String?) ?? '',
      );

  final String name;
  final String generalDirective;
  final String reportDirective;

  String get combinedDirectiveText => [generalDirective, reportDirective]
      .where((part) => part.isNotEmpty)
      .join(
        '\n\n',
      );

  bool get isDefault =>
      name == 'default' &&
      generalDirective.trim().isEmpty &&
      reportDirective.trim().isEmpty;

  String mergedGeneralDirective(String baseline) {
    final trimmedDirective = generalDirective.trim();
    if (trimmedDirective.isEmpty) return '';

    final trimmedBaseline = baseline.trim();
    if (trimmedBaseline.isEmpty) return trimmedDirective;
    return '$trimmedBaseline\n\n$trimmedDirective';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    if (generalDirective.isNotEmpty) 'generalDirective': generalDirective,
    if (reportDirective.isNotEmpty) 'reportDirective': reportDirective,
  };
}

/// A model profile to grade against: local vs frontier, with the efficiency
/// target encoded as `tokenBudget`.
///
/// Optional token cost weights are non-secret, profile-local provenance for
/// model-class comparisons. They are relative integer units, not live provider
/// prices. Leave them at the default `1` to keep legacy token-ratio promotion
/// behavior.
class EvalProfile {
  const EvalProfile({
    required this.name,
    required this.isLocal,
    required this.modelClass,
    required this.modelId,
    this.temperature = 0.7,
    this.maxCompletionTokens,
    this.tokenBudget = 1 << 30,
    this.trialCount = 1,
    this.inputTokenCostMicros = 1,
    this.outputTokenCostMicros = 1,
    this.cachedInputTokenCostMicros = 1,
    this.thoughtsTokenCostMicros = 1,
  });

  factory EvalProfile.fromJson(Map<String, dynamic> json) => EvalProfile(
    name: json['name'] as String,
    isLocal: json['isLocal'] as bool,
    modelClass: EvalModelClass.fromName(
      (json['modelClass'] as String?) ??
          ((json['isLocal'] as bool) ? 'localReasoning' : 'frontierReasoning'),
    ),
    modelId: json['modelId'] as String,
    temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
    maxCompletionTokens: (json['maxCompletionTokens'] as num?)?.toInt(),
    tokenBudget: (json['tokenBudget'] as num?)?.toInt() ?? (1 << 30),
    trialCount: (json['trialCount'] as num?)?.toInt() ?? 1,
    inputTokenCostMicros: (json['inputTokenCostMicros'] as num?)?.toInt() ?? 1,
    outputTokenCostMicros:
        (json['outputTokenCostMicros'] as num?)?.toInt() ?? 1,
    cachedInputTokenCostMicros:
        (json['cachedInputTokenCostMicros'] as num?)?.toInt() ?? 1,
    thoughtsTokenCostMicros:
        (json['thoughtsTokenCostMicros'] as num?)?.toInt() ?? 1,
  );

  final String name;
  final bool isLocal;
  final EvalModelClass modelClass;
  final String modelId;
  final double temperature;
  final int? maxCompletionTokens;
  final int tokenBudget;
  final int trialCount;
  final int inputTokenCostMicros;
  final int outputTokenCostMicros;
  final int cachedInputTokenCostMicros;
  final int thoughtsTokenCostMicros;

  bool get usesWeightedTokenCosts =>
      inputTokenCostMicros != 1 ||
      outputTokenCostMicros != 1 ||
      cachedInputTokenCostMicros != 1 ||
      thoughtsTokenCostMicros != 1;

  Map<String, int> get tokenCostWeights => <String, int>{
    'inputTokenCostMicros': inputTokenCostMicros,
    'outputTokenCostMicros': outputTokenCostMicros,
    'cachedInputTokenCostMicros': cachedInputTokenCostMicros,
    'thoughtsTokenCostMicros': thoughtsTokenCostMicros,
  };

  List<String> missingEstimatedCostFields(
    InferenceUsage usage, {
    bool requireCoreTokenCounts = false,
  }) {
    final missing = <String>[];
    if (requireCoreTokenCounts && usage.inputTokens == null) {
      missing.add('inputTokens');
    }
    if (requireCoreTokenCounts && usage.outputTokens == null) {
      missing.add('outputTokens');
    }
    if (cachedInputTokenCostMicros != inputTokenCostMicros &&
        usage.cachedInputTokens == null) {
      missing.add('cachedInputTokens');
    }
    if (thoughtsTokenCostMicros != outputTokenCostMicros &&
        usage.thoughtsTokens == null) {
      missing.add('thoughtsTokens');
    }
    return missing;
  }

  int estimatedUsageCostMicros(InferenceUsage usage) {
    final inputTokens = usage.inputTokens ?? 0;
    final cachedInputTokens = usage.cachedInputTokens ?? 0;
    final billableCachedInputTokens = cachedInputTokens > inputTokens
        ? inputTokens
        : cachedInputTokens;
    final uncachedInputTokens = inputTokens - billableCachedInputTokens;
    final billableInputTokens = uncachedInputTokens < 0
        ? 0
        : uncachedInputTokens;
    return billableInputTokens * inputTokenCostMicros +
        billableCachedInputTokens * cachedInputTokenCostMicros +
        (usage.outputTokens ?? 0) * outputTokenCostMicros +
        (usage.thoughtsTokens ?? 0) * thoughtsTokenCostMicros;
  }

  int? estimatedUsageCostMicrosOrNull(
    InferenceUsage usage, {
    bool requireCoreTokenCounts = false,
  }) {
    if (missingEstimatedCostFields(
      usage,
      requireCoreTokenCounts: requireCoreTokenCounts,
    ).isNotEmpty) {
      return null;
    }
    return estimatedUsageCostMicros(usage);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'isLocal': isLocal,
    'modelClass': modelClass.name,
    'modelId': modelId,
    'temperature': temperature,
    if (maxCompletionTokens != null) 'maxCompletionTokens': maxCompletionTokens,
    'tokenBudget': tokenBudget,
    'trialCount': trialCount,
    if (inputTokenCostMicros != 1) 'inputTokenCostMicros': inputTokenCostMicros,
    if (outputTokenCostMicros != 1)
      'outputTokenCostMicros': outputTokenCostMicros,
    if (cachedInputTokenCostMicros != 1)
      'cachedInputTokenCostMicros': cachedInputTokenCostMicros,
    if (thoughtsTokenCostMicros != 1)
      'thoughtsTokenCostMicros': thoughtsTokenCostMicros,
  };
}

/// Result of one deterministic Level 1 check.
class EvalCheck {
  const EvalCheck({
    required this.name,
    required this.passed,
    this.detail = '',
  });

  factory EvalCheck.pass(String name, [String detail = '']) =>
      EvalCheck(name: name, passed: true, detail: detail);

  factory EvalCheck.fail(String name, String detail) =>
      EvalCheck(name: name, passed: false, detail: detail);

  factory EvalCheck.fromJson(Map<String, dynamic> json) => EvalCheck(
    name: json['name'] as String,
    passed: json['passed'] as bool,
    detail: (json['detail'] as String?) ?? '',
  );

  final String name;
  final bool passed;
  final String detail;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'passed': passed,
    'detail': detail,
  };
}

/// Non-secret metadata about the judge that produced a verdict.
///
/// This keeps Level 2 scores comparable over time and makes uncalibrated or
/// profile-visible grading explicit instead of hidden in a free-form rationale.
class JudgeProvenanceRecord {
  const JudgeProvenanceRecord({
    required this.judgeName,
    required this.judgeModel,
    required this.promptDigest,
    required this.calibrationSetVersion,
    required this.profileVisible,
    required this.modelIdentityVisible,
  });

  factory JudgeProvenanceRecord.fromJson(Map<String, dynamic> json) =>
      JudgeProvenanceRecord(
        judgeName: json['judgeName'] as String,
        judgeModel: json['judgeModel'] as String,
        promptDigest: json['promptDigest'] as String,
        calibrationSetVersion: json['calibrationSetVersion'] as String,
        profileVisible: json['profileVisible'] as bool,
        modelIdentityVisible: json['modelIdentityVisible'] as bool,
      );

  final String judgeName;
  final String judgeModel;
  final String promptDigest;
  final String calibrationSetVersion;

  /// Whether the judge saw the profile/model-class context used by the
  /// efficiency rubric. This should be true for current Lotti evals.
  final bool profileVisible;

  /// Whether exact provider/model identities were visible to the judge. Raw
  /// traces expose them; blinded judge exports should set this false only when
  /// the judge did not see the private key or raw trace directory.
  final bool modelIdentityVisible;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'judgeName': judgeName,
    'judgeModel': judgeModel,
    'promptDigest': promptDigest,
    'calibrationSetVersion': calibrationSetVersion,
    'profileVisible': profileVisible,
    'modelIdentityVisible': modelIdentityVisible,
  };
}

/// Audit binding proving a raw verdict was imported from a blinded judge packet.
class BlindedVerdictImportRecord {
  const BlindedVerdictImportRecord({
    required this.blindedTraceId,
    required this.reviewPayloadDigest,
    required this.judgeManifestDigest,
    required this.privateKeyDigest,
    required this.sourceManifestDigest,
    required this.rawTraceDigest,
  });

  factory BlindedVerdictImportRecord.fromJson(Map<String, dynamic> json) {
    final rawVersion = json['schemaVersion'];
    if (rawVersion != schemaVersion) {
      throw FormatException(
        'Unsupported BlindedVerdictImportRecord schemaVersion $rawVersion '
        '(expected $schemaVersion)',
      );
    }
    return BlindedVerdictImportRecord(
      blindedTraceId: json['blindedTraceId'] as String,
      reviewPayloadDigest: json['reviewPayloadDigest'] as String,
      judgeManifestDigest: json['judgeManifestDigest'] as String,
      privateKeyDigest: json['privateKeyDigest'] as String,
      sourceManifestDigest: json['sourceManifestDigest'] as String,
      rawTraceDigest: json['rawTraceDigest'] as String,
    );
  }

  static const schemaVersion = 1;

  final String blindedTraceId;
  final String reviewPayloadDigest;
  final String judgeManifestDigest;
  final String privateKeyDigest;
  final String sourceManifestDigest;
  final String rawTraceDigest;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'kind': 'lotti.blindedTraceImport',
    'blindedTraceId': blindedTraceId,
    'reviewPayloadDigest': reviewPayloadDigest,
    'judgeManifestDigest': judgeManifestDigest,
    'privateKeyDigest': privateKeyDigest,
    'sourceManifestDigest': sourceManifestDigest,
    'rawTraceDigest': rawTraceDigest,
  };
}

/// The verdict a Claude Code judge writes back for a trace (see
/// eval/prompts/judge_system.md).
class JudgeVerdict {
  const JudgeVerdict({
    required this.goalAttainment,
    required this.quality,
    required this.efficiency,
    required this.pass,
    required this.judge,
    this.traceDigest,
    this.blindedImport,
    this.rationale = '',
    this.issues = const <String>[],
  });

  factory JudgeVerdict.fromJson(Map<String, dynamic> json) {
    final rawVersion = json['schemaVersion'];
    if (rawVersion != schemaVersion) {
      throw FormatException(
        'Unsupported JudgeVerdict schemaVersion $rawVersion '
        '(expected $schemaVersion)',
      );
    }
    return JudgeVerdict(
      goalAttainment: (json['goalAttainment'] as num).toInt(),
      quality: (json['quality'] as num).toInt(),
      efficiency: (json['efficiency'] as num).toInt(),
      pass: json['pass'] as bool,
      judge: JudgeProvenanceRecord.fromJson(
        json['judge'] as Map<String, dynamic>,
      ),
      traceDigest: json['traceDigest'] as String?,
      blindedImport: json['blindedImport'] == null
          ? null
          : BlindedVerdictImportRecord.fromJson(
              json['blindedImport'] as Map<String, dynamic>,
            ),
      rationale: (json['rationale'] as String?) ?? '',
      issues: ((json['issues'] as List<dynamic>?) ?? const [])
          .map((e) => e as String)
          .toList(),
    );
  }

  static const schemaVersion = 1;

  final int goalAttainment;
  final int quality;
  final int efficiency;
  final bool pass;
  final JudgeProvenanceRecord judge;
  final String? traceDigest;
  final BlindedVerdictImportRecord? blindedImport;
  final String rationale;
  final List<String> issues;

  JudgeVerdict withTraceDigest(String digest) => JudgeVerdict(
    goalAttainment: goalAttainment,
    quality: quality,
    efficiency: efficiency,
    pass: pass,
    judge: judge,
    traceDigest: digest,
    blindedImport: blindedImport,
    rationale: rationale,
    issues: issues,
  );

  JudgeVerdict withBlindedImport(BlindedVerdictImportRecord provenance) =>
      JudgeVerdict(
        goalAttainment: goalAttainment,
        quality: quality,
        efficiency: efficiency,
        pass: pass,
        judge: judge,
        traceDigest: traceDigest,
        blindedImport: provenance,
        rationale: rationale,
        issues: issues,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'goalAttainment': goalAttainment,
    'quality': quality,
    'efficiency': efficiency,
    'pass': pass,
    'judge': judge.toJson(),
    if (traceDigest != null) 'traceDigest': traceDigest,
    if (blindedImport != null) 'blindedImport': blindedImport!.toJson(),
    'rationale': rationale,
    'issues': issues,
  };
}

/// Non-secret identity for the scenario catalog bundle used by a run.
///
/// Protected scenario contents remain in the trace artifacts for judging, so
/// this record intentionally stores only counts, ids, and digests. It is
/// included in the run manifest to bind tuning-readiness claims to the same
/// catalog bundle that produced the traces.
class EvalScenarioCatalogEvidence {
  const EvalScenarioCatalogEvidence({
    required this.scenarioSetDigest,
    required this.publicScenarioCount,
    required this.externalScenarioCount,
    required this.protectedHoldout,
    required this.protectedScenarioIds,
    required this.protectedHoldoutScenarioIds,
    this.externalCatalogDigest,
    this.externalCatalogId,
    this.externalSourceLabel,
  });

  factory EvalScenarioCatalogEvidence.fromJson(Map<String, dynamic> json) {
    return EvalScenarioCatalogEvidence(
      scenarioSetDigest: json['scenarioSetDigest'] as String,
      publicScenarioCount: (json['publicScenarioCount'] as num).toInt(),
      externalScenarioCount: (json['externalScenarioCount'] as num).toInt(),
      externalCatalogDigest: json['externalCatalogDigest'] as String?,
      externalCatalogId: json['externalCatalogId'] as String?,
      externalSourceLabel: json['externalSourceLabel'] as String?,
      protectedHoldout: json['protectedHoldout'] as bool,
      protectedScenarioIds:
          ((json['protectedScenarioIds'] as List<dynamic>?) ?? const [])
              .map((id) => id as String)
              .toList(),
      protectedHoldoutScenarioIds:
          ((json['protectedHoldoutScenarioIds'] as List<dynamic>?) ?? const [])
              .map((id) => id as String)
              .toList(),
    );
  }

  final String scenarioSetDigest;
  final int publicScenarioCount;
  final int externalScenarioCount;
  final String? externalCatalogDigest;
  final String? externalCatalogId;
  final String? externalSourceLabel;
  final bool protectedHoldout;
  final List<String> protectedScenarioIds;
  final List<String> protectedHoldoutScenarioIds;

  bool get usesExternalCatalog => externalScenarioCount > 0;

  bool get hasProtectedHoldoutEvidence =>
      usesExternalCatalog &&
      protectedHoldout &&
      externalCatalogDigest != null &&
      protectedHoldoutScenarioIds.isNotEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'scenarioSetDigest': scenarioSetDigest,
    'publicScenarioCount': publicScenarioCount,
    'externalScenarioCount': externalScenarioCount,
    if (externalCatalogDigest != null)
      'externalCatalogDigest': externalCatalogDigest,
    if (externalCatalogId != null) 'externalCatalogId': externalCatalogId,
    if (externalSourceLabel != null) 'externalSourceLabel': externalSourceLabel,
    'protectedHoldout': protectedHoldout,
    'protectedScenarioIds': protectedScenarioIds,
    'protectedHoldoutScenarioIds': protectedHoldoutScenarioIds,
  };
}

/// Provenance captured with every trace so stale or mixed-environment runs are
/// rejected before reporting.
class EvalTraceProvenance {
  const EvalTraceProvenance({
    required this.manifestDigest,
    required this.scenarioDigest,
    required this.profileDigest,
    required this.agentDirectiveVariantDigest,
    required this.promptDigest,
    required this.toolSchemaDigest,
    required this.codeRevision,
  });

  factory EvalTraceProvenance.fromJson(Map<String, dynamic> json) =>
      EvalTraceProvenance(
        manifestDigest: json['manifestDigest'] as String,
        scenarioDigest: json['scenarioDigest'] as String,
        profileDigest: json['profileDigest'] as String,
        agentDirectiveVariantDigest:
            json['agentDirectiveVariantDigest'] as String,
        promptDigest: json['promptDigest'] as String,
        toolSchemaDigest: json['toolSchemaDigest'] as String,
        codeRevision: json['codeRevision'] as String,
      );

  final String manifestDigest;
  final String scenarioDigest;
  final String profileDigest;
  final String agentDirectiveVariantDigest;
  final String promptDigest;
  final String toolSchemaDigest;
  final String codeRevision;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'manifestDigest': manifestDigest,
    'scenarioDigest': scenarioDigest,
    'profileDigest': profileDigest,
    'agentDirectiveVariantDigest': agentDirectiveVariantDigest,
    'promptDigest': promptDigest,
    'toolSchemaDigest': toolSchemaDigest,
    'codeRevision': codeRevision,
  };
}

/// Non-secret promotion-plan artifact used to bind model-selection claims.
///
/// The final report-time plan includes [manifestDigest], but the run manifest
/// records only [EvalPromotionPlanEvidence] derived from the subject fields
/// below. That lets operators pre-register the candidate/baseline/policy before
/// live outcomes exist, then add the completed manifest digest after the run.
class EvalPromotionPlan {
  const EvalPromotionPlan({
    required this.planId,
    required this.candidateProfileName,
    required this.baselineProfileName,
    required this.scenarioSetDigest,
    required this.profileSetDigest,
    required this.policyDigest,
    this.manifestDigest,
    this.createdAt,
    this.notes,
  });

  factory EvalPromotionPlan.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'];
    if (schemaVersion != schemaVersionValue) {
      throw FormatException(
        'Unsupported EvalPromotionPlan schemaVersion $schemaVersion '
        '(expected $schemaVersionValue)',
      );
    }
    return EvalPromotionPlan(
      planId: _requiredNonEmptyString(json, 'planId'),
      candidateProfileName: _requiredNonEmptyString(
        json,
        'candidateProfileName',
      ),
      baselineProfileName: _requiredNonEmptyString(
        json,
        'baselineProfileName',
      ),
      scenarioSetDigest: _requiredDigest(json, 'scenarioSetDigest'),
      profileSetDigest: _requiredDigest(json, 'profileSetDigest'),
      policyDigest: _requiredDigest(json, 'policyDigest'),
      manifestDigest: _optionalDigest(json, 'manifestDigest'),
      createdAt: _optionalString(json, 'createdAt'),
      notes: _optionalString(json, 'notes'),
    );
  }

  static const schemaVersionValue = 1;

  final String planId;
  final String candidateProfileName;
  final String baselineProfileName;
  final String scenarioSetDigest;
  final String profileSetDigest;
  final String policyDigest;
  final String? manifestDigest;
  final String? createdAt;
  final String? notes;

  Map<String, dynamic> toSubjectJson() => <String, dynamic>{
    'schemaVersion': schemaVersionValue,
    'planId': planId,
    'candidateProfileName': candidateProfileName,
    'baselineProfileName': baselineProfileName,
    'scenarioSetDigest': scenarioSetDigest,
    'profileSetDigest': profileSetDigest,
    'policyDigest': policyDigest,
  };

  Map<String, dynamic> toJson() => <String, dynamic>{
    ...toSubjectJson(),
    if (manifestDigest != null) 'manifestDigest': manifestDigest,
    if (createdAt != null) 'createdAt': createdAt,
    if (notes != null) 'notes': notes,
  };
}

class EvalPromotionPlanEvidence {
  const EvalPromotionPlanEvidence({
    required this.planId,
    required this.candidateProfileName,
    required this.baselineProfileName,
    required this.scenarioSetDigest,
    required this.profileSetDigest,
    required this.policyDigest,
    required this.promotionPlanSubjectDigest,
  });

  factory EvalPromotionPlanEvidence.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'];
    if (schemaVersion != schemaVersionValue) {
      throw FormatException(
        'Unsupported EvalPromotionPlanEvidence schemaVersion $schemaVersion '
        '(expected $schemaVersionValue)',
      );
    }
    return EvalPromotionPlanEvidence(
      planId: _requiredNonEmptyString(json, 'planId'),
      candidateProfileName: _requiredNonEmptyString(
        json,
        'candidateProfileName',
      ),
      baselineProfileName: _requiredNonEmptyString(
        json,
        'baselineProfileName',
      ),
      scenarioSetDigest: _requiredDigest(json, 'scenarioSetDigest'),
      profileSetDigest: _requiredDigest(json, 'profileSetDigest'),
      policyDigest: _requiredDigest(json, 'policyDigest'),
      promotionPlanSubjectDigest: _requiredDigest(
        json,
        'promotionPlanSubjectDigest',
      ),
    );
  }

  static const schemaVersionValue = 1;

  final String planId;
  final String candidateProfileName;
  final String baselineProfileName;
  final String scenarioSetDigest;
  final String profileSetDigest;
  final String policyDigest;
  final String promotionPlanSubjectDigest;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersionValue,
    'planId': planId,
    'candidateProfileName': candidateProfileName,
    'baselineProfileName': baselineProfileName,
    'scenarioSetDigest': scenarioSetDigest,
    'profileSetDigest': profileSetDigest,
    'policyDigest': policyDigest,
    'promotionPlanSubjectDigest': promotionPlanSubjectDigest,
  };
}

/// One run-level manifest persisted before Level 2 traces are written.
class EvalRunManifest {
  const EvalRunManifest({
    required this.runId,
    required this.traceSchemaVersion,
    required this.targetName,
    required this.targetKind,
    required this.createdAt,
    required this.command,
    required this.scenarioSetDigest,
    required this.profileSetDigest,
    required this.profileBindingSetDigest,
    required this.profileExecutionBindings,
    required this.agentDirectiveVariantSetDigest,
    required this.agentDirectiveVariants,
    required this.promptDigest,
    required this.toolSchemaDigest,
    required this.codeRevision,
    required this.gitDirty,
    required this.envPresence,
    this.dirtyDiffDigest,
    this.scenarioCatalogEvidence,
    this.promotionPlanEvidence,
    this.manifestDigest,
  });

  factory EvalRunManifest.fromJson(Map<String, dynamic> json) {
    final rawVersion = json['schemaVersion'];
    if (rawVersion != schemaVersion) {
      throw FormatException(
        'Unsupported EvalRunManifest schemaVersion $rawVersion '
        '(expected $schemaVersion)',
      );
    }
    return EvalRunManifest(
      runId: json['runId'] as String,
      traceSchemaVersion: (json['traceSchemaVersion'] as num).toInt(),
      targetName: json['targetName'] as String,
      targetKind: json['targetKind'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      command: json['command'] as String,
      scenarioSetDigest: json['scenarioSetDigest'] as String,
      profileSetDigest: json['profileSetDigest'] as String,
      profileBindingSetDigest:
          (json['profileBindingSetDigest'] as String?) ?? '',
      profileExecutionBindings:
          ((json['profileExecutionBindings'] as List<dynamic>?) ?? const [])
              .map(
                (e) => EvalProfileExecutionBinding.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList(),
      agentDirectiveVariantSetDigest:
          json['agentDirectiveVariantSetDigest'] as String,
      agentDirectiveVariants:
          ((json['agentDirectiveVariants'] as List<dynamic>?) ?? const [])
              .map(
                (e) => EvalAgentDirectiveVariant.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList(),
      promptDigest: json['promptDigest'] as String,
      toolSchemaDigest: json['toolSchemaDigest'] as String,
      codeRevision: json['codeRevision'] as String,
      gitDirty: json['gitDirty'] as bool,
      dirtyDiffDigest: json['dirtyDiffDigest'] as String?,
      scenarioCatalogEvidence: json['scenarioCatalogEvidence'] == null
          ? null
          : EvalScenarioCatalogEvidence.fromJson(
              json['scenarioCatalogEvidence'] as Map<String, dynamic>,
            ),
      promotionPlanEvidence: json['promotionPlanEvidence'] == null
          ? null
          : EvalPromotionPlanEvidence.fromJson(
              json['promotionPlanEvidence'] as Map<String, dynamic>,
            ),
      envPresence: ((json['envPresence'] as Map<String, dynamic>?) ?? const {})
          .map((key, value) => MapEntry(key, value as bool)),
      manifestDigest: json['manifestDigest'] as String?,
    );
  }

  static const schemaVersion = 2;

  final String runId;
  final int traceSchemaVersion;
  final String targetName;
  final String targetKind;
  final DateTime createdAt;
  final String command;
  final String scenarioSetDigest;
  final String profileSetDigest;
  final String profileBindingSetDigest;
  final List<EvalProfileExecutionBinding> profileExecutionBindings;
  final String agentDirectiveVariantSetDigest;
  final List<EvalAgentDirectiveVariant> agentDirectiveVariants;
  final String promptDigest;
  final String toolSchemaDigest;
  final String codeRevision;
  final bool gitDirty;
  final String? dirtyDiffDigest;
  final Map<String, bool> envPresence;
  final EvalScenarioCatalogEvidence? scenarioCatalogEvidence;
  final EvalPromotionPlanEvidence? promotionPlanEvidence;
  final String? manifestDigest;

  EvalRunManifest withManifestDigest(String digest) => EvalRunManifest(
    runId: runId,
    traceSchemaVersion: traceSchemaVersion,
    targetName: targetName,
    targetKind: targetKind,
    createdAt: createdAt,
    command: command,
    scenarioSetDigest: scenarioSetDigest,
    profileSetDigest: profileSetDigest,
    profileBindingSetDigest: profileBindingSetDigest,
    profileExecutionBindings: profileExecutionBindings,
    agentDirectiveVariantSetDigest: agentDirectiveVariantSetDigest,
    agentDirectiveVariants: agentDirectiveVariants,
    promptDigest: promptDigest,
    toolSchemaDigest: toolSchemaDigest,
    codeRevision: codeRevision,
    gitDirty: gitDirty,
    dirtyDiffDigest: dirtyDiffDigest,
    envPresence: envPresence,
    scenarioCatalogEvidence: scenarioCatalogEvidence,
    promotionPlanEvidence: promotionPlanEvidence,
    manifestDigest: digest,
  );

  Map<String, dynamic> toJson({bool includeManifestDigest = true}) {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      if (includeManifestDigest && manifestDigest != null)
        'manifestDigest': manifestDigest,
      'runId': runId,
      'traceSchemaVersion': traceSchemaVersion,
      'targetName': targetName,
      'targetKind': targetKind,
      'createdAt': createdAt.toIso8601String(),
      'command': command,
      'scenarioSetDigest': scenarioSetDigest,
      'profileSetDigest': profileSetDigest,
      'profileBindingSetDigest': profileBindingSetDigest,
      'profileExecutionBindings': [
        for (final binding in [
          ...profileExecutionBindings,
        ]..sort((a, b) => a.profileName.compareTo(b.profileName)))
          binding.toJson(),
      ],
      'agentDirectiveVariantSetDigest': agentDirectiveVariantSetDigest,
      'agentDirectiveVariants': [
        for (final variant in [
          ...agentDirectiveVariants,
        ]..sort((a, b) => a.name.compareTo(b.name)))
          variant.toJson(),
      ],
      'promptDigest': promptDigest,
      'toolSchemaDigest': toolSchemaDigest,
      'codeRevision': codeRevision,
      'gitDirty': gitDirty,
      if (dirtyDiffDigest != null) 'dirtyDiffDigest': dirtyDiffDigest,
      if (scenarioCatalogEvidence != null)
        'scenarioCatalogEvidence': scenarioCatalogEvidence!.toJson(),
      if (promotionPlanEvidence != null)
        'promotionPlanEvidence': promotionPlanEvidence!.toJson(),
      'envPresence': {
        for (final key in envPresence.keys.toList()..sort())
          key: envPresence[key],
      },
    };
  }
}

String _requiredNonEmptyString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw FormatException('$key must be a non-empty string');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('$key must be a string');
}

String _requiredDigest(Map<String, dynamic> json, String key) {
  final value = _requiredNonEmptyString(json, key);
  if (_isDigest(value)) return value;
  throw FormatException('$key must be a sha256 digest');
}

String? _optionalDigest(Map<String, dynamic> json, String key) {
  final value = _optionalString(json, key);
  if (value == null || value.isEmpty) return null;
  if (_isDigest(value)) return value;
  throw FormatException('$key must be a sha256 digest');
}

bool _isDigest(String value) =>
    RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(value);

/// Identifies one wake inside a multi-wake cascade trace sequence.
class EvalTraceCascadeWake {
  const EvalTraceCascadeWake({
    required this.cascadeId,
    required this.wakeIndex,
    required this.wakeCount,
  });

  factory EvalTraceCascadeWake.fromJson(Map<String, dynamic> json) =>
      EvalTraceCascadeWake(
        cascadeId: _requiredNonEmptyString(json, 'cascadeId'),
        wakeIndex: (json['wakeIndex'] as num).toInt(),
        wakeCount: (json['wakeCount'] as num).toInt(),
      );

  static const taskLogCascadeId = 'task-log';

  final String cascadeId;
  final int wakeIndex;
  final int wakeCount;

  String get keySuffix => 'cascade-$cascadeId::wake-$wakeIndex-of-$wakeCount';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'cascadeId': cascadeId,
    'wakeIndex': wakeIndex,
    'wakeCount': wakeCount,
  };
}

/// The artifact persisted per `(scenario, profile)` and handed to the judge.
class EvalTrace {
  const EvalTrace({
    required this.runId,
    required this.scenario,
    required this.profile,
    this.agentDirectiveVariant = const EvalAgentDirectiveVariant(),
    required this.provenance,
    required this.output,
    this.trialIndex = 0,
    this.cascadeWake,
    this.level1Checks = const <EvalCheck>[],
    this.verdict,
  });

  factory EvalTrace.fromJson(Map<String, dynamic> json) {
    final rawVersion = json['schemaVersion'];
    if (rawVersion != schemaVersion) {
      throw FormatException(
        'Unsupported EvalTrace schemaVersion $rawVersion '
        '(expected $schemaVersion)',
      );
    }
    return EvalTrace(
      runId: json['runId'] as String,
      trialIndex: (json['trialIndex'] as num?)?.toInt() ?? 0,
      cascadeWake: json['cascadeWake'] == null
          ? null
          : EvalTraceCascadeWake.fromJson(
              json['cascadeWake'] as Map<String, dynamic>,
            ),
      scenario: EvalScenario.fromJson(json['scenario'] as Map<String, dynamic>),
      profile: EvalProfile.fromJson(json['profile'] as Map<String, dynamic>),
      agentDirectiveVariant: json['agentDirectiveVariant'] == null
          ? const EvalAgentDirectiveVariant()
          : EvalAgentDirectiveVariant.fromJson(
              json['agentDirectiveVariant'] as Map<String, dynamic>,
            ),
      provenance: EvalTraceProvenance.fromJson(
        json['provenance'] as Map<String, dynamic>,
      ),
      output: AgentRunOutput.fromJson(json['output'] as Map<String, dynamic>),
      level1Checks: ((json['level1Checks'] as List<dynamic>?) ?? const [])
          .map((e) => EvalCheck.fromJson(e as Map<String, dynamic>))
          .toList(),
      verdict: json['verdict'] == null
          ? null
          : JudgeVerdict.fromJson(json['verdict'] as Map<String, dynamic>),
    );
  }

  static const schemaVersion = 11;

  final String runId;
  final int trialIndex;
  final EvalTraceCascadeWake? cascadeWake;
  final EvalScenario scenario;
  final EvalProfile profile;
  final EvalAgentDirectiveVariant agentDirectiveVariant;
  final EvalTraceProvenance provenance;
  final AgentRunOutput output;
  final List<EvalCheck> level1Checks;
  final JudgeVerdict? verdict;

  /// Whether every Level 1 check passed.
  bool get level1Passed => level1Checks.every((c) => c.passed);

  bool get isCascadeWake => cascadeWake != null;

  EvalTrace withVerdict(JudgeVerdict v) => EvalTrace(
    runId: runId,
    scenario: scenario,
    profile: profile,
    agentDirectiveVariant: agentDirectiveVariant,
    provenance: provenance,
    output: output,
    trialIndex: trialIndex,
    cascadeWake: cascadeWake,
    level1Checks: level1Checks,
    verdict: v,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'runId': runId,
    'trialIndex': trialIndex,
    if (cascadeWake != null) 'cascadeWake': cascadeWake!.toJson(),
    'scenario': scenario.toJson(),
    'profile': profile.toJson(),
    if (!agentDirectiveVariant.isDefault)
      'agentDirectiveVariant': agentDirectiveVariant.toJson(),
    'provenance': provenance.toJson(),
    'output': output.toJson(),
    'level1Checks': level1Checks.map((c) => c.toJson()).toList(),
    if (verdict != null) 'verdict': verdict!.toJson(),
  };
}

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

/// Resolves a checklist item's current state from its ID.
///
/// Returns `null` if the item cannot be found.
typedef ChecklistItemStateResolver =
    Future<({String? title, bool? isChecked})?> Function(String itemId);

/// Resolves the set of existing checklist item titles for the target task.
///
/// Returns normalized (lowercased, trimmed) titles so that title-based
/// deduplication for `add_checklist_item` is case-insensitive.
typedef ExistingChecklistTitlesResolver = Future<Set<String>> Function();

/// Resolves a human-readable label name from its ID.
///
/// Returns `null` if the label cannot be found.
typedef LabelNameResolver = Future<String?> Function(String labelId);

/// Resolves the set of label IDs already assigned to the target task.
///
/// Used to suppress redundant label assignment proposals.
typedef ExistingLabelIdsResolver = Future<Set<String>> Function();

/// Result of adding batch items to a [ChangeSetBuilder].
class BatchAddResult {
  const BatchAddResult({
    required this.added,
    required this.skipped,
    this.redundant = 0,
    this.redundantDetails = const [],
  });

  /// Number of valid items that were added.
  final int added;

  /// Number of array elements that were skipped (not `Map<String, dynamic>`).
  final int skipped;

  /// Number of items suppressed because they propose no actual change.
  final int redundant;

  /// Human-readable descriptions of each suppressed redundant item,
  /// e.g. `'"Buy groceries" is already checked'`.
  final List<String> redundantDetails;
}

/// Accumulates deferred tool calls during an agent wake and produces a
/// [ChangeSetEntity] at the end.
///
/// Batch tools (e.g., `add_multiple_checklist_items`) are exploded into
/// individual [ChangeItem] entries so each element can be independently
/// confirmed or rejected by the user.
class ChangeSetBuilder {
  ChangeSetBuilder({
    required this.agentId,
    required this.taskId,
    required this.threadId,
    required this.runKey,
    this.checklistItemStateResolver,
    this.existingChecklistTitlesResolver,
    this.labelNameResolver,
    this.existingLabelIdsResolver,
    this.domainLogger,
  });

  /// The agent instance ID.
  final String agentId;

  /// The journal entity being modified.
  final String taskId;

  /// The conversation thread ID for the current wake.
  final String threadId;

  /// The run key for the current wake cycle.
  final String runKey;

  /// Optional resolver for checklist item state. When provided, the builder
  /// looks up the current title and checked state of checklist items that the
  /// LLM references by ID only (without including the title in the tool args).
  /// Also used to detect and suppress redundant updates.
  final ChecklistItemStateResolver? checklistItemStateResolver;

  /// Optional resolver for existing checklist item titles. When provided,
  /// `add_checklist_item` proposals are checked against existing titles
  /// (case-insensitive) and suppressed if a match is found.
  final ExistingChecklistTitlesResolver? existingChecklistTitlesResolver;

  /// Optional resolver for label names. When provided, human-readable
  /// summaries for `assign_task_label` items include the label name.
  final LabelNameResolver? labelNameResolver;

  /// Optional resolver for label IDs already assigned to the task. When
  /// provided, `assign_task_label` proposals for already-assigned labels
  /// are suppressed.
  final ExistingLabelIdsResolver? existingLabelIdsResolver;

  /// Optional domain logger for structured, PII-safe logging.
  final DomainLogger? domainLogger;

  final List<ChangeItem> _items = [];
  static const _uuid = Uuid();

  /// Lazily-resolved existing checklist titles (normalized), cached across
  /// a single batch to avoid repeated DB lookups.
  Set<String>? _cachedExistingTitles;

  /// Lazily-resolved existing label IDs, cached across a single batch.
  Set<String>? _cachedExistingLabelIds;

  /// All items accumulated so far.
  List<ChangeItem> get items => List.unmodifiable(_items);

  /// Whether any deferred items have been added.
  bool get hasItems => _items.isNotEmpty;

  /// Add a single tool call as a change item.
  ///
  /// For batch tools listed in [AgentToolRegistry.explodedBatchTools], use
  /// [addBatchItem] instead — this method does NOT auto-explode.
  ///
  /// For `add_checklist_item`, checks against existing titles and returns
  /// a redundancy detail if the title already exists. Returns `null` when
  /// the item was added successfully.
  Future<String?> addItem({
    required String toolName,
    required Map<String, dynamic> args,
    required String humanSummary,
  }) async {
    // Check for title-based redundancy on add_checklist_item.
    if (toolName == TaskAgentToolNames.addChecklistItem) {
      final existingTitles = await _resolveExistingTitles();
      final detail = _checkAddRedundancy(toolName, args, existingTitles);
      if (detail != null) return detail;

      // Track the title so subsequent addItem calls see it.
      final title = args['title'];
      if (title is String) {
        final normalized = title.trim().toLowerCase();
        if (normalized.isNotEmpty) {
          existingTitles.add(normalized);
        }
      }
    }

    _items.add(
      ChangeItem(
        toolName: toolName,
        args: args,
        humanSummary: humanSummary,
      ),
    );
    return null;
  }

  /// Explode a batch tool call into individual [ChangeItem] entries.
  ///
  /// [toolName] must be in [AgentToolRegistry.explodedBatchTools].
  /// [args] must contain the array key specified in the registry.
  ///
  /// Each array element becomes a separate item with its own human summary.
  /// The [summaryPrefix] is prepended to each element's description.
  ///
  /// Returns a [BatchAddResult] indicating how many items were added and how
  /// many were skipped (non-map elements).
  Future<BatchAddResult> addBatchItem({
    required String toolName,
    required Map<String, dynamic> args,
    required String summaryPrefix,
  }) async {
    final arrayKey = AgentToolRegistry.explodedBatchTools[toolName];
    if (arrayKey == null) {
      // Not a known batch tool — fall back to a single item.
      await addItem(
        toolName: toolName,
        args: args,
        humanSummary: '$summaryPrefix (batch)',
      );
      return const BatchAddResult(added: 1, skipped: 0);
    }

    final array = args[arrayKey];
    if (array is! List || array.isEmpty) {
      // Empty or invalid array — add as a single item.
      await addItem(
        toolName: toolName,
        args: args,
        humanSummary: '$summaryPrefix (empty)',
      );
      return const BatchAddResult(added: 0, skipped: 0);
    }

    // Derive the singular tool name by replacing 'add_multiple_' with 'add_'
    // and 'update_checklist_items' with 'update_checklist_item'.
    final singularToolName = _singularize(toolName);

    // Only resolve existing titles when this is an add-checklist batch.
    final isAddBatch = singularToolName == TaskAgentToolNames.addChecklistItem;
    final existingTitles = isAddBatch ? await _resolveExistingTitles() : null;

    // Resolve existing label IDs when this is a label-assignment batch.
    final isLabelBatch = singularToolName == TaskAgentToolNames.assignTaskLabel;
    final existingLabelIds = isLabelBatch
        ? await _resolveExistingLabelIds()
        : null;

    var added = 0;
    var skipped = 0;
    var redundant = 0;
    final redundantDetails = <String>[];
    for (final element in array) {
      if (element is Map<String, dynamic>) {
        // Check for redundant add_checklist_item proposals (title already
        // exists on the task or was already proposed in this wake).
        if (existingTitles != null) {
          final addRedundancyDetail = _checkAddRedundancy(
            singularToolName,
            element,
            existingTitles,
          );
          if (addRedundancyDetail != null) {
            redundant++;
            redundantDetails.add(addRedundancyDetail);
            continue;
          }
        }

        // Check for redundant label assignments (already on the task).
        if (existingLabelIds != null) {
          final labelRedundancyDetail = await _checkLabelRedundancy(
            element,
            existingLabelIds,
          );
          if (labelRedundancyDetail != null) {
            redundant++;
            redundantDetails.add(labelRedundancyDetail);
            continue;
          }
        }

        // Resolve state once per item to avoid redundant DB lookups and
        // duplicate error logging.
        final itemId = element['id'];
        final resolvedState = itemId is String && !isLabelBatch
            ? await _resolveState(itemId)
            : null;

        // Check for redundant update_checklist_item proposals.
        final redundancyDetail = _checkRedundancy(
          singularToolName,
          element,
          resolvedState,
        );
        if (redundancyDetail != null) {
          redundant++;
          redundantDetails.add(redundancyDetail);
          continue;
        }

        final summary = isLabelBatch
            ? await _generateLabelSummary(element)
            : _generateItemSummary(
                singularToolName,
                element,
                summaryPrefix,
                resolvedState: resolvedState,
              );
        _items.add(
          ChangeItem(
            toolName: singularToolName,
            args: element,
            humanSummary: summary,
          ),
        );

        // Track the title in the existing set so that subsequent items in
        // the same batch with the same title are caught as duplicates.
        if (existingTitles != null) {
          final title = element['title'];
          if (title is String) {
            final normalized = title.trim().toLowerCase();
            if (normalized.isNotEmpty) {
              existingTitles.add(normalized);
            }
          }
        }

        // Track the label ID so subsequent items in the same batch
        // with the same ID are caught as duplicates.
        if (existingLabelIds != null) {
          final labelId = element['id'];
          if (labelId is String) {
            existingLabelIds.add(labelId);
          }
        }
        added++;
      } else {
        skipped++;
      }
    }
    return BatchAddResult(
      added: added,
      skipped: skipped,
      redundant: redundant,
      redundantDetails: redundantDetails,
    );
  }

  /// Build and persist the [ChangeSetEntity].
  ///
  /// Items that already appear in [existingPendingSets] (matched by
  /// `toolName` + `args`) are silently dropped to avoid showing the user
  /// duplicate proposals across consecutive agent wakes. Rejected and
  /// deferred items are included in the dedup set so the agent cannot
  /// re-propose a mutation the user already rejected.
  ///
  /// [rejectedFingerprints] contains fingerprints reconstructed from
  /// persisted [ChangeDecisionEntity] records whose verdict was `rejected`.
  /// These are merged into the dedup set so that items the user rejected
  /// in a previous (now-resolved) change set are still blocked.
  ///
  /// When existing pending change sets exist, all their items are
  /// consolidated into a single set together with the new items. Any
  /// surplus sets are marked as [ChangeSetStatus.resolved] so they no
  /// longer appear in the UI or future queries.
  ///
  /// Returns `null` if no items remain after deduplication.
  Future<ChangeSetEntity?> build(
    AgentSyncService syncService, {
    List<ChangeSetEntity> existingPendingSets = const [],
    Set<String> rejectedFingerprints = const {},
  }) async {
    if (!hasItems) return null;

    // Extract all non-confirmed items from existing change sets for
    // deduplication. Rejected and deferred items must be included so the
    // agent cannot re-propose a mutation the user already rejected.
    final existingItems = existingPendingSets
        .expand(
          (cs) => cs.items.where(
            (i) => i.status != ChangeItemStatus.confirmed,
          ),
        )
        .toList();

    final deduped = _deduplicateItems(
      _items,
      existingItems,
      rejectedFingerprints: rejectedFingerprints,
    );
    if (deduped.isEmpty) return null;

    if (existingPendingSets.isNotEmpty) {
      // Consolidate: pick the newest set as the survivor, collect all
      // items from every set, append the new deduplicated items, and
      // mark all other sets as resolved so the UI shows exactly one card.
      final survivor = existingPendingSets.reduce(
        (a, b) => a.createdAt.isAfter(b.createdAt) ? a : b,
      );

      // Gather items from non-survivor sets that aren't already in the
      // survivor or in the new deduped items.
      final knownFingerprints = {
        ...survivor.items.map(ChangeItem.fingerprint),
        ...deduped.map(ChangeItem.fingerprint),
      };
      final otherItems = existingPendingSets
          .where((cs) => cs.id != survivor.id)
          .expand((cs) => cs.items)
          .where((i) => knownFingerprints.add(ChangeItem.fingerprint(i)))
          .toList();

      final merged = survivor.copyWith(
        items: [...survivor.items, ...otherItems, ...deduped],
      );
      await syncService.upsertEntity(merged);

      // Mark all non-survivor sets as resolved so they disappear from
      // pending queries and the UI.
      for (final cs in existingPendingSets) {
        if (cs.id != survivor.id) {
          await syncService.upsertEntity(
            cs.copyWith(
              status: ChangeSetStatus.resolved,
              resolvedAt: clock.now(),
            ),
          );
        }
      }

      return merged;
    }

    // No existing set — create a new one.
    final entity =
        AgentDomainEntity.changeSet(
              id: _uuid.v4(),
              agentId: agentId,
              taskId: taskId,
              threadId: threadId,
              runKey: runKey,
              status: ChangeSetStatus.pending,
              items: List.unmodifiable(deduped),
              createdAt: clock.now(),
              vectorClock: null,
            )
            as ChangeSetEntity;

    await syncService.upsertEntity(entity);
    return entity;
  }

  /// Returns items from [proposed] that do not already exist in [existing],
  /// comparing on `toolName` and `args` only (ignoring `humanSummary`).
  ///
  /// [rejectedFingerprints] are merged into the dedup set so that items
  /// rejected in previously-resolved change sets are still blocked.
  static List<ChangeItem> _deduplicateItems(
    List<ChangeItem> proposed,
    List<ChangeItem> existing, {
    Set<String> rejectedFingerprints = const {},
  }) {
    if (existing.isEmpty && rejectedFingerprints.isEmpty) return proposed;
    final existingHashes = {
      ...existing.map(ChangeItem.fingerprint),
      ...rejectedFingerprints,
    };
    return proposed
        .where((item) => !existingHashes.contains(ChangeItem.fingerprint(item)))
        .toList();
  }

  /// Convert batch tool name to a singular form for individual items.
  static String _singularize(String toolName) => switch (toolName) {
    TaskAgentToolNames.addMultipleChecklistItems =>
      TaskAgentToolNames.addChecklistItem,
    TaskAgentToolNames.updateChecklistItems =>
      TaskAgentToolNames.updateChecklistItem,
    TaskAgentToolNames.assignTaskLabels => TaskAgentToolNames.assignTaskLabel,
    _ => throw ArgumentError(
      'Unsupported batch tool for singularization: $toolName. '
      'Add an explicit mapping.',
    ),
  };

  /// Generate a human-readable summary for a single exploded item.
  ///
  /// [resolvedState] is the pre-resolved checklist item state (if available).
  /// Callers should resolve the state once and pass it here to avoid redundant
  /// DB lookups.
  String _generateItemSummary(
    String singularToolName,
    Map<String, dynamic> args,
    String prefix, {
    ({String? title, bool? isChecked})? resolvedState,
  }) {
    // For checklist items, use the title.
    final title = args['title'];
    if (title is String && title.isNotEmpty) {
      if (singularToolName.startsWith('add_')) {
        return 'Add: "$title"';
      }
      if (singularToolName.startsWith('update_')) {
        final isChecked = args['isChecked'];
        if (isChecked is bool) {
          final action = isChecked ? 'Check' : 'Uncheck';
          return '$action: "$title"';
        }
        return 'Update: "$title"';
      }
    }

    // For updates by ID only (no title in args) — use pre-resolved state.
    final id = args['id'];
    if (id is String) {
      final resolvedTitle = resolvedState?.title;
      final isChecked = args['isChecked'];
      if (isChecked is bool) {
        final action = isChecked ? 'Check off' : 'Uncheck';
        if (resolvedTitle != null) {
          return '$action: "$resolvedTitle"';
        }
        return '$action item ${_truncateId(id)}';
      }
      if (resolvedTitle != null) {
        return '$prefix: "$resolvedTitle"';
      }
      return '$prefix item ${_truncateId(id)}';
    }

    return '$prefix item';
  }

  /// Resolve a checklist item's current state via the injected resolver.
  ///
  /// Returns `null` if no resolver is set or the item cannot be found.
  Future<({String? title, bool? isChecked})?> _resolveState(
    String itemId,
  ) async {
    final resolver = checklistItemStateResolver;
    if (resolver == null) return null;
    try {
      return await resolver(itemId);
    } catch (e, s) {
      domainLogger?.error(
        LogDomains.agentWorkflow,
        'failed to resolve checklist item state for '
        '${DomainLogger.sanitizeId(itemId)}',
        error: e,
        stackTrace: s,
      );
      return null;
    }
  }

  /// Resolve existing checklist titles, initialising the cache on first call.
  ///
  /// The returned set is the canonical `_cachedExistingTitles` instance —
  /// callers may mutate it (e.g. adding titles for same-wake dedup) and the
  /// additions will be visible to subsequent calls without re-scanning.
  Future<Set<String>> _resolveExistingTitles() async {
    if (_cachedExistingTitles != null) return _cachedExistingTitles!;

    final resolver = existingChecklistTitlesResolver;
    if (resolver != null) {
      try {
        // Copy to a mutable set so callers can add in-wake titles.
        _cachedExistingTitles = {...await resolver()};
      } catch (e, s) {
        domainLogger?.error(
          LogDomains.agentWorkflow,
          'failed to resolve existing checklist titles',
          error: e,
          stackTrace: s,
        );
        _cachedExistingTitles = {};
      }
    } else {
      _cachedExistingTitles = {};
    }

    return _cachedExistingTitles!;
  }

  /// Check whether an `add_checklist_item` proposal is redundant because
  /// an item with the same title (case-insensitive) already exists on the
  /// task.
  ///
  /// Returns a human-readable detail string if redundant, or `null` if the
  /// item should be kept.
  static String? _checkAddRedundancy(
    String singularToolName,
    Map<String, dynamic> args,
    Set<String> existingTitles,
  ) {
    if (singularToolName != TaskAgentToolNames.addChecklistItem) {
      return null;
    }

    final title = args['title'];
    if (title is! String) return null;
    final normalized = title.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    if (existingTitles.contains(normalized)) {
      return '"$title" already exists on the task';
    }
    return null;
  }

  /// Check whether an `update_checklist_item` proposal is redundant.
  ///
  /// Returns a human-readable detail string if the item is redundant (should
  /// be suppressed), or `null` if the item should be kept.
  ///
  /// An update is redundant when:
  /// - The proposed `isChecked` matches the current `isChecked`, AND
  /// - No title change is proposed (or the proposed title matches current).
  ///
  /// Conservative: if the resolver is unavailable or the item is not found,
  /// the item is kept (returns `null`).
  ///
  /// [currentState] is the pre-resolved checklist item state.
  static String? _checkRedundancy(
    String singularToolName,
    Map<String, dynamic> args,
    ({String? title, bool? isChecked})? currentState,
  ) {
    if (singularToolName != TaskAgentToolNames.updateChecklistItem) {
      return null;
    }

    final itemId = args['id'];
    if (itemId is! String) return null;
    if (currentState == null) return null; // Item not found — keep it.

    final proposedIsChecked = args['isChecked'];
    final proposedTitle = args['title'];

    // Determine whether each field represents an actual change.
    final isCheckedChanging =
        proposedIsChecked is bool &&
        (currentState.isChecked == null ||
            proposedIsChecked != currentState.isChecked);

    final isTitleChanging =
        proposedTitle is String &&
        proposedTitle.isNotEmpty &&
        proposedTitle != currentState.title;

    // If either field is changing, the proposal is not redundant.
    if (isCheckedChanging || isTitleChanging) {
      return null;
    }

    // Only suppress if the proposal contains at least one valid field.
    final hasValidProposal =
        proposedIsChecked is bool ||
        (proposedTitle is String && proposedTitle.isNotEmpty);
    if (!hasValidProposal) {
      return null; // Malformed — keep it defensively.
    }

    // At this point the update is redundant.
    final displayTitle = currentState.title ?? _truncateId(itemId);
    final checkedLabel = currentState.isChecked == true
        ? 'checked'
        : 'unchecked';
    return '"$displayTitle" is already $checkedLabel';
  }

  /// Resolve existing label IDs, initialising the cache on first call.
  Future<Set<String>> _resolveExistingLabelIds() async {
    if (_cachedExistingLabelIds != null) return _cachedExistingLabelIds!;

    final resolver = existingLabelIdsResolver;
    if (resolver != null) {
      try {
        _cachedExistingLabelIds = {...await resolver()};
      } catch (e, s) {
        domainLogger?.error(
          LogDomains.agentWorkflow,
          'failed to resolve existing label IDs',
          error: e,
          stackTrace: s,
        );
        _cachedExistingLabelIds = {};
      }
    } else {
      _cachedExistingLabelIds = {};
    }

    return _cachedExistingLabelIds!;
  }

  /// Check whether an `assign_task_label` proposal is redundant because
  /// the label is already assigned to the task.
  ///
  /// Returns a human-readable detail string if redundant, or `null` if the
  /// item should be kept.
  Future<String?> _checkLabelRedundancy(
    Map<String, dynamic> args,
    Set<String> existingLabelIds,
  ) async {
    final labelId = args['id'];
    if (labelId is! String) return null;
    if (!existingLabelIds.contains(labelId)) return null;

    final labelName = await _resolveLabelName(labelId);
    final display = labelName ?? _truncateId(labelId);
    return 'Label "$display" is already assigned';
  }

  /// Generate a human-readable summary for a single exploded label item.
  Future<String> _generateLabelSummary(Map<String, dynamic> args) async {
    final labelId = args['id'];
    final confidence = args['confidence'];
    final labelName = labelId is String
        ? await _resolveLabelName(labelId)
        : null;
    final display =
        labelName ?? (labelId is String ? _truncateId(labelId) : '?');
    final confidenceSuffix = confidence is String ? ' ($confidence)' : '';
    return 'Assign label: "$display"$confidenceSuffix';
  }

  /// Resolve a label's human-readable name via the injected resolver.
  Future<String?> _resolveLabelName(String labelId) async {
    final resolver = labelNameResolver;
    if (resolver == null) return null;
    try {
      return await resolver(labelId);
    } catch (e, s) {
      domainLogger?.error(
        LogDomains.agentWorkflow,
        'failed to resolve label name for '
        '${DomainLogger.sanitizeId(labelId)}',
        error: e,
        stackTrace: s,
      );
      return null;
    }
  }

  /// Truncate a UUID to a short prefix for display as a fallback.
  static String _truncateId(String id) =>
      id.length > 8 ? '${id.substring(0, 8)}…' : id;
}

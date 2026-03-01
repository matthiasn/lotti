import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
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
typedef ChecklistItemStateResolver = Future<({String? title, bool? isChecked})?>
    Function(String itemId);

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

  /// Optional domain logger for structured, PII-safe logging.
  final DomainLogger? domainLogger;

  final List<ChangeItem> _items = [];
  static const _uuid = Uuid();

  /// All items accumulated so far.
  List<ChangeItem> get items => List.unmodifiable(_items);

  /// Whether any deferred items have been added.
  bool get hasItems => _items.isNotEmpty;

  /// Add a single tool call as a change item.
  ///
  /// For batch tools listed in [AgentToolRegistry.explodedBatchTools], use
  /// [addBatchItem] instead — this method does NOT auto-explode.
  void addItem({
    required String toolName,
    required Map<String, dynamic> args,
    required String humanSummary,
  }) {
    _items.add(
      ChangeItem(
        toolName: toolName,
        args: args,
        humanSummary: humanSummary,
      ),
    );
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
      addItem(
        toolName: toolName,
        args: args,
        humanSummary: '$summaryPrefix (batch)',
      );
      return const BatchAddResult(added: 1, skipped: 0);
    }

    final array = args[arrayKey];
    if (array is! List || array.isEmpty) {
      // Empty or invalid array — add as a single item.
      addItem(
        toolName: toolName,
        args: args,
        humanSummary: '$summaryPrefix (empty)',
      );
      return const BatchAddResult(added: 0, skipped: 0);
    }

    // Derive the singular tool name by replacing 'add_multiple_' with 'add_'
    // and 'update_checklist_items' with 'update_checklist_item'.
    final singularToolName = _singularize(toolName);

    var added = 0;
    var skipped = 0;
    var redundant = 0;
    final redundantDetails = <String>[];
    for (final element in array) {
      if (element is Map<String, dynamic>) {
        // Resolve state once per item to avoid redundant DB lookups and
        // duplicate error logging.
        final itemId = element['id'];
        final resolvedState =
            itemId is String ? await _resolveState(itemId) : null;

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

        final summary = _generateItemSummary(
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
  /// Items that already appear in [existingPendingItems] (matched by
  /// `toolName` + `args`) are silently dropped to avoid showing the user
  /// duplicate proposals across consecutive agent wakes.
  ///
  /// Returns `null` if no items remain after deduplication.
  Future<ChangeSetEntity?> build(
    AgentSyncService syncService, {
    List<ChangeItem> existingPendingItems = const [],
  }) async {
    if (!hasItems) return null;

    final deduped = _deduplicateItems(_items, existingPendingItems);
    if (deduped.isEmpty) return null;

    final entity = AgentDomainEntity.changeSet(
      id: _uuid.v4(),
      agentId: agentId,
      taskId: taskId,
      threadId: threadId,
      runKey: runKey,
      status: ChangeSetStatus.pending,
      items: List.unmodifiable(deduped),
      createdAt: clock.now(),
      vectorClock: null,
    ) as ChangeSetEntity;

    await syncService.upsertEntity(entity);
    return entity;
  }

  static const _deepEquals = DeepCollectionEquality();

  /// Returns items from [proposed] that do not already exist in [existing],
  /// comparing on `toolName` and `args` only (ignoring `humanSummary`).
  static List<ChangeItem> _deduplicateItems(
    List<ChangeItem> proposed,
    List<ChangeItem> existing,
  ) {
    if (existing.isEmpty) return proposed;
    final existingHashes = existing
        .map((e) => '${e.toolName}:${_deepEquals.hash(e.args)}')
        .toSet();
    return proposed
        .where(
          (item) => !existingHashes
              .contains('${item.toolName}:${_deepEquals.hash(item.args)}'),
        )
        .toList();
  }

  /// Convert batch tool name to a singular form for individual items.
  static String _singularize(String toolName) => switch (toolName) {
        TaskAgentToolNames.addMultipleChecklistItems =>
          TaskAgentToolNames.addChecklistItem,
        TaskAgentToolNames.updateChecklistItems =>
          TaskAgentToolNames.updateChecklistItem,
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

    // If isChecked is not being changed, check title.
    final isCheckedRedundant = proposedIsChecked is bool &&
        currentState.isChecked != null &&
        proposedIsChecked == currentState.isChecked;

    final hasTitleChange = proposedTitle is String &&
        proposedTitle.isNotEmpty &&
        proposedTitle != currentState.title;

    // If the proposal only changes isChecked (no title) and it's redundant,
    // suppress it.
    if (proposedIsChecked is bool && !isCheckedRedundant) {
      return null; // Actual change — keep it.
    }

    if (proposedIsChecked is! bool && proposedTitle is! String) {
      return null; // No meaningful fields — keep it (defensive).
    }

    if (hasTitleChange) {
      return null; // Title is changing — keep it.
    }

    // At this point the update is redundant.
    final displayTitle = currentState.title ?? _truncateId(itemId);
    final checkedLabel =
        currentState.isChecked == true ? 'checked' : 'unchecked';
    return '"$displayTitle" is already $checkedLabel';
  }

  /// Truncate a UUID to a short prefix for display as a fallback.
  static String _truncateId(String id) =>
      id.length > 8 ? '${id.substring(0, 8)}…' : id;
}

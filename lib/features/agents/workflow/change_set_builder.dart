import 'package:clock/clock.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:uuid/uuid.dart';

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
  });

  /// The agent instance ID.
  final String agentId;

  /// The journal entity being modified.
  final String taskId;

  /// The conversation thread ID for the current wake.
  final String threadId;

  /// The run key for the current wake cycle.
  final String runKey;

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
  void addBatchItem({
    required String toolName,
    required Map<String, dynamic> args,
    required String summaryPrefix,
  }) {
    final arrayKey = AgentToolRegistry.explodedBatchTools[toolName];
    if (arrayKey == null) {
      // Not a known batch tool — fall back to a single item.
      addItem(
        toolName: toolName,
        args: args,
        humanSummary: '$summaryPrefix (batch)',
      );
      return;
    }

    final array = args[arrayKey];
    if (array is! List || array.isEmpty) {
      // Empty or invalid array — add as a single item.
      addItem(
        toolName: toolName,
        args: args,
        humanSummary: '$summaryPrefix (empty)',
      );
      return;
    }

    // Derive the singular tool name by replacing 'add_multiple_' with 'add_'
    // and 'update_checklist_items' with 'update_checklist_item'.
    final singularToolName = _singularize(toolName);

    for (final element in array) {
      if (element is Map<String, dynamic>) {
        final summary = _generateItemSummary(
          singularToolName,
          element,
          summaryPrefix,
        );
        _items.add(
          ChangeItem(
            toolName: singularToolName,
            args: element,
            humanSummary: summary,
          ),
        );
      }
    }
  }

  /// Build and persist the [ChangeSetEntity].
  ///
  /// Returns `null` if no items have been accumulated.
  Future<ChangeSetEntity?> build(AgentSyncService syncService) async {
    if (!hasItems) return null;

    final entity = AgentDomainEntity.changeSet(
      id: _uuid.v4(),
      agentId: agentId,
      taskId: taskId,
      threadId: threadId,
      runKey: runKey,
      status: ChangeSetStatus.pending,
      items: List.unmodifiable(_items),
      createdAt: clock.now(),
      vectorClock: null,
    ) as ChangeSetEntity;

    await syncService.upsertEntity(entity);
    return entity;
  }

  /// Convert batch tool name to a singular form for individual items.
  static String _singularize(String toolName) {
    if (toolName == 'add_multiple_checklist_items') {
      return 'add_checklist_item';
    }
    if (toolName == 'update_checklist_items') {
      return 'update_checklist_item';
    }
    // Generic fallback: drop trailing 's'.
    if (toolName.endsWith('s')) {
      return toolName.substring(0, toolName.length - 1);
    }
    return toolName;
  }

  /// Generate a human-readable summary for a single exploded item.
  static String _generateItemSummary(
    String singularToolName,
    Map<String, dynamic> args,
    String prefix,
  ) {
    // For checklist items, use the title.
    final title = args['title'];
    if (title is String && title.isNotEmpty) {
      if (singularToolName.startsWith('add_')) {
        return 'Add: "$title"';
      }
      if (singularToolName.startsWith('update_')) {
        final id = args['id'] ?? '';
        final isChecked = args['isChecked'];
        if (isChecked != null) {
          final action = isChecked == true ? 'Check' : 'Uncheck';
          return '$action: "$title"';
        }
        return 'Update "$title" ($id)';
      }
    }

    // For updates by ID only (no title change).
    final id = args['id'];
    if (id is String) {
      final isChecked = args['isChecked'];
      if (isChecked != null) {
        final action = isChecked == true ? 'Check off' : 'Uncheck';
        return '$action item $id';
      }
    }

    return '$prefix item';
  }
}

import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/task_link_tool_definitions.dart';
import 'package:lotti/features/tasks/model/directed_relation.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';

/// Applies a confirmed `link_task` proposal: records one typed relationship
/// between the current task and an existing target task.
///
/// The relation reads with the current task as its subject ("This task
/// blocks …"); [DirectedRelation.canonicalEndpoints] resolves which side is
/// stored as `fromId`, so a `blocks` link's `fromId` is always the blocker
/// regardless of which phrasing the user spoke. Exactly one edge is written
/// per relationship (ADR 0042 decision 2).
class TaskLinkHandler {
  TaskLinkHandler({
    required this._persistenceLogic,
    required this._journalDb,
    this._domainLogger,
  });

  final PersistenceLogic _persistenceLogic;
  final JournalDb _journalDb;
  final DomainLogger? _domainLogger;

  static const _sub = 'TaskLinkHandler';

  /// Creates the typed link between [sourceTaskId] (the anchor) and the
  /// target task named in [args].
  ///
  /// Returns a [ToolExecutionResult] with `mutatedEntityId` set to the target
  /// task's id when an edge was written. An already-existing identical
  /// relationship reports success without writing, so confirming a proposal
  /// that raced a manual link never surfaces as a failure.
  Future<ToolExecutionResult> handle(
    String sourceTaskId,
    Map<String, dynamic> args,
  ) async {
    final rawRelation = args['relation'];
    final relation = rawRelation is String
        ? DirectedRelation.fromWireName(rawRelation)
        : null;
    if (relation == null) {
      return ToolExecutionResult(
        success: false,
        output:
            'Error: "relation" must be one of '
            '${taskRelationWireNames.join(', ')}',
        errorMessage: 'Invalid relation',
      );
    }

    final rawTargetId = args['targetTaskId'];
    final targetTaskId = rawTargetId is String ? rawTargetId.trim() : '';
    if (targetTaskId.isEmpty) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: "targetTaskId" must be a non-empty string',
        errorMessage: 'Missing targetTaskId',
      );
    }
    if (targetTaskId == sourceTaskId) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: a task cannot be linked to itself',
        errorMessage: 'Self-link rejected',
      );
    }

    final target = await _journalDb.journalEntityById(targetTaskId);
    if (target is! Task || target.meta.deletedAt != null) {
      return ToolExecutionResult(
        success: false,
        output: 'Error: target task $targetTaskId not found or not a Task',
        errorMessage: 'Target task lookup failed',
      );
    }

    final endpoints = relation.canonicalEndpoints(
      anchorId: sourceTaskId,
      otherId: targetTaskId,
    );
    final phrase = relation.englishPhrase;
    final summary = 'this task $phrase "${target.data.title}"';

    if (await _linkExists(relation, endpoints)) {
      return ToolExecutionResult(
        success: true,
        output: 'Already linked: $summary — nothing to change',
      );
    }

    final created = await _persistenceLogic.createLink(
      fromId: endpoints.fromId,
      toId: endpoints.toId,
      linkType: relation.type,
    );

    if (!created) {
      // createLink also returns false for a duplicate row, and another
      // device or a manual link can write the same edge between the
      // precheck and the insert. Recheck before naming a cause: a lost
      // race means the requested relationship now exists — success, not a
      // cycle error that would leave a dead retry.
      if (await _linkExists(relation, endpoints)) {
        return ToolExecutionResult(
          success: true,
          output: 'Already linked: $summary — nothing to change',
        );
      }

      // Not a duplicate, so a refused `blocks` edge is the creation-time
      // cycle guard (ADR 0042 §5) speaking.
      final reason = relation.type == EntryLinkType.blocks
          ? 'the link would create a blocking cycle'
          : 'the link could not be created';
      _domainLogger?.log(
        LogDomain.agentWorkflow,
        'createLink refused ${relation.wireName} '
        '${DomainLogger.sanitizeId(endpoints.fromId)} → '
        '${DomainLogger.sanitizeId(endpoints.toId)}',
        subDomain: _sub,
      );
      return ToolExecutionResult(
        success: false,
        output: 'Error: $reason',
        errorMessage: reason,
      );
    }

    return ToolExecutionResult(
      success: true,
      output: 'Linked: $summary',
      mutatedEntityId: targetTaskId,
    );
  }

  /// Whether a live link with the same canonical `(fromId, toId, type)`
  /// triple already exists.
  ///
  /// A symmetric `relates_to` matches **either** row orientation: a plain
  /// link means the same thing read from both ends, but the schema's
  /// `UNIQUE(from_id, to_id, type)` is directional, so without this the
  /// reverse of an existing plain link would be written as a second row —
  /// two linked-task entries for one relationship.
  Future<bool> _linkExists(
    DirectedRelation relation,
    ({String fromId, String toId}) endpoints,
  ) async {
    try {
      final existing = await _journalDb.typedLinksForTaskIds(
        {endpoints.fromId},
        types: {entryLinkTypeDbName(relation.type)},
      );
      return existing.any((link) {
        if (link.deletedAt != null || link.hidden == true) return false;
        final direct =
            link.fromId == endpoints.fromId && link.toId == endpoints.toId;
        final reverse =
            relation.isSymmetric &&
            link.fromId == endpoints.toId &&
            link.toId == endpoints.fromId;
        return direct || reverse;
      });
    } catch (e) {
      _domainLogger?.error(
        LogDomain.agentWorkflow,
        e,
        message: 'Existing-link precheck failed; falling through to create',
        subDomain: _sub,
      );
      // Conservative: let createLink's own duplicate guard decide.
      return false;
    }
  }
}

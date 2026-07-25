import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/link_created_feedback.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/relationship_type_selector.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/task_search_picker_body.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Modal for searching and selecting a task to link to the current task, with
/// a relationship-type + direction picker (defaults to a plain "Link", today's
/// behavior, unchanged when untouched).
///
/// Shows a relationship picker plus a search field and list of candidate
/// tasks. Excludes the current task, and any task that already holds the
/// relationship currently selected — but not tasks linked by some *other*
/// relationship, which remain valid candidates.
class LinkTaskModal extends ConsumerStatefulWidget {
  const LinkTaskModal({
    required this.currentTaskId,
    required this.existingRelations,
    super.key,
  });

  /// The ID of the current task (to exclude from results).
  final String currentTaskId;

  /// Relationships the current task already holds, so the candidate list can
  /// exclude only the ones that would duplicate the selected relation.
  final Set<ExistingRelation> existingRelations;

  /// Shows the modal and returns the selected task, or null if cancelled.
  static Future<Task?> show({
    required BuildContext context,
    required String currentTaskId,
    required Set<ExistingRelation> existingRelations,
  }) {
    return ModalUtils.showSinglePageModal<Task>(
      context: context,
      title: context.messages.linkExistingTaskTitle,
      padding: EdgeInsets.zero,
      builder: (_) => LinkTaskModal(
        currentTaskId: currentTaskId,
        existingRelations: existingRelations,
      ),
    );
  }

  @override
  ConsumerState<LinkTaskModal> createState() => _LinkTaskModalState();
}

class _LinkTaskModalState extends ConsumerState<LinkTaskModal> {
  DirectedRelation _relation = const DirectedRelation(EntryLinkType.basic);

  /// A link has already been committed by this sheet.
  ///
  /// The sheet commits at most one: it pops on success, and the
  /// post-dismissal create path must not add a second edge (and a second
  /// confirmation) for a task the user has already moved on from. The picker
  /// makes creation exclusive so this cannot normally be reached; it is the
  /// backstop that keeps the invariant true regardless.
  bool _linkCommitted = false;

  Future<void> _selectTask(Task task) =>
      _commitLink(task, _captureCommitDeps());

  /// Everything committing a link needs that lives on the widget tree.
  ///
  /// Captured before any await, because the sheet can be dismissed while the
  /// write is in flight — and a link the user asked for must still land, and
  /// still be undoable, when it does.
  _LinkCommitDeps _captureCommitDeps() => _LinkCommitDeps(
    relation: _relation,
    messenger: ScaffoldMessenger.of(context),
    repository: ref.read(journalRepositoryProvider),
    messages: context.messages,
    phrase: directedRelationLabel(context, _relation),
  );

  /// Writes exactly one edge for [task] under [deps]' relation, confirms it,
  /// and pops if this sheet is still mounted.
  ///
  /// Every message goes through [deps] rather than `context`, so the whole
  /// path is valid after dismissal; `mounted` gates only the pop, which is
  /// the one step that genuinely needs a live route.
  Future<void> _commitLink(Task task, _LinkCommitDeps deps) async {
    final swap = deps.relation.inverse;
    final fromId = swap ? task.meta.id : widget.currentTaskId;
    final toId = swap ? widget.currentTaskId : task.meta.id;

    final created = await getIt<PersistenceLogic>().createLink(
      fromId: fromId,
      toId: toId,
      linkType: deps.relation.type,
    );

    if (!created) {
      // Only a blocking link can fail the cycle guard. Reporting a cycle for
      // a "Relates to" or "Duplicates" pick named a cause that cannot apply
      // and a remedy — choose a different task — that would not help.
      showLinkFailureMessage(
        messenger: deps.messenger,
        message: deps.relation.type == EntryLinkType.blocks
            ? deps.messages.linkBlocksCycleErrorMessage
            : deps.messages.linkCreateFailedMessage,
      );
      return;
    }

    _linkCommitted = true;
    await HapticFeedback.mediumImpact();

    showLinkCreatedFeedback(
      messages: deps.messages,
      phrase: deps.phrase,
      messenger: deps.messenger,
      repository: deps.repository,
      relation: deps.relation,
      fromId: fromId,
      toId: toId,
      linkedTaskTitle: task.data.title,
    );
    if (mounted) Navigator.of(context).pop(task);
  }

  /// Creates the task a search miss described, ready to be linked.
  ///
  /// No `linkedId`: that would write a plain link the caller would then have
  /// to unpick whenever a typed relation was chosen — the dance the card's
  /// overflow flow has to do because it creates before it knows the relation.
  /// Here the relation is already selected above the search field, so the
  /// task is created bare and [_selectTask] writes exactly one edge.
  /// `inheritContextFrom` still carries the anchor's project *and privacy*
  /// across, which `linkedId` would otherwise have been doing; without it the
  /// new task is missing from that project's lists and rollups, and a task
  /// created from inside a private task's picker persists as public.
  ///
  /// The category is likewise inherited from the task being linked from: a
  /// task created from inside another task's link picker belongs with it, and
  /// leaving it uncategorized would drop it out of every category-scoped
  /// view the parent appears in.
  Future<Task?> _createTask(String title) async {
    final entryState = ref.read(entryControllerProvider(widget.currentTaskId));
    // Read before the await. Persistence can outlive the sheet — dismissing
    // it mid-write disposes this state — and a post-gap `ref` read throws,
    // which would strand a task that had already been written.
    final agentService = ref.read(taskAgentServiceProvider);
    final deps = _captureCommitDeps();

    final created = await createTask(
      title: title,
      categoryId: entryState.value?.entry?.meta.categoryId,
      inheritContextFrom: widget.currentTaskId,
    );
    if (created == null) return null;

    // Same follow-up the card's create flow performs, so a task created here
    // is not left behind on category-agent assignment. The `With` variant
    // takes the pre-captured service rather than a WidgetRef.
    unawaited(autoAssignCategoryAgentWith(agentService, created));

    if (mounted) return created;

    // Dismissed while the write was in flight. The task exists and the user
    // asked for it to be linked; returning null here would leave it created,
    // unlinked and unannounced — visible only as a stray row in the task
    // list. Commit the link on the captured dependencies instead, so the
    // confirmation and its Undo still arrive.
    //
    // Unless this sheet already linked something: then the dismissal was the
    // pop that followed that link, not an abandonment, and a second edge here
    // would be one the user never asked for.
    if (_linkCommitted) return null;
    await _commitLink(created, deps);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    // The relation panel expands inline rather than over its host, so it adds
    // its full height to this sheet. Bounded at the measure the picker already
    // uses, the open panel takes its space from the result list instead of
    // pushing the sheet to the full height of the screen. It does not stop the
    // sheet resizing altogether — only an overlay-rendered panel would, which
    // is a change to the shared dropdown rather than to this modal.
    final maxHeight = math
        .min(MediaQuery.sizeOf(context).height * 0.9, 640)
        .toDouble();

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.step5,
              tokens.spacing.step5,
              tokens.spacing.step5,
              // Matches the container inset: the gap between the two fields
              // was tighter than the gap around them.
              tokens.spacing.step5,
            ),
            child: RelationshipTypeSelector(
              selected: _relation,
              onChanged: (relation) => setState(() => _relation = relation),
            ),
          ),
          Flexible(
            child: TaskSearchPickerBody(
              topInset: false,
              excludeIds: {
                widget.currentTaskId,
                // Only the tasks that already hold *this* relation — a pair may
                // legitimately hold several different ones.
                for (final existing in widget.existingRelations)
                  if (existing.relation == _relation) existing.taskId,
              },
              onTaskSelected: _selectTask,
              onCreateTask: _createTask,
            ),
          ),
        ],
      ),
    );
  }
}

/// The tree-bound dependencies of a link commit, captured before any await.
///
/// Exists so [_LinkTaskModalState._commitLink] can run to completion after the
/// sheet that started it is gone: a create can outlive its picker, and a link
/// the user asked for should not be lost to the dismissal that raced it.
class _LinkCommitDeps {
  const _LinkCommitDeps({
    required this.relation,
    required this.messenger,
    required this.repository,
    required this.messages,
    required this.phrase,
  });

  final DirectedRelation relation;
  final ScaffoldMessengerState messenger;
  final JournalRepository repository;
  final AppLocalizations messages;

  /// The relation's localized phrase, resolved while a context still existed.
  final String phrase;
}

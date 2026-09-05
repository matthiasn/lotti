import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/project_recommendation_service.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/tools/project_tool_definitions.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/tldr_section_part.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_inline_action.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/state/project_detail_record_provider.dart';
import 'package:lotti/features/projects/ui/widgets/next_steps/project_next_step_row.dart';
import 'package:lotti/features/projects/ui/widgets/next_steps/project_next_steps_model.dart';
import 'package:lotti/features/projects/ui/widgets/next_steps/project_next_steps_summary.dart';
import 'package:lotti/features/projects/ui/widgets/next_steps/project_proposal_row.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The action bands inside the project AI card: the newest run's
/// **recommended next steps** and the agent's **proposed changes**, each under
/// its own heading because they ask different questions — advice the user
/// may turn into a task, versus a mutation the user authorises.
///
/// Every decision leaves its row in place with a tag; nothing is removed on
/// tap and nothing on the page is invalidated by hand. The service notifies
/// the agent's update stream, the snapshot provider re-reads, and the row
/// changes state where it stands. A run whose every step was already decided
/// when the page opened collapses to a one-line summary with a history
/// disclosure; decisions made while the page is open stay inline.
class ProjectRecommendationsPanel extends ConsumerStatefulWidget {
  const ProjectRecommendationsPanel({
    required this.projectId,
    this.enabled = true,
    this.onOpenTask,
    this.onTaskCreated,
    super.key,
  });

  /// How long an added step keeps its Undo before the creation is final.
  static const Duration undoWindow = Duration(seconds: 8);

  /// Steps a phone shows before "Show N more".
  static const int phoneStepCap = 3;

  final String projectId;

  /// `false` disables every control while the page runs a mutation of its
  /// own; the bands stay mounted so no decision state is lost.
  final bool enabled;

  /// Called with the task id when the "Added → title" link is tapped; the
  /// page brings that task into view in the list below.
  final ValueChanged<String>? onOpenTask;

  /// Called with the task id right after a step created it, so the page can
  /// mark the new row in the list without moving the band.
  final ValueChanged<String>? onTaskCreated;

  @override
  ConsumerState<ProjectRecommendationsPanel> createState() =>
      _ProjectRecommendationsPanelState();
}

class _ProjectRecommendationsPanelState
    extends ConsumerState<ProjectRecommendationsPanel> {
  final _busySteps = <String>{};

  /// Steps whose last attempt failed: whether a retry can help, and the
  /// message to show when it cannot (the step was consumed and a task may
  /// need cleaning up).
  final _failures = <String, ({bool retryable, String? message})>{};

  /// Row states the user just produced, shown until the snapshot catches up
  /// so a decided row never flickers back through "pending".
  final _optimistic = <String, ProjectNextStepRowState>{};
  final _undoDeadlines = <String, DateTime>{};
  final _undoTimers = <String, Timer>{};

  /// Task ids created this session, so "Open task" works before the snapshot
  /// carries the id.
  final _createdTasks = <String, String>{};
  final _busyProposals = <String>{};

  /// Proposals decided this session, kept visible with their tag after the
  /// pending read stops returning their change set.
  final _decidedProposals = <String, (ChangeSetEntity, int)>{};

  bool _showAllSteps = false;
  bool _bulkBusy = false;
  bool _historyOpen = false;

  /// The run the collapse decision below was made for, and the decision.
  bool _collapseDecided = false;
  DateTime? _collapseRun;
  bool _collapsed = false;

  @override
  void dispose() {
    for (final timer in _undoTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  DateTime get _now => ref.read(projectDetailNowProvider)();

  // ---------------------------------------------------------------- steps --

  ProjectNextStepRowState _rowState(ProjectRecommendationEntity step) {
    if (_busySteps.contains(step.id)) return ProjectNextStepRowState.busy;
    if (_failures.containsKey(step.id)) return ProjectNextStepRowState.failed;
    final durable = switch (projectNextStepOutcome(step)) {
      ProjectNextStepOutcome.pending => ProjectNextStepRowState.pending,
      ProjectNextStepOutcome.added => ProjectNextStepRowState.added,
      ProjectNextStepOutcome.done => ProjectNextStepRowState.done,
      ProjectNextStepOutcome.dismissed => ProjectNextStepRowState.dismissed,
    };
    final optimistic = _optimistic[step.id];
    if (optimistic == null) return durable;
    if (optimistic == durable) {
      // The snapshot caught up; the overlay has done its job.
      _optimistic.remove(step.id);
      return durable;
    }
    return optimistic;
  }

  bool _canUndo(ProjectRecommendationEntity step, ProjectNextStepRowState s) {
    if (!widget.enabled) return false;
    return switch (s) {
      ProjectNextStepRowState.dismissed || ProjectNextStepRowState.done => true,
      ProjectNextStepRowState.added =>
        _undoDeadlines[step.id]?.isAfter(_now) ?? false,
      ProjectNextStepRowState.pending ||
      ProjectNextStepRowState.busy ||
      ProjectNextStepRowState.failed => false,
    };
  }

  void _armUndo(String stepId) {
    _undoTimers.remove(stepId)?.cancel();
    _undoDeadlines[stepId] = _now.add(ProjectRecommendationsPanel.undoWindow);
    _undoTimers[stepId] = Timer(ProjectRecommendationsPanel.undoWindow, () {
      _undoTimers.remove(stepId);
      if (!mounted) return;
      setState(() => _undoDeadlines.remove(stepId));
    });
  }

  Future<void> _addTask(ProjectRecommendationEntity step) async {
    if (_busySteps.contains(step.id)) return;
    setState(() {
      _busySteps.add(step.id);
      _failures.remove(step.id);
    });
    try {
      final result = await ref
          .read(projectRecommendationServiceProvider)
          .createTask(step.id);
      if (!mounted) return;
      if (result.success) {
        final taskId = result.mutatedEntityId;
        _optimistic[step.id] = taskId == null
            ? ProjectNextStepRowState.done
            : ProjectNextStepRowState.added;
        if (taskId != null) {
          _createdTasks[step.id] = taskId;
          widget.onTaskCreated?.call(taskId);
        }
        _armUndo(step.id);
        if (result.errorMessage case final warning?) {
          context.showToast(
            tone: DesignSystemToastTone.warning,
            title: context.messages.changeSetItemConfirmedWithWarning(warning),
          );
        }
      } else {
        // A consumed claim (task created, link and rollback both failed)
        // cannot be retried: every retry would report "no longer active".
        _failures[step.id] = (
          retryable: !result.nonRetryable,
          message: result.nonRetryable ? result.errorMessage : null,
        );
      }
    } catch (error, stackTrace) {
      _log(
        'Failed to create a task from a project suggestion',
        error,
        stackTrace,
      );
      if (!mounted) return;
      _failures[step.id] = (retryable: true, message: null);
    } finally {
      if (mounted) setState(() => _busySteps.remove(step.id));
    }
  }

  Future<void> _dismiss(ProjectRecommendationEntity step) async {
    await _transition(
      step,
      () => ref
          .read(projectRecommendationServiceProvider)
          .dismissRecommendation(step.id),
      settled: ProjectNextStepRowState.dismissed,
    );
  }

  Future<void> _undo(ProjectRecommendationEntity step) async {
    await _transition(
      step,
      () => ref
          .read(projectRecommendationServiceProvider)
          .restoreRecommendation(step.id),
      settled: ProjectNextStepRowState.pending,
      // Only a successful restore forfeits the undo window and the task
      // link; a refused undo leaves the row exactly as it was.
      onSuccess: () {
        _undoTimers.remove(step.id)?.cancel();
        _undoDeadlines.remove(step.id);
        _createdTasks.remove(step.id);
      },
    );
  }

  Future<void> _transition(
    ProjectRecommendationEntity step,
    Future<bool> Function() run, {
    required ProjectNextStepRowState settled,
    VoidCallback? onSuccess,
  }) async {
    if (_busySteps.contains(step.id)) return;
    setState(() {
      _busySteps.add(step.id);
      _failures.remove(step.id);
    });
    var succeeded = false;
    try {
      succeeded = await run();
    } catch (error, stackTrace) {
      _log('Failed to update a project suggestion', error, stackTrace);
    }
    if (!mounted) return;
    setState(() {
      _busySteps.remove(step.id);
      if (succeeded) {
        _optimistic[step.id] = settled;
        onSuccess?.call();
      }
    });
    if (!succeeded) {
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.projectRecommendationUpdateError,
      );
    }
  }

  Future<void> _runBulk(
    Iterable<ProjectRecommendationEntity> steps,
    Future<void> Function(ProjectRecommendationEntity step) action,
  ) async {
    if (_bulkBusy) return;
    setState(() => _bulkBusy = true);
    try {
      for (final step in steps.toList()) {
        if (!mounted) return;
        await action(step);
      }
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  // ------------------------------------------------------------ proposals --

  String _proposalKey(ChangeSetEntity set, int index) => '${set.id}:$index';

  Future<void> _decideProposal(
    ChangeSetEntity set,
    int index, {
    required bool confirm,
  }) async {
    final key = _proposalKey(set, index);
    if (_busyProposals.contains(key)) return;
    setState(() => _busyProposals.add(key));
    var succeeded = false;
    try {
      final service = ref.read(projectProposalServiceProvider);
      succeeded = confirm
          ? (await service.confirm(set, index)).success
          : await service.reject(set, index);
    } catch (error, stackTrace) {
      _log('Failed to apply a project proposal', error, stackTrace);
    }
    if (!mounted) return;
    setState(() {
      _busyProposals.remove(key);
      if (succeeded) {
        final items = [...set.items];
        items[index] = items[index].copyWith(
          status: confirm
              ? ChangeItemStatus.confirmed
              : ChangeItemStatus.rejected,
        );
        _decidedProposals[key] = (set.copyWith(items: items), index);
        _armUndo(key);
      }
    });
    // Only the proposal read moves; the agent's update stream is left alone
    // so the report, health and footer never reload for a row decision.
    ref.invalidate(projectPendingChangeSetsProvider(widget.projectId));
    if (!succeeded) {
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.projectRecommendationUpdateError,
      );
    }
  }

  /// A decided proposal offers Undo for the same window as an added step,
  /// and only while the service can still put its effect back.
  bool _canUndoProposal(ChangeSetEntity set, int index) {
    if (!widget.enabled) return false;
    final key = _proposalKey(set, index);
    if (!(_undoDeadlines[key]?.isAfter(_now) ?? false)) return false;
    return ref.read(projectProposalServiceProvider).canUndo(set, index);
  }

  Future<void> _undoProposal(ChangeSetEntity set, int index) async {
    final key = _proposalKey(set, index);
    if (_busyProposals.contains(key)) return;
    setState(() => _busyProposals.add(key));
    var succeeded = false;
    try {
      succeeded = await ref
          .read(projectProposalServiceProvider)
          .undo(set, index);
    } catch (error, stackTrace) {
      _log('Failed to undo a project proposal', error, stackTrace);
    }
    if (!mounted) return;
    setState(() {
      _busyProposals.remove(key);
      if (succeeded) {
        _decidedProposals.remove(key);
        _undoTimers.remove(key)?.cancel();
        _undoDeadlines.remove(key);
      }
    });
    ref.invalidate(projectPendingChangeSetsProvider(widget.projectId));
    if (!succeeded) {
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.projectRecommendationUpdateError,
      );
    }
  }

  void _log(String message, Object error, StackTrace stackTrace) {
    developer.log(
      message,
      name: 'ProjectRecommendationsPanel',
      error: error,
      stackTrace: stackTrace,
    );
  }

  // ----------------------------------------------------------------- build --

  @override
  Widget build(BuildContext context) {
    final snapshot = ref
        .watch(projectNextStepsProvider(widget.projectId))
        .value;
    final sets =
        ref.watch(projectPendingChangeSetsProvider(widget.projectId)).value ??
        const <AgentDomainEntity>[];
    final proposals = _proposalRows(sets);
    if (snapshot == null && proposals.isEmpty) return const SizedBox.shrink();

    final tokens = context.designTokens;
    final messages = context.messages;
    final now = ref.watch(projectDetailNowProvider)();
    // Counted from the rows' effective state, so a step added or dismissed a
    // moment ago leaves the count and the bulk rail before the snapshot
    // catches up.
    final openSteps = snapshot == null
        ? const <ProjectRecommendationEntity>[]
        : snapshot.steps
              .where(
                (step) => _rowState(step) == ProjectNextStepRowState.pending,
              )
              .toList();

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: TldrBody.maxReadingWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (snapshot != null)
              _Band(
                icon: LottiIcons.tip,
                title: messages.projectRecommendationsTitle,
                count: openSteps.length,
                child: _stepsBody(context, snapshot, now, openSteps),
              ),
            if (proposals.isNotEmpty)
              _Band(
                icon: LottiIcons.factCheck,
                title: messages.changeSetCardTitle,
                count: proposals
                    .where(
                      (row) =>
                          row.$1.items[row.$2].status ==
                          ChangeItemStatus.pending,
                    )
                    .length,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (set, index) in proposals)
                      Padding(
                        key: ValueKey('proposal-${_proposalKey(set, index)}'),
                        padding: EdgeInsets.only(bottom: tokens.spacing.step2),
                        child: ProjectProposalRow(
                          changeSet: set,
                          itemIndex: index,
                          busy: _busyProposals.contains(
                            _proposalKey(set, index),
                          ),
                          enabled: widget.enabled && !_bulkBusy,
                          onConfirm: () =>
                              _decideProposal(set, index, confirm: true),
                          onReject: () =>
                              _decideProposal(set, index, confirm: false),
                          canUndo: _canUndoProposal(set, index),
                          onUndo: () => _undoProposal(set, index),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Every proposal row to show: the live sets' open items in order, plus
  /// rows decided this session — whether their set still comes back from the
  /// pending read or not. Items decided in an earlier session stay out.
  List<(ChangeSetEntity, int)> _proposalRows(List<AgentDomainEntity> sets) {
    final rows = <(ChangeSetEntity, int)>[];
    final seen = <String>{};
    for (final set in sets.whereType<ChangeSetEntity>()) {
      for (final (index, item) in set.items.indexed) {
        if (item.toolName == ProjectAgentToolNames.recommendNextSteps) continue;
        final key = _proposalKey(set, index);
        final decided = _decidedProposals[key];
        if (decided != null) {
          seen.add(key);
          rows.add(decided);
          continue;
        }
        // A sibling decided in an earlier session is history, not a row.
        if (item.status != ChangeItemStatus.pending) continue;
        seen.add(key);
        rows.add((set, index));
      }
    }
    for (final entry in _decidedProposals.entries) {
      if (!seen.contains(entry.key)) rows.add(entry.value);
    }
    return rows;
  }

  Widget _stepsBody(
    BuildContext context,
    ProjectNextStepsSnapshot snapshot,
    DateTime now,
    List<ProjectRecommendationEntity> pending,
  ) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final steps = snapshot.steps;
    final tally = ProjectNextStepsTally.of(steps);

    if (!_collapseDecided || _collapseRun != snapshot.runCreatedAt) {
      _collapseDecided = true;
      _collapseRun = snapshot.runCreatedAt;
      _collapsed = tally.allDecided;
      _showAllSteps = false;
      _historyOpen = false;
    }

    if (steps.isEmpty) {
      return ProjectNextStepsEmpty(
        runCreatedAt: snapshot.runCreatedAt,
        now: now,
      );
    }
    if (_collapsed) {
      return ProjectNextStepsSummary(
        steps: steps,
        runCreatedAt: snapshot.runCreatedAt,
        now: now,
        historyOpen: _historyOpen,
        onToggleHistory: () => setState(() => _historyOpen = !_historyOpen),
      );
    }

    final phone =
        MediaQuery.sizeOf(context).width < ProjectNextStepRow.wideBreakpoint;
    final visible = visibleProjectNextSteps(
      steps,
      cap: phone ? ProjectRecommendationsPanel.phoneStepCap : steps.length,
      showAll: _showAllSteps,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final step in visible)
          Padding(
            key: ValueKey('step-${step.id}'),
            padding: EdgeInsets.only(bottom: tokens.spacing.step2),
            child: Builder(
              builder: (context) {
                final state = _rowState(step);
                final taskId = step.createdTaskId ?? _createdTasks[step.id];
                final openTask = widget.onOpenTask;
                final failure = _failures[step.id];
                return ProjectNextStepRow(
                  step: step,
                  state: state,
                  enabled: widget.enabled && !_bulkBusy,
                  canUndo: _canUndo(step, state),
                  failureMessage: failure?.message,
                  onAddTask: failure?.retryable == false
                      ? null
                      : () => unawaited(_addTask(step)),
                  onDismiss: () => unawaited(_dismiss(step)),
                  onUndo: () => unawaited(_undo(step)),
                  onOpenTask: taskId == null || openTask == null
                      ? null
                      : () => openTask(taskId),
                );
              },
            ),
          ),
        if (visible.length < steps.length)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: DesignSystemInlineAction(
              onTap: () => setState(() => _showAllSteps = true),
              semanticsLabel: messages.projectNextStepsShowMore(
                steps.length - visible.length,
              ),
              label: messages.projectNextStepsShowMore(
                steps.length - visible.length,
              ),
              leadingIcon: LottiIcons.chevronDown,
              ink: tokens.colors.interactive.enabled,
            ),
          ),
        if (pending.length > 1) ...[
          SizedBox(height: tokens.spacing.step2),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: tokens.spacing.step3,
            runSpacing: tokens.spacing.step2,
            children: [
              IntrinsicWidth(
                child: DesignSystemInlineAction(
                  onTap: widget.enabled && !_bulkBusy
                      ? () => unawaited(_runBulk(pending, _dismiss))
                      : null,
                  semanticsLabel: messages.projectNextStepsDismissAll,
                  label: messages.projectNextStepsDismissAll,
                  leadingIcon: LottiIcons.close,
                ),
              ),
              DesignSystemButton(
                label: messages.projectNextStepsAddAll,
                leadingIcon: LottiIcons.add,
                variant: DesignSystemButtonVariant.outlined,
                size: DesignSystemButtonSize.dense,
                tapTargetSize: MaterialTapTargetSize.padded,
                isLoading: _bulkBusy,
                onPressed: widget.enabled && !_bulkBusy
                    ? () => unawaited(_runBulk(pending, _addTask))
                    : null,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// One titled band inside the AI card: a hairline above, the heading with
/// its pending count, then the band's rows.
class _Band extends StatelessWidget {
  const _Band({
    required this.icon,
    required this.title,
    required this.count,
    required this.child,
  });

  final IconData icon;
  final String title;
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: ai.borderSoft)),
      ),
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.cardPadding,
        tokens.spacing.step3,
        tokens.spacing.cardPadding,
        tokens.spacing.step4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: IconSizes.s, color: ai.titleText),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: ai.titleText,
                  ),
                ),
              ),
              if (count > 0) ...[
                SizedBox(width: tokens.spacing.step3),
                Text(
                  context.messages.changeSetPendingCount(count),
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: ai.metaText,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: tokens.spacing.step3),
          child,
        ],
      ),
    );
  }
}

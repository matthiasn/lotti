import 'dart:async';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_report_provenance.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/agents/ui/agent_model_sheet.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/assign_agent_cta_part.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/proposals_section_part.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/tldr_section_part.dart';
import 'package:lotti/features/agents/ui/task_agent_controls_footer.dart';
import 'package:lotti/features/agents/ui/task_agent_model_identity.dart';
import 'package:lotti/features/agents/ui/widgets/ai_card_chrome.dart';
import 'package:lotti/features/design_system/components/motion/size_fade_collapse.dart';
import 'package:lotti/features/design_system/components/motion/size_fade_entrance.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/features/tts/ui/widgets/tts_play_button.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';

export 'package:lotti/features/agents/ui/ai_summary_card/proposal_kind_part.dart';
export 'package:lotti/features/agents/ui/ai_summary_card/proposal_row_widgets_part.dart';

/// Unified AI summary card for the task details column.
///
/// Replaces the separate "AI Summary" + "Decision Activity" stack with
/// a single deep-teal-tinted-navy surface. Reading order: identity
/// header, the TLDR with an expandable inline report, a constant-height
/// freshness strip with the manual wake CTA (while automatic updates
/// are off — out-of-date warning or up-to-date confirmation, no layout
/// jump between the two), the actionable proposals list (only while
/// something is proposed), the resolved history (only while the report
/// is expanded), and a quiet controls footer (wake / countdown /
/// automatic-updates toggle / model identity). Uses the same data
/// sources as the prior `AgentSuggestionsPanel` (proposal ledger, agent
/// report, wake state).
///
/// The card is a library split across part files in the
/// `ai_summary_card/` directory:
/// * `tldr_section_part.dart` — header, badge, pills, countdown,
///   TLDR body
/// * `proposals_section_part.dart` — proposals section, history
///   section, pending pill, history toggle
/// * `proposal_kind_part.dart` — kind enum + tool-name mapping +
///   token lookup
/// * `assign_agent_cta_part.dart` — fallback CTA + create flow
class AiSummaryCard extends ConsumerWidget {
  const AiSummaryCard({
    required this.taskId,
    this.proposalsFocusKey,
    this.onSuggestionResolveStart,
    this.showAssignCta = true,
    super.key,
  });

  final String taskId;
  final GlobalKey? proposalsFocusKey;

  /// Whether to render [AssignAgentCta] when no agent is attached.
  ///
  /// False when the host already offers assignment somewhere better — the
  /// task page's first-run block folds the same offer into its own rows, and
  /// two "Assign Agent" affordances on one screen is one too many.
  final bool showAssignCta;

  /// Called synchronously when the user commits to resolving a suggestion,
  /// before the underlying task mutation can change surrounding layout.
  final VoidCallback? onSuggestionResolveStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAgentAsync = ref.watch(taskAgentProvider(taskId));

    return taskAgentAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: SizedBox.shrink,
      error: (_, _) => const SizedBox.shrink(),
      data: (agentEntity) {
        final identity = agentEntity?.mapOrNull(agent: (e) => e);
        if (identity == null) {
          return showAssignCta
              ? AssignAgentCta(taskId: taskId)
              : const SizedBox.shrink();
        }
        return _AiSummaryShell(
          taskId: taskId,
          identity: identity,
          proposalsFocusKey: proposalsFocusKey,
          onSuggestionResolveStart: onSuggestionResolveStart,
        );
      },
    );
  }
}

class _AiSummaryShell extends ConsumerStatefulWidget {
  const _AiSummaryShell({
    required this.taskId,
    required this.identity,
    required this.proposalsFocusKey,
    required this.onSuggestionResolveStart,
  });

  final String taskId;
  final AgentIdentityEntity identity;
  final GlobalKey? proposalsFocusKey;
  final VoidCallback? onSuggestionResolveStart;

  @override
  ConsumerState<_AiSummaryShell> createState() => _AiSummaryShellState();
}

class _AiSummaryShellState extends ConsumerState<_AiSummaryShell> {
  bool _expanded = false;
  bool _historyOpen = false;
  bool _confirmAllBusy = false;
  final Set<String> _automaticUpdatesBusyAgentIds = {};
  int _confirmAllPulse = 0;
  bool _cancelledManually = false;
  UnifiedSuggestionList? _lastVisibleSuggestions;

  /// Fingerprints already shown at least once. The first non-null suggestion
  /// batch — the initial load, whenever it resolves — is seeded here without
  /// animating; only fingerprints that arrive *after* that play an entrance
  /// reveal, so a proposal produced by a background wake eases the list open
  /// while the initial load (covered by the card's StaggeredEntrance) stays
  /// instant.
  final Set<String> _seenFingerprints = {};
  bool _hasSeededFingerprints = false;

  /// Fingerprints that arrived on the most recent sync — the rows that should
  /// play their entrance reveal. Recomputed each sync; a row reads it once when
  /// it first mounts.
  Set<String> _newlyArrivedFingerprints = {};

  /// Fingerprints of suggestions the user has committed to (accept/reject) but
  /// whose row is still animating out. The provider drops a confirmed item
  /// immediately; this set keeps the row in the visible list (collapsing in
  /// place) until its exit animation completes, so the row never blinks out
  /// from under the finger. The dual of [_mergeUnresolvedOpenSuggestions].
  final Set<String> _exitingFingerprints = {};

  /// True from a Confirm-all tap until the last row of that batch has left.
  /// Keeps the rail on screen for the whole sweep: the rows prune one by one,
  /// and the rail would otherwise collapse the moment a single row remained,
  /// while that row was still leaving.
  bool _confirmAllSweeping = false;

  /// Whether the resolved-history band is showing. Latched while rows are
  /// collapsing: the first confirm of a sweep already puts an entry in the
  /// ledger, and letting the band appear mid-sweep would shove the rows still
  /// leaving — the ones the user is watching — by its own height. It reveals
  /// once the sweep has settled, easing open instead of snapping.
  bool _showHistory = false;

  /// Whether the history band's next appearance should ease open. False when
  /// the band is part of the initial load, whose bands the `StaggeredEntrance`
  /// above already choreographs; true for a band that appears later.
  bool _historyRevealAnimates = false;

  /// Whether the history decision has been taken against a real list at
  /// least once. Distinguishes a band present on the initial load (no reveal)
  /// from one appearing after it.
  bool _historyDecidedWithList = false;

  /// The proposals section most recently built with rows in it, kept so the
  /// section can collapse away as a unit once the last row has left. Without
  /// it the residual — the section header, its paddings and the rail — would
  /// unmount in one frame.
  ProposalsSection? _lastProposalsSection;

  /// Bumped each time the section comes back after having been absent, so
  /// the collapse wrapper is rebuilt fresh and the returning rows play their
  /// own entrance reveal rather than the whole section scaling back open.
  int _proposalsGeneration = 0;

  /// Whether the previous build had a section with rows in it. Read against
  /// the *previous build* rather than [_lastProposalsSection], which is only
  /// dropped a frame after the collapse ends — a section returning inside
  /// that frame would otherwise keep the collapsed wrapper and scale open.
  bool _hadProposalsSection = false;

  ProviderSubscription<AsyncValue<UnifiedSuggestionList>>?
  _suggestionsSubscription;
  ProviderSubscription<AsyncValue<bool>>? _runningSubscription;

  @override
  void initState() {
    super.initState();
    _startSuggestionSubscriptions();
  }

  @override
  void didUpdateWidget(covariant _AiSummaryShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskId != widget.taskId ||
        oldWidget.identity.agentId != widget.identity.agentId) {
      // Drop in-flight exit state too: a fingerprint left over from the
      // previous task must not carry into the next one (it would keep
      // `settling` on or skew the pending-count filter).
      _exitingFingerprints.clear();
      _confirmAllSweeping = false;
      _lastProposalsSection = null;
      _hadProposalsSection = false;
      _showHistory = false;
      _historyRevealAnimates = false;
      _historyDecidedWithList = false;
      _lastVisibleSuggestions = null;
      _seenFingerprints.clear();
      _hasSeededFingerprints = false;
      _newlyArrivedFingerprints = const {};
      _closeSuggestionSubscriptions();
      _startSuggestionSubscriptions();
    }
  }

  @override
  void dispose() {
    _exitingFingerprints.clear();
    _closeSuggestionSubscriptions();
    super.dispose();
  }

  void _startSuggestionSubscriptions() {
    _syncVisibleSuggestions(notify: false);
    _suggestionsSubscription = ref
        .listenManual<AsyncValue<UnifiedSuggestionList>>(
          unifiedSuggestionListProvider(widget.taskId),
          (_, _) => _syncVisibleSuggestions(),
        );
    _runningSubscription = ref.listenManual<AsyncValue<bool>>(
      agentIsRunningProvider(widget.identity.agentId),
      (_, _) => _syncVisibleSuggestions(),
    );
  }

  void _closeSuggestionSubscriptions() {
    _suggestionsSubscription?.close();
    _runningSubscription?.close();
    _suggestionsSubscription = null;
    _runningSubscription = null;
  }

  /// The user committed to this suggestion — keep its row mounted while it
  /// collapses, even after the provider resolves it away. Rebuild so the
  /// pending-count pill ticks down with the action (the row is excluded from
  /// the count the instant it is committed).
  void _onRowResolveStart(PendingSuggestion suggestion) {
    if (!_exitingFingerprints.add(suggestion.fingerprint)) return;
    widget.onSuggestionResolveStart?.call();
    if (mounted) setState(() {});
  }

  /// The row's exit animation finished, or the write failed. On `removed: true`
  /// drop the suggestion from the visible list now — independent of provider
  /// timing — so a slow re-query can't briefly pop the collapsed row back. On
  /// `removed: false` (failed / no-op write) restore provider truth so the row
  /// stays.
  void _onRowResolveEnd(PendingSuggestion suggestion, {required bool removed}) {
    if (!_exitingFingerprints.remove(suggestion.fingerprint)) return;
    if (_exitingFingerprints.isEmpty) _confirmAllSweeping = false;
    // The exiting set changed, and both `settling` and the pending count derive
    // from it — always rebuild so neither can stick in a stale state, even on
    // the paths where the visible list itself doesn't change.
    if (!mounted) return;
    if (removed) {
      final list = _lastVisibleSuggestions;
      setState(() {
        if (list != null) {
          final open = list.open
              .where((s) => s.fingerprint != suggestion.fingerprint)
              .toList();
          if (open.length != list.open.length) {
            _lastVisibleSuggestions = UnifiedSuggestionList(
              open: open,
              activity: list.activity,
              agentName: list.agentName,
            );
          }
        }
      });
      return;
    }
    setState(() {});
    _syncVisibleSuggestions();
  }

  void _syncVisibleSuggestions({bool notify = true}) {
    final listAsync = ref.read(unifiedSuggestionListProvider(widget.taskId));
    final runningAsync = ref.read(
      agentIsRunningProvider(widget.identity.agentId),
    );
    final isRunning = runningAsync.hasValue && (runningAsync.value ?? false);
    final next = _resolveVisibleSuggestionList(
      listAsync,
      isRunning: isRunning,
      previous: _lastVisibleSuggestions,
    );
    if (next == _lastVisibleSuggestions) return;
    _updateArrivals(next);

    if (!notify || !mounted) {
      _lastVisibleSuggestions = next;
      return;
    }

    setState(() => _lastVisibleSuggestions = next);
  }

  /// Tracks which open fingerprints are *newly arrived* so only their rows
  /// animate in. The first non-null batch seeds [_seenFingerprints] silently
  /// (it is the initial load); thereafter any fingerprint not yet seen counts
  /// as new for this sync.
  void _updateArrivals(UnifiedSuggestionList? next) {
    if (next == null) return;
    final openFps = {for (final s in next.open) s.fingerprint};
    if (!_hasSeededFingerprints) {
      _hasSeededFingerprints = true;
      _newlyArrivedFingerprints = const {};
    } else {
      _newlyArrivedFingerprints = openFps.difference(_seenFingerprints);
    }
    _seenFingerprints.addAll(openFps);
  }

  int _computeRemainingSeconds(DateTime? nextWakeAt) {
    if (nextWakeAt == null) return 0;
    final remaining = nextWakeAt.difference(clock.now()).inSeconds;
    return remaining <= 0 ? 0 : remaining;
  }

  void _openInternals({String? agentName}) {
    Navigator.of(context).push(
      AgentInternalsPanel.route(
        context: context,
        agentId: widget.identity.agentId,
        agentName: agentName ?? widget.identity.displayName,
      ),
    );
  }

  Future<void> _updateAutomaticUpdates({required bool enabled}) async {
    final agentId = widget.identity.agentId;
    if (_automaticUpdatesBusyAgentIds.contains(agentId)) return;
    setState(() => _automaticUpdatesBusyAgentIds.add(agentId));
    try {
      await ref
          .read(taskAgentServiceProvider)
          .updateAutomaticUpdates(
            agentId: agentId,
            enabled: enabled,
          );
      ref.invalidate(agentIdentityProvider(agentId));
    } catch (error, stackTrace) {
      developer.log(
        'Task-agent automatic update failed',
        name: 'AiSummaryCard',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted && widget.identity.agentId == agentId) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.commonError,
          clearQueue: true,
        );
      }
    } finally {
      if (mounted && _automaticUpdatesBusyAgentIds.contains(agentId)) {
        setState(() => _automaticUpdatesBusyAgentIds.remove(agentId));
      }
    }
  }

  /// Confirms every visible suggestion while retaining the whole batch until
  /// each proposal row finishes its staggered exit animation.
  Future<void> _confirmAll(List<PendingSuggestion> pending) async {
    if (_confirmAllBusy || pending.isEmpty) return;
    // Start viewport stabilization before the first persistence call can grow
    // or shrink checklist content above this card.
    widget.onSuggestionResolveStart?.call();
    // Protect the entire batch synchronously, before either the staggered row
    // timers or the first persistence call can run. Checklist check-off writes
    // are fast enough for the provider to resolve every suggestion before a
    // later row's stagger starts; without this eager retention those rows are
    // unmounted abruptly instead of completing the confirm-all sweep. Insert
    // writes are slower, which previously hid this race in that code path.
    // One light haptic for the whole gesture (the rows no longer tick
    // individually — that machine-gunned on a big batch). Bump the pulse so
    // the rows run their resolve → collapse exit as one staggered downward
    // sweep while the batch confirm writes run.
    unawaited(HapticFeedback.selectionClick());
    // A single assertive screen-reader announcement for the whole batch — the
    // per-row sweep does not announce individually (that would flood SR users).
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        context.messages.changeSetItemConfirmed,
        Directionality.of(context),
        assertiveness: Assertiveness.assertive,
      ),
    );
    setState(() {
      _exitingFingerprints.addAll(pending.map((s) => s.fingerprint));
      _confirmAllSweeping = true;
      _confirmAllBusy = true;
      _confirmAllPulse++;
    });

    final service = ref.read(changeSetConfirmationServiceProvider);
    final notifier = ref.read(updateNotificationsProvider);
    final messages = context.messages;

    final distinctSets = <String, ChangeSetEntity>{
      for (final s in pending) s.changeSet.id: s.changeSet,
    };
    final agentIds = <String>{
      for (final cs in distinctSets.values) cs.agentId,
    };

    var anyFailed = false;
    try {
      for (final cs in distinctSets.values) {
        final results = await service.confirmAll(cs);
        if (results.any((r) => !r.success)) anyFailed = true;
      }
      // Only surface a toast on failure — a successful batch is already made
      // abundantly clear by the rows sweeping out and the count dropping to
      // zero, so a "Change applied" banner is redundant noise.
      if (anyFailed && mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: messages.changeSetConfirmError,
          clearQueue: true,
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        'confirmAll failed',
        name: 'AiSummaryCard',
        error: e.runtimeType,
        stackTrace: stackTrace,
      );
      if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: messages.changeSetConfirmError,
          clearQueue: true,
        );
      }
    } finally {
      notifier.notify(agentIds);
      if (mounted) setState(() => _confirmAllBusy = false);
    }
  }

  /// Builds the Supertonic playback control that reads [text] aloud, deriving
  /// its mode and progress from the app-wide [TtsPlaybackController]. [text] is
  /// whatever the body currently shows (TL;DR alone when collapsed, TL;DR plus
  /// the full report when expanded). Only reflects an active state when this
  /// card's task is the playing source so multiple cards never animate for one
  /// utterance.
  Widget _buildPlaybackControl(TtsPlaybackState playback, String text) {
    final taskId = widget.taskId;
    final active = playback.isActiveFor(taskId);
    final mode = !active
        ? TtsButtonMode.idle
        : switch (playback.status) {
            TtsPlaybackStatus.downloadingModel ||
            TtsPlaybackStatus.synthesizing => TtsButtonMode.preparing,
            TtsPlaybackStatus.playing => TtsButtonMode.playing,
            _ => TtsButtonMode.idle,
          };
    final durationMs = playback.duration.inMilliseconds;
    final progress = (mode == TtsButtonMode.playing && durationMs > 0)
        ? playback.position.inMilliseconds / durationMs
        : null;
    final notifier = ref.read(ttsPlaybackControllerProvider.notifier);
    return TtsPlayButton(
      mode: mode,
      progress: progress,
      onPlay: () => notifier.speak(sourceId: taskId, text: text),
      onStop: notifier.stop,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final agentId = widget.identity.agentId;

    final reportAsync = ref.watch(agentReportProvider(agentId));
    final report = reportAsync.value?.mapOrNull(agentReport: (r) => r);
    final liveIdentity = ref
        .watch(agentIdentityProvider(agentId))
        .value
        ?.mapOrNull(agent: (value) => value);
    final effectiveIdentity = liveIdentity ?? widget.identity;
    final resolvedSetup = ref
        .watch(taskAgentResolvedSetupProvider(agentId))
        .value;
    final reportProvenance = report == null
        ? null
        : ReportInferenceProvenance.tryRead(report.provenance);
    final identityData = TaskAgentModelIdentityViewData.fromResolution(
      setup: resolvedSetup,
      reportProvenance: reportProvenance,
      hasReport: report != null,
    );
    final inferenceAvailable =
        identityData.presentation != TaskAgentIdentityPresentation.disabled &&
        identityData.presentation != TaskAgentIdentityPresentation.broken;
    final automaticUpdatesEnabled =
        effectiveIdentity.config.automaticUpdatesEnabledEffective;

    final tldr = resolveReportTldr(report);
    final additionalReport = resolveReportAdditional(report);

    final isRunning = ref.watch(agentIsRunningProvider(agentId)).value ?? false;
    final list = _lastVisibleSuggestions;
    // Prefer the template displayName (e.g. "Task Laura") over the
    // generic agent kind label so the subtitle reads as the named
    // persona the user picked.
    final templateAsync = ref.watch(templateForAgentProvider(agentId));
    final templateEntity = templateAsync.value;
    final templateName = templateEntity is AgentTemplateEntity
        ? templateEntity.displayName.trim()
        : null;
    final subtitle = templateName != null && templateName.isNotEmpty
        ? templateName
        : widget.identity.displayName;
    final ttsEnabled =
        ref.watch(configFlagProvider(enableAiSummaryTtsFlag)).value ?? false;
    final ttsEngineSupported = ref.watch(ttsEngineProvider).isSupported;
    final playback = ref.watch(ttsPlaybackControllerProvider);
    // Read aloud exactly what the body shows: the TL;DR when collapsed, the
    // TL;DR followed by the full report once expanded.
    final spokenText = _expanded && additionalReport != null
        ? '$tldr\n\n$additionalReport'
        : tldr;
    final playbackControl = ttsEnabled && tldr.isNotEmpty && ttsEngineSupported
        ? _buildPlaybackControl(playback, spokenText)
        : null;

    // Surface a toast when playback fails for this card's summary.
    ref.listen(ttsPlaybackControllerProvider, (previous, next) {
      if (next.status == TtsPlaybackStatus.error &&
          next.sourceId == widget.taskId &&
          previous?.status != TtsPlaybackStatus.error) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.commonError,
          clearQueue: true,
        );
      }
    });

    final agentStateAsync = ref.watch(agentStateProvider(agentId));
    final agentState = agentStateAsync.value?.mapOrNull(
      agentState: (state) => state,
    );
    final nextWakeAt = agentState?.nextWakeAt;
    final reportIsStale = agentState?.isReportStale ?? false;
    final remainingSeconds = _computeRemainingSeconds(nextWakeAt);

    ref.listen(agentStateProvider(agentId), (prev, next) {
      final previousNextWake = prev?.value?.mapOrNull(
        agentState: (s) => s.nextWakeAt,
      );
      final newNextWake = next.value?.mapOrNull(
        agentState: (s) => s.nextWakeAt,
      );
      // Clear the manual-cancel flag in two situations: (a) the
      // current wake has already expired, or (b) a fresh wake has
      // been scheduled (different timestamp, still in the future).
      // Without (b) a rescheduled wake would stay hidden after the
      // user cancels the previous one.
      final newRemaining = _computeRemainingSeconds(newNextWake);
      final wakeRescheduled =
          newNextWake != null &&
          newNextWake != previousNextWake &&
          newRemaining > 0;
      if (newRemaining <= 0 || wakeRescheduled) {
        _cancelledManually = false;
      }
    });

    final showCountdown =
        inferenceAvailable &&
        automaticUpdatesEnabled &&
        !isRunning &&
        remainingSeconds > 0 &&
        !_cancelledManually;

    final runNow = inferenceAvailable
        ? () => ref.read(taskAgentServiceProvider).triggerReanalysis(agentId)
        : null;
    void cancelTimer() {
      ref.read(taskAgentServiceProvider).cancelScheduledWake(agentId);
      setState(() => _cancelledManually = true);
    }

    // The freshness state (out of date / up to date) always rides along
    // with the wake control and switch in the footer's automation cluster —
    // it never moves to a separate row depending on automaticUpdatesEnabled.
    // Without any report content there is nothing to be "out of date", so
    // the footer omits the glyph entirely rather than showing a default.
    final hasReportContent = tldr.isNotEmpty || additionalReport != null;

    final controlsFooter = TaskAgentControlsFooter(
      automaticUpdatesEnabled: automaticUpdatesEnabled,
      automationBusy: _automaticUpdatesBusyAgentIds.contains(agentId),
      inferenceAvailable: inferenceAvailable,
      isRunning: isRunning,
      showCountdown: showCountdown,
      nextWakeAt: nextWakeAt,
      hasReportContent: hasReportContent,
      isStale: reportIsStale,
      onAutomaticUpdatesChanged: (enabled) =>
          unawaited(_updateAutomaticUpdates(enabled: enabled)),
      onRunNow: runNow,
      onSkipScheduledUpdate: cancelTimer,
      onCountdownExpired: () {
        if (mounted) setState(() {});
      },
      identityData: identityData,
      onSetupTap: () => AgentModelSheet.show(
        context: context,
        taskId: widget.taskId,
        agentId: agentId,
      ),
    );
    final reportBody = TldrBody(
      disclosureKey: const ValueKey('taskAgentReportDisclosure'),
      tldr: tldr,
      expanded: _expanded,
      additionalReport: additionalReport,
      onToggle: () => setState(() => _expanded = !_expanded),
      onOpenInternals: () => _openInternals(agentName: subtitle),
    );
    // Nothing to propose, no section: an empty "Proposed changes" band cost a
    // divider and two paddings to say what the missing rows already said. A
    // row committed by the user stays in `open` until its collapse finishes;
    // then the section — header, paddings, rail — collapses away as a unit
    // on the row's own clock, rather than unmounting in one frame.
    final proposalsSection = list == null || list.open.isEmpty
        ? null
        : ProposalsSection(
            key: widget.proposalsFocusKey,
            open: list.open,
            newlyArrived: _newlyArrivedFingerprints,
            // The pill counts what the user still has to act on: rows
            // already committed (collapsing out) are excluded, so the count
            // ticks down *with* the action rather than waiting for prune.
            pendingCount: list.open
                .where(
                  (s) => !_exitingFingerprints.contains(s.fingerprint),
                )
                .length,
            // Loading for the whole sweep, not just the writes: fast writes
            // return before the rows have left, and a rail that re-enables
            // then would re-run the batch — a second haptic, a second
            // announcement, a redundant service round-trip.
            confirmAllBusy: _confirmAllBusy || _confirmAllSweeping,
            confirmAllPulse: _confirmAllPulse,
            // The rail earns its place with more than one row to act on, and
            // keeps it for the whole of a Confirm-all sweep: the rows prune
            // one at a time, and it must not drop out while the last is
            // still leaving.
            onConfirmAll: list.open.length > 1 || _confirmAllSweeping
                ? () => _confirmAll(list.open)
                : null,
            onResolveStart: _onRowResolveStart,
            onResolveEnd: _onRowResolveEnd,
            // While any row is collapsing out, the survivors are sliding
            // up — guard them so a fast second tap can't land on a row
            // that just moved under the pointer.
            settling: _exitingFingerprints.isNotEmpty,
          );
    // Latches, updated in build rather than in a listener: each is a pure
    // function of state the build already holds (`_expanded`, the report,
    // the exiting set), so the frame that reads them is the frame that can
    // decide them, with no setState behind it. The same applies to the
    // history latch below.
    if (proposalsSection != null && !_hadProposalsSection) {
      _proposalsGeneration++;
    }
    _hadProposalsSection = proposalsSection != null;
    if (proposalsSection != null) _lastProposalsSection = proposalsSection;
    // Mounted whenever there has been a section to show: the current one, or
    // the last one collapsing away. A section that returns after collapsing
    // gets a fresh wrapper (the generation key) so it stands at full height
    // at once and only its new rows reveal themselves.
    final retainedSection = _lastProposalsSection;
    final proposalsBand = retainedSection == null
        ? null
        : SizeFadeCollapse(
            key: ValueKey('proposals-band-$_proposalsGeneration'),
            collapsed: proposalsSection == null,
            duration: ProposalMotion.collapse,
            // Fully gone: drop the departed section, at zero height, where
            // unmounting it moves nothing.
            onCollapsed: () {
              if (mounted && (_lastVisibleSuggestions?.open.isEmpty ?? true)) {
                setState(() => _lastProposalsSection = null);
              }
            },
            child: retainedSection,
          );
    // History rides with the full report, not with the summary: while the
    // card is collapsed the reader wants the TL;DR and the decisions still
    // open, and a permanent "History · n" row competed with both. Expanding
    // the report is the move that says "show me the rest", so that is where
    // the record appears.
    //
    // A report with nothing further to read has no expanded state to gate on
    // — there the card is already showing everything it has, and hiding the
    // record behind a control that does not exist would strand it.
    final reportIsExpandable = additionalReport?.trim().isNotEmpty ?? false;
    final wantHistory =
        list != null &&
        list.activity.isNotEmpty &&
        (_expanded || !reportIsExpandable);
    // Latched while rows are collapsing — see [_showHistory].
    if (_exitingFingerprints.isEmpty && wantHistory != _showHistory) {
      _showHistory = wantHistory;
      _historyRevealAnimates = wantHistory && _historyDecidedWithList;
    }
    if (list != null) _historyDecidedWithList = true;
    final historySection = _showHistory && list != null
        ? SizeFadeEntrance(
            key: const ValueKey('proposalHistoryBand'),
            animate: _historyRevealAnimates,
            child: ProposalHistorySection(
              resolved: list.activity,
              open: _historyOpen,
              onToggle: () => setState(() => _historyOpen = !_historyOpen),
            ),
          )
        : null;

    final cardRadius = aiCardRadius(context);
    return DecoratedBox(
      // The chrome both AI panels share — see [aiCardDecoration].
      decoration: aiCardDecoration(context),
      child: ClipRRect(
        borderRadius: cardRadius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TldrHeader(
              agentName: subtitle,
              onAgentTap: () => _openInternals(agentName: subtitle),
              trailing: playbackControl,
            ),
            // Reading order: the summary first, then the update CTA for the
            // summary just read, then the proposals. Quiet links already own
            // their compact row height, so the section needs only step3 below.
            if (hasReportContent)
              Padding(
                // No bottom inset here: the body's own disclosure row carries
                // the trailing optical gap inside its tap target, and supplies
                // an explicit one when it renders no row at all.
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.cardPadding,
                ),
                child: reportBody,
              ),
            // Both hidden until the first value to avoid flashing empty state.
            ?proposalsBand,
            ?historySection,
            controlsFooter,
          ],
        ),
      ),
    );
  }

  UnifiedSuggestionList? _resolveVisibleSuggestionList(
    AsyncValue<UnifiedSuggestionList> listAsync, {
    required bool isRunning,
    required UnifiedSuggestionList? previous,
  }) {
    final next = listAsync.hasValue ? listAsync.value : null;
    if (next == null) {
      return previous;
    }

    var resolved = isRunning && previous != null
        ? _mergeUnresolvedOpenSuggestions(previous, next)
        : next;

    if (_exitingFingerprints.isNotEmpty && previous != null) {
      resolved = _retainExitingSuggestions(previous, resolved);
    }

    return resolved;
  }

  /// Re-insert any suggestion the user is currently dismissing whose row is
  /// still collapsing but which the provider has already dropped. Keeps it near
  /// its previous slot (by stable fingerprint identity) so the row widget keeps
  /// its exit animation running rather than being torn down mid-collapse.
  UnifiedSuggestionList _retainExitingSuggestions(
    UnifiedSuggestionList previous,
    UnifiedSuggestionList current,
  ) {
    final currentFingerprints = {
      for (final suggestion in current.open) suggestion.fingerprint,
    };
    final open = [...current.open];
    for (final suggestion in previous.open) {
      final fingerprint = suggestion.fingerprint;
      if (!_exitingFingerprints.contains(fingerprint)) continue;
      if (currentFingerprints.contains(fingerprint)) continue;
      final index = previous.open
          .indexWhere((s) => s.fingerprint == fingerprint)
          .clamp(0, open.length);
      open.insert(index, suggestion);
    }
    if (open.length == current.open.length) return current;
    return UnifiedSuggestionList(
      open: open,
      activity: current.activity,
      agentName: current.agentName,
    );
  }

  UnifiedSuggestionList _mergeUnresolvedOpenSuggestions(
    UnifiedSuggestionList previous,
    UnifiedSuggestionList next,
  ) {
    if (previous.open.isEmpty) return next;

    final nextOpenFingerprints = {
      for (final suggestion in next.open) suggestion.fingerprint,
    };
    final resolvedFingerprints = {
      for (final entry in next.activity) entry.fingerprint,
    };
    final stillUnresolvedPrevious = previous.open.where((suggestion) {
      return !nextOpenFingerprints.contains(suggestion.fingerprint) &&
          !resolvedFingerprints.contains(suggestion.fingerprint);
    }).toList();

    if (stillUnresolvedPrevious.isEmpty) return next;

    return UnifiedSuggestionList(
      open: [...next.open, ...stillUnresolvedPrevious],
      activity: next.activity,
      agentName: next.agentName ?? previous.agentName,
    );
  }
}

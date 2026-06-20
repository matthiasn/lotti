import 'dart:async';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/assign_agent_cta_part.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/proposals_section_part.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/tldr_section_part.dart';
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
/// a single deep-teal-tinted-navy surface that exposes the agent's
/// TLDR, an expandable inline report, the actionable proposals list,
/// and the resolved-proposal history. Also surfaces the wake-cycle
/// affordances (countdown / run-now / cancel) directly in the header.
/// Uses the same data sources as the prior `AgentSuggestionsPanel`
/// (proposal ledger, agent report, wake state).
///
/// The card is a library split across part files in the
/// `ai_summary_card/` directory:
/// * `tldr_section_part.dart` — header, badge, pills, countdown,
///   TLDR body
/// * `proposals_section_part.dart` — section, row, kind chip, row
///   actions, history toggle, resolved tag
/// * `proposal_kind_part.dart` — kind enum + tool-name mapping +
///   token lookup
/// * `assign_agent_cta_part.dart` — fallback CTA + create flow
class AiSummaryCard extends ConsumerWidget {
  const AiSummaryCard({
    required this.taskId,
    this.proposalsFocusKey,
    super.key,
  });

  final String taskId;
  final GlobalKey? proposalsFocusKey;

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
        if (identity == null) return AssignAgentCta(taskId: taskId);
        return _AiSummaryShell(
          taskId: taskId,
          identity: identity,
          proposalsFocusKey: proposalsFocusKey,
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
  });

  final String taskId;
  final AgentIdentityEntity identity;
  final GlobalKey? proposalsFocusKey;

  @override
  ConsumerState<_AiSummaryShell> createState() => _AiSummaryShellState();
}

class _AiSummaryShellState extends ConsumerState<_AiSummaryShell> {
  bool _expanded = false;
  bool _historyOpen = false;
  bool _confirmAllBusy = false;
  int _confirmAllPulse = 0;
  bool _cancelledManually = false;
  UnifiedSuggestionList? _lastVisibleSuggestions;

  /// Fingerprints of suggestions the user has committed to (accept/reject) but
  /// whose row is still animating out. The provider drops a confirmed item
  /// immediately; this set keeps the row in the visible list (collapsing in
  /// place) until its exit animation completes, so the row never blinks out
  /// from under the finger. The dual of [_mergeUnresolvedOpenSuggestions].
  final Set<String> _exitingFingerprints = {};

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
      _lastVisibleSuggestions = null;
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
    if (mounted) setState(() {});
  }

  /// The row's exit animation finished, or the write failed. On `removed: true`
  /// drop the suggestion from the visible list now — independent of provider
  /// timing — so a slow re-query can't briefly pop the collapsed row back. On
  /// `removed: false` (failed / no-op write) restore provider truth so the row
  /// stays.
  void _onRowResolveEnd(PendingSuggestion suggestion, {required bool removed}) {
    if (!_exitingFingerprints.remove(suggestion.fingerprint)) return;
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

    if (!notify || !mounted) {
      _lastVisibleSuggestions = next;
      return;
    }

    setState(() => _lastVisibleSuggestions = next);
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

  Future<void> _confirmAll(List<PendingSuggestion> pending) async {
    if (_confirmAllBusy || pending.isEmpty) return;
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
    final ai = tokens.colors.aiCard;
    final agentId = widget.identity.agentId;

    final reportAsync = ref.watch(agentReportProvider(agentId));
    final report = reportAsync.value?.mapOrNull(agentReport: (r) => r);

    final tldr = _resolveTldr(report);
    final additionalReport = _resolveAdditionalReport(report);

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
    final nextWakeAt = agentStateAsync.value?.mapOrNull(
      agentState: (s) => s.nextWakeAt,
    );
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
        !isRunning && remainingSeconds > 0 && !_cancelledManually;

    final cardRadius = BorderRadius.circular(tokens.radii.l);
    return DecoratedBox(
      decoration: BoxDecoration(
        // A directional accent wash anchored at the top-left (where the
        // sparkle badge sits) leads the eye to the AI identity, then falls off
        // to the flat background — a crafted "intelligence" panel that stays
        // within the aiCard palette and the design system's flat aesthetic.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0, 0.55, 1],
          colors: [
            // A gentle top-left accent wash that falls off to the flat
            // background — a touch more present than the original (which read
            // as muted) but without carrying the accent across the whole card
            // (which read as too loud). Landed between the two.
            Color.alphaBlend(ai.accent.withValues(alpha: 0.12), ai.background),
            ai.background,
            ai.background,
          ],
        ),
        borderRadius: cardRadius,
        border: Border.all(color: ai.border),
        boxShadow: [
          BoxShadow(
            color: ai.accent.withValues(alpha: 0.2),
            blurRadius: 24,
            spreadRadius: -4,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: cardRadius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TldrHeader(
              agentName: subtitle,
              hasMore: tldr.isNotEmpty || additionalReport != null,
              expanded: _expanded,
              onToggle: () => setState(() => _expanded = !_expanded),
              onAgentTap: () => _openInternals(agentName: subtitle),
              playbackControl: playbackControl,
              isRunning: isRunning,
              showCountdown: showCountdown,
              nextWakeAt: nextWakeAt,
              onRunNow: () =>
                  ref.read(taskAgentServiceProvider).triggerReanalysis(agentId),
              onCancelTimer: () {
                ref.read(taskAgentServiceProvider).cancelScheduledWake(agentId);
                setState(() => _cancelledManually = true);
              },
              onCountdownExpired: () {
                if (mounted) setState(() {});
              },
            ),
            if (tldr.isNotEmpty)
              TldrBody(
                tldr: tldr,
                expanded: _expanded,
                additionalReport: additionalReport,
                onOpenInternals: () => _openInternals(agentName: subtitle),
              ),
            // Hide the proposals section until the unified
            // suggestion list has produced its first value. This
            // avoids briefly rendering the "No open proposals"
            // placeholder during the initial async fetch.
            if (list != null)
              ProposalsSection(
                key: widget.proposalsFocusKey,
                open: list.open,
                // The pill counts what the user still has to act on: rows
                // already committed (collapsing out) are excluded, so the count
                // ticks down *with* the action rather than waiting for prune.
                pendingCount: list.open
                    .where((s) => !_exitingFingerprints.contains(s.fingerprint))
                    .length,
                resolved: list.activity,
                historyOpen: _historyOpen,
                onToggleHistory: () =>
                    setState(() => _historyOpen = !_historyOpen),
                confirmAllBusy: _confirmAllBusy,
                confirmAllPulse: _confirmAllPulse,
                onConfirmAll: list.open.length > 1
                    ? () => _confirmAll(list.open)
                    : null,
                onResolveStart: _onRowResolveStart,
                onResolveEnd: _onRowResolveEnd,
                // While any row is collapsing out, the survivors are sliding
                // up — guard them so a fast second tap can't land on a row
                // that just moved under the pointer.
                settling: _exitingFingerprints.isNotEmpty,
              ),
          ],
        ),
      ),
    );
  }

  String _resolveTldr(AgentReportEntity? report) {
    if (report == null) return '';
    final explicit = report.tldr?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return report.content.trim();
  }

  String? _resolveAdditionalReport(AgentReportEntity? report) {
    if (report == null) return null;
    final content = report.content.trim();
    if (content.isEmpty) return null;
    final explicitTldr = report.tldr?.trim();
    if (explicitTldr == null || explicitTldr.isEmpty) return null;
    return content;
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

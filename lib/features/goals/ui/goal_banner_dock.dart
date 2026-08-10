import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/service/goal_nudge_interactions.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/goal_banner_actions.dart';
import 'package:lotti/features/goals/ui/goal_banner_exposure_tracker.dart';
import 'package:lotti/features/goals/ui/goal_banner_style.dart';
import 'package:lotti/features/goals/ui/goal_banner_widgets.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

/// How long one banner holds the dock before the rotation advances — long
/// enough to read the copy twice and act, short enough that three goals
/// cycle fully within a minute (design handover 1b).
const goalBannerDockTenure = Duration(seconds: 15);

/// The two-line headline + one-line caption text block of the compact tenant
/// at the 1.0 text scale — the term that grows with accessibility text. The
/// figure is measured against the rendered `_DockTenant` (worst case: a
/// headline that wraps to the full two lines) and guarded by
/// `goal_banner_dock_test.dart`, which asserts the reserve covers the actual
/// rendered dock at both 1× and 2×. The text scaler multiplies only this
/// block; the chrome and the 48dp dismiss target are fixed.
const _dockTenantTextBlockAtUnitScale = 60.0;

/// Clearance the compact (mobile) dock claims above the bottom bar when a
/// goal is speaking — the shell reserves it in the overlay-height scope so
/// page content and FABs never sit underneath (handover 1b's reserved lane).
///
/// Derived from the dock's own design-system dimensions rather than a flat
/// constant, and scale-aware: the tenant row is as tall as the taller of the
/// [TapTargets.minimum] dismiss target and the text block (which grows with
/// the accessibility text scaler), plus the fixed chrome — outer padding
/// (`step3` both edges), the tenure strip (`step1`), and the tenant's own
/// vertical padding (`step3` both edges). A pure `× scale` multiply of a base
/// constant would under-clear at 1× (the fixed dismiss target already exceeds
/// a small base) and mis-track at large scales; this tracks the rendered
/// height instead. Collapses to zero reserve when no goal speaks (the caller
/// only adds it while the dock is speaking).
double goalBannerDockReservedHeight(BuildContext context) {
  final tokens = context.designTokens;
  final scaler = MediaQuery.textScalerOf(context);
  final chrome =
      tokens.spacing.step3 * 4 + // outer + tenant vertical padding, both edges
      tokens.spacing.step1; // tenure strip
  final scaledText = scaler.scale(_dockTenantTextBlockAtUnitScale);
  final row = scaledText > TapTargets.minimum ? scaledText : TapTargets.minimum;
  return chrome + row;
}

/// The dock — one rotating slot for the agents' standing voices, the
/// "now playing" bar of the goal feature (design handover 1b).
///
/// One fixed-height region cycles every standing banner round-robin,
/// [goalBannerDockTenure] per tenant, with ONE shared rotation state: the
/// shell mounts a single dock instance that survives tab switches. Rules:
///
/// - a freshly refreshed banner (a completion acknowledgment) jumps the
///   queue — the check-off → fresh-copy loop is the feature's best moment;
/// - the cycle pauses while hovered or touched (the WCAG pause affordance —
///   auto-advance continues under reduced motion, only transitions change);
/// - dismissal removes the tenant for the day and advances immediately;
/// - with a single tenant there are no dots, no tenure hairline and no
///   auto-advance — it just sits;
/// - with zero tenants the dock collapses entirely: the disappearance IS
///   the dismissal feedback (no toast, no "dismissed!" snackbar);
/// - on phones the dock yields while the keyboard is up.
///
/// Exposure metering rides the existing tracker: a docked tenant is visible
/// whenever the app is foregrounded, so tenure ≈ real screen time — exactly
/// what the rating/reuse loop needs.
class GoalBannerDock extends ConsumerStatefulWidget {
  const GoalBannerDock({required this.compact, super.key});

  /// Phone layout: two-line headline, X only, swipe to dismiss.
  final bool compact;

  @override
  ConsumerState<GoalBannerDock> createState() => _GoalBannerDockState();
}

class _GoalBannerDockState extends ConsumerState<GoalBannerDock>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _tenure = AnimationController(
    vsync: this,
    duration: goalBannerDockTenure,
  );

  /// The cycle pauses while the app is not foregrounded — a rotation the
  /// user cannot see is wasted motion, and it would desync from the
  /// exposure tracker (which already stops metering off-screen).
  bool _backgrounded = false;

  String? _currentId;

  /// The tenant that queue-jumped on a fresh acknowledgment — its caption
  /// carries "· just now" for that one tenure.
  String? _jumpedId;

  /// activationCount per nudge id, for detecting re-runs (which jump the
  /// queue exactly like new banners: fresh copy is an acknowledgment).
  final Map<String, int> _seenActivations = {};

  /// The last rendered tenant order, so that when the current tenant leaves
  /// (dismissed, expired, superseded) the dock advances to its SUCCESSOR
  /// rather than rewinding to the first entry.
  List<String> _lastOrder = const [];

  bool _hovered = false;
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tenure.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Post-frame: the completion tick can arrive during another
        // animated widget's layout (the collapse SizeTransition) — a
        // synchronous setState here would re-dirty a render object inside
        // its own performLayout.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _advance();
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final backgrounded = state != AppLifecycleState.resumed;
    if (backgrounded == _backgrounded) return;
    _backgrounded = backgrounded;
    if (backgrounded) {
      _tenure.stop();
    } else if (!_hovered &&
        !_touched &&
        _visible(ref.read(activeGoalNudgesProvider).value).length > 1) {
      _tenure.forward();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tenure.dispose();
    super.dispose();
  }

  List<GoalBannerEntry> _visible(List<GoalBannerEntry>? raw) {
    // Same render-time contract as every banner surface: retained data
    // survives a failed background refresh, but stale copy never renders,
    // and locally dismissed ids stay suppressed.
    final now = clock.now();
    final locallyDismissed = ref.read(locallyDismissedNudgeIdsProvider);
    return [
      for (final entry in raw ?? const <GoalBannerEntry>[])
        if ((entry.nudge.staleAt == null ||
                now.isBefore(entry.nudge.staleAt!)) &&
            !locallyDismissed.contains(entry.nudge.id))
          entry,
    ];
  }

  void _advance() {
    final entries = _visible(ref.read(activeGoalNudgesProvider).value);
    if (entries.length <= 1) return;
    final currentIndex = entries.indexWhere(
      (e) => e.nudge.id == _currentId,
    );
    setState(() {
      _currentId = entries[(currentIndex + 1) % entries.length].nudge.id;
      _jumpedId = null;
    });
    _restartTenure(entries.length);
  }

  void _restartTenure(int tenantCount) {
    _tenure.reset();
    if (tenantCount > 1 && !_hovered && !_touched && !_backgrounded) {
      _tenure.forward();
    }
  }

  /// Reconciles rotation state against a new provider snapshot: adopts a
  /// first tenant, queue-jumps fresh acknowledgments, and advances off a
  /// tenant that disappeared (dismissal, supersession, staleness).
  void _reconcile(List<GoalBannerEntry> entries) {
    if (entries.isEmpty) {
      _currentId = null;
      _jumpedId = null;
      _seenActivations.clear();
      _tenure.stop();
      return;
    }
    String? jumpTo;
    // The very first snapshot after mount adopts entries without jumping —
    // cold start is rotation, not acknowledgment. Captured BEFORE the loop:
    // the map fills as we walk, and entry #2 must not read entry #1's
    // insertion as evidence the dock was already rotating.
    final coldStart = _seenActivations.isEmpty;
    for (final entry in entries) {
      final seen = _seenActivations[entry.nudge.id];
      // Entries are newest-first, so the FIRST jump-worthy match is the most
      // recent acknowledgment — keep it (`??=`) rather than letting an older
      // fresh banner later in the list overwrite it.
      if (seen != null && entry.nudge.activationCount > seen) {
        // A re-run's fresh copy is an acknowledgment — it takes the slot.
        jumpTo ??= entry.nudge.id;
      } else if (seen == null && !coldStart) {
        // A banner that appeared AFTER the dock was already rotating is a
        // fresh voice — it takes the slot.
        jumpTo ??= entry.nudge.id;
      }
      _seenActivations[entry.nudge.id] = entry.nudge.activationCount;
    }
    _seenActivations.removeWhere(
      (id, _) => !entries.any((e) => e.nudge.id == id),
    );
    if (jumpTo != null) {
      _currentId = jumpTo;
      _jumpedId = jumpTo;
      _restartTenure(entries.length);
      return;
    }
    final stillPresent = entries.any((e) => e.nudge.id == _currentId);
    if (!stillPresent) {
      // The tenant left (dismissed here or elsewhere): advance to its
      // SUCCESSOR in the last rendered order, not back to the first entry
      // — rewinding would replay a banner the user just moved past.
      _currentId =
          _successorOf(_currentId, entries)?.nudge.id ?? entries.first.nudge.id;
      _jumpedId = null;
      _restartTenure(entries.length);
    } else if (entries.length == 1) {
      // Fell to a lone tenant: it just sits, no cycle. (A new arrival takes
      // the jump path above; a released pause resumes via `_setPaused`; a
      // resumed app via the lifecycle hook — so no resume is needed here.)
      _tenure.stop();
    }
  }

  /// The entry after [removedId] in the last rendered order, skipping any
  /// that also left, and never landing back on [removedId] — the tenant
  /// that would have been next had the current one simply advanced.
  GoalBannerEntry? _successorOf(
    String? removedId,
    List<GoalBannerEntry> entries,
  ) {
    final from = _lastOrder.indexOf(removedId ?? '');
    if (from < 0) return null;
    for (var step = 1; step <= _lastOrder.length; step++) {
      final candidateId = _lastOrder[(from + step) % _lastOrder.length];
      if (candidateId == removedId) break;
      final match = entries.where((e) => e.nudge.id == candidateId);
      if (match.isNotEmpty) return match.first;
    }
    return null;
  }

  void _setPaused({bool? hovered, bool? touched}) {
    _hovered = hovered ?? _hovered;
    _touched = touched ?? _touched;
    if (_hovered || _touched) {
      _tenure.stop();
    } else if (!_tenure.isAnimating &&
        !_backgrounded &&
        _visible(ref.read(activeGoalNudgesProvider).value).length > 1) {
      _tenure.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(activeGoalNudgesProvider, (_, next) {
        setState(() => _reconcile(_visible(next.value)));
      })
      // Local dismissals bypass the async provider — reconcile on those too.
      ..listen(locallyDismissedNudgeIdsProvider, (_, _) {
        setState(
          () => _reconcile(_visible(ref.read(activeGoalNudgesProvider).value)),
        );
      });

    final tokens = context.designTokens;
    final entries = _visible(ref.watch(activeGoalNudgesProvider).value);

    // First build when the provider was ALREADY resolved (a cached value on
    // tab re-entry): `ref.listen` fires only on changes, so this adopts the
    // first tenant that the listener never saw arrive. Exercised only with a
    // pre-warmed provider, which widget tests don't reproduce.
    // coverage:ignore-start
    if (_currentId == null && entries.isNotEmpty) {
      _reconcile(entries);
    }
    // coverage:ignore-end

    final keyboardUp =
        widget.compact && MediaQuery.viewInsetsOf(context).bottom > 0;
    final current = entries.isEmpty
        ? null
        : entries.firstWhere(
            (e) => e.nudge.id == _currentId,
            // Transient guard (the orElse) for the frame between a removed
            // id landing on `_currentId` and the reconcile that fixes it.
            orElse: () => entries.first,
          );

    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // Remember the rendered order so the NEXT reconcile, when the current
    // tenant leaves, advances to its successor rather than rewinding.
    _lastOrder = [for (final e in entries) e.nudge.id];

    // Zero tenants (or the keyboard needs the space): collapse entirely.
    // The quiet IS the dismissal feedback.
    //
    // AnimatedSwitcher, not AnimatedSize: the dock subtree holds the
    // continuously-ticking tenure controller, and an AnimatedSize wrapping
    // it re-dirties itself mid-layout when that controller fires during its
    // own size animation. AnimatedSwitcher animates between the dock and an
    // empty box via a SizeTransition it owns, with no such reentrancy.
    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : MotionDurations.medium1,
      switchInCurve: MotionCurves.emphasizedDecelerate,
      switchOutCurve: MotionCurves.standard,
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        alignment: Alignment.topCenter,
        child: child,
      ),
      child: current == null || keyboardUp
          ? const SizedBox(key: ValueKey('dock-empty'), width: double.infinity)
          : KeyedSubtree(
              key: const ValueKey('dock-full'),
              child: _buildDock(
                context,
                tokens,
                entries,
                current,
                reduceMotion,
              ),
            ),
    );
  }

  Widget _buildDock(
    BuildContext context,
    DsTokens tokens,
    List<GoalBannerEntry> entries,
    GoalBannerEntry current,
    bool reduceMotion,
  ) {
    final style = goalBannerStyle(
      tone: current.nudge.brief.tone,
      accent: current.nudge.brief.accent,
      colors: tokens.colors,
      brightness: Theme.of(context).brightness,
    );
    final radius = BorderRadius.circular(tokens.radii.m);
    final multi = entries.length > 1;

    Widget tenant = _DockTenant(
      key: ValueKey(
        'dock-${current.nudge.id}-${current.nudge.activationCount}',
      ),
      entry: current,
      style: style,
      compact: widget.compact,
      justNow: _jumpedId == current.nudge.id,
      onDismiss: () => dismissGoalBanner(context, ref, current),
      onRate: () => showGoalBannerRatingSheet(context, ref, current),
    );

    if (widget.compact) {
      tenant = Dismissible(
        key: ValueKey('dock-swipe-${current.nudge.id}'),
        confirmDismiss: (_) => dismissGoalBanner(context, ref, current),
        child: tenant,
      );
    }

    return MouseRegion(
      onEnter: (_) => _setPaused(hovered: true),
      onExit: (_) => _setPaused(hovered: false),
      child: Listener(
        onPointerDown: (_) => _setPaused(touched: true),
        onPointerUp: (_) => _setPaused(touched: false),
        onPointerCancel: (_) => _setPaused(touched: false),
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.step3),
          child: Material(
            color: style.fill,
            borderRadius: radius,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: style.border),
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tenure progress hairline: the rotation made visible.
                    // Only meaningful with someone waiting in the queue. A
                    // CustomPaint (repaint-only) rather than a
                    // FractionallySizedBox — a per-tick relayout inside the
                    // collapse AnimatedSwitcher's SizeTransition would
                    // re-dirty it mid-layout.
                    SizedBox(
                      height: tokens.spacing.step1,
                      width: double.infinity,
                      child: multi
                          ? CustomPaint(
                              painter: _TenurePainter(
                                progress: _tenure,
                                color: style.accent,
                              ),
                            )
                          : null,
                    ),
                    AnimatedSwitcher(
                      duration: reduceMotion
                          ? Duration.zero
                          : MotionDurations.medium1,
                      switchInCurve: MotionCurves.emphasizedDecelerate,
                      switchOutCurve: MotionCurves.standard,
                      transitionBuilder: (child, animation) => reduceMotion
                          // Crossfade under reduced motion; slide-up is
                          // the standard transition between tenants.
                          ? FadeTransition(opacity: animation, child: child)
                          : FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.25),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            ),
                      child: tenant,
                    ),
                    if (multi)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: tokens.spacing.step2,
                        ),
                        // Decorative — the tenant's own content carries the
                        // semantics; dots would only add noise for readers.
                        child: ExcludeSemantics(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (final entry in entries) ...[
                                Container(
                                  width: tokens.spacing.step2,
                                  height: tokens.spacing.step2,
                                  margin: EdgeInsets.symmetric(
                                    horizontal: tokens.spacing.step1,
                                  ),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: entry.nudge.id == current.nudge.id
                                        ? style.accent
                                        : tokens.colors.background.level03,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the tenure progress fill left-to-right. Repaints on every tick of
/// [progress] without triggering a relayout — the collapse
/// AnimatedSwitcher's SizeTransition must never be re-dirtied inside its own
/// layout pass.
class _TenurePainter extends CustomPainter {
  _TenurePainter({required this.progress, required this.color})
    : super(repaint: progress);

  final Animation<double> progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width * progress.value.clamp(0.0, 1.0);
    if (width <= 0) return;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, size.height),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_TenurePainter oldDelegate) => oldDelegate.color != color;
}

/// One tenant's condensed row: chip · headline/caption · CTA · star · X.
class _DockTenant extends ConsumerWidget {
  const _DockTenant({
    required this.entry,
    required this.style,
    required this.compact,
    required this.justNow,
    required this.onDismiss,
    required this.onRate,
    super.key,
  });

  final GoalBannerEntry entry;
  final GoalBannerStyle style;
  final bool compact;
  final bool justNow;
  final VoidCallback onDismiss;
  final VoidCallback onRate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final brief = entry.nudge.brief;
    final ratingDue = GoalNudgeInteractions.ratingDue(entry.nudge);
    final caption = justNow
        ? '${entry.goalTitle} · ${context.messages.goalDockJustNow}'
        : entry.goalTitle;

    return GoalBannerExposureTracker(
      nudgeId: entry.nudge.id,
      child: InkWell(
        onTap: () => beamToNamed('/agents/details/${entry.nudge.agentId}'),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.cardPadding,
            vertical: tokens.spacing.step3,
          ),
          child: Row(
            children: [
              GoalBannerPersonaChip.forStyle(
                monogram: GoalBannerPersonaChip.monogramFor(entry.goalTitle),
                style: style,
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      brief.headline,
                      maxLines: compact ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.typography.styles.subtitle.subtitle2
                          .copyWith(
                            color: tokens.colors.text.highEmphasis,
                          ),
                    ),
                    Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ],
                ),
              ),
              if (!compact && brief.cta != null) ...[
                SizedBox(width: tokens.spacing.step3),
                // Flexible so a long CTA is bounded by the row and its own
                // ellipsis actually engages — a bare Row child would be
                // measured at full intrinsic width and overflow the dock.
                Flexible(
                  child: GoalBannerCtaPill(
                    label: brief.cta!,
                    style: style,
                    onTap: () =>
                        beamToNamed('/agents/details/${entry.nudge.agentId}'),
                  ),
                ),
              ],
              if (!compact)
                SizedBox(
                  width: TapTargets.minimum,
                  height: TapTargets.minimum,
                  child: ratingDue
                      ? IconButton(
                          onPressed: onRate,
                          tooltip: context.messages.goalBannerRateTooltip,
                          icon: Icon(
                            Icons.star_outline_rounded,
                            size: tokens.spacing.step5,
                            color: tokens.colors.text.lowEmphasis,
                          ),
                        )
                      : null,
                ),
              SizedBox(
                width: TapTargets.minimum,
                height: TapTargets.minimum,
                child: IconButton(
                  onPressed: onDismiss,
                  tooltip: context.messages.goalBannerDismissTooltip,
                  icon: Icon(
                    Icons.close_rounded,
                    size: tokens.spacing.step5,
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

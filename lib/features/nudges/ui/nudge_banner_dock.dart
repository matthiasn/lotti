import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/design_system/components/ds_quiet_ink.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/nudges/logic/nudge_banner_snooze.dart';
import 'package:lotti/features/nudges/logic/nudge_private_copy.dart';
import 'package:lotti/features/nudges/model/nudge_banner_entry.dart';
import 'package:lotti/features/nudges/service/nudge_interactions.dart';
import 'package:lotti/features/nudges/state/nudge_banner_providers.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_actions.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_animated_text.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_dock_swipe.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_exposure_tracker.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_quiet_actions.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_style.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_widgets.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

/// How long one banner holds the dock before the rotation advances — long
/// enough to read the copy twice and act, short enough that three tenants
/// cycle fully within a minute (design handover 1b).
const nudgeBannerDockTenure = Duration(seconds: 15);

/// Applies the render-time visibility contract shared by the dock and the
/// shell lane that reserves space for it, including the per-kind surface
/// gate (ADR 0059 Decision 6): an entry whose kind does not speak on
/// [surface] is not visible there, whatever its own state says. A null
/// [surface] skips the gate — subject-owned pages (a goal's detail page)
/// list their own banners regardless of shell surface.
List<NudgeBannerEntry> visibleNudgeBannerEntries({
  required Iterable<NudgeBannerEntry>? entries,
  required Map<String, NudgeBannerLocalSuppression> locallySnoozedDeadlines,
  required NudgeBannerSurface? surface,
  DateTime? now,
}) {
  final instant = now ?? clock.now();
  bool isLocallySuppressed(NudgeBannerEntry entry) {
    final suppression = locallySnoozedDeadlines[entry.nudge.id];
    return suppression != null &&
        suppression.activation == entry.nudge.activationCount &&
        suppression.until.isAfter(instant);
  }

  return [
    for (final entry in entries ?? const <NudgeBannerEntry>[])
      if ((surface == null || nudgeKindShowsOn(entry.kind, surface)) &&
          (entry.nudge.staleAt == null ||
              instant.isBefore(entry.nudge.staleAt!)) &&
          !nudgeBannerIsSnoozed(entry.nudge, instant) &&
          !nudgeBannerIsDismissedForDay(entry.nudge, instant) &&
          !isLocallySuppressed(entry))
        entry,
  ];
}

/// When [entry] returns to the SHELL dock, or null while it is eligible now.
///
/// Snoozes and day dismissals quiet the rotating dock only — the subject's own
/// page (a goal's detail page, a person's page) always shows its current
/// banner, captioned with this deadline as a countdown, so "where did my
/// banner go" is answered on the page that owns it. Considers the durable
/// snooze, the durable rest-of-day dismissal (until the next local midnight)
/// and this device's optimistic local echo, returning the LATEST active
/// deadline.
DateTime? nudgeBannerShellHiddenUntil(
  NudgeBannerEntry entry, {
  required Map<String, NudgeBannerLocalSuppression> locallySnoozedDeadlines,
  DateTime? now,
}) {
  final instant = now ?? clock.now();
  DateTime? latest;
  void consider(DateTime? candidate) {
    if (candidate == null || !candidate.isAfter(instant)) return;
    if (latest == null || candidate.isAfter(latest!)) latest = candidate;
  }

  if (nudgeBannerIsSnoozed(entry.nudge, instant)) {
    consider(nudgeBannerSnoozedUntil(entry.nudge));
  }
  if (nudgeBannerIsDismissedForDay(entry.nudge, instant)) {
    consider(nudgeBannerNextLocalMidnight(instant));
  }
  final suppression = locallySnoozedDeadlines[entry.nudge.id];
  if (suppression != null &&
      suppression.activation == entry.nudge.activationCount) {
    consider(suppression.until);
  }
  return latest;
}

/// The dock — one rotating slot for the agents' standing voices, the
/// "now playing" bar of the banner channel (design handover 1b).
///
/// One fixed-height region cycles every standing banner round-robin,
/// [nudgeBannerDockTenure] per tenant, with ONE shared rotation state: the
/// shell mounts a single dock instance that survives tab switches. Rules:
///
/// - a freshly refreshed banner (a completion acknowledgment) jumps the
///   queue — the check-off → fresh-copy loop is the feature's best moment;
/// - the cycle pauses while hovered or touched (the WCAG pause affordance —
///   auto-advance continues under reduced motion, only transitions change);
/// - snooze removes the tenant temporarily and advances immediately;
/// - with a single tenant there are no dots, no tenure hairline and no
///   auto-advance — it just sits;
/// - with zero tenants the dock collapses entirely: the disappearance IS
///   the visibility-action feedback (no toast or confirmation snackbar).
///
/// Exposure metering rides the existing tracker: a docked tenant is visible
/// whenever the app is foregrounded, so tenure ≈ real screen time — exactly
/// what the rating/reuse loop needs.
class NudgeBannerDock extends ConsumerStatefulWidget {
  const NudgeBannerDock({
    required this.compact,
    required this.surface,
    super.key,
  });

  /// Phone layout: the goal banner card's grammar at phone width — identity
  /// and the quiet actions on the caption row, the headline beneath, the CTA
  /// pill flush left under it.
  final bool compact;

  /// The navigation surface this mount lives on; the dock filters its
  /// tenants per kind (ADR 0059 Decision 6).
  final NudgeBannerSurface surface;

  @override
  ConsumerState<NudgeBannerDock> createState() => _NudgeBannerDockState();
}

class _NudgeBannerDockState extends ConsumerState<NudgeBannerDock>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _tenure = AnimationController(
    vsync: this,
    duration: nudgeBannerDockTenure,
  );

  /// The cycle pauses while the app is not foregrounded — a rotation the
  /// user cannot see is wasted motion, and it would desync from the
  /// exposure tracker (which already stops metering off-screen).
  bool _backgrounded = false;

  String? _currentId;

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
  void didUpdateWidget(NudgeBannerDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surface == widget.surface) return;
    // The shell mounts ONE dock and swaps its surface as tabs change, so a
    // surface whose kinds are all filtered out (People, until a relationship
    // agent ships) empties the dock without any provider event. Without a
    // reconcile here the tenure would run out on that surface, `_advance`
    // would bail on the empty list without restarting it, and the rotation
    // would stay dead after returning to a surface that does have tenants.
    setState(() => _reconcile(_visible(ref.read(activeNudgeBannersProvider))));
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
        _visible(ref.read(activeNudgeBannersProvider)).length > 1) {
      _tenure.forward();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tenure.dispose();
    super.dispose();
  }

  List<NudgeBannerEntry> _visible(List<NudgeBannerEntry>? raw) {
    // Same render-time contract as every banner surface: retained data
    // survives a failed background refresh, but stale copy never renders,
    // and locally hidden ids stay suppressed.
    return visibleNudgeBannerEntries(
      entries: raw,
      locallySnoozedDeadlines: ref.read(locallySnoozedNudgeDeadlinesProvider),
      surface: widget.surface,
    );
  }

  void _advance() {
    final entries = _visible(ref.read(activeNudgeBannersProvider));
    if (entries.length <= 1) return;
    final currentIndex = entries.indexWhere((e) => e.nudge.id == _currentId);
    setState(() {
      _currentId = entries[(currentIndex + 1) % entries.length].nudge.id;
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
  void _reconcile(List<NudgeBannerEntry> entries) {
    if (entries.isEmpty) {
      _currentId = null;
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
  NudgeBannerEntry? _successorOf(
    String? removedId,
    List<NudgeBannerEntry> entries,
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

  /// Pauses the rotation while the pointer rests on the dock or a finger
  /// holds it, and hands the banner a whole new tenure on release.
  ///
  /// The countdown is rewound, not frozen: a hairline stuck part-way told
  /// nobody the rotation had stopped, and resuming it there let the dock
  /// advance a moment after the pointer left — taking the banner away just
  /// as the user turned to act on it. An empty hairline is the visible
  /// pause, and the time to read starts over when it ends.
  void _setPaused({bool? hovered, bool? touched}) {
    final wasPaused = _hovered || _touched;
    _hovered = hovered ?? _hovered;
    _touched = touched ?? _touched;
    final paused = _hovered || _touched;
    if (paused == wasPaused) return;
    _restartTenure(_visible(ref.read(activeNudgeBannersProvider)).length);
  }

  /// Shows the banner [id] by the user's own hand — a dot, a swipe — with
  /// a fresh tenure, which stays paused while the hand is still on the dock.
  void _show(String id) {
    if (id == _currentId) return;
    setState(() => _currentId = id);
    _restartTenure(_visible(ref.read(activeNudgeBannersProvider)).length);
  }

  /// Moves [offset] banners along the rotation, wrapping at either end.
  void _step(int offset) {
    final entries = _visible(ref.read(activeNudgeBannersProvider));
    if (entries.length <= 1) return;
    final index = entries.indexWhere((e) => e.nudge.id == _currentId);
    _show(entries[(index + offset) % entries.length].nudge.id);
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(activeNudgeBannersProvider, (_, next) {
        setState(() => _reconcile(_visible(next)));
      })
      ..listen(locallySnoozedNudgeDeadlinesProvider, (_, _) {
        setState(
          () => _reconcile(_visible(ref.read(activeNudgeBannersProvider))),
        );
      });

    final tokens = context.designTokens;
    final entries = _visible(ref.watch(activeNudgeBannersProvider));

    // First build when the provider was ALREADY resolved (a cached value on
    // tab re-entry): `ref.listen` fires only on changes, so this adopts the
    // first tenant that the listener never saw arrive. Exercised only with a
    // pre-warmed provider, which widget tests don't reproduce.
    // coverage:ignore-start
    if (_currentId == null && entries.isNotEmpty) {
      _reconcile(entries);
    }
    // coverage:ignore-end

    final current = entries.isEmpty
        ? null
        : entries.firstWhere(
            (e) => e.nudge.id == _currentId,
            // Transient guard (the orElse) for the frame between a removed
            // id landing on `_currentId` and the reconcile that fixes it.
            orElse: () => entries.first, // coverage:ignore-line
          );

    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // Remember the rendered order so the NEXT reconcile, when the current
    // tenant leaves, advances to its successor rather than rewinding.
    _lastOrder = [for (final e in entries) e.nudge.id];

    // Zero tenants: collapse entirely. The quiet IS the visibility-action
    // feedback.
    //
    // AnimatedSwitcher, not AnimatedSize: the dock subtree holds the
    // continuously-ticking tenure controller, and an AnimatedSize wrapping
    // it re-dirties itself mid-layout when that controller fires during its
    // own size animation. AnimatedSwitcher animates between the dock and an
    // empty box via a SizeTransition it owns, with no such reentrancy.
    return SizedBox(
      width: double.infinity,
      child: AnimatedSwitcher(
        duration: reduceMotion ? Duration.zero : MotionDurations.medium1,
        switchInCurve: MotionCurves.emphasizedDecelerate,
        switchOutCurve: MotionCurves.standard,
        transitionBuilder: (child, animation) => SizeTransition(
          sizeFactor: animation,
          alignment: Alignment.topCenter,
          child: child,
        ),
        child: current == null
            ? const SizedBox(
                key: ValueKey('dock-empty'),
                width: double.infinity,
              )
            : SizedBox(
                key: const ValueKey('dock-full'),
                width: double.infinity,
                child: _buildDock(
                  context,
                  tokens,
                  entries,
                  current,
                  reduceMotion,
                ),
              ),
      ),
    );
  }

  Widget _buildDock(
    BuildContext context,
    DsTokens tokens,
    List<NudgeBannerEntry> entries,
    NudgeBannerEntry current,
    bool reduceMotion,
  ) {
    final style = nudgeBannerStyle(
      tone: current.nudge.brief.tone,
      accent: current.nudge.brief.accent,
      colors: tokens.colors,
      brightness: Theme.of(context).brightness,
    );
    // The card's radius: the strip and the card are one banner at two
    // widths, and share one frame.
    final radius = BorderRadius.circular(tokens.radii.l);
    final multi = entries.length > 1;

    final tenant = SizedBox(
      key: ValueKey(
        'dock-${current.nudge.id}-${current.nudge.activationCount}',
      ),
      width: double.infinity,
      child: _DockTenant(
        entry: current,
        style: style,
        compact: widget.compact,
        onSnooze: () => showNudgeBannerSnoozeSheet(context, ref, current),
        onRate: () => showNudgeBannerRatingSheet(context, ref, current),
      ),
    );

    final card = Material(
      color: style.fill,
      borderRadius: radius,
      child: Ink(
        key: const ValueKey('nudge-banner-dock-frame'),
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: style.border),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            children: [
              AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : MotionDurations.medium1,
                switchInCurve: MotionCurves.emphasizedDecelerate,
                switchOutCurve: MotionCurves.standard,
                transitionBuilder: (child, animation) => reduceMotion
                    // Crossfade under reduced motion; slide-up is the
                    // standard transition between tenants.
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
              // Tenure progress hairline: the rotation made visible, only
              // with someone waiting in the queue, and empty while the
              // rotation is paused. It overlays the tenant's top edge. A
              // CustomPaint (repaint-only) rather than a
              // FractionallySizedBox — a per-tick relayout inside the
              // collapse AnimatedSwitcher's SizeTransition would re-dirty it
              // mid-layout. A true hairline, at rest strength: the rotation
              // is chrome, the current dot below already marks progress at
              // linework, and the strip's entry corner must not be its most
              // saturated accent.
              if (multi)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: BorderWidths.hairline,
                  child: CustomPaint(
                    painter: _TenurePainter(
                      progress: _tenure,
                      color: style.accent.withValues(
                        alpha: SurfaceAlphas.muted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    // The whole carousel — the card and its dots — is one hover region, one
    // hold and one swipe surface: resting on the dots to pick a banner must
    // not let the rotation move the banner out from under the pointer.
    return MouseRegion(
      onEnter: (_) => _setPaused(hovered: true),
      onExit: (_) => _setPaused(hovered: false),
      child: Listener(
        onPointerDown: (_) => _setPaused(touched: true),
        onPointerUp: (_) => _setPaused(touched: false),
        onPointerCancel: (_) => _setPaused(touched: false),
        child: NudgeBannerDockSwipe(
          enabled: multi,
          onNext: () => _step(1),
          onPrevious: () => _step(-1),
          child: Padding(
            // With dots, the bottom inset is the dot row's own: its hit
            // boxes are taller than the dots, and their slack below the dot
            // matches the gap above it.
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.step3,
              tokens.spacing.step3,
              tokens.spacing.step3,
              multi ? 0 : tokens.spacing.step3,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                card,
                // Below the card, not inside it: overlaid on the tenant's
                // bottom inset the dots crowded the CTA and read as part of
                // the banner's copy. A second tenant arriving therefore
                // grows the dock by the dot row — once, as the queue forms.
                if (multi)
                  _DockPager(
                    entries: entries,
                    currentId: current.nudge.id,
                    accent: style.accent,
                    onSelect: _show,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The dots under the dock: where the current banner sits in the rotation,
/// and a way to go straight to any other.
///
/// Each dot is a button on a `step6`-square hit box (24 dp) — the WCAG
/// 2.2 minimum target size — named for the banner it shows, so a screen
/// reader or a keyboard reaches every banner without waiting out the
/// rotation. Larger targets would put a 48 dp row under every queue; a touch
/// user has the swipe as well.
class _DockPager extends StatelessWidget {
  const _DockPager({
    required this.entries,
    required this.currentId,
    required this.accent,
    required this.onSelect,
  });

  final List<NudgeBannerEntry> entries;
  final String currentId;
  final Color accent;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final hitBox = tokens.spacing.step6;
    // A Wrap, not a Row: the queue has no upper bound, and a row of 24 dp
    // targets runs off a narrow phone after a dozen banners, stranding the
    // outer ones. Wrapped, every dot stays on screen and reachable.
    return Wrap(
      key: const ValueKey('nudge-banner-dock-pager'),
      alignment: WrapAlignment.center,
      children: [
        for (final (index, entry) in entries.indexed)
          Semantics(
            // Keyed on the direct child, by banner: when the queue gains,
            // loses or reorders a banner, each button — and the focus node
            // its ink owns — follows its banner instead of being rebuilt in
            // place, so keyboard focus survives a background refresh.
            key: ValueKey('nudge-banner-dock-dot-${entry.nudge.id}'),
            button: true,
            selected: entry.nudge.id == currentId,
            label: context.messages.nudgeBannerDockPageLabel(
              index + 1,
              entries.length,
            ),
            child: DsQuietInk(
              borderRadius: BorderRadius.circular(hitBox),
              focusRing: true,
              onTap: () => onSelect(entry.nudge.id),
              builder: (context, highlighted) => SizedBox.square(
                dimension: hitBox,
                child: Center(
                  child: _TenureDot(
                    current: entry.nudge.id == currentId,
                    highlighted: highlighted,
                    accent: accent,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One pagination dot. The current tenant is a filled disc, the queued ones
/// rings — position is carried by shape as well as strength, so it survives
/// the light theme's pale tint and a reader who does not resolve alpha. Both
/// stay below the CTA's full accent: the disc at linework, the rings at rest,
/// and a ring the pointer or focus rests on at linework too — the answer to
/// "can I click this" that a dot has no other way to give.
class _TenureDot extends StatelessWidget {
  const _TenureDot({
    required this.current,
    required this.highlighted,
    required this.accent,
  });

  final bool current;
  final bool highlighted;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // Large enough for a hairline ring to read as hollow at 1×.
    return Container(
      width: tokens.spacing.step3,
      height: tokens.spacing.step3,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: current
            ? accent.withValues(alpha: SurfaceAlphas.linework)
            : null,
        border: current
            ? null
            : Border.all(
                color: accent.withValues(
                  alpha: highlighted
                      ? SurfaceAlphas.linework
                      : SurfaceAlphas.muted,
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

/// One tenant of the dock.
///
/// Wide: identity · copy · CTA · quiet actions on one line, the copy taking
/// whatever the intrinsic controls leave. Compact: the goal banner card's
/// grammar at phone width — identity and the quiet actions share the
/// caption row, the headline runs full width beneath, and the CTA sits flush
/// left under it — so the phone strip is the card, not a third layout.
///
/// The body is a quiet doorway to the conversation (`DsQuietInk`, as on the
/// card): Material's hover overlay washed the whole strip like one enormous
/// button, while the CTA pill is the element that advertises pressability.
class _DockTenant extends ConsumerWidget {
  const _DockTenant({
    required this.entry,
    required this.style,
    required this.compact,
    required this.onSnooze,
    required this.onRate,
  });

  final NudgeBannerEntry entry;
  final NudgeBannerStyle style;
  final bool compact;
  final VoidCallback onSnooze;
  final VoidCallback onRate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final brief = nudgeDisplayBrief(
      entry.nudge,
      showPrivate: ref.watch(configFlagProvider(privateFlag)).value ?? false,
    );
    final ratingDue = NudgeInteractions.ratingDue(entry.nudge);
    void open() => openNudgeBanner(context, ref, entry);

    // The same identity language as the full banner card: the persona chip
    // and the subject's name, so the voice in the dock is never anonymous —
    // a nudge only makes sense as SOME subject's nudge. Excluded from
    // semantics: the enclosing node already announces the subject via the
    // per-kind semantic label, and merging these in would read the name
    // (and monogram) twice before the headline.
    final chip = ExcludeSemantics(
      child: NudgeBannerPersonaChip.forStyle(
        monogram: NudgeBannerPersonaChip.monogramFor(entry.subjectTitle),
        style: style,
      ),
    );
    final caption = ExcludeSemantics(
      child: Text(
        entry.subjectTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: tokens.typography.styles.others.caption.copyWith(
          color: tokens.colors.text.mediumEmphasis,
        ),
      ),
    );
    // The card's headline tier, so the two renderings speak with one voice.
    final headline = NudgeBannerAnimatedText(
      text: brief.headline,
      animation: brief.animation,
      maxLines: null,
      style: tokens.typography.styles.subtitle.subtitle1.copyWith(
        color: tokens.colors.text.highEmphasis,
      ),
    );
    // CTA copy is contractually 2–4 words. Kept intrinsic so it cannot
    // claim a flex share and arbitrarily cap the banner copy.
    final cta = brief.cta == null
        ? null
        : NudgeBannerCtaPill(label: brief.cta!, style: style, onTap: open);
    final actions = NudgeBannerQuietActions(
      ratingDue: ratingDue,
      compact: compact,
      snoozeKey: const ValueKey('nudge-banner-dock-snooze'),
      onRate: onRate,
      onSnooze: onSnooze,
    );

    final Widget body;
    if (compact) {
      // One interval everywhere (the card's rhythm). The 48dp action row
      // carries step3 of slack around its glyphs, the headline a line's
      // leading, the pill its floor's slack: a step2 top inset, a step1 gap
      // and step4 before the pill all render as the same measure as the
      // bottom cardPadding, once that slack is counted.
      body = Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.cardPadding,
          tokens.spacing.step2,
          tokens.spacing.cardPadding,
          tokens.spacing.cardPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                chip,
                SizedBox(width: tokens.spacing.step3),
                Expanded(child: caption),
                actions,
              ],
            ),
            SizedBox(height: tokens.spacing.step1),
            headline,
            if (cta != null) ...[SizedBox(height: tokens.spacing.step4), cta],
          ],
        ),
      );
    } else {
      body = Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.cardPadding,
          vertical: tokens.spacing.step3,
        ),
        child: Row(
          children: [
            chip,
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              key: const ValueKey('nudge-banner-copy-region'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [caption, headline],
              ),
            ),
            // Clearly wider than the quiet pair's own rhythm (Snooze pulls
            // its label outward by its inset, which widens the pair's gap),
            // so the row reads as one action plus two quiet controls, not
            // three peers.
            if (cta != null) ...[SizedBox(width: tokens.spacing.step4), cta],
            SizedBox(width: tokens.spacing.step6),
            actions,
          ],
        ),
      );
    }

    return NudgeBannerExposureTracker(
      nudgeId: entry.nudge.id,
      child: Semantics(
        container: true,
        label: switch (entry.kind) {
          NudgeBannerKind.goal => context.messages.goalBannerSemanticLabel(
            entry.subjectTitle,
          ),
          NudgeBannerKind.relationship =>
            context.messages.relationshipBannerSemanticLabel(
              entry.subjectTitle,
            ),
        },
        child: DsQuietInk(
          key: const ValueKey('nudge-banner-dock-tenant'),
          borderRadius: BorderRadius.circular(tokens.radii.l),
          focusRing: true,
          onTap: open,
          // Touch pauses the rotation while held; a hold that ends must not
          // then count as the tap that opens (or, for a relationship
          // reminder, pauses) the banner. Owning the long press makes the
          // release a no-op.
          onLongPress: () {},
          builder: (context, highlighted) => body,
        ),
      ),
    );
  }
}

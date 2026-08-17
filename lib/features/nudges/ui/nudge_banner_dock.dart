import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/nudges/logic/nudge_banner_snooze.dart';
import 'package:lotti/features/nudges/model/nudge_banner_entry.dart';
import 'package:lotti/features/nudges/service/nudge_interactions.dart';
import 'package:lotti/features/nudges/state/nudge_banner_providers.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_actions.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_animated_text.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_exposure_tracker.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_style.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_widgets.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

/// How long one banner holds the dock before the rotation advances — long
/// enough to read the copy twice and act, short enough that three tenants
/// cycle fully within a minute (design handover 1b).
const nudgeBannerDockTenure = Duration(seconds: 15);

/// Height of [lines] lines rendered in [style] at [scaler] — measured from
/// the actual text metrics so the dock reserve tracks the real typography
/// rather than a magic constant.
double _textBlockHeight(TextStyle style, int lines, TextScaler scaler) {
  final painter = TextPainter(
    text: TextSpan(text: 'Xg', style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    maxLines: 1,
  )..layout();
  return painter.height * lines;
}

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

/// Clearance the compact (mobile) dock claims above the bottom bar when a
/// banner is speaking — the shell reserves it in the overlay-height scope so
/// page content and FABs never sit underneath (handover 1b's reserved lane).
///
/// Derived entirely from the dock's own design-system dimensions and text
/// styles, and scale-aware. The tenant row is as tall as the taller of the
/// [TapTargets.minimum] visibility-action target and the tallest active authored
/// headline, measured at the dock's real compact width and current
/// [MediaQuery.textScalerOf]. The dock never caps the headline. Around it sits
/// the chrome — outer padding (`step3` both edges), the tenure-strip slot
/// (`step1`), the tenant's own vertical padding (`step3` both edges) — and the
/// multi-tenant dot-row footer
/// (`step2` dot + `step2` bottom padding), always included so a two-plus-tenant
/// dock never under-clears. `nudge_banner_dock_test.dart` asserts the reserve
/// covers the actual rendered dock at 1× and 2×, single- and multi-tenant.
/// Collapses to zero reserve when no banner speaks (the caller only adds it
/// while the dock is speaking).
double nudgeBannerDockReservedHeight(
  BuildContext context, {
  required Iterable<NudgeBrief> briefs,
}) {
  final tokens = context.designTokens;
  final spacing = tokens.spacing;
  final scaler = MediaQuery.textScalerOf(context);
  final animationsDisabled = MediaQuery.disableAnimationsOf(context);
  final activeBriefs = briefs.toList(growable: false);
  final multi = activeBriefs.length > 1;
  final chrome =
      spacing.step3 * 4 + // outer + tenant vertical padding, both edges
      spacing.step1; // tenure-strip slot
  final footer = multi
      ? spacing.step2 *
            2 // dot row + its bottom padding
      : 0;
  // The persona chip scales with text size (see [NudgeBannerPersonaChip]).
  final chipSize = spacing.step6 * scaler.scale(1);
  final reservedHorizontally =
      spacing.step3 * 2 + // outer dock padding
      spacing.cardPadding + // tenant leading padding
      chipSize + // persona chip
      spacing.step3 + // chip → copy gap
      spacing.step2 + // tenant trailing padding
      TapTargets.minimum; // snooze target
  final measuredWidth = MediaQuery.sizeOf(context).width - reservedHorizontally;
  final availableWidth = measuredWidth > 0 ? measuredWidth : 0.0;
  // The subject-title caption rides above every headline (one ellipsized line).
  final captionLine = _textBlockHeight(
    tokens.typography.styles.others.caption,
    1,
    scaler,
  );
  var textBlock = 0.0;
  for (final brief in activeBriefs) {
    final height =
        captionLine +
        (brief.animation == NudgeBannerAnimation.marquee && !animationsDisabled
            ? _textBlockHeight(
                tokens.typography.styles.subtitle.subtitle2,
                1,
                scaler,
              )
            : (TextPainter(
                text: TextSpan(
                  text: brief.headline,
                  style: tokens.typography.styles.subtitle.subtitle2,
                ),
                textDirection: Directionality.of(context),
                textScaler: scaler,
              )..layout(maxWidth: availableWidth)).height);
    if (height > textBlock) textBlock = height;
  }
  // The row is as tall as its tallest occupant: the copy column, the
  // visibility-action tap target, or the scale-grown persona chip.
  var row = textBlock > TapTargets.minimum ? textBlock : TapTargets.minimum;
  if (chipSize > row) row = chipSize;
  // A `step1` cushion absorbs sub-pixel rounding between TextPainter and the
  // rendered animation wrapper.
  return chrome + footer + row + spacing.step1;
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
///   the visibility-action feedback (no toast or confirmation snackbar);
/// - on phones the dock yields while the keyboard is up.
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

  /// Phone layout: complete animated headline and compact snooze control.
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
      locallySnoozedDeadlines: ref.read(
        locallySnoozedNudgeDeadlinesProvider,
      ),
      surface: widget.surface,
    );
  }

  void _advance() {
    final entries = _visible(ref.read(activeNudgeBannersProvider));
    if (entries.length <= 1) return;
    final currentIndex = entries.indexWhere(
      (e) => e.nudge.id == _currentId,
    );
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

  void _setPaused({bool? hovered, bool? touched}) {
    _hovered = hovered ?? _hovered;
    _touched = touched ?? _touched;
    if (_hovered || _touched) {
      _tenure.stop();
    } else if (!_tenure.isAnimating &&
        !_backgrounded &&
        _visible(ref.read(activeNudgeBannersProvider)).length > 1) {
      _tenure.forward();
    }
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

    final keyboardUp =
        widget.compact && MediaQuery.viewInsetsOf(context).bottom > 0;
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

    // Zero tenants (or the keyboard needs the space): collapse entirely.
    // The quiet IS the visibility-action feedback.
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
        child: current == null || keyboardUp
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
    final radius = BorderRadius.circular(tokens.radii.m);
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
              key: const ValueKey('nudge-banner-dock-frame'),
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

/// One tenant's condensed row: complete animated headline · actions · X.
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
    final brief = entry.nudge.brief;
    final ratingDue = NudgeInteractions.ratingDue(entry.nudge);

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
        child: InkWell(
          key: const ValueKey('nudge-banner-dock-tenant'),
          onTap: () => beamToNamed(entry.tapRoute),
          child: Padding(
            padding: EdgeInsets.only(
              left: tokens.spacing.cardPadding,
              top: tokens.spacing.step3,
              right: tokens.spacing.step2,
              bottom: tokens.spacing.step3,
            ),
            child: Row(
              children: [
                // The same identity language as the full banner card: the
                // persona chip and the subject's name, so the voice in the
                // dock is never anonymous — a nudge only makes sense as SOME
                // subject's nudge. Excluded from semantics: the enclosing
                // node already announces the subject via the per-kind
                // semantic label, and merging these in would read the name
                // (and monogram) twice before the headline.
                ExcludeSemantics(
                  child: NudgeBannerPersonaChip.forStyle(
                    monogram: NudgeBannerPersonaChip.monogramFor(
                      entry.subjectTitle,
                    ),
                    style: style,
                  ),
                ),
                SizedBox(width: tokens.spacing.step3),
                Expanded(
                  key: const ValueKey('nudge-banner-copy-region'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExcludeSemantics(
                        child: Text(
                          entry.subjectTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.typography.styles.others.caption
                              .copyWith(
                                color: tokens.colors.text.mediumEmphasis,
                              ),
                        ),
                      ),
                      NudgeBannerAnimatedText(
                        text: brief.headline,
                        animation: brief.animation,
                        maxLines: null,
                        style: tokens.typography.styles.subtitle.subtitle2
                            .copyWith(
                              color: tokens.colors.text.highEmphasis,
                            ),
                      ),
                    ],
                  ),
                ),
                if (!compact && brief.cta != null) ...[
                  SizedBox(width: tokens.spacing.step3),
                  // CTA copy is contractually 2–4 words. Keep it intrinsic so
                  // it cannot claim a flex share and arbitrarily cap the banner
                  // copy at half the dock.
                  NudgeBannerCtaPill(
                    label: brief.cta!,
                    style: style,
                    onTap: () => beamToNamed(entry.tapRoute),
                  ),
                ],
                if (!compact)
                  SizedBox(
                    width: TapTargets.minimum,
                    height: TapTargets.minimum,
                    child: ratingDue
                        ? IconButton(
                            onPressed: onRate,
                            tooltip: context.messages.nudgeBannerRateTooltip,
                            icon: Icon(
                              Icons.star_outline_rounded,
                              size: tokens.spacing.step5,
                              color: tokens.colors.text.lowEmphasis,
                            ),
                          )
                        : null,
                  ),
                DesignSystemButton(
                  key: const ValueKey('nudge-banner-dock-snooze'),
                  label: compact ? '' : context.messages.nudgeBannerSnoozeLabel,
                  semanticsLabel: context.messages.nudgeBannerSnoozeLabel,
                  leadingIcon: Icons.snooze_rounded,
                  size: DesignSystemButtonSize.dense,
                  tapTargetSize: MaterialTapTargetSize.padded,
                  onPressed: onSnooze,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;
import 'package:lotti/ui/app_fonts.dart';

/// Test hook used by widget tests to invoke the indicator's tap action
/// without depending on the live router. Has no instances — its only
/// purpose is to namespace the static [navigatorOverride] hook.
@visibleForTesting
abstract final class SyncActivityIndicatorTestHooks {
  /// Override the navigation callback the indicator triggers on tap.
  /// Setting to `null` restores the default `beamToNamed` behaviour.
  static void Function(String path)? navigatorOverride;
}

/// Route the indicator navigates to on tap. Lands on the Sync
/// Settings landing page (Settings → Sync), where the user can drill
/// into the outbox monitor, queue depth, backfill, and sync stats.
const String kSyncOutboxRoute = '/settings/sync';

/// Hold duration for an LED flash. Per the design handoff the LED is
/// on for roughly 140 ms per packet, then fades to its idle state.
const Duration kSyncActivityLedHold = Duration(milliseconds: 140);

/// LED active background colors. Sourced directly from the design
/// handoff in `docs/design/README.md` (variant D4a) — the spec calls
/// these out as intentionally outside the normal `--fg-*` ramp because
/// the indicator must read quieter than disabled text. The TX amber
/// has no design-system equivalent (the closest token, `warning`, is
/// far more saturated) so it stays as a literal pending a token
/// decision; RX is `interactive.enabled` and the focus ring follows
/// it (resolved from the active theme at build time).
const Color kSyncActivityTxColor = Color(0xFFC99A4E); // muted amber

/// Pure-white-with-alpha values for the muted "ambient awareness, not
/// notification" feel. The handoff calls for these to stay quieter
/// than the softest design-system text token (64% white), so they are
/// intentionally below the existing token ramp.
const Color _ledIdle = Color(0x1AFFFFFF); // 10% white
const Color _labelColor = Color(0x4DFFFFFF); // 30% white
const Color _valueActive = Color(0x8CFFFFFF); // 55% white
const Color _valueIdle = Color(0x52FFFFFF); // 32% white
const Color _hoverWash = Color(0x0AFFFFFF); // 4% white

/// Ambient sidebar indicator showing live Matrix sync traffic. A single
/// monospace row (`• tx 0   • rx 0`) with two 5×5 LEDs that flash
/// briefly per packet committed on the matching channel.
///
/// Variant **D4a** in `docs/design/`. Visual semantics — colors,
/// timings, LED sizes — stay pinned to the handoff. The row layout was
/// adopted later (sidebar Wake Queue handoff, S1) so the indicator can
/// sit at the very bottom of the rail without claiming two lines.
///
/// The numeric slot for each channel is fixed-width so the row never
/// reflows as the queue depths grow or shrink — the LED, label and
/// trailing tab stop stay anchored to the same x-coordinate even when
/// the value rolls over between e.g. `9` and `99`.
class SyncActivityIndicator extends ConsumerStatefulWidget {
  const SyncActivityIndicator({super.key});

  @override
  ConsumerState<SyncActivityIndicator> createState() =>
      _SyncActivityIndicatorState();
}

class _SyncActivityIndicatorState extends ConsumerState<SyncActivityIndicator> {
  bool _txOn = false;
  bool _rxOn = false;
  bool _hovered = false;
  Timer? _txTimer;
  Timer? _rxTimer;

  @override
  void dispose() {
    _txTimer?.cancel();
    _rxTimer?.cancel();
    super.dispose();
  }

  void _flashTx() {
    if (!mounted) return;
    setState(() => _txOn = true);
    _txTimer?.cancel();
    _txTimer = Timer(kSyncActivityLedHold, () {
      if (!mounted) return;
      setState(() => _txOn = false);
    });
  }

  void _flashRx() {
    if (!mounted) return;
    setState(() => _rxOn = true);
    _rxTimer?.cancel();
    _rxTimer = Timer(kSyncActivityLedHold, () {
      if (!mounted) return;
      setState(() => _rxOn = false);
    });
  }

  void _handleTap() {
    final override = SyncActivityIndicatorTestHooks.navigatorOverride;
    if (override != null) {
      override(kSyncOutboxRoute);
      return;
    }
    // Switch to the Settings tab AND beam the inner Settings Beamer
    // delegate to the Sync sub-route. Going through the global
    // `beamToNamed` helper alone races with the IndexedStack mount
    // cycle when the user is currently on a different tab — by the
    // time the Settings Beamer mounts it has fallen back to its
    // `/settings` initial path, so the user lands on Settings instead
    // of Settings → Sync. The two-step pattern matches the project
    // detail page's category-deep-link flow.
    final navService = getIt<NavService>();
    navService.tapIndex(navService.settingsIndex);
    navService.settingsDelegate.beamToNamed(kSyncOutboxRoute);
    unawaited(navService.persistNamedRoute(kSyncOutboxRoute));
  }

  @override
  Widget build(BuildContext context) {
    // ref.listen handles the subscription lifecycle and reacts to
    // provider overrides automatically — preferable to the manual
    // initState subscription, which would stay tied to whatever
    // provider instance was current when the widget first mounted.
    ref
      ..listen<AsyncValue<DateTime>>(syncActivityTxPulsesProvider, (_, next) {
        if (next is AsyncData<DateTime>) _flashTx();
      })
      ..listen<AsyncValue<DateTime>>(syncActivityRxPulsesProvider, (_, next) {
        if (next is AsyncData<DateTime>) _flashRx();
      });

    final outbox = ref.watch(outboxPendingCountProvider).value ?? 0;
    final inbox = ref.watch(inboundQueueDepthProvider).value ?? 0;
    final semanticsLabel = context.messages.syncActivityIndicatorSemantics(
      outbox,
      inbox,
    );

    // RX dot and focus ring follow the active theme's interactive
    // accent (`#5ED4B7` in dark mode), so they read consistently with
    // every other primary affordance in the sidebar.
    final rxColor = context.designTokens.colors.interactive.enabled;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Semantics(
        button: true,
        label: semanticsLabel,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowHoverHighlight: (hovered) {
            if (!mounted) return;
            setState(() => _hovered = hovered);
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _handleTap();
                return null;
              },
            ),
          },
          child: Builder(
            builder: (context) {
              final focused = Focus.of(context).hasFocus;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _handleTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _hovered ? _hoverWash : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    // Always render a 2 px border and toggle its color
                    // on focus — keeps the strip's outer dimensions
                    // stable so neighbouring rows don't jump on
                    // focus-in / focus-out.
                    border: Border.all(
                      color: focused ? rxColor : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SyncActivityChannel(
                        label: 'tx',
                        on: _txOn,
                        color: kSyncActivityTxColor,
                        value: outbox,
                      ),
                      const SizedBox(width: 12),
                      _SyncActivityChannel(
                        label: 'rx',
                        on: _rxOn,
                        color: rxColor,
                        value: inbox,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Width reserved for the numeric column on each channel. Wide enough to
/// fit a 4-digit count without forcing the surrounding row to reflow —
/// the value is right-aligned inside this fixed slot, so the LED and
/// label keep their x-positions even when the count grows or shrinks.
const double _kSyncActivityValueColumnWidth = 28;

class _SyncActivityChannel extends StatelessWidget {
  const _SyncActivityChannel({
    required this.label,
    required this.on,
    required this.color,
    required this.value,
  });

  final String label;
  final bool on;
  final Color color;
  final int value;

  @override
  Widget build(BuildContext context) {
    final valueStyle =
        AppFonts.inconsolata(
          fontSize: 10,
          fontWeight: FontWeight.w400,
          color: value > 0 ? _valueActive : _valueIdle,
          letterSpacing: 0.3,
        ).copyWith(
          fontFeatures: numericBadgeFontFeatures,
          height: 1.4,
        );
    final labelStyle = AppFonts.inconsolata(
      fontSize: 10,
      fontWeight: FontWeight.w400,
      color: _labelColor,
      letterSpacing: 0.3,
    ).copyWith(height: 1.4);

    return SizedBox(
      height: 14,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SyncActivityLed(on: on, color: color),
          const SizedBox(width: 6),
          ExcludeSemantics(child: Text(label, style: labelStyle)),
          const SizedBox(width: 6),
          // Fixed-width numeric slot — the value is right-aligned so the
          // LED + label stay anchored regardless of digit count.
          SizedBox(
            width: _kSyncActivityValueColumnWidth,
            child: ExcludeSemantics(
              child: Text(
                value > 0 ? '$value' : '',
                style: valueStyle,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.clip,
                softWrap: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncActivityLed extends StatelessWidget {
  const _SyncActivityLed({required this.on, required this.color});

  final bool on;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        color: on ? color : _ledIdle,
        shape: BoxShape.circle,
        boxShadow: on
            ? [
                BoxShadow(
                  color: color,
                  blurRadius: 5,
                ),
              ]
            : null,
      ),
    );
  }
}

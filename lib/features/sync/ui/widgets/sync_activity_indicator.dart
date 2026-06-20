import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;

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

/// Hold duration for an LED flash. The LED is on for roughly 140 ms per
/// packet, then fades to its idle state.
const Duration kSyncActivityLedHold = Duration(milliseconds: 140);

/// Ambient sidebar footer showing live Matrix sync traffic: two quiet
/// Inter rows (`• Outbox` / `• Inbox`, localized) whose small LEDs flash on
/// the brand teal accent per packet committed on the matching channel, and
/// whose numeric count appears only when that queue is non-empty.
///
/// The treatment deliberately matches the rest of the sidebar — Inter
/// type, design-system text colors, and the teal `interactive.enabled`
/// accent (no monospace, no off-token amber) — so it reads as a calm part
/// of the rail rather than a terminal readout. It is quiet at rest (dim
/// neutral dots, no counts) and only "speaks" colour/numbers when there is
/// actually a queue to drain.
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
    final outboxLabel = context.messages.syncActivityOutboxLabel;
    final inboxLabel = context.messages.syncActivityInboxLabel;

    final tokens = context.designTokens;
    // Both channels flash on the brand teal accent and the focus ring
    // follows it, so the footer reads consistently with every other
    // affordance in the sidebar. State is carried by brightness + count,
    // not by a second hue.
    final accent = tokens.colors.interactive.enabled;
    final ledIdle = tokens.colors.decorative.level01;
    final hoverWash = tokens.colors.surface.enabled;

    return Semantics(
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
                // Align the LED column to the same left inset as the nav
                // icons and the activity-well glyphs above.
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step5,
                  vertical: tokens.spacing.step2,
                ),
                decoration: BoxDecoration(
                  color: _hovered ? hoverWash : Colors.transparent,
                  borderRadius: BorderRadius.circular(tokens.radii.s),
                  // Always render a 2 px border and toggle its color
                  // on focus — keeps the strip's outer dimensions
                  // stable so neighbouring rows don't jump on
                  // focus-in / focus-out.
                  border: Border.all(
                    color: focused ? accent : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  // Left-align so the Outbox/Inbox rows share one left edge.
                  // (Their widths differ now that the labels are words and one
                  // carries a count; the default centring indented the
                  // narrower row.)
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SyncActivityChannel(
                      label: outboxLabel,
                      on: _txOn,
                      color: accent,
                      idleColor: ledIdle,
                      value: outbox,
                    ),
                    _SyncActivityChannel(
                      label: inboxLabel,
                      on: _rxOn,
                      color: accent,
                      idleColor: ledIdle,
                      value: inbox,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SyncActivityChannel extends StatelessWidget {
  const _SyncActivityChannel({
    required this.label,
    required this.on,
    required this.color,
    required this.idleColor,
    required this.value,
  });

  final String label;
  final bool on;
  final Color color;
  final Color idleColor;
  final int value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final valueStyle = tokens.typography.styles.others.caption.copyWith(
      color: value > 0
          ? tokens.colors.text.mediumEmphasis
          : tokens.colors.text.lowEmphasis,
      fontFeatures: numericBadgeFontFeatures,
    );
    final labelStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );

    return SizedBox(
      height: 18,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SyncActivityLed(on: on, color: color, idleColor: idleColor),
          const SizedBox(width: 8),
          ExcludeSemantics(child: Text(label, style: labelStyle)),
          // Count sits inline after the label and only when the queue is
          // non-empty — it is the last element in the row, so it can grow to
          // any digit count without clipping or shifting the LED + label.
          if (value > 0) ...[
            const SizedBox(width: 6),
            ExcludeSemantics(child: Text('$value', style: valueStyle)),
          ],
        ],
      ),
    );
  }
}

class _SyncActivityLed extends StatelessWidget {
  const _SyncActivityLed({
    required this.on,
    required this.color,
    required this.idleColor,
  });

  final bool on;
  final Color color;
  final Color idleColor;

  @override
  Widget build(BuildContext context) {
    // No glow/boxShadow — the colour swap alone carries the packet flash,
    // keeping the footer free of peripheral motion-noise.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: on ? color : idleColor,
        shape: BoxShape.circle,
      ),
    );
  }
}

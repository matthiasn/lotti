import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/ui/app_fonts.dart';

/// Test hook used by widget tests to invoke the indicator's tap action
/// without depending on the live router.
@visibleForTesting
class SyncActivityIndicatorTestHooks {
  const SyncActivityIndicatorTestHooks._();

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
/// the indicator must read quieter than disabled text.
const Color kSyncActivityTxColor = Color(0xFFC99A4E); // muted amber
const Color kSyncActivityRxColor = Color(0xFF5ED4B7); // Lotti teal-light

const Color _ledIdle = Color(0x1AFFFFFF); // 10% white
const Color _labelColor = Color(0x4DFFFFFF); // 30% white
const Color _valueActive = Color(0x8CFFFFFF); // 55% white
const Color _valueIdle = Color(0x52FFFFFF); // 32% white
const Color _hoverWash = Color(0x0AFFFFFF); // 4% white
const Color _focusRing = Color(0xFF5ED4B7); // matches Lotti teal-light

/// Ambient sidebar indicator showing live Matrix sync traffic. Two
/// stacked monospace rows (`tx <count>` / `rx <count>`) each with a
/// 5×5 LED that flashes briefly per packet committed on that channel.
///
/// Variant **D4a** in `docs/design/`. Visual semantics — colors,
/// timings, sizes — are pinned to the handoff and reproduced
/// pixel-for-pixel.
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
  ProviderSubscription<AsyncValue<DateTime>>? _txSub;
  ProviderSubscription<AsyncValue<DateTime>>? _rxSub;

  @override
  void initState() {
    super.initState();
    // listenManual lets us subscribe outside of build() so each pulse
    // (a new AsyncData emission from the stream provider) triggers
    // exactly one LED flash regardless of how often the widget rebuilds.
    _txSub = ref.listenManual<AsyncValue<DateTime>>(
      syncActivityTxPulsesProvider,
      (_, next) {
        if (next is AsyncData<DateTime>) _flashTx();
      },
    );
    _rxSub = ref.listenManual<AsyncValue<DateTime>>(
      syncActivityRxPulsesProvider,
      (_, next) {
        if (next is AsyncData<DateTime>) _flashRx();
      },
    );
  }

  @override
  void dispose() {
    _txTimer?.cancel();
    _rxTimer?.cancel();
    _txSub?.close();
    _rxSub?.close();
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
    beamToNamed(kSyncOutboxRoute);
  }

  @override
  Widget build(BuildContext context) {
    final outbox = ref.watch(outboxPendingCountProvider).value ?? 0;
    final inbox = ref.watch(inboundQueueDepthProvider).value ?? 0;
    final semanticsLabel = context.messages.syncActivityIndicatorSemantics(
      outbox,
      inbox,
    );

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
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _hovered ? _hoverWash : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: focused
                        ? Border.all(color: _focusRing, width: 2)
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SyncActivityRow(
                        label: 'tx',
                        on: _txOn,
                        color: kSyncActivityTxColor,
                        value: outbox,
                      ),
                      const SizedBox(height: 3),
                      _SyncActivityRow(
                        label: 'rx',
                        on: _rxOn,
                        color: kSyncActivityRxColor,
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

class _SyncActivityRow extends StatelessWidget {
  const _SyncActivityRow({
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
          fontFeatures: const [FontFeature.tabularFigures()],
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
          SizedBox(
            width: 14,
            child: ExcludeSemantics(child: Text(label, style: labelStyle)),
          ),
          const SizedBox(width: 6),
          if (value > 0)
            ExcludeSemantics(
              child: Text(
                '$value',
                style: valueStyle,
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

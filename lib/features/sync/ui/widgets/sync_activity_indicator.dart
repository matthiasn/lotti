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

/// Ambient sidebar footer showing Matrix sync as one compact status control.
///
/// Healthy sync is intentionally just an icon and label. Queue counts appear
/// only while work exists, keeping transport telemetry subordinate to global
/// navigation while preserving a one-click route to detailed diagnostics.
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
    final hasWork = outbox > 0 || inbox > 0 || _txOn || _rxOn;
    final semanticsLabel = context.messages.syncActivityIndicatorSemantics(
      outbox,
      inbox,
    );
    final tokens = context.designTokens;
    final accent = tokens.colors.interactive.enabled;
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
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step4,
                  vertical: tokens.spacing.step3,
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
                    width: tokens.spacing.step1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.sync_rounded,
                      size: tokens.spacing.step5,
                      color: hasWork ? accent : tokens.colors.text.lowEmphasis,
                    ),
                    SizedBox(width: tokens.spacing.step3),
                    Expanded(
                      child: ExcludeSemantics(
                        child: Text(
                          hasWork
                              ? context.messages.syncActivitySyncingTitle
                              : context.messages.syncActivityTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.typography.styles.others.caption
                              .copyWith(
                                color: tokens.colors.text.mediumEmphasis,
                                fontWeight: tokens.typography.weight.semiBold,
                              ),
                        ),
                      ),
                    ),
                    if (outbox > 0)
                      _QueueMetric(
                        icon: Icons.arrow_upward_rounded,
                        value: _formatQueueCount(outbox),
                      ),
                    if (outbox > 0 && inbox > 0)
                      SizedBox(width: tokens.spacing.step3),
                    if (inbox > 0)
                      _QueueMetric(
                        icon: Icons.arrow_downward_rounded,
                        value: _formatQueueCount(inbox),
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

String _formatQueueCount(int value) => value > 999 ? '999+' : '$value';

class _QueueMetric extends StatelessWidget {
  const _QueueMetric({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: tokens.spacing.step4,
            color: tokens.colors.text.lowEmphasis,
          ),
          SizedBox(width: tokens.spacing.step1),
          Text(
            value,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
              fontFeatures: numericBadgeFontFeatures,
            ),
          ),
        ],
      ),
    );
  }
}

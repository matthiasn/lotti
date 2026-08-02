import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/callouts/design_system_inline_callout.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/sync/models/pairing_check_code.dart';
import 'package:lotti/features/sync/models/sync_device_info.dart';
import 'package:lotti/features/sync/onboarding/onboarding_sync_service.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/state/sync_devices_provider.dart';
import 'package:lotti/features/sync/ui/clipboard_helper.dart';
import 'package:lotti/features/sync/ui/re_sync_modal.dart';
import 'package:lotti/features/sync/ui/sync_modal.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/pairing_check_code_view.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/sync_sticky_bar.dart';
import 'package:lotti/features/sync/ui/widgets/sync_well.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// How often the roster is re-fetched while the sheet waits for the new device
/// to appear. Nothing else pushes that state, so without a poll the "waiting"
/// stop would never resolve.
const Duration kAddDevicePollInterval = Duration(seconds: 5);

/// Consecutive failed roster fetches before the sheet stops pretending to wait.
/// One miss is a flaky request; three in a row is a problem worth reporting.
const int kAddDeviceMaxPollFailures = 3;

/// Card width at which the code and its details sit side by side rather than
/// stacked. Below it a phone column would cramp both.
const double kAddDeviceWideCard = 420;

/// Width the detail column needs beside the code. Its widest child is a button
/// label, and the joining device's manual screen names that label, so it must
/// not ellipsise.
const double kAddDeviceDetailsMin = 250;

/// Vertical space the QR must leave for everything that shares its viewport:
/// the sheet header, the heading and intro, the pairing card's own padding,
/// and the pinned bar.
///
/// The sheet scrolls, but the QR is the one artifact that must render whole
/// at rest — a code sliced by the pinned bar is unscannable and reads as a
/// broken app, which is exactly what happened at 1280×700. The regression
/// test pins the no-overlap guarantee at that size.
const double kAddDeviceQrViewportOverhead = 440;

/// What the inviting sheet is waiting on, shared between the scroll body and
/// the pinned bar. The bar is built outside the view's `State`, and the live
/// signal has to live there: on a phone the body's own status strip can sit
/// below the fold, so a caption pointing "above" pointed at nothing.
enum AddDeviceJoinState { waiting, joined, ready, rosterFailed }

/// The one object the scroll body and the pinned bar share: the live state,
/// plus the retry that only the body knows how to perform (it owns the poll
/// timer and the consecutive-failure count).
class AddDeviceJoinSignal extends ValueNotifier<AddDeviceJoinState> {
  AddDeviceJoinSignal() : super(AddDeviceJoinState.waiting);

  /// Set by the body once it is mounted; read by the bar's error row.
  VoidCallback? onRetry;

  /// Exact Matrix target discovered and verified by this onboarding sheet.
  OnboardingSyncTarget? target;
}

/// The deliberate "hand this account to another device" act.
///
/// The handover payload is a live credential, so it is minted on demand here
/// rather than rendered wherever the sync settings happen to be open. Every
/// paired device can present it — a surviving phone must be able to onboard a
/// replacement for a dead desktop.
class AddDeviceModal {
  static Future<void> show(BuildContext context) {
    final joinState = AddDeviceJoinSignal();
    return ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.syncAddDeviceAction,
      // Clears the sticky bar, which would otherwise cover the last block.
      padding:
          WoltModalConfig.pagePadding +
          EdgeInsets.only(
            bottom:
                context.designTokens.spacing.step13 +
                context.designTokens.spacing.step10,
          ),
      stickyActionBarBuilder: (_) => AddDeviceActionBar(signal: joinState),
      builder: (_) => AddDeviceView(signal: joinState),
    ).whenComplete(joinState.dispose);
  }
}

/// The hand-off actions, pinned to the sheet so they are reachable without
/// scrolling past the QR — the joining device's own instructions send the
/// user here.
///
/// Both actions stay visibly locked until the device that joined through this
/// sheet has completed emoji verification, and the caption says why. That
/// ordering matches Matrix key sharing: before verification the new device
/// has ciphertext, but no keys to read it.
class AddDeviceActionBar extends StatelessWidget {
  const AddDeviceActionBar({
    required this.signal,
    super.key,
    this.onSendMessages,
    this.onSendSettings,
  });

  /// What the body is waiting on, and how to retry looking. Drives the
  /// caption and whether the actions unlock.
  final AddDeviceJoinSignal signal;

  /// Test seam for the settings hand-off; defaults to opening [SyncModal].
  final Future<void> Function(BuildContext context)? onSendSettings;

  /// Test seam for the message-history hand-off; defaults to opening
  /// [ReSyncModal].
  final Future<void> Function(BuildContext context)? onSendMessages;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    return ValueListenableBuilder<AddDeviceJoinState>(
      valueListenable: signal,
      builder: (context, state, _) {
        final enabled = state == AddDeviceJoinState.ready;
        final sendSettings = DesignSystemButton(
          key: const Key('add_device_send_settings'),
          label: messages.syncAddDeviceSendSettings,
          // Accent whenever it actually works. Not `secondary` for the
          // locked case: its enabled fill is the same token the component
          // paints a *disabled* filled button with, so a live action read
          // as inert. `outlined` drops its border when disabled, so the
          // two can never be confused. The lock glyph carries the "not
          // yet" story without a paragraph.
          variant: enabled
              ? DesignSystemButtonVariant.primary
              : DesignSystemButtonVariant.outlined,
          size: DesignSystemButtonSize.large,
          leadingIcon: enabled ? Icons.sync_alt_rounded : Icons.lock_outline,
          onPressed: enabled
              ? () => unawaited(
                  (onSendSettings ?? SyncModal.show)(context),
                )
              : null,
        );
        final sendMessages = DesignSystemButton(
          key: const Key('add_device_send_messages'),
          label: messages.syncAddDeviceSendMessages,
          variant: DesignSystemButtonVariant.outlined,
          size: DesignSystemButtonSize.large,
          leadingIcon: enabled ? Icons.history_rounded : Icons.lock_outline,
          onPressed: enabled
              ? () => unawaited(
                  onSendMessages?.call(context) ??
                      ReSyncModal.show(
                        context,
                        onboardingTarget: signal.target,
                      ),
                )
              : null,
        );

        final caption = _BarCaption(state: state, onRetry: signal.onRetry);

        return SyncStickyBar(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= kAddDeviceWideCard) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: sendSettings),
                        SizedBox(width: tokens.spacing.step3),
                        Expanded(child: sendMessages),
                      ],
                    ),
                    SizedBox(height: tokens.spacing.step2),
                    caption,
                  ],
                );
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  sendSettings,
                  SizedBox(height: tokens.spacing.step3),
                  sendMessages,
                  SizedBox(height: tokens.spacing.step2),
                  caption,
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// The pinned bar's one explanatory line: why the actions are locked, that
/// the device has joined, that everything is ready — or that the roster
/// cannot be read at all, with the retry.
class _BarCaption extends StatelessWidget {
  const _BarCaption({required this.state, required this.onRetry});

  final AddDeviceJoinState state;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final caption = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );

    switch (state) {
      case AddDeviceJoinState.ready:
        return Row(
          key: const Key('add_device_ready'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.verified_user_rounded,
              size: IconSizes.xs,
              color: tokens.colors.alert.success.defaultColor,
            ),
            SizedBox(width: tokens.spacing.step2),
            Flexible(
              child: Text(
                messages.syncAddDeviceSendSettingsReady,
                textAlign: TextAlign.center,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
            ),
          ],
        );
      case AddDeviceJoinState.joined:
        return Text(
          messages.syncAddDeviceConnected,
          key: const Key('add_device_joined'),
          textAlign: TextAlign.center,
          style: caption,
        );
      case AddDeviceJoinState.rosterFailed:
        // A Wrap, not a Row: the error line plus the retry pill exceed a
        // narrow bar by a hair, and an inflexible row clips where this can
        // simply break onto a second run.
        return Wrap(
          key: const Key('add_device_poll_failed'),
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: tokens.spacing.step2,
          runSpacing: tokens.spacing.step2,
          children: [
            Text(
              messages.syncAddDeviceRosterError,
              textAlign: TextAlign.center,
              style: caption,
            ),
            DesignSystemButton(
              key: const Key('add_device_poll_retry'),
              label: messages.provisionedSyncRetry,
              variant: DesignSystemButtonVariant.outlined,
              onPressed: onRetry,
            ),
          ],
        );
      case AddDeviceJoinState.waiting:
        return Text(
          messages.syncAddDeviceUnlockHint,
          key: const Key('add_device_send_settings_pending'),
          textAlign: TextAlign.center,
          style: caption,
        );
    }
  }
}

class AddDeviceView extends ConsumerStatefulWidget {
  const AddDeviceView({
    super.key,
    this.signal,
    this.pollInterval = kAddDevicePollInterval,
  });

  /// Shared with the pinned bar, which is built outside this widget's `State`
  /// and still has to render the caption and its retry.
  final AddDeviceJoinSignal? signal;

  /// Test seam for the roster poll that drives the waiting state.
  final Duration pollInterval;

  @override
  ConsumerState<AddDeviceView> createState() => _AddDeviceViewState();
}

class _AddDeviceViewState extends ConsumerState<AddDeviceView> {
  String? _handover;
  String? _checkCode;
  String? _localUserId;
  bool _loading = true;
  bool _revealed = false;

  /// True when minting the code threw, as opposed to there being no sync
  /// config to mint one from. The remedies differ: retry versus set sync up.
  bool _generateFailed = false;

  /// The sessions already on the account when this sheet opened, keyed by
  /// user *and* device: ids are only unique within a Matrix user, and the
  /// roster deliberately spans users so legacy one-account-per-device pairings
  /// still show up. Keyed on the device id alone, a new device whose id
  /// collided with any foreign user's would read as already known and the
  /// sheet would never latch.
  Set<String>? _knownDeviceIds;
  String? _newDeviceIdentity;
  bool _joined = false;
  bool _ready = false;
  int _pollFailures = 0;
  bool _pollInFlight = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    widget.signal?.onRetry = _retryPolling;
    unawaited(_generate());
  }

  @override
  void dispose() {
    _poll?.cancel();
    widget.signal?.onRetry = null;
    super.dispose();
  }

  Future<void> _generate() async {
    if (mounted) setState(() => _loading = true);
    String? data;
    String? check;
    var failed = false;
    try {
      data = await ref
          .read(provisioningControllerProvider.notifier)
          .regenerateHandover();

      // Derived from the same account and room the code carries, so the
      // joining device computes the identical value from its decoded bundle.
      final service = ref.read(matrixServiceProvider);
      final config = await service.loadConfig();
      final roomId = service.syncRoomId;
      _localUserId = config?.user;
      if (config != null && roomId != null) {
        check = pairingCheckCode(
          user: config.user,
          roomId: roomId,
          homeServer: config.homeServer,
        );
      }
    } catch (e, stackTrace) {
      // Launched with `unawaited`, so without this the exception escapes to
      // the zone — and the finally branch would meanwhile render "set up sync
      // on this device first", a misdiagnosis on a device that is set up.
      failed = true;
      getIt<DomainLogger>().error(
        LogDomain.sync,
        e,
        stackTrace: stackTrace,
        subDomain: 'addDeviceGenerate',
      );
    } finally {
      if (mounted) {
        setState(() {
          _handover = data;
          _checkCode = check;
          _generateFailed = failed;
          _loading = false;
        });
        if (data != null) _startPolling();
      }
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _pollFailures = 0;
    _poll = Timer.periodic(widget.pollInterval, (_) {
      if (!mounted || _ready) return;
      unawaited(_pollOnce());
    });
  }

  /// One roster fetch, counting consecutive failures. Without this the stop
  /// spins "Waiting for the new device…" forever against a dead homeserver.
  ///
  /// Serialized: a fetch slower than the interval used to overlap the next
  /// tick, so a struggling homeserver got *more* concurrent load the worse it
  /// performed, and the failure count could advance more than once per round
  /// trip.
  Future<void> _pollOnce() async {
    if (_pollInFlight) return;
    _pollInFlight = true;
    final bool succeeded;
    try {
      succeeded = await ref
          .read(syncDevicesControllerProvider.notifier)
          .refresh();
    } finally {
      _pollInFlight = false;
    }
    if (!mounted) return;
    setState(() {
      _pollFailures = succeeded ? 0 : _pollFailures + 1;
    });
    // Once the bar has given up and offered Retry, stop asking on a timer:
    // continuing to poll a homeserver that has failed three times running
    // changes nothing on screen and only adds load. Retry restarts it.
    if (_pollFailures >= kAddDeviceMaxPollFailures) _poll?.cancel();
    _publishJoinState();
  }

  void _retryPolling() {
    setState(() => _pollFailures = 0);
    _publishJoinState();
    _startPolling();
    unawaited(_pollOnce());
  }

  /// Mirrors the body's state onto the notifier the pinned bar listens to.
  /// Deferred: callers reach this from `build`, and the bar rebuilds on it.
  void _publishJoinState() {
    final notifier = widget.signal;
    if (notifier == null) return;
    final next = _ready
        ? AddDeviceJoinState.ready
        : _pollFailures >= kAddDeviceMaxPollFailures
        ? AddDeviceJoinState.rosterFailed
        : _joined
        ? AddDeviceJoinState.joined
        : AddDeviceJoinState.waiting;
    if (notifier.value == next) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) notifier.value = next;
    });
  }

  /// Latches on the first device identity that was not present when the sheet
  /// opened, then follows that exact device until Matrix reports it verified.
  /// An older peer must never unlock the transfer actions for the new target.
  ///
  /// Derived during build rather than via `setState`: the value is a pure
  /// function of the roster this widget already watches, and it only ever
  /// moves forward, so no extra frame is needed to show it.
  /// Identity of a roster row: device ids are unique only within a user.
  static String _rosterIdentity(SyncDeviceInfo device) =>
      '${device.userId ?? 'self'}/${device.deviceId}';

  void _observeRoster(List<SyncDeviceInfo> devices) {
    if (_ready) return;
    final identities = devices.map(_rosterIdentity).toList(growable: false);
    final known = _knownDeviceIds;
    if (known == null) {
      _knownDeviceIds = identities.toSet();
      return;
    }

    for (final identity in identities) {
      if (!known.contains(identity)) {
        _newDeviceIdentity ??= identity;
        break;
      }
    }
    final targetIdentity = _newDeviceIdentity;
    if (targetIdentity == null) return;

    if (!_joined) {
      _joined = true;
      _publishJoinState();
    }

    for (final device in devices) {
      if (_rosterIdentity(device) == targetIdentity && device.verified) {
        final userId = device.userId ?? _localUserId;
        if (userId == null) return;
        widget.signal?.target = OnboardingSyncTarget(
          userId: userId,
          deviceId: device.deviceId,
        );
        _ready = true;
        _poll?.cancel();
        _publishJoinState();
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    if (_loading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: tokens.spacing.step10),
          child: const DesignSystemSpinner(),
        ),
      );
    }

    final handover = _handover;
    if (handover == null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.step6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _generateFailed
                  ? messages.syncAddDeviceGenerateFailed
                  : messages.syncAddDeviceUnavailable,
              key: const Key('add_device_unavailable'),
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
            SizedBox(height: tokens.spacing.step4),
            DesignSystemButton(
              key: const Key('add_device_regenerate'),
              label: messages.provisionedSyncRetry,
              variant: DesignSystemButtonVariant.outlined,
              onPressed: () => unawaited(_generate()),
            ),
          ],
        ),
      );
    }

    final devices = ref.watch(syncDevicesControllerProvider).value;
    if (devices != null) {
      _observeRoster(devices);
    }

    final checkCode = _checkCode;
    final joinState = _ready
        ? AddDeviceJoinState.ready
        : _joined
        ? AddDeviceJoinState.joined
        : AddDeviceJoinState.waiting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          messages.syncAddDeviceStepScanTitle,
          style: tokens.typography.styles.heading.heading3,
        ),
        SizedBox(height: tokens.spacing.step2),
        Text(
          messages.syncAddDeviceIntro,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step4),
        // The handshake is the hero: QR and check code live in one pairing
        // card that can never be separated — which is also how the phone
        // clipping defect dies. The check code sits inside the card, above
        // the pinned bar, at every height.
        SyncWell(
          radius: tokens.radii.sectionCards,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (checkCode != null) ...[
                    PairingCheckCodeView(
                      code: checkCode,
                      label: messages.syncPairCheckCodeLabel,
                      caption: messages.syncPairCheckCode,
                      codeKey: const Key('add_device_check_code'),
                      centered: constraints.maxWidth < kAddDeviceWideCard,
                    ),
                    SizedBox(height: tokens.spacing.step4),
                  ],
                  _CodeRow(
                    data: handover,
                    revealed: _revealed,
                    onToggle: () => setState(() => _revealed = !_revealed),
                  ),
                ],
              );

              // Side by side once the card is wide enough. That is what pays
              // for the larger code a desktop needs: stacked, a code sized for
              // a camera across a desk pushed the no-camera fallback — the
              // only route this screen offers a device without one — under
              // the pinned bar.
              if (constraints.maxWidth >= kAddDeviceWideCard) {
                // Budget the detail column first and give the code what is
                // left: sizing the code by a share and clamping it let the
                // floor win at the dialog's actual width, starving the column
                // and ellipsising the very control the joining device names.
                //
                // The quiet zone counts. `side` is the image; _QrCard pads it
                // by step3 on each side, so the card occupies `side + 2·step3`
                // and budgeting as though it were `side` overspent by exactly
                // that much.
                final widthBudget =
                    (constraints.maxWidth -
                            kAddDeviceDetailsMin -
                            tokens.spacing.step5 -
                            tokens.spacing.step3 * 2)
                        .clamp(180.0, 300.0);
                // The height budget is what stops the pinned bar slicing the
                // code on a short window: the width formula alone sized the
                // QR for the dialog's width and let a 1280×700 screen cut it
                // mid-symbol. The floor keeps it scannable; below that the
                // page scrolls rather than shrinking the code further.
                final heightBudget =
                    (MediaQuery.sizeOf(context).height -
                            kAddDeviceQrViewportOverhead)
                        .clamp(160.0, 300.0);
                final side = math.min(widthBudget, heightBudget);
                return Row(
                  children: [
                    _QrCard(data: handover, side: side),
                    SizedBox(width: tokens.spacing.step5),
                    Expanded(child: details),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _QrCard(data: handover),
                  SizedBox(height: tokens.spacing.step4),
                  details,
                ],
              );
            },
          ),
        ),
        SizedBox(height: tokens.spacing.step4),
        // Under the credential it concerns. Warning tone, deliberately —
        // this is a live credential on screen, and de-toned to grey it was
        // quieter than the buttons offering to copy it.
        DesignSystemInlineCallout(
          key: const Key('add_device_security_note'),
          icon: Icons.lock_outline_rounded,
          text: messages.syncAddDeviceSecurityNote,
        ),
        SizedBox(height: tokens.spacing.step5),
        // The wait, narrated as a timeline the account fills in: waiting,
        // joined, verified. The bar below only explains the locked actions.
        _JoinTimeline(state: joinState),
      ],
    );
  }
}

/// The three stops of the inviting side's wait, with the live one pulsing.
class _JoinTimeline extends StatelessWidget {
  const _JoinTimeline({required this.state});

  final AddDeviceJoinState state;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    // rosterFailed pauses the *poll*, not the journey: the stops keep their
    // last honest reading while the bar explains the retry.
    final reached = switch (state) {
      AddDeviceJoinState.waiting || AddDeviceJoinState.rosterFailed => 0,
      AddDeviceJoinState.joined => 1,
      AddDeviceJoinState.ready => 2,
    };
    final labels = [
      messages.syncAddDeviceTimelineWaiting,
      messages.syncAddDeviceTimelineJoined,
      messages.syncAddDeviceTimelineVerified,
    ];

    return Column(
      key: const Key('add_device_timeline'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < labels.length; i++)
          _TimelineStop(
            label: labels[i],
            isDone:
                i < reached ||
                (i == reached && state == AddDeviceJoinState.ready),
            isActive: i == reached && state != AddDeviceJoinState.ready,
            isLast: i == labels.length - 1,
          ),
      ],
    );
  }
}

class _TimelineStop extends StatelessWidget {
  const _TimelineStop({
    required this.label,
    required this.isDone,
    required this.isActive,
    required this.isLast,
  });

  final String label;
  final bool isDone;
  final bool isActive;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final dotSide = tokens.spacing.step1 * 5;

    final Widget dot;
    if (isActive) {
      dot = _PulsingDot(side: dotSide);
    } else if (isDone) {
      dot = DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.interactive.enabled,
          shape: BoxShape.circle,
        ),
        child: SizedBox(width: dotSide, height: dotSide),
      );
    } else {
      dot = DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: tokens.colors.decorative.level02,
            width: BorderWidths.emphasis,
          ),
        ),
        child: SizedBox(width: dotSide, height: dotSide),
      );
    }

    final labelStyle = isActive
        ? tokens.typography.styles.subtitle.subtitle2
        : tokens.typography.styles.body.bodySmall.copyWith(
            color: isDone
                ? tokens.colors.text.mediumEmphasis
                : tokens.colors.text.lowEmphasis,
          );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Padding(
              padding: EdgeInsets.only(top: tokens.spacing.step1),
              child: dot,
            ),
            if (!isLast)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.colors.decorative.level01,
                ),
                child: SizedBox(
                  width: BorderWidths.emphasis,
                  height: tokens.spacing.step5,
                ),
              ),
          ],
        ),
        SizedBox(width: tokens.spacing.step4),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.step2),
            child: Text(label, style: labelStyle),
          ),
        ),
      ],
    );
  }
}

/// The live stop's marker: a softly pulsing accent dot; steady under reduced
/// motion.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.side});

  final double side;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.35).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.interactive.enabled,
          shape: BoxShape.circle,
        ),
        child: SizedBox(width: widget.side, height: widget.side),
      ),
    );
  }
}

/// The scannable payload. The quiet zone stays white in both themes because
/// scanners need the contrast — this is a functional surface, not a styled one.
class _QrCard extends StatelessWidget {
  const _QrCard({required this.data, this.side});

  final String data;

  /// Set by the wide layout, which has already decided how the card's width
  /// is split. Left null, the code sizes itself for a single column.
  final double? side;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Stacked, the height share is what stops the code consuming the
        // viewport and pushing the no-camera fallback under the pinned bar.
        // Side by side, the parent has already budgeted the width — and it is
        // the wider screen that most needs the size, since a monitor is
        // lower-density and further from the scanning camera than a phone.
        final side =
            this.side ??
            math
                .min(
                  constraints.maxWidth,
                  MediaQuery.sizeOf(context).height * 0.26,
                )
                .clamp(200.0, 260.0);
        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radii.m),
            child: ColoredBox(
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.all(tokens.spacing.step3),
                child: QrImageView(
                  data: data,
                  padding: EdgeInsets.zero,
                  size: side,
                  key: const Key('addDeviceQrImage'),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The text fallback for a device without a camera, masked until asked for.
///
/// The reveal and copy controls carry labels rather than bare glyphs: on the
/// joining device's manual screen the instruction names "Copy pairing code",
/// so the control it names has to be findable by that name.
class _CodeRow extends StatelessWidget {
  const _CodeRow({
    required this.data,
    required this.revealed,
    required this.onToggle,
  });

  final String data;
  final bool revealed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final codeStyle = monoMetaStyle(
      tokens,
      tokens.colors,
      base: tokens.typography.styles.body.bodySmall,
      color: tokens.colors.text.mediumEmphasis,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (revealed) ...[
          // Bounded so a long payload cannot stretch the sheet.
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: tokens.spacing.step12),
            child: SingleChildScrollView(
              child: SelectableText(data, style: codeStyle),
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
        ],
        Wrap(
          spacing: tokens.spacing.step3,
          runSpacing: tokens.spacing.step2,
          children: [
            DesignSystemButton(
              key: const Key('addDeviceCopyHandoverData'),
              label: messages.syncAddDeviceCopyCode,
              leadingIcon: Icons.copy_rounded,
              variant: DesignSystemButtonVariant.outlined,
              onPressed: () => ClipboardHelper.copyTextAndNotify(
                context,
                data,
                title: messages.provisionedSyncCopiedToClipboard,
              ),
            ),
            // Both neutral: copying is the useful act of the pair, and the
            // accent on this sheet belongs to the unlocked hand-off alone.
            DesignSystemButton(
              key: const Key('addDeviceToggleHandoverVisibility'),
              label: revealed
                  ? messages.syncAddDeviceHideCode
                  : messages.syncAddDeviceRevealCode,
              leadingIcon: revealed
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              variant: DesignSystemButtonVariant.outlined,
              onPressed: onToggle,
            ),
          ],
        ),
      ],
    );
  }
}

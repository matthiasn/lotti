import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/sync/models/pairing_check_code.dart';
import 'package:lotti/features/sync/models/sync_device_info.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/state/sync_devices_provider.dart';
import 'package:lotti/features/sync/ui/clipboard_helper.dart';
import 'package:lotti/features/sync/ui/provisioned/bundle_import_page.dart';
import 'package:lotti/features/sync/ui/re_sync_modal.dart';
import 'package:lotti/features/sync/ui/sync_modal.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/pairing_check_code_view.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/sync_callout.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/sync_flow_section.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/sync_sticky_bar.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// How often the roster is re-fetched while the sheet waits for the new device
/// to appear. Nothing else pushes that state, so without a poll the "waiting"
/// strip would never resolve.
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

/// What the inviting sheet is waiting on, shared between the scroll body and
/// the pinned bar. The bar is built outside the view's `State`, and the live
/// signal has to live there: on a phone the body's own status strip is below
/// the fold, so a caption pointing "above" pointed at nothing.
enum AddDeviceJoinState { waiting, joined, rosterFailed }

/// The one object the scroll body and the pinned bar share: the live state,
/// plus the retry that only the body knows how to perform (it owns the poll
/// timer and the consecutive-failure count).
class AddDeviceJoinSignal extends ValueNotifier<AddDeviceJoinState> {
  AddDeviceJoinSignal() : super(AddDeviceJoinState.waiting);

  /// Set by the body once it is mounted; read by the bar's error row.
  VoidCallback? onRetry;
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

/// Step 2's action, pinned to the sheet so it is reachable without scrolling
/// past the QR — the joining device's own instructions send the user here.
///
/// Every signal here follows one question — can this be pressed? — because
/// three lines about one control that disagreed left the user unable to tell.
/// It is pressable whenever the account has a peer at all, since a reopened
/// sheet must still offer the hand-off; when it is, the button takes the
/// accent and the "after it joins" lead-in disappears. When it is not, the
/// lead-in, the status line and an outlined button all say so.
class AddDeviceActionBar extends ConsumerWidget {
  const AddDeviceActionBar({
    required this.signal,
    super.key,
    this.onSendMessages,
    this.onSendSettings,
  });

  /// What step 1 is waiting on, and how to retry looking. Drives the live
  /// status line and whether the action takes the accent.
  final AddDeviceJoinSignal signal;

  /// Test seam for the settings hand-off; defaults to opening [SyncModal].
  final Future<void> Function(BuildContext context)? onSendSettings;

  /// Test seam for the message-history hand-off; defaults to opening
  /// [ReSyncModal].
  final Future<void> Function(BuildContext context)? onSendMessages;

  /// Whether the account has a session other than this one.
  ///
  /// Deliberately *not* "a device appeared while this sheet was open": the
  /// joining device tells the user to come back here and press this, by which
  /// point the sheet has usually been closed and reopened, and a delta-only
  /// gate would leave the button dead forever.
  static bool hasPeer(List<SyncDeviceInfo>? devices) =>
      devices?.any((device) => !device.isCurrentDevice) ?? false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final enabled = hasPeer(ref.watch(syncDevicesControllerProvider).value);

    return ValueListenableBuilder<AddDeviceJoinState>(
      valueListenable: signal,
      builder: (context, state, _) {
        return SyncStickyBar(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // A lead-in, deliberately without a fraction: the body already
              // carries "Now · Show the code", and a second "Step N of M" on
              // the same viewport stops either of them indicating anything.
              //
              // It also has to agree with the two lines under it. "Next ·
              // after it joins" over a status reading "Send now" over an
              // outlined button gave one control three different answers to
              // "can I press this?", and it is the only pinned control here.
              // Only while the action is not yet live. Once it is, the
              // status line and the accent already say so, and a lead-in
              // reading "after it joins" over them gave one control three
              // different answers to "can I press this?".
              if (!enabled)
                SyncPairStepIndicator(
                  key: const Key('add_device_step_settings'),
                  label: messages.syncAddDeviceNextLeadIn,
                  align: TextAlign.center,
                  bottomGap: tokens.spacing.step2,
                ),
              // Whenever the pill is quiet, say why. The live status lives here
              // rather than in the card because on a phone the card's own strip
              // is below the fold, and a caption naming it pointed at nothing.
              _BarStatus(
                state: state,
                enabled: enabled,
                onRetry: signal.onRetry,
              ),
              SizedBox(height: tokens.spacing.step2),
              DesignSystemButton(
                key: const Key('add_device_send_settings'),
                label: messages.syncAddDeviceSendSettings,
                // Accent only once the new device is actually here; until then
                // the QR is the thing to look at.
                // Accent whenever it actually works. Not `secondary` for the
                // quiet case: its enabled fill is the same token the component
                // paints a *disabled* filled button with, so a live action
                // read as inert. `outlined` drops its border when disabled, so
                // the two can never be confused.
                variant: enabled
                    ? DesignSystemButtonVariant.primary
                    : DesignSystemButtonVariant.outlined,
                size: DesignSystemButtonSize.large,
                leadingIcon: Icons.sync_alt_rounded,
                fullWidth: true,
                onPressed: enabled
                    ? () => unawaited(
                        (onSendSettings ?? SyncModal.show)(context),
                      )
                    : null,
              ),
              SizedBox(height: tokens.spacing.step3),
              DesignSystemButton(
                key: const Key('add_device_send_messages'),
                label: messages.syncAddDeviceSendMessages,
                variant: DesignSystemButtonVariant.outlined,
                size: DesignSystemButtonSize.large,
                leadingIcon: Icons.history_rounded,
                fullWidth: true,
                onPressed: enabled
                    ? () => unawaited(
                        (onSendMessages ?? ReSyncModal.show)(context),
                      )
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The pinned bar's one live line: waiting, joined, or unable to look.
class _BarStatus extends StatelessWidget {
  const _BarStatus({
    required this.state,
    required this.enabled,
    required this.onRetry,
  });

  final AddDeviceJoinState state;
  final bool enabled;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final caption = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );

    switch (state) {
      case AddDeviceJoinState.joined:
        return Row(
          key: const Key('add_device_joined'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: tokens.spacing.step5,
              color: tokens.colors.alert.success.defaultColor,
            ),
            SizedBox(width: tokens.spacing.step2),
            Flexible(
              child: Text(
                messages.syncAddDeviceConnected,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
            ),
          ],
        );
      case AddDeviceJoinState.rosterFailed:
        return Row(
          key: const Key('add_device_poll_failed'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                messages.syncAddDeviceRosterError,
                textAlign: TextAlign.center,
                style: caption,
              ),
            ),
            SizedBox(width: tokens.spacing.step2),
            DesignSystemButton(
              key: const Key('add_device_poll_retry'),
              label: messages.provisionedSyncRetry,
              variant: DesignSystemButtonVariant.outlined,
              onPressed: onRetry,
            ),
          ],
        );
      case AddDeviceJoinState.waiting:
        return Row(
          key: const Key('add_device_waiting'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Only while the action is genuinely blocked. Spinning beside a
            // live button said "wait" over copy that said "send now".
            if (!enabled)
              DesignSystemSpinner(
                size: tokens.spacing.step4,
                strokeWidth: tokens.spacing.step1 / 2,
              )
            else
              Icon(
                Icons.schedule_rounded,
                size: tokens.spacing.step4,
                color: tokens.colors.text.mediumEmphasis,
              ),
            SizedBox(width: tokens.spacing.step2),
            Flexible(
              child: Text(
                enabled
                    ? messages.syncAddDeviceSendSettingsReady
                    : messages.syncAddDeviceSendSettingsPending,
                key: const Key('add_device_send_settings_pending'),
                textAlign: TextAlign.center,
                style: caption,
              ),
            ),
          ],
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
  /// and still has to render the live line and its retry.
  final AddDeviceJoinSignal? signal;

  /// Test seam for the roster poll that drives the waiting state.
  final Duration pollInterval;

  @override
  ConsumerState<AddDeviceView> createState() => _AddDeviceViewState();
}

class _AddDeviceViewState extends ConsumerState<AddDeviceView> {
  String? _handover;
  String? _checkCode;
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
  bool _joined = false;
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
      if (!mounted || _joined) return;
      unawaited(_pollOnce());
    });
  }

  /// One roster fetch, counting consecutive failures. Without this the strip
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
    // Once the strip has given up and offered Retry, stop asking on a timer:
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
    final next = _joined
        ? AddDeviceJoinState.joined
        : _pollFailures >= kAddDeviceMaxPollFailures
        ? AddDeviceJoinState.rosterFailed
        : AddDeviceJoinState.waiting;
    if (notifier.value == next) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) notifier.value = next;
    });
  }

  /// Latches on the first device id that was not present when the sheet
  /// opened. Latching matters: the roster keeps refreshing afterwards, and a
  /// success that blinks away is worse than none.
  ///
  /// Drives the status strip only. Whether the settings hand-off is offered is
  /// a separate, weaker question — see [AddDeviceActionBar.hasPeer].
  ///
  /// Derived during build rather than via `setState`: the value is a pure
  /// function of the roster this widget already watches, and it only ever
  /// moves forward, so no extra frame is needed to show it.
  /// Identity of a roster row: device ids are unique only within a user.
  static String _rosterIdentity(SyncDeviceInfo device) =>
      '${device.userId ?? 'self'}/${device.deviceId}';

  void _observeRoster(List<String> deviceIds) {
    if (_joined) return;
    final known = _knownDeviceIds;
    if (known == null) {
      _knownDeviceIds = deviceIds.toSet();
      return;
    }
    if (deviceIds.any((id) => !known.contains(id))) {
      _joined = true;
      _poll?.cancel();
      _publishJoinState();
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
      _observeRoster(
        devices.map(_rosterIdentity).toList(growable: false),
      );
    }

    final checkCode = _checkCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SyncPairStepIndicator(label: messages.syncAddDeviceStepScan),
        _StepHeading(
          label: messages.syncAddDeviceStepScanTitle,
          done: _joined,
        ),
        SizedBox(height: tokens.spacing.step3),
        Text(
          messages.syncAddDeviceIntro,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step4),
        // Before the credential, not after it. As the last child it was below
        // the fold on both viewports — a caveat about a secret that the reader
        // never reaches is not a caveat. Neutral ink so it does not out-shout
        // the live status inside the card.
        SyncCallout(
          icon: Icons.lock_outline_rounded,
          text: messages.syncAddDeviceSecurityNote,
          tone: tokens.colors.text.lowEmphasis,
          calloutKey: const Key('add_device_security_note'),
        ),
        SizedBox(height: tokens.spacing.step4),
        // One block: the code, the value to compare it by, whether the other
        // device has arrived, and the no-camera fallback for the same code.
        // Separating them read as four peers, and on desktop it put the
        // fallback control below the fold while naming it above.
        SyncFlowSection(
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
                final side =
                    (constraints.maxWidth -
                            kAddDeviceDetailsMin -
                            tokens.spacing.step5 -
                            tokens.spacing.step3 * 2)
                        .clamp(180.0, 300.0);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                  SizedBox(height: tokens.spacing.step3),
                  details,
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Numbered section heading, so the sheet reads as an ordered procedure rather
/// than a stack of equally-weighted blocks.
class _StepHeading extends StatelessWidget {
  const _StepHeading({required this.label, this.done = false});

  /// Carries the whole heading. The eyebrow above it is temporal ("Now · …")
  /// rather than a fraction: this half's second rung lives in the pinned bar,
  /// which is on screen from the start, so a count here would either promise a
  /// step that never announces itself or put two positions in one viewport.
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // A rank above the body copy it heads; at subtitle2 the numbering was the
    // only thing distinguishing structure from prose.
    final style = tokens.typography.styles.subtitle.subtitle1;

    return Row(
      children: [
        if (done) ...[
          Icon(
            Icons.check_circle_rounded,
            size: tokens.spacing.step5,
            color: tokens.colors.alert.success.defaultColor,
          ),
          SizedBox(width: tokens.spacing.step2),
        ],
        Expanded(child: Text(label, style: style)),
      ],
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
            borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
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
/// joining device's manual screen the instruction names "Copy code", so the
/// control it names has to be findable by that name.
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
        Text(
          messages.syncAddDeviceCodeHint,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        if (revealed) ...[
          SizedBox(height: tokens.spacing.step2),
          // Bounded so a long payload cannot stretch the sheet.
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: tokens.spacing.step12),
            child: SingleChildScrollView(
              child: SelectableText(data, style: codeStyle),
            ),
          ),
        ],
        SizedBox(height: tokens.spacing.step3),
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
            // accent on this screen belongs to the pinned action alone.
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

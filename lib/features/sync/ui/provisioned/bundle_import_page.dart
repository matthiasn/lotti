import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/textareas/design_system_textarea.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/models/pairing_check_code.dart';
import 'package:lotti/features/sync/state/bundle_decode_error.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/pairing_check_code_view.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/sync_callout.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/sync_flow_section.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

SliverWoltModalSheetPage bundleImportPage({
  required BuildContext context,
  required ValueNotifier<int> pageIndexNotifier,
}) {
  return ModalUtils.modalSheetPage(
    context: context,
    showCloseButton: true,
    title: context.messages.provisionedSyncImportTitle,
    padding:
        WoltModalConfig.pagePadding +
        const EdgeInsets.only(
          bottom: WoltModalConfig.stickyActionBarClearance,
        ),
    child: BundleImportWidget(pageIndexNotifier: pageIndexNotifier),
  );
}

class BundleImportWidget extends ConsumerStatefulWidget {
  const BundleImportWidget({
    required this.pageIndexNotifier,
    super.key,
  });

  final ValueNotifier<int> pageIndexNotifier;

  @override
  ConsumerState<BundleImportWidget> createState() => _BundleImportWidgetState();
}

class _BundleImportWidgetState extends ConsumerState<BundleImportWidget> {
  final _textController = TextEditingController();
  String? _errorText;
  SyncProvisioningBundle? _decodedBundle;

  /// Mobile opens straight into the camera: scanning is the path a new phone
  /// is actually here for, and a base64 field is a poor first impression.
  /// Desktop has no usable camera, so it starts on the manual field.
  late bool _manualEntry = isDesktop;

  /// Payloads the user explicitly declined. The rejected QR is usually still
  /// on the other device's screen, so without this the very next camera frame
  /// re-decodes it and the confirmation the user just refused reappears.
  ///
  /// Kept for the life of the sheet rather than cleared when the camera comes
  /// back: clearing there would make the guard unreachable, because declining
  /// already lands on the manual field. The scanner says so rather than going
  /// quietly inert, and pasting the same payload is still accepted — an
  /// explicit paste is a deliberate act in a way a camera frame is not.
  final _rejectedCodes = <String>{};
  MobileScannerController? _scannerController;
  String? _lastScannedCode;

  /// Bumped to force a fresh [MobileScanner] subtree after a retry; the
  /// widget caches its failed start otherwise.
  int _scannerGeneration = 0;

  MobileScannerController _ensureScannerController() {
    return _scannerController ??= MobileScannerController();
  }

  /// Recreates the camera after the user has granted permission elsewhere.
  void _restartScanner() {
    final old = _scannerController;
    _scannerController = null;
    unawaited(old?.dispose());
    setState(() {
      _scannerGeneration++;
      _errorText = null;
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  void _importBundle(String input) {
    try {
      final bundle = ref
          .read(provisioningControllerProvider.notifier)
          .decodeBundle(input);
      setState(() {
        _decodedBundle = bundle;
        // Whatever the source — camera, clipboard or typing — this is the
        // payload on the confirmation screen, so declining it has something
        // to remember. Tracking it only in `_handleBarcode` meant a pasted
        // code that was rejected could be re-scanned straight back in.
        _lastScannedCode = input;
        _errorText = null;
      });
    } on BundleDecodeException catch (e) {
      setState(() {
        // Naming the remedy matters most for a version mismatch: the code is
        // fine, the two apps disagree, and "invalid code" sends the user
        // hunting for a new one that will fail identically.
        _errorText = switch (e.error) {
          BundleDecodeError.unsupportedVersion =>
            context.messages.syncPairErrorVersion,
          BundleDecodeError.malformedPayload =>
            context.messages.syncPairErrorMalformed,
        };
        _decodedBundle = null;
        _lastScannedCode = null;
      });
    } on FormatException {
      setState(() {
        _errorText = context.messages.syncPairErrorMalformed;
        _decodedBundle = null;
        _lastScannedCode = null;
      });
    }
  }

  void _handleBarcode(BarcodeCapture barcodes) {
    final code = barcodes.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty || code == _lastScannedCode) return;
    if (_rejectedCodes.contains(code)) {
      // Silently ignoring it left the camera looking alive and permanently
      // inert, with nothing on screen suggesting a way out.
      _lastScannedCode = code;
      setState(() => _errorText = context.messages.syncPairScannerRejected);
      return;
    }
    _lastScannedCode = code;
    _importBundle(code);
  }

  /// Paste is the *only* live control on a desktop's manual screen, so both
  /// failure modes have to say something — silently doing nothing reads as a
  /// broken app rather than an empty clipboard.
  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text?.trim();
      if (text == null || text.isEmpty) {
        setState(() => _errorText = context.messages.syncPairClipboardEmpty);
        return;
      }
      _textController.text = text;
      _importBundle(text);
    } on PlatformException {
      setState(
        () => _errorText = context.messages.syncPairClipboardUnavailable,
      );
    }
  }

  /// Declines the decoded code and lands where the button's label promises.
  ///
  /// Two things this must not do, both of which it used to. Returning to the
  /// camera contradicts "Enter a different pairing code" *and* re-decodes the
  /// rejected QR — still on the other device's screen — on the next frame, so
  /// the reject button visibly bounced the user back to what they rejected.
  void _discardDecoded() {
    final rejected = _decodedBundle == null ? null : _lastScannedCode;
    setState(() {
      if (rejected != null) _rejectedCodes.add(rejected);
      _decodedBundle = null;
      _lastScannedCode = null;
      _errorText = null;
      _textController.clear();
      _manualEntry = true;
    });
  }

  void _setManualEntry({required bool manual}) {
    setState(() {
      _manualEntry = manual;
      _lastScannedCode = null;
      // A failed scan must not leave a red error hanging off an empty field,
      // and vice versa.
      _errorText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final decoded = _decodedBundle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Where the user is in a four-screen journey. The inviting device
        // numbers its steps; the device being onboarded — held by whoever has
        // the least context — had no indicator at all.
        SyncPairStepIndicator(
          label: decoded != null
              ? context.messages.syncPairStepConfirm
              : context.messages.syncPairStepScan,
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: decoded != null
              ? _DecodedView(
                  key: const ValueKey('bundle_import_decoded'),
                  bundle: decoded,
                  onConnect: () {
                    ref
                        .read(provisioningControllerProvider.notifier)
                        .configureFromBundle(decoded);
                    widget.pageIndexNotifier.value = 1;
                  },
                  onDiscard: _discardDecoded,
                )
              : Column(
                  key: const ValueKey('bundle_import_input'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The screen's own imperative leads, at the same rank the
                    // confirm and paired screens use. The prerequisite about a
                    // *different* device is supporting copy, and sat above it.
                    _StepTitle(
                      _manualEntry
                          ? context.messages.syncPairPasteTitle
                          : context.messages.syncPairScanTitle,
                    ),
                    if (_manualEntry)
                      _ManualEntry(
                        controller: _textController,
                        errorText: _errorText,
                        onChanged: () => setState(() => _errorText = null),
                        onImport: () =>
                            _importBundle(_textController.text.trim()),
                        onPaste: _pasteFromClipboard,
                        onUseCamera: isMobile
                            ? () => _setManualEntry(manual: false)
                            : null,
                      )
                    else
                      _ScannerView(
                        key: ValueKey('scanner_$_scannerGeneration'),
                        controller: _ensureScannerController(),
                        onDetect: _handleBarcode,
                        errorText: _errorText,
                        onEnterManually: () => _setManualEntry(manual: true),
                        onRetryCamera: _restartScanner,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// "Step 2 of 3 · Check it matches" — the joining journey's position line.
///
/// Shared with the config page so the two halves of the flow cannot disagree
/// about how many steps there are.
class SyncPairStepIndicator extends StatelessWidget {
  const SyncPairStepIndicator({
    required this.label,
    super.key,
    this.align = TextAlign.start,
    this.bottomGap,
  });

  final String label;

  /// The pinned bar centres its lead-in; the page bodies start theirs on the
  /// content rail. One component either way, so the two cannot drift apart.
  final TextAlign align;
  final double? bottomGap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomGap ?? tokens.spacing.step3),
      child: Text(
        label,
        textAlign: align,
        style: tokens.typography.styles.body.bodySmall.copyWith(
          color: tokens.colors.text.mediumEmphasis,
        ),
      ),
    );
  }
}

/// Which codes are safe to accept, in the same badged grammar the inviting
/// device uses for its own caveat.
///
/// It sits on this side too — and above the camera, not below it — because
/// this is the side an attack lands on: scanning somebody else's code joins
/// this device, and everything written on it, to their account. Ranking it
/// level with the menu-path prose, under a live viewfinder, put the warning
/// where it could only be read after the scan had already fired.
class _OnlyOwnCodeWarning extends StatelessWidget {
  const _OnlyOwnCodeWarning();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.step4),
      child: SyncCallout(
        icon: Icons.lock_outline_rounded,
        text: context.messages.syncPairOnlyOwnCode,
        tone: tokens.colors.text.lowEmphasis,
        calloutKey: const Key('sync_pair_only_own_code'),
      ),
    );
  }
}

/// Names where the code comes from — wayfinding, not a caveat, so it stays
/// plain prose and stops looking like the warning above it.
class _WhereToFindHint extends StatelessWidget {
  const _WhereToFindHint({this.extra});

  /// A second prerequisite sentence, on the screen that needs one: how to
  /// physically move the code to a machine with no camera.
  final String? extra;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final extra = this.extra;
    final style = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.step4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.messages.syncPairWhereToFind, style: style),
          if (extra != null) ...[
            SizedBox(height: tokens.spacing.step2),
            Text(
              extra,
              key: const Key('bundle_import_copy_code_hint'),
              style: style,
            ),
          ],
        ],
      ),
    );
  }
}

/// The imperative that owns each screen, at the rank every other surface in
/// the flow leads with.
class _StepTitle extends StatelessWidget {
  const _StepTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.step4),
      child: Text(
        label,
        key: const Key('sync_pair_step_title'),
        style: tokens.typography.styles.subtitle.subtitle1,
      ),
    );
  }
}

class _ScannerView extends StatelessWidget {
  const _ScannerView({
    required this.controller,
    required this.onDetect,
    required this.onEnterManually,
    required this.onRetryCamera,
    super.key,
    this.errorText,
  });

  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final VoidCallback onEnterManually;

  /// Rebuilds the scanner after the user grants permission out of band —
  /// without it, "Allow it in system settings" is an instruction with no way
  /// back into the flow.
  final VoidCallback onRetryCamera;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final error = errorText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _OnlyOwnCodeWarning(),
        LayoutBuilder(
          builder: (context, constraints) {
            // Sized from the real constraint and a height budget, not the raw
            // screen width: `isMobile` covers tablets, where a screen-derived
            // square grew taller than the sheet could ever show.
            final side = math
                .min(
                  constraints.maxWidth,
                  MediaQuery.sizeOf(context).height * 0.45,
                )
                .clamp(200.0, 360.0);
            return Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
                child: SizedBox.square(
                  dimension: side,
                  child: MobileScanner(
                    controller: controller,
                    onDetect: onDetect,
                    errorBuilder: (context, error) => _CameraUnavailable(
                      message: messages.syncPairCameraDenied,
                      onRetry: onRetryCamera,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (error != null) ...[
          SizedBox(height: tokens.spacing.step3),
          Text(
            error,
            key: const Key('bundle_import_scan_error'),
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.alert.error.ink,
            ),
          ),
        ],
        SizedBox(height: tokens.spacing.step4),
        // Below the viewfinder, unlike the manual screen, which puts it above
        // its field. The camera is already actionable the moment the screen
        // opens, so the prerequisite supports it; the field is not, so there
        // the prerequisite has to come first. It still precedes the escape
        // hatch, which otherwise sat between the user and their first task.
        const _WhereToFindHint(),
        // Neutral, hug-width, centred — the same object as "Scan with camera"
        // on the other screen. On the accent it was the only coloured element
        // on a page whose real action is holding the camera up, teaching that
        // the way out is the way forward.
        Center(
          child: DesignSystemButton(
            key: const Key('bundle_import_enter_manually'),
            label: messages.syncPairEnterManually,
            variant: DesignSystemButtonVariant.outlined,
            onPressed: onEnterManually,
          ),
        ),
      ],
    );
  }
}

/// Shown in place of the viewfinder when the camera cannot start — most often
/// a denied permission, which otherwise leaves a silent black rectangle.
class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return SyncFlowSection(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.no_photography_outlined,
              size: tokens.spacing.step8,
              color: tokens.colors.text.mediumEmphasis,
            ),
            SizedBox(height: tokens.spacing.step3),
            Text(
              message,
              key: const Key('bundle_import_camera_denied'),
              textAlign: TextAlign.center,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
            SizedBox(height: tokens.spacing.step3),
            // The copy above names a remedy the user performs elsewhere, so
            // the flow has to offer a way back in once they have.
            DesignSystemButton(
              key: const Key('bundle_import_camera_retry'),
              label: context.messages.syncPairCameraRetry,
              variant: DesignSystemButtonVariant.outlined,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualEntry extends StatelessWidget {
  const _ManualEntry({
    required this.controller,
    required this.onChanged,
    required this.onImport,
    required this.onPaste,
    this.errorText,
    this.onUseCamera,
  });

  final TextEditingController controller;
  final String? errorText;
  final VoidCallback onChanged;
  final VoidCallback onImport;
  final Future<void> Function() onPaste;
  final VoidCallback? onUseCamera;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final useCamera = onUseCamera;
    final hasText = controller.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _OnlyOwnCodeWarning(),
        // One prerequisite block above the field: where to make a code appear,
        // then how to move it here. Split around the input, the second half
        // was orphaned after the button that consumes it — and on desktop
        // nothing followed it at all.
        _WhereToFindHint(extra: messages.syncPairCopyCodeHint),
        DesignSystemTextarea(
          controller: controller,
          // The heading above already says "Paste the pairing code"; a bold
          // label repeating it gave the screen two titles and no field.
          hintText: messages.provisionedSyncImportHint,
          errorText: errorText,
          minLines: 2,
          maxLines: 4,
          onChanged: (_) => onChanged(),
        ),
        SizedBox(height: tokens.spacing.step4),
        // Paste leads while the field is empty: a full-width disabled slab
        // above the only live control read as the primary action. Paste is
        // offered on every platform — the manual screen is exactly where a
        // user lands when the camera is unavailable.
        if (hasText) ...[
          DesignSystemButton(
            onPressed: onImport,
            label: messages.provisionedSyncImportButton,
            size: DesignSystemButtonSize.large,
            fullWidth: true,
          ),
          SizedBox(height: tokens.spacing.step3),
          // Still reachable with text in the field: the malformed-code error
          // tells the user to copy the code again on the other device, and
          // this was the control that disappeared exactly then, leaving a bad
          // payload with no way to overwrite it short of select-all on a
          // phone.
          Center(
            child: DesignSystemButton(
              key: const Key('bundle_import_paste_again'),
              onPressed: onPaste,
              leadingIcon: Icons.content_paste,
              label: messages.provisionedSyncPasteClipboard,
              variant: DesignSystemButtonVariant.outlined,
            ),
          ),
        ] else
          DesignSystemButton(
            onPressed: onPaste,
            leadingIcon: Icons.content_paste,
            label: messages.provisionedSyncPasteClipboard,
            size: DesignSystemButtonSize.large,
            fullWidth: true,
          ),
        if (useCamera != null) ...[
          SizedBox(height: tokens.spacing.step4),
          Center(
            child: DesignSystemButton(
              key: const Key('bundle_import_scan_instead'),
              onPressed: useCamera,
              leadingIcon: Icons.qr_code_scanner,
              label: messages.syncPairScanInstead,
              variant: DesignSystemButtonVariant.outlined,
            ),
          ),
        ],
      ],
    );
  }
}

class _DecodedView extends StatelessWidget {
  const _DecodedView({
    required this.bundle,
    required this.onConnect,
    required this.onDiscard,
    super.key,
  });

  final SyncProvisioningBundle bundle;
  final VoidCallback onConnect;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // An instruction, not a receipt. That the base64 parsed is the least
        // consequential fact on this screen; whether the code matches is the
        // only thing the user can actually decide.
        Text(
          messages.syncPairCheckCode,
          key: const Key('bundle_import_compare_heading'),
          style: tokens.typography.styles.subtitle.subtitle1,
        ),
        SizedBox(height: tokens.spacing.step4),
        _BundleSummaryCard(bundle: bundle),
        SizedBox(height: tokens.spacing.step4),
        DesignSystemButton(
          onPressed: onConnect,
          label: messages.syncPairConnectButton,
          size: DesignSystemButtonSize.large,
          fullWidth: true,
        ),
        SizedBox(height: tokens.spacing.step3),
        // Neutral, not accent: the accent means "commit" one button up, and
        // it cannot also mean "back out".
        // Neutral *and* smaller: identical width, height and type made the
        // back-out read as a peer of the commit on the one screen asking for
        // a deliberate security decision.
        Center(
          child: DesignSystemButton(
            key: const Key('bundle_import_discard'),
            onPressed: onDiscard,
            label: messages.syncPairDiscardCode,
            variant: DesignSystemButtonVariant.outlined,
          ),
        ),
        SizedBox(height: tokens.spacing.step2),
        // *After* the reject, because it explains the reject. Between the two
        // buttons it read as the accent button's helper caption — an argument
        // against connecting, directly under "Connect this device" — and it
        // broke the accept/reject pair into two unrelated-looking controls.
        Text(
          messages.syncPairMismatchRemedy,
          key: const Key('bundle_import_mismatch_remedy'),
          textAlign: TextAlign.center,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      ],
    );
  }
}

/// What the code will connect this device to.
///
/// The check code leads because it is the only value a person can actually
/// compare — the inviting device renders the identical one. The account and
/// server follow as supporting detail. The room id is an opaque handle that
/// nobody can verify by eye, so it lives in the diagnostics dump instead.
class _BundleSummaryCard extends StatelessWidget {
  const _BundleSummaryCard({required this.bundle});

  final SyncProvisioningBundle bundle;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final tokens = context.designTokens;
    final check = pairingCheckCode(
      user: bundle.user,
      roomId: bundle.roomId,
      homeServer: bundle.homeServer,
    );

    return SyncFlowSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Names the consequence too: asking someone to compare two values
          // without saying what a mismatch means leaves them with no decision
          // to make.
          Center(
            child: PairingCheckCodeView(
              code: check,
              label: messages.syncPairCheckCodeLabel,
              caption: messages.syncPairMismatchWarning,
              codeKey: const Key('bundle_import_check_code'),
            ),
          ),
          SizedBox(height: tokens.spacing.step4),
          // Introduced as context rather than left under the "check this
          // matches" heading: neither row appears on the other device, so
          // presenting them as comparables reads as an unfinished checklist.
          Text(
            messages.syncPairWillJoin,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step2),
          _SummaryRow(
            label: messages.provisionedSyncSummaryUser,
            value: bundle.user,
          ),
          SizedBox(height: tokens.spacing.step2),
          _SummaryRow(
            label: messages.provisionedSyncSummaryHomeserver,
            value: Uri.tryParse(bundle.homeServer)?.host ?? bundle.homeServer,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final styles = tokens.typography.styles.body;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: tokens.spacing.step12,
          child: Text(
            label,
            style: styles.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: styles.bodySmall.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
        ),
      ],
    );
  }
}

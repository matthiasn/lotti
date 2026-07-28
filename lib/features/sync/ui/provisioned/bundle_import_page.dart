import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_inline_action.dart';
import 'package:lotti/features/design_system/components/textareas/design_system_textarea.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/settings/state/manual_language_controller.dart';
import 'package:lotti/features/sync/models/pairing_check_code.dart';
import 'package:lotti/features/sync/state/bundle_decode_error.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/pairing_check_code_view.dart';
import 'package:lotti/features/sync/ui/widgets/sync_well.dart';
import 'package:lotti/features/sync/ui/widgets/sync_wizard_progress_track.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/dev_logger.dart';
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
    // No sticky bar on this page — reserving clearance for one left a dead
    // band under the last element on every desktop capture.
    padding: WoltModalConfig.pagePadding,
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

  /// The camera is started by [_ScannerView] rather than by `MobileScanner`.
  ///
  /// With `autoStart` the package calls `start()` from an initializer it never
  /// awaits, so a page torn down mid-initialisation resumes that call against
  /// a disposed controller and the error surfaces as an unhandled async
  /// failure nothing can catch. Starting it ourselves makes the same failure
  /// catchable.
  MobileScannerController _ensureScannerController() {
    return _scannerController ??= MobileScannerController(autoStart: false);
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
  /// camera contradicts "They don't match" *and* re-decodes the rejected QR —
  /// still on the other device's screen — on the next frame, so the reject
  /// button visibly bounced the user back to what they rejected.
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
    // "Enter a new code" on the failed connect screen resets the controller
    // and lands back here; without this the page still shows the stale
    // decoded bundle the user is trying to replace.
    ref.listen(provisioningControllerProvider, (previous, next) {
      final wasStart =
          previous?.maybeWhen(initial: () => true, orElse: () => false) ?? true;
      final isStart = next.maybeWhen(initial: () => true, orElse: () => false);
      if (isStart && !wasStart) {
        setState(() {
          _decodedBundle = null;
          _lastScannedCode = null;
          _errorText = null;
          _textController.clear();
          if (isDesktop) _manualEntry = true;
        });
      }
    });

    final decoded = _decodedBundle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Where the user is, drawn rather than narrated: the same
        // three-station track the connect page carries.
        SyncWizardProgressTrack(
          active: decoded != null
              ? SyncWizardStep.check
              : SyncWizardStep.getCode,
        ),
        SizedBox(height: context.designTokens.spacing.step5),
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
                    _StepTitle(
                      _manualEntry
                          ? context.messages.syncPairPasteTitle
                          : context.messages.syncPairScanTitle,
                    ),
                    SizedBox(height: context.designTokens.spacing.step2),
                    _SupportLine(
                      _manualEntry
                          ? context.messages.syncPairWhereToFind
                          : context.messages.syncPairScanHint,
                    ),
                    SizedBox(height: context.designTokens.spacing.step5),
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

/// The imperative that owns each screen, at the rank the sheet's chrome uses.
class _StepTitle extends StatelessWidget {
  const _StepTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      key: const Key('sync_pair_step_title'),
      style: context.designTokens.typography.styles.heading.heading3,
    );
  }
}

/// The one supporting sentence directly under the step title.
class _SupportLine extends StatelessWidget {
  const _SupportLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Text(
      text,
      style: tokens.typography.styles.body.bodySmall.copyWith(
        color: tokens.colors.text.mediumEmphasis,
      ),
    );
  }
}

/// The account-takeover caveat, rendered *inside* the credential frame so the
/// warning physically touches the thing it warns about.
class _OnlyOwnCodeWarning extends StatelessWidget {
  const _OnlyOwnCodeWarning();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Row(
      key: const Key('sync_pair_only_own_code'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: tokens.spacing.step5,
          color: tokens.colors.alert.warning.defaultColor,
        ),
        SizedBox(width: tokens.spacing.step3),
        Expanded(
          child: Text(
            context.messages.syncPairOnlyOwnCode,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ),
      ],
    );
  }
}

/// The manual's first-device guide: where the very first pairing code comes
/// from when no device exists to mint one.
const String _kFirstDeviceGuidePath = 'sync-and-data/first-device';

/// The honest branch for the account's very first device: there is no other
/// device to mint a code, and the screen used to leave that user staring at
/// instructions that cannot be followed — with "see the manual" as prose and
/// nothing to press. The button deep-links to the manual's first-device
/// guide, not the manual root: a root landing still left the user hunting
/// for a page that explains the provisioning tool.
class _FirstDeviceCard extends ConsumerWidget {
  const _FirstDeviceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;

    return SyncWell(
      child: Column(
        key: const Key('bundle_import_first_device_hint'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            messages.syncPairFirstDeviceTitle,
            style: tokens.typography.styles.subtitle.subtitle2,
          ),
          SizedBox(height: tokens.spacing.step2),
          Text(
            messages.syncPairFirstDeviceHint,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          DesignSystemButton(
            key: const Key('bundle_import_open_manual'),
            label: messages.syncPairOpenManual,
            variant: DesignSystemButtonVariant.outlined,
            leadingIcon: Icons.menu_book_outlined,
            onPressed: () => unawaited(
              openManualInBrowser(
                systemLocale: WidgetsBinding.instance.platformDispatcher.locale,
                override: ref.read(manualLanguageControllerProvider).value,
                path: _kFirstDeviceGuidePath,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Replaces the live camera preview, for tests and manual screenshots.
///
/// A headless capture has no camera plugin: `MobileScanner` renders a black
/// rectangle and the platform channel answers every call with
/// `MissingPluginException`. Neither belongs in the manual, and a stand-in
/// viewfinder documents the step better than an empty frame would.
///
/// Follows the same override pattern as `beamToNamedOverride`. Null in
/// production, where the real scanner is always used.
@visibleForTesting
Widget Function(BuildContext context, double side)? scannerPreviewOverride;

class _ScannerView extends StatefulWidget {
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
  State<_ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<_ScannerView> {
  @override
  void initState() {
    super.initState();
    // Nothing to start when the preview is a stand-in.
    if (scannerPreviewOverride == null) {
      // After the first frame, not during initState: `MobileScanner` is a
      // child, so it has not mounted or called `attach()` yet. Starting here
      // would leave the controller waiting on its attachment timeout instead
      // of a completed attach.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_startCamera());
      });
    }
  }

  @override
  void dispose() {
    // Best effort: the controller belongs to the page, which disposes it.
    if (scannerPreviewOverride == null) {
      unawaited(widget.controller.stop().catchError((Object _) {}));
    }
    super.dispose();
  }

  /// Starts the camera and swallows a failure to do so.
  ///
  /// The failure that matters is the page being torn down while this is in
  /// flight: the controller is disposed and `start()` then rejects. With
  /// `autoStart` that call lives inside `MobileScanner`'s own un-awaited
  /// initializer, where nothing can catch it and it surfaces as an unhandled
  /// async error. Owning the call is what makes it catchable — a camera that
  /// cannot start is already reported through `errorBuilder`.
  Future<void> _startCamera() async {
    try {
      await widget.controller.start();
    } on Exception catch (error, stackTrace) {
      // Logged rather than dropped: a camera the platform refuses already
      // reaches the user through `errorBuilder`, but a start that fails for
      // any other reason would otherwise leave no trace at all.
      DevLogger.error(
        name: 'BundleImport',
        message: 'Camera start failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final error = widget.errorText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      scannerPreviewOverride?.call(context, side) ??
                          MobileScanner(
                            controller: widget.controller,
                            onDetect: widget.onDetect,
                            errorBuilder: (context, error) =>
                                _CameraUnavailable(
                                  message: messages.syncPairCameraDenied,
                                  onRetry: widget.onRetryCamera,
                                ),
                          ),
                      // The pairing moment's frame: accent corner brackets
                      // marking where the code should land. Decorative and
                      // input-transparent.
                      const IgnorePointer(child: _ViewfinderBrackets()),
                    ],
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
        // Glued to the viewfinder it concerns: this side is where an attack
        // lands — scanning somebody else's code joins this device, and
        // everything written on it, to their account.
        SyncWell(
          borderColor: tokens.colors.alert.warning.defaultColor,
          padding: EdgeInsets.all(tokens.spacing.step4),
          child: const _OnlyOwnCodeWarning(),
        ),
        SizedBox(height: tokens.spacing.step4),
        // The escape hatch for a phone whose camera cannot be pointed at
        // anything useful. Full width, but neutral: the page's real action is
        // holding the camera up.
        DesignSystemButton(
          key: const Key('bundle_import_enter_manually'),
          label: messages.syncPairEnterManually,
          leadingIcon: Icons.content_paste,
          variant: DesignSystemButtonVariant.outlined,
          size: DesignSystemButtonSize.large,
          fullWidth: true,
          onPressed: widget.onEnterManually,
        ),
        SizedBox(height: tokens.spacing.step5),
        const _FirstDeviceCard(),
      ],
    );
  }
}

/// Accent corner brackets and a center scan line over the camera square.
class _ViewfinderBrackets extends StatelessWidget {
  const _ViewfinderBrackets();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return CustomPaint(
      painter: _ViewfinderBracketsPainter(
        color: tokens.colors.interactive.enabled,
        cornerLength: tokens.spacing.step7,
        cornerRadius: tokens.radii.l,
        strokeWidth: tokens.spacing.step1,
        inset: tokens.spacing.step5,
      ),
    );
  }
}

class _ViewfinderBracketsPainter extends CustomPainter {
  _ViewfinderBracketsPainter({
    required this.color,
    required this.cornerLength,
    required this.cornerRadius,
    required this.strokeWidth,
    required this.inset,
  });

  final Color color;
  final double cornerLength;
  final double cornerRadius;
  final double strokeWidth;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    final r = cornerRadius;
    final l = cornerLength;

    // One bracket per corner: a horizontal leg and a vertical leg joined by
    // a bezier through the corner point, so the elbow renders rounded.
    void drawBracket(Offset corner, {required int dx, required int dy}) {
      final path = Path()
        ..moveTo(corner.dx + dx * l, corner.dy)
        ..lineTo(corner.dx + dx * r, corner.dy)
        ..quadraticBezierTo(
          corner.dx,
          corner.dy,
          corner.dx,
          corner.dy + dy * r,
        )
        ..lineTo(corner.dx, corner.dy + dy * l);
      canvas.drawPath(path, paint);
    }

    drawBracket(rect.topLeft, dx: 1, dy: 1);
    drawBracket(rect.topRight, dx: -1, dy: 1);
    drawBracket(rect.bottomLeft, dx: 1, dy: -1);
    drawBracket(rect.bottomRight, dx: -1, dy: -1);

    // The scan line: a faint accent rule across the middle.
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(rect.left + l, rect.center.dy),
      Offset(rect.right - l, rect.center.dy),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(_ViewfinderBracketsPainter oldDelegate) =>
      color != oldDelegate.color ||
      cornerLength != oldDelegate.cornerLength ||
      cornerRadius != oldDelegate.cornerRadius ||
      strokeWidth != oldDelegate.strokeWidth ||
      inset != oldDelegate.inset;
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

    return SyncWell(
      radius: tokens.radii.sectionCards,
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
        // The credential frame: field, its action and the caveat share one
        // warning-bordered well, so the warning cannot drift away from the
        // secret it concerns and the screen has one hero instead of a stack
        // of equally weighted blocks.
        SyncWell(
          borderColor: tokens.colors.alert.warning.defaultColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DesignSystemTextarea(
                controller: controller,
                // The heading above already says "Paste the pairing code"; a
                // bold label repeating it gave the screen two titles and no
                // field.
                hintText: messages.provisionedSyncImportHint,
                errorText: errorText,
                minLines: 2,
                maxLines: 4,
                onChanged: (_) => onChanged(),
              ),
              SizedBox(height: tokens.spacing.step4),
              // Paste leads while the field is empty: a full-width disabled
              // slab above the only live control read as the primary action.
              if (hasText) ...[
                DesignSystemButton(
                  onPressed: onImport,
                  label: messages.provisionedSyncImportButton,
                  size: DesignSystemButtonSize.large,
                  fullWidth: true,
                ),
                SizedBox(height: tokens.spacing.step3),
                // Still reachable with text in the field: the malformed-code
                // error tells the user to copy the code again on the other
                // device, and this was the control that disappeared exactly
                // then, leaving a bad payload with no way to overwrite it
                // short of select-all on a phone.
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
              SizedBox(height: tokens.spacing.step4),
              const _OnlyOwnCodeWarning(),
            ],
          ),
        ),
        if (useCamera != null) ...[
          SizedBox(height: tokens.spacing.step4),
          Center(
            child: DesignSystemInlineAction(
              key: const Key('bundle_import_scan_instead'),
              onTap: useCamera,
              leadingIcon: Icons.qr_code_scanner,
              label: messages.syncPairScanLink,
              semanticsLabel: messages.syncPairScanLink,
            ),
          ),
        ],
        SizedBox(height: tokens.spacing.step5),
        const _FirstDeviceCard(),
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
        // The security moment: the check code IS the screen. That the base64
        // parsed is the least consequential fact here; whether the code
        // matches is the only thing the user can actually decide.
        Text(
          messages.syncPairReviewTitle,
          key: const Key('bundle_import_compare_heading'),
          style: tokens.typography.styles.heading.heading3,
        ),
        SizedBox(height: tokens.spacing.step2),
        _SupportLine(messages.syncPairReviewIntro),
        SizedBox(height: tokens.spacing.step5),
        SyncWell(
          padding: EdgeInsets.symmetric(
            vertical: tokens.spacing.step6,
            horizontal: tokens.spacing.step5,
          ),
          child: PairingCheckCodeView(
            code: pairingCheckCode(
              user: bundle.user,
              roomId: bundle.roomId,
              homeServer: bundle.homeServer,
            ),
            caption: messages.syncPairSameCodeQuestion,
            codeKey: const Key('bundle_import_check_code'),
          ),
        ),
        SizedBox(height: tokens.spacing.step4),
        _ContextRow(
          label: messages.provisionedSyncSummaryUser,
          value: bundle.user,
        ),
        SizedBox(height: tokens.spacing.step2),
        _ContextRow(
          label: messages.provisionedSyncSummaryHomeserver,
          value: Uri.tryParse(bundle.homeServer)?.host ?? bundle.homeServer,
        ),
        SizedBox(height: tokens.spacing.step5),
        DesignSystemButton(
          onPressed: onConnect,
          label: messages.syncPairConnectButton,
          leadingIcon: Icons.check_rounded,
          size: DesignSystemButtonSize.large,
          fullWidth: true,
        ),
        SizedBox(height: tokens.spacing.step3),
        // Neutral, not accent: the accent means "commit" one button up, and
        // it cannot also mean "back out".
        DesignSystemButton(
          key: const Key('bundle_import_discard'),
          onPressed: onDiscard,
          label: messages.syncPairDiscardCode,
          variant: DesignSystemButtonVariant.secondary,
          fullWidth: true,
        ),
        SizedBox(height: tokens.spacing.step3),
        // The mismatch consequence rides on the decline action it argues
        // for, not buried under the summary rows.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: tokens.spacing.step4,
              color: tokens.colors.alert.warning.defaultColor,
            ),
            SizedBox(width: tokens.spacing.step2),
            Flexible(
              child: Text(
                messages.syncPairMismatchWarning,
                textAlign: TextAlign.center,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One context row under the check code: what account and server this code
/// would join. Mono values — identifiers, not prose.
class _ContextRow extends StatelessWidget {
  const _ContextRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final styles = tokens.typography.styles.body;

    // A Wrap, not a Row: at large text scales a long localized label would
    // otherwise take its full intrinsic width and squeeze the identifier —
    // the one value this screen exists to let the user review. When the
    // pair no longer fits side by side, the value drops to its own line.
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: tokens.spacing.step4,
        children: [
          Text(
            label,
            style: styles.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          Text(
            value,
            // Mono, so the account and server read as exact identifiers: a
            // proportional face with hyphen line-breaks undermined the one
            // screen whose typography must guarantee exact comparison.
            style: monoMetaStyle(
              tokens,
              tokens.colors,
              base: styles.bodySmall,
              color: tokens.colors.text.highEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/matrix/credential_encryption.dart';
import 'package:lotti/features/sync/model/sync_qr_payload.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

/// Modal page for scanning a setup QR code and logging in.
///
/// This page allows users on a new device to scan a QR code from an
/// existing device to automatically log in with the same Matrix account.
SliverWoltModalSheetPage qrScanLoginPage({
  required BuildContext context,
  required ValueNotifier<int> pageIndexNotifier,
  required VoidCallback onLoginSuccess,
  required VoidCallback onCancel,
}) {
  return ModalUtils.modalSheetPage(
    context: context,
    showCloseButton: true,
    stickyActionBar: Padding(
      padding: WoltModalConfig.pagePadding,
      child: LottiSecondaryButton(
        onPressed: onCancel,
        label: context.messages.syncSetupCancel,
      ),
    ),
    title: context.messages.syncSetupScanQr,
    padding: WoltModalConfig.pagePadding + const EdgeInsets.only(bottom: 80),
    child: QrScanLoginWidget(
      onLoginSuccess: onLoginSuccess,
    ),
  );
}

/// Widget that handles QR scanning and PIN entry for login.
class QrScanLoginWidget extends ConsumerStatefulWidget {
  const QrScanLoginWidget({
    required this.onLoginSuccess,
    super.key,
  });

  final VoidCallback onLoginSuccess;

  @override
  ConsumerState<QrScanLoginWidget> createState() => _QrScanLoginWidgetState();
}

class _QrScanLoginWidgetState extends ConsumerState<QrScanLoginWidget> {
  final MobileScannerController _scannerController = MobileScannerController();
  SyncQrPayload? _scannedPayload;
  String? _lastCode;
  DateTime? _lastScanAt;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return _buildProcessing(context);
    }

    if (_scannedPayload != null) {
      return _buildPinEntry(context);
    }

    return _buildScanner(context);
  }

  Widget _buildScanner(BuildContext context) {
    if (!isMobile) {
      return Center(
        child: Text(
          'QR scanning is only available on mobile devices.',
          style: context.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      );
    }

    final camDimension =
        max(MediaQuery.of(context).size.width - 100, 300).toDouble();

    return Column(
      children: [
        Text(
          context.messages.syncSetupScanningQr,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: camDimension,
              width: camDimension,
              child: MobileScanner(
                controller: _scannerController,
                onDetect: _handleBarcode,
              ),
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildPinEntry(BuildContext context) {
    return PinEntryWidget(
      onPinSubmitted: _handlePinSubmitted,
      onCancel: () {
        setState(() {
          _scannedPayload = null;
          _errorMessage = null;
        });
        _scannerController.start();
      },
      errorMessage: _errorMessage,
    );
  }

  Widget _buildProcessing(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            context.messages.syncSetupAutoJoining,
            style: context.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Future<void> _handleBarcode(BarcodeCapture barcodes) async {
    if (_isProcessing || _scannedPayload != null) return;

    final barcode = barcodes.barcodes.firstOrNull;
    final rawValue = barcode?.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    // Debounce duplicate scans
    final now = DateTime.now();
    if (_lastCode == rawValue &&
        _lastScanAt != null &&
        now.difference(_lastScanAt!) < const Duration(seconds: 2)) {
      return;
    }

    _lastCode = rawValue;
    _lastScanAt = now;

    // Try to parse as SyncQrPayload
    final payload = SyncQrPayload.tryParse(rawValue);
    if (payload == null) {
      setState(() {
        _errorMessage = 'Invalid QR code. Please scan a Lotti setup QR.';
      });
      return;
    }

    if (!payload.isSupported) {
      setState(() {
        _errorMessage = 'Unsupported QR code version.';
      });
      return;
    }

    // Stop scanner and show PIN entry
    try {
      await _scannerController.stop();
    } catch (_) {
      // best-effort
    }

    setState(() {
      _scannedPayload = payload;
      _errorMessage = null;
    });
  }

  Future<void> _handlePinSubmitted(String pin) async {
    final payload = _scannedPayload;
    if (payload == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final result = await CredentialEncryption.decrypt(
        payload.encryptedData,
        pin,
      );

      switch (result) {
        case DecryptionSuccess(:final credentials):
          // Login with decrypted credentials
          final matrixService = ref.read(matrixServiceProvider);
          final config = credentials.toConfig();

          await matrixService.setConfig(config);
          final loginSuccess = await matrixService.login();

          if (!mounted) return;

          if (loginSuccess) {
            widget.onLoginSuccess();
          } else {
            setState(() {
              _isProcessing = false;
              _errorMessage = context.messages.syncSetupLoginFailed;
            });
          }

        case DecryptionExpired():
          if (!mounted) return;
          setState(() {
            _isProcessing = false;
            _scannedPayload = null;
            _errorMessage = context.messages.syncSetupExpired;
          });
          unawaited(_scannerController.start());

        case DecryptionFailed():
          if (!mounted) return;
          setState(() {
            _isProcessing = false;
            _errorMessage = context.messages.syncSetupInvalidPin;
          });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = 'An error occurred. Please try again.';
      });
    }
  }
}

/// Widget for entering the 6-digit PIN.
class PinEntryWidget extends StatefulWidget {
  const PinEntryWidget({
    required this.onPinSubmitted,
    required this.onCancel,
    this.errorMessage,
    super.key,
  });

  final Future<void> Function(String pin) onPinSubmitted;
  final VoidCallback onCancel;
  final String? errorMessage;

  @override
  State<PinEntryWidget> createState() => _PinEntryWidgetState();
}

class _PinEntryWidgetState extends State<PinEntryWidget> {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus the PIN field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.lock_outline,
          size: 48,
          color: context.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          context.messages.syncSetupEnterPinTitle,
          style: context.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          context.messages.syncSetupEnterPinDescription,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.outline,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 200,
          child: TextField(
            controller: _pinController,
            focusNode: _focusNode,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: context.textTheme.headlineMedium?.copyWith(
              letterSpacing: 8,
              fontFamily: 'Inconsolata',
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              hintText: context.messages.syncSetupPinPlaceholder,
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              // Auto-submit when 6 digits entered
              if (value.length == 6) {
                _submit();
              }
            },
            onSubmitted: (_) => _submit(),
          ),
        ),
        if (widget.errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            widget.errorMessage!,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LottiSecondaryButton(
              onPressed: widget.onCancel,
              label: context.messages.syncSetupCancel,
            ),
            const SizedBox(width: 16),
            LottiPrimaryButton(
              onPressed: _isSubmitting ? null : _submit,
              label: context.messages.syncSetupVerifyPin,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final pin = _pinController.text;
    if (pin.length != 6 || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      await widget.onPinSubmitted(pin);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

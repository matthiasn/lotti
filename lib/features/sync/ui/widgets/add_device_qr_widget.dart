import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/matrix/credential_encryption.dart';
import 'package:lotti/features/sync/model/sync_qr_payload.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Widget that displays a QR code with encrypted credentials for adding
/// another device to the sync.
///
/// Shows:
/// - 6-digit PIN prominently
/// - QR code containing encrypted credentials
/// - Countdown timer (15 minutes)
/// - Regenerate button
class AddDeviceQrWidget extends ConsumerStatefulWidget {
  const AddDeviceQrWidget({super.key});

  @override
  ConsumerState<AddDeviceQrWidget> createState() => _AddDeviceQrWidgetState();
}

class _AddDeviceQrWidgetState extends ConsumerState<AddDeviceQrWidget> {
  String? _pin;
  String? _qrData;
  DateTime? _expiresAt;
  Timer? _timer;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _generateQrCode();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _generateQrCode() async {
    setState(() {
      _isGenerating = true;
      _pin = null;
      _qrData = null;
      _expiresAt = null;
    });

    _timer?.cancel();

    try {
      final matrixService = ref.read(matrixServiceProvider);
      final config = await matrixService.loadConfig();

      if (config == null) {
        if (mounted) {
          setState(() => _isGenerating = false);
        }
        return;
      }

      final pin = CredentialEncryption.generatePin();
      final encryptedData = await CredentialEncryption.encrypt(
        config,
        pin,
      );

      final payload = SyncQrPayload.v1(encryptedData);
      final expiresAt = DateTime.now().add(CredentialEncryption.defaultExpiry);

      if (mounted) {
        setState(() {
          _pin = pin;
          _qrData = payload.toQrString();
          _expiresAt = expiresAt;
          _isGenerating = false;
        });

        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _timer?.cancel();
        return;
      }

      final expiresAt = _expiresAt;
      if (expiresAt == null) return;

      if (DateTime.now().isAfter(expiresAt)) {
        setState(() {
          _pin = null;
          _qrData = null;
          _expiresAt = null;
        });
        _timer?.cancel();
      } else {
        // Force rebuild to update countdown
        setState(() {});
      }
    });
  }

  String _formatTimeRemaining() {
    final expiresAt = _expiresAt;
    if (expiresAt == null) return '';

    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return '';

    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  bool get _isExpired {
    final expiresAt = _expiresAt;
    return expiresAt == null || DateTime.now().isAfter(expiresAt);
  }

  @override
  Widget build(BuildContext context) {
    if (_isGenerating) {
      return _buildLoading(context);
    }

    if (_isExpired) {
      return _buildExpired(context);
    }

    return _buildQrCode(context);
  }

  Widget _buildLoading(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            context.messages.syncSetupGeneratingQr,
            style: context.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildExpired(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_off,
            size: 64,
            color: context.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            context.messages.syncSetupQrExpired,
            style: context.textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          LottiPrimaryButton(
            onPressed: _generateQrCode,
            label: context.messages.syncSetupRegenerateQr,
          ),
        ],
      ),
    );
  }

  Widget _buildQrCode(BuildContext context) {
    final pin = _pin;
    final qrData = _qrData;

    if (pin == null || qrData == null) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // PIN display
          _PinDisplay(pin: pin),
          const SizedBox(height: 8),
          Text(
            context.messages.syncSetupPinHint,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // QR Code
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: QrImageView(
                  data: qrData,
                  padding: EdgeInsets.zero,
                  size: 200,
                  key: const Key('AddDeviceQrImage'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Instructions
          Text(
            context.messages.syncAddDeviceDescription,
            style: context.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Timer
          _CountdownTimer(
            timeRemaining: _formatTimeRemaining(),
          ),
          const SizedBox(height: 24),

          // Regenerate button
          LottiPrimaryButton(
            onPressed: _generateQrCode,
            label: context.messages.syncSetupRegenerateQr,
          ),
        ],
      ),
    );
  }
}

/// Displays the 6-digit PIN in a prominent, easy-to-read format.
class _PinDisplay extends StatelessWidget {
  const _PinDisplay({required this.pin});

  final String pin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: context.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            context.messages.syncSetupPin,
            style: context.textTheme.labelMedium?.copyWith(
              color: context.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: pin.split('').map((digit) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: context.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: context.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  digit,
                  style: context.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inconsolata',
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Displays the countdown timer until QR expiration.
class _CountdownTimer extends StatelessWidget {
  const _CountdownTimer({required this.timeRemaining});

  final String timeRemaining;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.timer_outlined,
          size: 20,
          color: context.colorScheme.outline,
        ),
        const SizedBox(width: 8),
        Text(
          context.messages.syncSetupExpiresIn(
            timeRemaining.split(':').first,
            timeRemaining.split(':').last,
          ),
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

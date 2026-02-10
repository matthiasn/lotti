import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
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
    padding: WoltModalConfig.pagePadding + const EdgeInsets.only(bottom: 80),
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
  bool _showScanner = false;
  MobileScannerController? _scannerController;
  String? _lastScannedCode;

  MobileScannerController _ensureScannerController() {
    return _scannerController ??= MobileScannerController();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  void _importBundle(String input) {
    try {
      final bundle =
          ref.read(provisioningControllerProvider.notifier).decodeBundle(input);
      setState(() {
        _decodedBundle = bundle;
        _errorText = null;
        _showScanner = false;
      });
    } on FormatException catch (e) {
      setState(() {
        _errorText = e.message;
        _decodedBundle = null;
      });
    }
  }

  void _handleBarcode(BarcodeCapture barcodes) {
    final code = barcodes.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty || code == _lastScannedCode) return;
    _lastScannedCode = code;
    _importBundle(code);
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final camDimension =
        max(MediaQuery.of(context).size.width - 100, 300).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _textController,
          decoration: InputDecoration(
            hintText: messages.provisionedSyncImportHint,
            errorText: _errorText,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) {
            setState(() {
              _errorText = null;
            });
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: LottiPrimaryButton(
                onPressed: _textController.text.trim().isEmpty
                    ? null
                    : () => _importBundle(_textController.text),
                label: messages.provisionedSyncImportButton,
              ),
            ),
            if (isMobile) ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _showScanner = !_showScanner);
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(messages.provisionedSyncScanButton),
                ),
              ),
            ],
          ],
        ),
        if (isMobile && _showScanner) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: camDimension,
              width: camDimension,
              child: MobileScanner(
                controller: _ensureScannerController(),
                onDetect: _handleBarcode,
              ),
            ),
          ),
        ],
        if (_decodedBundle != null) ...[
          const SizedBox(height: 24),
          _BundleSummaryCard(bundle: _decodedBundle!),
          const SizedBox(height: 16),
          LottiPrimaryButton(
            onPressed: () {
              ref
                  .read(provisioningControllerProvider.notifier)
                  .configureFromBundle(
                    _decodedBundle!,
                    rotatePassword: isDesktop,
                  );
              widget.pageIndexNotifier.value = 1;
            },
            label: messages.provisionedSyncConfigureButton,
          ),
        ],
      ],
    );
  }
}

class _BundleSummaryCard extends StatelessWidget {
  const _BundleSummaryCard({required this.bundle});

  final SyncProvisioningBundle bundle;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryRow(
              label: messages.provisionedSyncSummaryHomeserver,
              value: bundle.homeServer,
            ),
            const SizedBox(height: 8),
            _SummaryRow(
              label: messages.provisionedSyncSummaryUser,
              value: bundle.user,
            ),
            const SizedBox(height: 8),
            _SummaryRow(
              label: messages.provisionedSyncSummaryRoom,
              value: bundle.roomId,
            ),
          ],
        ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: context.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

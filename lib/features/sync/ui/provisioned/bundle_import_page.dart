import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/state/provisioning_controller.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/sync_flow_section.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
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
    } on FormatException {
      setState(() {
        _errorText = context.messages.provisionedSyncInvalidBundle;
        _decodedBundle = null;
        _lastScannedCode = null;
      });
    }
  }

  void _handleBarcode(BarcodeCapture barcodes) {
    final code = barcodes.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty || code == _lastScannedCode) return;
    _lastScannedCode = code;
    _importBundle(code);
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text?.trim();
      if (text == null || text.isEmpty) return;
      _textController.text = text;
      _importBundle(text);
    } on PlatformException {
      // Ignore clipboard access failures and keep manual paste as fallback.
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final availableWidth = MediaQuery.of(context).size.width - 100;
    final camDimension = max(availableWidth, 200).toDouble();
    final hasDecodedBundle = _decodedBundle != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: hasDecodedBundle
              ? Column(
                  key: const ValueKey('bundle_import_decoded'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: context.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          messages.provisionedSyncBundleImported,
                          style: context.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                )
              : Column(
                  key: const ValueKey('bundle_import_input'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          messages.provisionedSyncImportHint,
                          style: context.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _textController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: context.colorScheme.surfaceContainer,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            errorText: _errorText,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: context.colorScheme.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                          onChanged: (_) {
                            setState(() {
                              _errorText = null;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (isDesktop)
                          LottiSecondaryButton(
                            onPressed: _pasteFromClipboard,
                            icon: Icons.content_paste,
                            label: messages.provisionedSyncPasteClipboard,
                          ),
                        if (isMobile)
                          Expanded(
                            child: LottiSecondaryButton(
                              onPressed: () {
                                setState(() {
                                  _showScanner = !_showScanner;
                                  _lastScannedCode = null;
                                });
                              },
                              icon: Icons.qr_code_scanner,
                              label: messages.provisionedSyncScanButton,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                      ],
                    ),
                    if (isMobile && _showScanner) ...[
                      const SizedBox(height: 16),
                      SyncFlowSection(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: camDimension,
                            width: camDimension,
                            child: MobileScanner(
                              controller: _ensureScannerController(),
                              onDetect: _handleBarcode,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
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

    return SyncFlowSection(
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

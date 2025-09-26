import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';

/// Dialog for installing Gemma models that are not currently available
class GemmaModelInstallDialog extends ConsumerStatefulWidget {
  const GemmaModelInstallDialog({
    required this.modelName,
    this.onModelInstalled,
    super.key,
  });

  final String modelName;
  final VoidCallback? onModelInstalled;

  @override
  ConsumerState<GemmaModelInstallDialog> createState() =>
      _GemmaModelInstallDialogState();
}

class _GemmaModelInstallDialogState
    extends ConsumerState<GemmaModelInstallDialog> {
  bool _isInstalling = false;
  String _status = '';
  double _progress = 0;
  String? _error;

  Future<void> _installModel() async {
    setState(() {
      _isInstalling = true;
      _error = null;
      _status = 'Starting model download...';
      _progress = 0;
    });

    try {
      // Get the Gemma provider configuration to find the base URL
      final providers = await ref.read(aiConfigByTypeControllerProvider(
              configType: AiConfigType.inferenceProvider)
          .future);
      final gemmaProvider = providers
          .whereType<AiConfigInferenceProvider>()
          .where((AiConfigInferenceProvider p) =>
              p.inferenceProviderType == InferenceProviderType.gemma3n)
          .firstOrNull;

      if (gemmaProvider == null) {
        throw Exception(
            'Gemma provider not found. Please configure Gemma in settings.');
      }

      final httpClient = http.Client();

      try {
        // Call the Gemma server's model pull endpoint
        final uri = Uri.parse(gemmaProvider.baseUrl).resolve('v1/models/pull');

        final request = http.Request('POST', uri);
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode({
          'model_name': widget.modelName,
          'stream': true,
        });

        developer.log(
          'Starting Gemma model download: ${widget.modelName}',
          name: 'GemmaModelInstallDialog',
        );

        final streamedResponse = await httpClient.send(request).timeout(
          const Duration(minutes: 30), // Generous timeout for model downloads
          onTimeout: () {
            throw TimeoutException(
              'Model download timed out after 30 minutes',
              const Duration(minutes: 30),
            );
          },
        );

        if (streamedResponse.statusCode != 200) {
          final body = await streamedResponse.stream.bytesToString();
          throw Exception(
              'Failed to start model download (HTTP ${streamedResponse.statusCode}): $body');
        }

        // Process the server-sent events stream
        final stream = streamedResponse.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter());

        await for (final line in stream) {
          if (!mounted) break;

          // Parse SSE format: "data: {json}"
          if (line.startsWith('data: ')) {
            final data = line.substring(6); // Remove "data: " prefix

            try {
              final json = jsonDecode(data) as Map<String, dynamic>;
              final status = json['status'] as String? ?? '';
              final total = json['total'] as int?;
              final completed = json['completed'] as int?;
              // final message = json['message'] as String?;

              setState(() {
                _status = status;

                if (total != null && completed != null && total > 0) {
                  _progress = completed / total;
                } else if (status == 'success') {
                  _progress = 1.0;
                }

                if (json['error'] != null) {
                  _error = json['error'] as String;
                }
              });

              // Check if download completed successfully
              if (status == 'success') {
                developer.log(
                  'Model download completed: ${widget.modelName}',
                  name: 'GemmaModelInstallDialog',
                );

                // Installation completed successfully
                if (mounted) {
                  // Show success message first
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Model "${widget.modelName}" installed successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  // Close dialog
                  Navigator.of(context).pop();

                  // Wait a frame for dialog to close properly, then trigger callback
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    widget.onModelInstalled?.call();
                  });
                }
                return;
              }

              // Check for error status
              if (status == 'error' || json['error'] != null) {
                final errorMsg =
                    json['error'] as String? ?? 'Unknown error occurred';
                setState(() {
                  _error = errorMsg;
                  _isInstalling = false;
                });
                return;
              }
            } catch (e) {
              // Log but don't fail on individual chunk parse errors
              developer.log(
                'Error parsing SSE chunk: $data',
                name: 'GemmaModelInstallDialog',
                error: e,
              );
            }
          }
        }

        // If we reach here without success, it's likely an error
        if (_error == null && _progress < 1.0) {
          setState(() {
            _error = 'Download completed unexpectedly without success status';
            _isInstalling = false;
          });
        }
      } finally {
        httpClient.close();
      }
    } catch (e) {
      developer.log(
        'Model installation error: $e',
        name: 'GemmaModelInstallDialog',
        error: e,
      );

      if (mounted) {
        setState(() {
          _error = e.toString();
          _isInstalling = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final command =
        'python download_model.py ${_extractVariant(widget.modelName)}';

    developer.log(
      'Building GemmaModelInstallDialog for model: ${widget.modelName}',
      name: 'GemmaModelInstallDialog',
    );

    return AlertDialog(
      title: const Text('Gemma Model Not Available'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('The model "${widget.modelName}" is not available.'),
          const SizedBox(height: 12),
          if (!_isInstalling) ...[
            const Text(
                'To install it manually, run this command in the services/gemma-local directory:'),
            const SizedBox(height: 8),
            SelectableText(command,
                style: const TextStyle(fontFamily: 'monospace')),
            const SizedBox(height: 16),
            const Text('Would you like to install it now from Lotti?'),
          ] else ...[
            const Text('Downloading model...'),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _progress > 0
                  ? _progress
                  : null, // Indeterminate if no progress info
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 8),
            Text(_status, style: Theme.of(context).textTheme.bodySmall),
            if (_progress > 0) ...[
              const SizedBox(height: 4),
              Text('${(_progress * 100).toStringAsFixed(1)}%'),
            ],
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              'Error: $_error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        if (!_isInstalling) ...[
          LottiTertiaryButton(
            onPressed: () => Navigator.of(context).pop(),
            label: context.messages.cancelButton,
          ),
          ElevatedButton(
            onPressed: _installModel,
            child: const Text('Install'),
          ),
        ] else ...[
          if (_error != null)
            ElevatedButton(
              onPressed: _installModel,
              child: const Text('Retry'),
            ),
        ],
      ],
    );
  }

  /// Extract model variant (E2B/E4B) from model name
  String _extractVariant(String modelName) {
    if (modelName.contains('E4B')) return 'E4B';
    if (modelName.contains('E2B')) return 'E2B';
    return 'E2B'; // Default to E2B
  }
}

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:lotti/features/ai/services/whisper_model_service.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';

/// Dialog for downloading Whisper models for local transcription
class WhisperModelDownloadDialog extends StatefulWidget {
  const WhisperModelDownloadDialog({
    required this.modelName,
    this.onModelDownloaded,
    super.key,
  });

  final String modelName;
  final VoidCallback? onModelDownloaded;

  /// Shows the dialog and returns true if the model was downloaded successfully
  static Future<bool> show(
    BuildContext context, {
    required String modelName,
    VoidCallback? onModelDownloaded,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => WhisperModelDownloadDialog(
        modelName: modelName,
        onModelDownloaded: onModelDownloaded,
      ),
    );
    return result ?? false;
  }

  @override
  State<WhisperModelDownloadDialog> createState() =>
      _WhisperModelDownloadDialogState();
}

class _WhisperModelDownloadDialogState
    extends State<WhisperModelDownloadDialog> {
  final WhisperModelService _modelService = WhisperModelService();
  StreamSubscription<WhisperModelDownloadProgress>? _progressSubscription;

  bool _isDownloading = false;
  double _progress = 0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String? _error;

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _modelService.dispose();
    super.dispose();
  }

  Future<void> _downloadModel() async {
    setState(() {
      _isDownloading = true;
      _error = null;
      _progress = 0;
      _downloadedBytes = 0;
    });

    // Listen to progress updates
    _progressSubscription = _modelService.downloadProgress.listen((progress) {
      if (mounted) {
        setState(() {
          _progress = progress.progress;
          _downloadedBytes = progress.downloadedBytes;
          _totalBytes = progress.totalBytes;

          if (progress.isComplete) {
            _isDownloading = false;
          }
        });
      }
    });

    try {
      developer.log(
        'Starting Whisper model download: ${widget.modelName}',
        name: 'WhisperModelDownloadDialog',
      );

      final result = await _modelService.downloadModel(widget.modelName);

      if (!mounted) return;

      if (result.success) {
        developer.log(
          'Model download completed: ${widget.modelName}',
          name: 'WhisperModelDownloadDialog',
        );

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Whisper model "${_getDisplayName()}" downloaded successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Close dialog with success
        Navigator.of(context).pop(true);

        // Trigger callback after dialog closes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onModelDownloaded?.call();
        });
      } else {
        setState(() {
          _error = result.message ?? 'Download failed';
          _isDownloading = false;
        });
      }
    } catch (e) {
      developer.log(
        'Model download error: $e',
        name: 'WhisperModelDownloadDialog',
        error: e,
      );

      if (mounted) {
        setState(() {
          _error = e.toString();
          _isDownloading = false;
        });
      }
    }
  }

  String _getDisplayName() {
    final info = WhisperModelService.availableModels[widget.modelName];
    return info?.displayName ?? widget.modelName;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final info = WhisperModelService.availableModels[widget.modelName];

    return AlertDialog(
      title: const Text('Download Whisper Model'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Model: ${_getDisplayName()}'),
          if (info != null) ...[
            const SizedBox(height: 4),
            Text(
              'Size: ${info.sizeMB}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (info.description != null) ...[
              const SizedBox(height: 8),
              Text(
                info.description!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
          const SizedBox(height: 16),
          if (!_isDownloading && _error == null) ...[
            const Text(
              'This model needs to be downloaded for local transcription. '
              'Download will start when you press the button below.',
            ),
          ] else if (_isDownloading) ...[
            const Text('Downloading model...'),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_formatBytes(_downloadedBytes)} / ${_formatBytes(_totalBytes)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '${(_progress * 100).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (!_isDownloading) ...[
          LottiTertiaryButton(
            onPressed: () => Navigator.of(context).pop(false),
            label: context.messages.cancelButton,
          ),
          ElevatedButton(
            onPressed: _downloadModel,
            child: Text(_error != null ? 'Retry' : 'Download'),
          ),
        ],
      ],
    );
  }
}

/// Widget for selecting which Whisper model to use
class WhisperModelSelector extends StatelessWidget {
  const WhisperModelSelector({
    required this.selectedModel,
    required this.onModelSelected,
    this.downloadedModels = const [],
    super.key,
  });

  final String selectedModel;
  final ValueChanged<String> onModelSelected;
  final List<String> downloadedModels;

  @override
  Widget build(BuildContext context) {
    final models = WhisperModelService.availableModels.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Whisper Model',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        ...models.map((entry) {
          final isDownloaded = downloadedModels.contains(entry.key);
          final isSelected = selectedModel == entry.key;

          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
            ),
            title: Row(
              children: [
                Text(entry.value.displayName),
                const SizedBox(width: 8),
                if (isDownloaded)
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  )
                else
                  Icon(
                    Icons.cloud_download_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.outline,
                  ),
              ],
            ),
            subtitle: Text(
              '${entry.value.sizeMB}${entry.value.description != null ? ' - ${entry.value.description}' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            selected: isSelected,
            onTap: () => onModelSelected(entry.key),
          );
        }),
      ],
    );
  }
}

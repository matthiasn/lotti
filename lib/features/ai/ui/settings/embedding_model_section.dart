import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/ai/model_files/pinned_model_files.dart';
import 'package:lotti/features/ai/on_device_embedding/on_device_embedding_repository.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_progress_bar.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/download_size.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a link outside the app.
typedef ExternalLinkOpener = Future<bool> Function(Uri uri);

// A platform call, so it cannot run in a widget test; tests inject an opener.
// coverage:ignore-start
Future<bool> _openExternally(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);
// coverage:ignore-end

/// The on-device embedding model in the "generate embeddings" flow: what it
/// is, its size and terms, and its download.
///
/// [ready] turns true once the model is on this device, which is when
/// embeddings can be generated.
class EmbeddingModelSection extends StatefulWidget {
  const EmbeddingModelSection({
    required this.repository,
    required this.ready,
    this.openLink = _openExternally,
    super.key,
  });

  final OnDeviceEmbeddingRepository repository;
  final ValueNotifier<bool> ready;
  final ExternalLinkOpener openLink;

  @override
  State<EmbeddingModelSection> createState() => _EmbeddingModelSectionState();
}

class _EmbeddingModelSectionState extends State<EmbeddingModelSection> {
  bool? _installed;
  double? _progress;
  bool _failed = false;
  bool _checkFailed = false;

  @override
  void initState() {
    super.initState();
    // A download started earlier, from a sheet since closed, is still
    // running: follow it rather than offer to start it again.
    if (widget.repository.isInstalling) {
      _progress = 0;
      // After the first frame: joining reports the progress so far at once.
      WidgetsBinding.instance.addPostFrameCallback((_) => _follow());
    } else {
      _check();
    }
  }

  Future<void> _check() async {
    final bool installed;
    try {
      installed = await widget.repository.isInstalled();
    } catch (_) {
      if (mounted) setState(() => _checkFailed = true);
      return;
    }
    if (!mounted) return;
    setState(() {
      _installed = installed;
      _checkFailed = false;
    });
    widget.ready.value = installed;
  }

  void _checkAgain() {
    setState(() => _checkFailed = false);
    _check();
  }

  Future<void> _download() async {
    setState(() {
      _progress = 0;
      _failed = false;
    });
    await _follow();
  }

  /// Runs the install, or joins the one running, showing its progress.
  Future<void> _follow() async {
    try {
      await widget.repository.install(
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      if (!mounted) return;
      setState(() => _installed = true);
      widget.ready.value = true;
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final model = widget.repository.model;
    final secondary = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );
    final progress = _progress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.name,
                    style: tokens.typography.styles.subtitle.subtitle2,
                  ),
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    formatDownloadMegabytes(messages, pinnedModelBytes(model)),
                    style: secondary,
                  ),
                ],
              ),
            ),
            SizedBox(width: tokens.spacing.step3),
            _status(context),
          ],
        ),
        // What the download is for, until it is done.
        if (_installed == false) ...[
          SizedBox(height: tokens.spacing.step2),
          Text(
            messages.embeddingModelDescription,
            style: tokens.typography.styles.body.bodySmall,
          ),
        ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: DesignSystemButton(
            label: messages.embeddingModelTerms,
            variant: DesignSystemButtonVariant.tertiary,
            alignsLabelToLeadingEdge: true,
            onPressed: () => widget.openLink(model.termsUri),
          ),
        ),
        if (progress != null) ...[
          SizedBox(height: tokens.spacing.step2),
          DesignSystemProgressBar(
            value: progress.clamp(0, 1),
            label: messages.embeddingModelDownloading,
            semanticsLabel: messages.embeddingModelDownloadSemantics(
              model.name,
            ),
            progressText: NumberFormat.percentPattern(
              messages.localeName,
            ).format(progress.clamp(0, 1)),
          ),
        ],
        if (_checkFailed) ...[
          SizedBox(height: tokens.spacing.step2),
          Text(
            messages.embeddingModelCheckFailed,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.alert.error.ink,
            ),
          ),
        ],
        if (_failed) ...[
          SizedBox(height: tokens.spacing.step2),
          Text(
            messages.embeddingModelDownloadFailed,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.alert.error.ink,
            ),
          ),
        ],
      ],
    );
  }

  Widget _status(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final installed = _installed;
    // The progress bar below stands for the download while it runs.
    if (_progress != null) return const SizedBox.shrink();
    if (_checkFailed) {
      return DesignSystemButton(
        label: messages.embeddingModelRetry,
        variant: DesignSystemButtonVariant.outlined,
        onPressed: _checkAgain,
      );
    }
    if (installed == null) {
      return const DesignSystemSpinner(
        size: IconSizes.s,
        strokeWidth: BorderWidths.emphasis,
      );
    }
    if (installed) {
      return Text(
        messages.embeddingModelInstalled,
        style: tokens.typography.styles.body.bodySmall.copyWith(
          color: tokens.colors.text.mediumEmphasis,
        ),
      );
    }
    return DesignSystemButton(
      label: _failed
          ? messages.embeddingModelRetry
          : messages.embeddingModelDownloadAction,
      semanticsLabel: messages.embeddingModelDownloadSemantics(
        widget.repository.model.name,
      ),
      leadingIcon: LottiIcons.download,
      variant: DesignSystemButtonVariant.outlined,
      onPressed: _download,
    );
  }
}

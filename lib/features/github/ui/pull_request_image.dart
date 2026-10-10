import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_anchor.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/github/service/pull_request_image_attacher.dart';
import 'package:lotti/features/github/state/github_providers.dart';
import 'package:lotti/features/journal/ui/widgets/entry_image_widget.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/markdown_link_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Keys the tests reach a description's image by.
abstract final class PullRequestImageKeys {
  static const addToTask = Key('pull_request_image_add_to_task');
}

/// The image builder a pull request description linked from [taskId] is
/// rendered with: each image loaded and shown in place, opening full size
/// on a tap, with the action to record it on the task.
ImageBuilder pullRequestImageBuilder(String taskId) =>
    (context, url, width, height) => PullRequestImage(
      url: url,
      taskId: taskId,
      width: width,
      height: height,
    );

/// The widest an image of the description below is shown, whatever its
/// own size: the description's width, as GitHub bounds it. A markdown table
/// gives its cells no width, so without this a screenshot would be shown at
/// its every pixel. An inherited widget rather than a value handed to the
/// builder: the markdown renderer keeps its parsed spans while only the
/// builder changes, and the width changes as the modal animates open, so
/// each image reads the width where it is built and follows it.
class PullRequestDescriptionWidth extends InheritedWidget {
  const PullRequestDescriptionWidth({
    required this.maxWidth,
    required super.child,
    super.key,
  });

  final double maxWidth;

  /// The width in effect at [context], or no bound outside a description.
  static double of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<PullRequestDescriptionWidth>()
          ?.maxWidth ??
      double.infinity;

  @override
  bool updateShouldNotify(PullRequestDescriptionWidth oldWidget) =>
      maxWidth != oldWidget.maxWidth;
}

/// One image of a pull request description, fetched from its own URL.
///
/// While it loads, a quiet box the size of a thumbnail; once it has, the
/// image, which a tap opens in the full-screen viewer, and a right-click
/// or a long press opens the menu over, with "Add to task": the image is
/// recorded on [taskId] as an image entry, like a pasted picture, and told
/// in a toast. An image that cannot be fetched or decoded says so where it
/// would have been, naming its host.
class PullRequestImage extends ConsumerStatefulWidget {
  const PullRequestImage({
    required this.url,
    required this.taskId,
    this.width,
    this.height,
    super.key,
  });

  final String url;
  final String taskId;

  /// The size the markdown asks for, when its alt text gives one.
  final double? width;
  final double? height;

  @override
  ConsumerState<PullRequestImage> createState() => _PullRequestImageState();
}

class _PullRequestImageState extends ConsumerState<PullRequestImage> {
  final _menu = MenuController();
  Uint8List? _bytes;
  bool _failed = false;
  bool _attaching = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PullRequestImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url) {
      _bytes = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final url = widget.url;
    final fetcher = ref.read(pullRequestImageFetcherProvider);
    final cached = fetcher.cached(url);
    if (cached != null) {
      _bytes = cached;
      return;
    }
    try {
      final bytes = await fetcher.fetch(url);
      if (!mounted || widget.url != url) return;
      setState(() => _bytes = bytes);
    } on Object {
      // Whatever went wrong — the fetcher's own failure, or a client closed
      // under it — the image is not coming; the notice must not wait.
      if (!mounted || widget.url != url) return;
      setState(() => _failed = true);
    }
  }

  /// Bytes that fetched but do not decode are as good as none: the notice
  /// replaces the image, and with it the actions, so what cannot be shown
  /// cannot be added to the task either. Called from the image's error
  /// builder, mid-build, so the state changes after the frame.
  void _markUndecodable() {
    if (_failed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_failed) setState(() => _failed = true);
    });
  }

  void _openFullSize() {
    final bytes = _bytes;
    if (bytes == null) return;
    final messages = context.messages;
    showFullscreenImageViewer(
      context,
      file: pullRequestImageFile(bytes, url: widget.url),
      heroTag: widget.url,
      action: ImageViewerAction(
        label: messages.githubImageAddToTask,
        icon: LottiIcons.image,
        onPressed: _addToTask,
      ),
    );
  }

  Future<void> _addToTask() async {
    final bytes = _bytes;
    if (bytes == null || _attaching) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final messages = context.messages;
    setState(() => _attaching = true);
    final attached = await ref
        .read(pullRequestImageAttacherProvider)
        .attach(bytes: bytes, taskId: widget.taskId);
    if (!mounted) return;
    setState(() => _attaching = false);
    messenger?.showDesignSystemToast(
      tone: attached
          ? DesignSystemToastTone.success
          : DesignSystemToastTone.error,
      title: attached
          ? messages.githubImageAdded
          : messages.githubImageAddFailed,
      replaceCurrent: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final host = markdownImageHost(widget.url);
    if (_failed) {
      return MarkdownImageNotice(label: messages.githubImageUnavailable(host));
    }
    final bytes = _bytes;
    if (bytes == null) {
      return _LoadingImage(label: messages.githubImageLoading(host));
    }
    final bound = PullRequestDescriptionWidth.of(context);
    final shownWidth = switch (widget.width) {
      final width? => width < bound ? width : bound,
      null => bound,
    };
    final cacheWidth = shownWidth.isFinite
        ? (shownWidth * MediaQuery.devicePixelRatioOf(context)).ceil()
        : null;
    return DesignSystemContextMenuAnchor(
      controller: _menu,
      semanticsLabel: messages.githubImageActions,
      size: DesignSystemContextMenuSize.small,
      items: [
        DesignSystemContextMenuItem(
          key: PullRequestImageKeys.addToTask,
          label: messages.githubImageAddToTask,
          icon: LottiIcons.image,
          onTap: _attaching ? null : _addToTask,
        ),
      ],
      builder: (context, {required toggle, required isOpen}) => Semantics(
        image: true,
        button: true,
        label: host,
        hint: messages.githubImageViewFullSize,
        onTap: _openFullSize,
        onLongPress: toggle,
        child: GestureDetector(
          // The Semantics above carries the tap and the long press.
          excludeFromSemantics: true,
          onTap: _openFullSize,
          onSecondaryTapUp: (details) =>
              _menu.open(position: details.localPosition),
          onLongPressStart: (details) =>
              _menu.open(position: details.localPosition),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: bound),
              child: Image.memory(
                bytes,
                width: widget.width,
                height: widget.height,
                // Decoded no larger than it is shown: a screenshot's pixels
                // are many times its place in the text, and a description
                // may hold twenty of them. Never upscaled by this.
                cacheWidth: cacheWidth,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
                errorBuilder: (context, error, stackTrace) {
                  _markUndecodable();
                  return MarkdownImageNotice(
                    label: messages.githubImageUnavailable(host),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Where an image will be once fetched: a box the size of a thumbnail, on
/// the second background level, with the spinner.
class _LoadingImage extends StatelessWidget {
  const _LoadingImage({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        width: tokens.spacing.step13,
        height: tokens.spacing.step12,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.colors.background.level02,
            borderRadius: BorderRadius.circular(tokens.radii.s),
          ),
          child: const Center(
            child: DesignSystemSpinner(
              style: DesignSystemSpinnerStyle.plain,
              size: IconSizes.l,
            ),
          ),
        ),
      ),
    );
  }
}

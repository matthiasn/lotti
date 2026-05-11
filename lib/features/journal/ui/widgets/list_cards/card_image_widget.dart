import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/ui/file_watcher_mixin.dart';
import 'package:lotti/utils/image_utils.dart';

class CardImageWidget extends StatefulWidget {
  const CardImageWidget({
    required this.journalImage,
    required this.height,
    super.key,
    this.fit = BoxFit.scaleDown,
  });

  final JournalImage journalImage;
  final int height;
  final BoxFit fit;

  @override
  State<CardImageWidget> createState() => _CardImageWidgetState();
}

class _CardImageWidgetState extends State<CardImageWidget>
    with FileWatcherMixin {
  @override
  void didUpdateWidget(CardImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.journalImage.id != widget.journalImage.id) {
      resetFileWatcher();
    }
  }

  @override
  void dispose() {
    disposeFileWatcher();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = getFullImagePath(widget.journalImage);
    setupFileWatcher(path);

    if (!fileExists) {
      return const SizedBox.shrink();
    }

    final size = widget.height.toDouble();
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cap = size > 0
        ? (size * devicePixelRatio).round().clamp(1, 10000)
        : null;
    final fileImage = FileImage(File(path));
    // Use ResizeImage.fit so capping both axes preserves aspect ratio
    // instead of squashing non-square source images into a square decode.
    ImageProvider imageProvider = fileImage;
    if (cap != null) {
      imageProvider = ResizeImage(
        fileImage,
        width: cap,
        height: cap,
        policy: ResizeImagePolicy.fit,
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: Image(
        image: imageProvider,
        fit: widget.fit,
      ),
    );
  }
}

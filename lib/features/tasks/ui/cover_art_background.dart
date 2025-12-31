import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/ui/file_watcher_mixin.dart';
import 'package:lotti/utils/image_utils.dart';

/// Background widget for displaying task cover art in SliverAppBar.
class CoverArtBackground extends ConsumerStatefulWidget {
  const CoverArtBackground({
    required this.imageId,
    super.key,
  });

  final String imageId;

  @override
  ConsumerState<CoverArtBackground> createState() => _CoverArtBackgroundState();
}

class _CoverArtBackgroundState extends ConsumerState<CoverArtBackground>
    with FileWatcherMixin {
  @override
  void didUpdateWidget(CoverArtBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageId != widget.imageId) {
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
    final provider = entryControllerProvider(id: widget.imageId);
    final entry = ref.watch(provider).value?.entry;

    if (entry is! JournalImage) {
      return const SizedBox.shrink();
    }

    final path = getFullImagePath(entry);
    setupFileWatcher(path);

    if (!fileExists) {
      return const SizedBox.shrink();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          File(path),
          fit: BoxFit.cover,
          cacheHeight: 600,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [
                Color(0x99000000),
                Colors.transparent,
              ],
            ),
          ),
          child: SizedBox.expand(),
        ),
      ],
    );
  }
}

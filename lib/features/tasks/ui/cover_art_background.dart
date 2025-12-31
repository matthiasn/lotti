import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/utils/platform.dart';

/// Background widget for displaying task cover art in SliverAppBar.
///
/// Displays a full-bleed 2:1 aspect ratio image with a gradient overlay
/// at the top for toolbar readability.
class CoverArtBackground extends ConsumerStatefulWidget {
  const CoverArtBackground({
    required this.imageId,
    super.key,
  });

  final String imageId;

  @override
  ConsumerState<CoverArtBackground> createState() => _CoverArtBackgroundState();
}

class _CoverArtBackgroundState extends ConsumerState<CoverArtBackground> {
  StreamSubscription<FileSystemEvent>? _watcher;
  String? _watchedPath;
  bool _fileExists = false;

  void _setupWatcher(String path) {
    // Skip in tests where file watching isn't needed
    if (isTestEnv) {
      _fileExists = File(path).existsSync();
      return;
    }

    // Already watching this path
    if (_watchedPath == path) return;

    // Clean up previous watcher
    _watcher?.cancel();
    _watcher = null;
    _watchedPath = path;

    final file = File(path);
    if (file.existsSync()) {
      _fileExists = true;
      return;
    }

    _fileExists = false;

    // Watch parent directory for file creation
    final dir = file.parent;
    if (!dir.existsSync()) return;

    _watcher = dir.watch().listen((event) {
      if (event.path == path && mounted) {
        _watcher?.cancel();
        _watcher = null;
        setState(() => _fileExists = true);
      }
    });
  }

  @override
  void didUpdateWidget(CoverArtBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageId != widget.imageId) {
      _watchedPath = null; // Force re-setup on next build
    }
  }

  @override
  void dispose() {
    _watcher?.cancel();
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
    _setupWatcher(path);

    if (!_fileExists) {
      return const SizedBox.shrink();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          File(path),
          fit: BoxFit.cover,
          // Cache at reasonable size for performance
          cacheHeight: 600,
        ),
        // Gradient overlay for toolbar readability
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [
                Color(0x99000000), // 60% black at top
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

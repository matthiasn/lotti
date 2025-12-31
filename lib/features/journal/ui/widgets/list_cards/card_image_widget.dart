import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/utils/platform.dart';

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

class _CardImageWidgetState extends State<CardImageWidget> {
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
  void didUpdateWidget(CardImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.journalImage.id != widget.journalImage.id) {
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
    final path = getFullImagePath(widget.journalImage);
    _setupWatcher(path);

    if (!_fileExists) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: widget.height.toDouble(),
      child: Image.file(
        File(path),
        cacheHeight: widget.height * 3,
        height: widget.height.toDouble(),
        fit: widget.fit,
      ),
    );
  }
}

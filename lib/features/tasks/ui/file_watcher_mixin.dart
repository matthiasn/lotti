import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:lotti/utils/platform.dart';

/// Mixin that provides file watching functionality for widgets that need to
/// display images that may not exist yet (e.g., still being written to disk).
///
/// Usage:
/// 1. Mix into your State class
/// 2. Call [setupFileWatcher] in build() with the file path
/// 3. Check [fileExists] to determine if file should be rendered
/// 4. Call [disposeFileWatcher] in dispose()
mixin FileWatcherMixin<T extends StatefulWidget> on State<T> {
  StreamSubscription<FileSystemEvent>? _fileWatcher;
  String? _watchedPath;
  bool _fileExists = false;

  /// Whether the file exists and is ready to be displayed.
  bool get fileExists => _fileExists;

  /// Sets up file watching for the given path.
  /// Call this in build() before checking [fileExists].
  ///
  /// If [forceReset] is true, resets the watcher even if path is the same.
  void setupFileWatcher(String path, {bool forceReset = false}) {
    // In test environment, just check file existence synchronously
    if (isTestEnv) {
      _fileExists = File(path).existsSync();
      return;
    }

    // coverage:ignore-start - Runtime file watching, not testable
    // Already watching this path
    if (!forceReset && _watchedPath == path) return;

    // Clean up previous watcher
    _disposeWatcher();
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

    _fileWatcher = dir.watch().listen((event) {
      if (event.path == path && mounted) {
        _disposeWatcher();
        setState(() => _fileExists = true);
      }
    });
    // coverage:ignore-end
  }

  /// Resets the file watcher state. Call when the source ID changes.
  void resetFileWatcher() {
    _watchedPath = null;
  }

  /// Disposes the file watcher. Call in dispose().
  void disposeFileWatcher() {
    _disposeWatcher();
  }

  void _disposeWatcher() {
    _fileWatcher?.cancel();
    _fileWatcher = null;
  }
}

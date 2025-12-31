import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:lotti/utils/platform.dart';
import 'package:path/path.dart' as p;

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
      if (pathsEqual(event.path, path) && mounted) {
        _disposeWatcher();
        setState(() => _fileExists = true);
      }
    });
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

/// Compares two file paths for equality, handling platform differences.
///
/// On Windows, paths are compared case-insensitively and with normalized
/// separators. On other platforms, paths are compared case-sensitively.
bool pathsEqual(String path1, String path2) {
  final normalized1 = p.normalize(p.absolute(path1));
  final normalized2 = p.normalize(p.absolute(path2));

  if (Platform.isWindows) {
    return normalized1.toLowerCase() == normalized2.toLowerCase();
  }
  return normalized1 == normalized2;
}

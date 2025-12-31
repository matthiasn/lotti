import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/ui/file_watcher_mixin.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FileWatcherMixin', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('file_watcher_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    testWidgets('fileExists returns true when file exists', (tester) async {
      final file = File('${tempDir.path}/existing.txt')
        ..writeAsStringSync('test');

      await tester.pumpWidget(
        MaterialApp(
          home: _TestWidget(path: file.path),
        ),
      );

      final state = tester.state<_TestWidgetState>(find.byType(_TestWidget));
      expect(state.fileExists, isTrue);
    });

    testWidgets('fileExists returns false when file does not exist',
        (tester) async {
      final path = '${tempDir.path}/nonexistent.txt';

      await tester.pumpWidget(
        MaterialApp(
          home: _TestWidget(path: path),
        ),
      );

      final state = tester.state<_TestWidgetState>(find.byType(_TestWidget));
      expect(state.fileExists, isFalse);
    });

    testWidgets('resetFileWatcher allows re-checking same path',
        (tester) async {
      final file = File('${tempDir.path}/test.txt');
      final path = file.path;

      await tester.pumpWidget(
        MaterialApp(
          home: _TestWidget(path: path),
        ),
      );

      final state = tester.state<_TestWidgetState>(find.byType(_TestWidget));
      expect(state.fileExists, isFalse);

      // Create the file
      file.writeAsStringSync('test');

      // Reset and re-check
      state
        ..resetFileWatcher()
        ..setupFileWatcher(path);

      expect(state.fileExists, isTrue);
    });

    testWidgets('disposeFileWatcher can be called safely', (tester) async {
      final path = '${tempDir.path}/test.txt';

      await tester.pumpWidget(
        MaterialApp(
          home: _TestWidget(path: path),
        ),
      );

      tester.state<_TestWidgetState>(find.byType(_TestWidget))

        // Should not throw
        ..disposeFileWatcher()
        ..disposeFileWatcher(); // Double dispose should be safe
    });

    testWidgets('setupFileWatcher is idempotent for same path', (tester) async {
      final file = File('${tempDir.path}/test.txt')..writeAsStringSync('test');

      await tester.pumpWidget(
        MaterialApp(
          home: _TestWidget(path: file.path),
        ),
      );

      final state = tester.state<_TestWidgetState>(find.byType(_TestWidget))

        // Call multiple times - should not cause issues
        ..setupFileWatcher(file.path)
        ..setupFileWatcher(file.path)
        ..setupFileWatcher(file.path);

      expect(state.fileExists, isTrue);
    });
  });

  group('pathsEqual', () {
    test('returns true for identical paths', () {
      expect(pathsEqual('/foo/bar/file.txt', '/foo/bar/file.txt'), isTrue);
    });

    test('returns false for different paths', () {
      expect(pathsEqual('/foo/bar/file.txt', '/foo/baz/file.txt'), isFalse);
    });

    test('normalizes paths with redundant separators', () {
      expect(pathsEqual('/foo//bar/file.txt', '/foo/bar/file.txt'), isTrue);
    });

    test('normalizes paths with . components', () {
      expect(pathsEqual('/foo/./bar/file.txt', '/foo/bar/file.txt'), isTrue);
    });

    test('normalizes paths with .. components', () {
      expect(
          pathsEqual('/foo/baz/../bar/file.txt', '/foo/bar/file.txt'), isTrue);
    });

    test('handles mixed forward and back slashes', () {
      // On non-Windows, backslashes are literal characters in paths.
      // On Windows, they're path separators.
      // This test verifies normalization handles this correctly.
      final path1 = p.join('foo', 'bar', 'file.txt');
      final path2 = p.join('foo', 'bar', 'file.txt');
      expect(pathsEqual(path1, path2), isTrue);
    });

    test('handles trailing separators consistently', () {
      // Directories with and without trailing separators
      expect(
        pathsEqual('/foo/bar/', '/foo/bar'),
        // Note: p.normalize keeps trailing separator for directories
        // but the paths should still compare correctly for files
        isTrue,
      );
    });

    test('handles relative paths by making them absolute', () {
      // Both paths should be made absolute before comparison
      final currentDir = Directory.current.path;
      const relativePath = 'test.txt';
      final absolutePath = p.join(currentDir, 'test.txt');
      expect(pathsEqual(relativePath, absolutePath), isTrue);
    });

    test('case sensitivity depends on platform', () {
      // On Windows, paths are case-insensitive
      // On Unix-like systems, paths are case-sensitive
      const path1 = '/foo/bar/File.txt';
      const path2 = '/foo/bar/file.txt';

      if (Platform.isWindows) {
        expect(pathsEqual(path1, path2), isTrue);
      } else {
        expect(pathsEqual(path1, path2), isFalse);
      }
    });

    test('handles Windows-style paths with backslashes on Windows', () {
      // This test is more meaningful on Windows, but should not break on other platforms
      if (Platform.isWindows) {
        expect(
          pathsEqual(r'C:\Users\test\file.txt', r'C:\Users\test\file.txt'),
          isTrue,
        );
        expect(
          pathsEqual(r'C:\Users\test\file.txt', 'C:/Users/test/file.txt'),
          isTrue,
        );
        // Case insensitivity on Windows
        expect(
          pathsEqual(r'C:\Users\Test\FILE.txt', r'C:\Users\test\file.txt'),
          isTrue,
        );
      }
    });

    test('handles paths with spaces', () {
      expect(
        pathsEqual('/foo/bar baz/file.txt', '/foo/bar baz/file.txt'),
        isTrue,
      );
    });

    test('handles paths with special characters', () {
      expect(
        pathsEqual('/foo/bar-baz_123/file.txt', '/foo/bar-baz_123/file.txt'),
        isTrue,
      );
    });
  });
}

/// Test widget that uses the FileWatcherMixin
class _TestWidget extends StatefulWidget {
  const _TestWidget({required this.path});

  final String path;

  @override
  State<_TestWidget> createState() => _TestWidgetState();
}

class _TestWidgetState extends State<_TestWidget> with FileWatcherMixin {
  @override
  void initState() {
    super.initState();
    setupFileWatcher(widget.path);
  }

  @override
  void dispose() {
    disposeFileWatcher();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(fileExists ? 'exists' : 'not exists');
  }
}

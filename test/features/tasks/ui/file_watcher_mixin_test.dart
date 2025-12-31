import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/ui/file_watcher_mixin.dart';

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

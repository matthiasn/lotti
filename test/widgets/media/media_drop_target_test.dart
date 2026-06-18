import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/media/media_drop_target.dart';
import 'package:path/path.dart' as p;
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../widget_test_utils.dart';

void main() {
  // NOTE: The actual drop path (`onPerformDrop`) cannot be exercised in a
  // widget test — it requires a real `super_drag_and_drop` DropEvent backed by
  // the native `super_native_extensions` plumbing, which is not mockable under
  // the test binding. Coverage here focuses on the extracted pure
  // `sanitizeDropFileName` helper and the widget's `build` path.
  group('sanitizeDropFileName', () {
    test('passes a plain file name through unchanged', () {
      expect(sanitizeDropFileName('photo.jpg'), 'photo.jpg');
    });

    test('reduces a POSIX path to its basename', () {
      expect(sanitizeDropFileName('a/b/c.png'), 'c.png');
    });

    test('strips POSIX traversal tokens, keeping only the basename', () {
      expect(sanitizeDropFileName('../../etc/passwd'), 'passwd');
    });

    test('normalizes Windows-style backslash separators on every platform', () {
      // `package:path`'s POSIX context (Linux/macOS) does not treat `\` as a
      // separator, so the helper normalizes backslashes to `/` first — a
      // Windows-style or malicious backslash payload is reduced to its basename
      // here too, not passed through verbatim.
      expect(sanitizeDropFileName(r'..\x.png'), 'x.png');
      expect(sanitizeDropFileName(r'..\..\evil.png'), 'evil.png');
      expect(sanitizeDropFileName(r'C:\Users\me\secret.png'), 'secret.png');
      // Mixed separators collapse and resolve the same way.
      expect(sanitizeDropFileName(r'a\b/../x.png'), 'x.png');
      expect(sanitizeDropFileName('a/b/../x.png'), 'x.png');
    });

    test('falls back to dropped_file for null', () {
      expect(sanitizeDropFileName(null), 'dropped_file');
    });

    test('falls back to dropped_file for an empty string', () {
      // The empty basename is the only case that triggers the fallback, since
      // `p.basename` strips trailing separators rather than returning empty.
      expect(sanitizeDropFileName(''), 'dropped_file');
      expect(p.basename('some/dir/'), 'dir');
    });
  });

  group('MediaDropTarget widget', () {
    testWidgets('builds a DropRegion that renders its child', (tester) async {
      var called = false;
      Future<void> onFiles(List<XFile> files) async {
        called = true;
      }

      await tester.pumpWidget(
        makeTestableWidget(
          MediaDropTarget(
            onFiles: onFiles,
            child: const Text('child'),
          ),
        ),
      );

      // build() path: the child is rendered and wrapped in a DropRegion from
      // package:super_drag_and_drop.
      expect(find.text('child'), findsOneWidget);
      expect(find.byType(DropRegion), findsOneWidget);

      // The widget exposes the typed onFiles callback unchanged; reading it
      // back confirms the field type without invoking the drop path.
      final widget = tester.widget<MediaDropTarget>(
        find.byType(MediaDropTarget),
      );
      expect(widget.onFiles, isA<Future<void> Function(List<XFile>)>());
      expect(widget.onFiles, same(onFiles));
      expect(called, isFalse);
    });
  });
}

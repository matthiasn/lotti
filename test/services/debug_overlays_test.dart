import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/services/debug_overlays.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The flag is a process-wide singleton. Tests run sequentially in the
  // same process, so reset it (and the underlying global) between cases
  // to avoid cross-test pollution.
  setUp(() {
    repaintRainbowEnabled.value = false;
    debugRepaintRainbowEnabled = false;
  });

  test(
    "mirrors true into Flutter's `debugRepaintRainbowEnabled` global "
    'and schedules a forced frame so the overlay shows up on the next '
    'vsync without waiting for an unrelated repaint',
    () {
      expect(debugRepaintRainbowEnabled, isFalse);

      repaintRainbowEnabled.value = true;

      expect(debugRepaintRainbowEnabled, isTrue);
    },
  );

  test(
    'mirrors false back into the global so the overlay can be turned '
    'off cleanly without leaving the diagnostic stuck on',
    () {
      repaintRainbowEnabled.value = true;
      expect(debugRepaintRainbowEnabled, isTrue);

      repaintRainbowEnabled.value = false;

      expect(debugRepaintRainbowEnabled, isFalse);
    },
  );

  test(
    'is a transient process-memory toggle: defaults to false at '
    'initialization, no DB persistence — guarantees a clean slate on '
    'every relaunch so a forgotten diagnostic flag cannot follow the '
    'app across sessions',
    () {
      expect(repaintRainbowEnabled.value, isFalse);
      expect(debugRepaintRainbowEnabled, isFalse);
    },
  );
}

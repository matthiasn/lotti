import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/demo/seed/demo_seed_progress.dart';

void main() {
  test('media progress exposes a bounded determinate fraction', () {
    expect(
      const DemoSeedProgress.downloadingMedia(
        completed: 3,
        total: 9,
      ).fraction,
      closeTo(1 / 3, 0.0001),
    );
    expect(
      const DemoSeedProgress.downloadingMedia(
        completed: 12,
        total: 9,
      ).fraction,
      1,
    );
    expect(
      const DemoSeedProgress.downloadingMedia(
        completed: -1,
        total: 9,
      ).fraction,
      0,
    );
    expect(
      const DemoSeedProgress.downloadingMedia(
        completed: 0,
        total: 0,
      ).fraction,
      isNull,
    );
  });

  test('non-media phases remain indeterminate', () {
    expect(const DemoSeedProgress.preparing().fraction, isNull);
    expect(const DemoSeedProgress.writingContent().fraction, isNull);
    expect(const DemoSeedProgress.activating().fraction, isNull);
  });
}

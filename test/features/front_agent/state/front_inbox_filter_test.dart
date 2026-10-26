import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';

void main() {
  test(
    'starts off, toggles, and starts off again once nobody watches it',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sub = container.listen(frontInboxFilterProvider, (_, _) {});
      expect(container.read(frontInboxFilterProvider), isFalse);
      container.read(frontInboxFilterProvider.notifier).toggle();
      expect(container.read(frontInboxFilterProvider), isTrue);
      container.read(frontInboxFilterProvider.notifier).toggle();
      expect(container.read(frontInboxFilterProvider), isFalse);
      // Clearing is off, whether it was on or already off.
      container.read(frontInboxFilterProvider.notifier).clear();
      expect(container.read(frontInboxFilterProvider), isFalse);
      container.read(frontInboxFilterProvider.notifier).toggle();
      container.read(frontInboxFilterProvider.notifier).clear();
      expect(container.read(frontInboxFilterProvider), isFalse);
      container.read(frontInboxFilterProvider.notifier).toggle();

      // The sheet closed: the filter is not remembered into the next opening.
      sub.close();
      await pumpEventQueue();
      final again = container.listen(frontInboxFilterProvider, (_, _) {});
      addTearDown(again.close);
      expect(container.read(frontInboxFilterProvider), isFalse);
    },
  );
}

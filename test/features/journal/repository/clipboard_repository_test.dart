import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/repository/clipboard_repository.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('clipboardRepository resolves without throwing', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // SystemClipboard.instance is null in headless test environments and a
    // real clipboard on devices — the provider must tolerate both.
    expect(() => container.read(clipboardRepositoryProvider), returnsNormally);
  });
}

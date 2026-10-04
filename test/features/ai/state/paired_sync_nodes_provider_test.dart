import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/state/paired_sync_nodes_provider.dart';

void main() {
  test('lists no paired devices until sync wires its directory', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(pairedSyncNodesProvider, (_, _) {});
    addTearDown(sub.close);

    expect(await container.read(pairedSyncNodesProvider.future), isEmpty);
  });
}

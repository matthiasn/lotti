import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/task_document_source_provider.dart';

void main() {
  test(
    'is unwired by default, so an app without the documents feature never '
    'offers the agent the document tools',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(taskDocumentSourceProvider), isNull);
    },
  );
}

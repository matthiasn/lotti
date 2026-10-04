import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/state/journal_card_ports.dart';

void main() {
  test(
    'both ports answer nothing until the composition root wires them',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final counts = container.listen(
        journalChecklistCountsProvider('checklist-1'),
        (_, _) {},
      );
      addTearDown(counts.close);
      final name = container.listen(
        journalRelationshipNameProvider('person-1'),
        (_, _) {},
      );
      addTearDown(name.close);

      expect(
        await container.read(
          journalChecklistCountsProvider('checklist-1').future,
        ),
        isNull,
      );
      expect(
        await container.read(
          journalRelationshipNameProvider('person-1').future,
        ),
        isNull,
      );
    },
  );
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/journal_card_wiring.dart';
import 'package:lotti/features/journal/state/journal_card_ports.dart';
import 'package:lotti/features/relationships/state/relationships_providers.dart';

void main() {
  test(
    'a check-in card names the person the relationships feature knows',
    () async {
      final container = ProviderContainer(
        overrides: [
          journalRelationshipNameProvider.overrideWith(
            relationshipNameFromRelationships,
          ),
          relationshipNameProvider(
            'person-1',
          ).overrideWith((ref) async => 'Frida Kjellsen'),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(
        journalRelationshipNameProvider('person-1'),
        (_, _) {},
      );
      addTearDown(sub.close);

      expect(
        await container.read(
          journalRelationshipNameProvider('person-1').future,
        ),
        'Frida Kjellsen',
      );
    },
  );
}

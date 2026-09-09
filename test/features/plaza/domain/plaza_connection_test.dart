import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/plaza/domain/plaza_connection.dart';
import 'package:lotti/features/tasks/model/directed_relation.dart';

void main() {
  for (final type in relationshipSelectorTypes) {
    test(
      '$type retains direction while allowing exploration from either end',
      () {
        final connection = PlazaConnection(
          id: 'edge',
          fromId: 'blocker',
          toId: 'dependent',
          type: type,
        );
        expect(connection.isDirected, type != EntryLinkType.basic);
        expect(connection.otherId('blocker'), 'dependent');
        expect(connection.otherId('dependent'), 'blocker');
        expect(connection.otherId('outside'), isNull);
        // Exploring the inverse does not rewrite the semantic direction.
        expect((connection.fromId, connection.toId), ('blocker', 'dependent'));
      },
    );
  }
}

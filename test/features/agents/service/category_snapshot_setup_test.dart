import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/features/agents/service/category_snapshot_setup.dart';

void main() {
  final asked = <String>[];
  Future<String?> lookup(String categoryId) async {
    asked.add(categoryId);
    return categoryId == 'with-default' ? 'profile-1' : null;
  }

  setUp(asked.clear);

  test('snapshots the profile the category names, attributed to it', () async {
    final setup = await categorySnapshotSetup(
      categoryId: 'with-default',
      lookup: lookup,
    );

    expect(setup!.mode, AgentInferenceSetupMode.configured);
    expect(setup.origin, AgentInferenceSetupOrigin.categorySnapshot);
    expect(setup.baseProfileId, 'profile-1');
    expect(setup.originEntityId, 'with-default');
  });

  test(
    'a category naming no profile gives no setup, not a disabled one',
    () async {
      expect(
        await categorySnapshotSetup(categoryId: 'bare', lookup: lookup),
        isNull,
      );
      expect(asked, ['bare']);
    },
  );

  test('no category asks nothing and gives no setup', () async {
    expect(
      await categorySnapshotSetup(categoryId: null, lookup: lookup),
      isNull,
    );
    expect(asked, isEmpty);
  });
}

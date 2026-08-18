import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/goals/model/goal_entry_ids.dart';

void main() {
  group('goal identity inputs', () {
    test('are stable for the same subject', () {
      // The whole point: every device derives the same input, so the backfill
      // converges on one row instead of one row per device.
      expect(goalEntryUuidV5Input('agent-1'), goalEntryUuidV5Input('agent-1'));
      expect(
        goalSpecSnapshotUuidV5Input('agent-1:spec-v1'),
        goalSpecSnapshotUuidV5Input('agent-1:spec-v1'),
      );
    });

    test('separate distinct subjects', () {
      expect(
        goalEntryUuidV5Input('agent-1'),
        isNot(goalEntryUuidV5Input('agent-2')),
      );
      expect(
        goalSpecSnapshotUuidV5Input('agent-1:spec-v1'),
        isNot(goalSpecSnapshotUuidV5Input('agent-1:spec-v2')),
      );
    });

    test('cannot collide across the two families', () {
      // A goal and a snapshot are different rows. Without distinct prefixes an
      // agent id and a version id that happened to match would derive the same
      // journal id, and the snapshot would overwrite its own goal.
      expect(
        goalEntryUuidV5Input('collide'),
        isNot(goalSpecSnapshotUuidV5Input('collide')),
      );
    });
  });
}

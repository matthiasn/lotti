import 'package:clock/clock.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/features/relationships/service/pending_interaction_store.dart';

/// An in-memory [PendingInteractionStore]: holds at most one marker, stamps
/// a remembered one with the ambient [clock], and counts clears so a test
/// can tell a marker that was taken up from one that was left alone.
class FakePendingInteractionStore implements PendingInteractionStore {
  FakePendingInteractionStore([this.pending]);

  PendingInteraction? pending;
  int clearCount = 0;

  @override
  Future<void> remember({
    required String relationshipId,
    required CheckInInteractionType interactionType,
  }) async {
    pending = (
      relationshipId: relationshipId,
      interactionType: interactionType,
      startedAt: clock.now(),
    );
  }

  @override
  Future<PendingInteraction?> read() async => pending;

  @override
  Future<void> put(PendingInteraction p) async => pending = p;

  @override
  Future<void> clear() async {
    clearCount++;
    pending = null;
  }
}

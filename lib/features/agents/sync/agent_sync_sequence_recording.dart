part of 'agent_sync_service.dart';

/// Sequence-log recording helpers for [AgentSyncService]: append received
/// (hostId, counter) marks for entities and links. Split from the main file
/// for size; library-private.
extension _AgentSyncSequenceRecording on AgentSyncService {
  Future<void> _recordAgentEntitySequence(AgentDomainEntity entity) async {
    final service = _sequenceLog;
    final vectorClock = entity.vectorClock;
    if (service == null || vectorClock == null) return;
    try {
      await service.recordSentEntry(
        entryId: entity.id,
        vectorClock: vectorClock,
        payloadType: SyncSequencePayloadType.agentEntity,
      );
    } catch (exception, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.sync,
        exception,
        message:
            'sequence record failed after agent entity write; VC already committed',
        stackTrace: stackTrace,
        subDomain: 'agentSync.recordEntity',
      );
    }
  }

  Future<void> _recordAgentLinkSequence(AgentLink link) async {
    final service = _sequenceLog;
    final vectorClock = link.vectorClock;
    if (service == null || vectorClock == null) return;
    try {
      await service.recordSentEntry(
        entryId: link.id,
        vectorClock: vectorClock,
        payloadType: SyncSequencePayloadType.agentLink,
      );
    } catch (exception, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.sync,
        exception,
        message:
            'sequence record failed after agent link write; VC already committed',
        stackTrace: stackTrace,
        subDomain: 'agentSync.recordLink',
      );
    }
  }
}

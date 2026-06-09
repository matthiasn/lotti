part of 'agent_sync_service.dart';

/// Per-chain transaction context, stored in a [Zone] value so that
/// concurrent transaction chains each have their own isolated buffer.
class _TransactionContext {
  final List<SyncMessage> pendingMessages = [];
  final List<Future<void> Function()> pendingSequenceBindings = [];
}

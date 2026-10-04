import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/sync/sync_node_profile.dart';

/// The devices this one syncs with, for choosing which of them claims a
/// profile's inbound audio.
///
/// Empty until the composition root wires the sync feature's node directory
/// (`knownSyncNodes`); the AI feature does not depend on sync.
final pairedSyncNodesProvider = StreamProvider<List<SyncNodeProfile>>(
  (ref) => Stream.value(const <SyncNodeProfile>[]),
  name: 'pairedSyncNodesProvider',
);

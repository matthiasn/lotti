import 'package:lotti/features/ai/database/embedding_register.dart';

/// A register version that arrived by sync, with its attachment.
class IncomingEmbeddingVersion {
  const IncomingEmbeddingVersion({required this.register, this.payload});

  /// The version as the sender stored it; its clock is the sender's.
  final EmbeddingRegister register;

  /// The vectors attachment's JSON, `null` for a tombstone and for a
  /// version whose file the sender no longer had: an exact copy already
  /// sent, or a version a newer one replaced before it went out.
  final String? payload;
}

/// Where the sync apply path hands received vector versions, and the hooks
/// that release versions held until their text arrives.
///
/// Defined and implemented in this feature; sync, which ranks above it,
/// calls it. Sync records the receipt of a version once [apply] returns,
/// whatever the outcome, so a version is never requested again; [apply]
/// throws only for a failure worth retrying (the store could not be
/// written), and then no receipt is recorded.
abstract interface class SyncedEmbeddingSink {
  /// Merges [version] into the register it belongs to: drops a dominated
  /// one, applies a tombstone, stores vectors whose hash matches this
  /// device's own text, and holds the rest until it does.
  Future<void> apply(IncomingEmbeddingVersion version);

  /// A journal entity was applied: re-check versions held for it.
  Future<void> onJournalEntityApplied(String entityId);

  /// An agent entity (a report among them) was applied: re-check versions
  /// held for it.
  Future<void> onAgentEntityApplied(String entityId);

  /// An entity definition was applied: re-check the task versions held for
  /// it, since a label's name is part of a task's text.
  Future<void> onEntityDefinitionApplied(String definitionId);

  /// Re-checks every held version: the backstop for a dependency no hook
  /// names, run when the inbound queue drains.
  Future<void> recheckAll();
}

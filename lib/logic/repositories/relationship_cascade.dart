import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';

/// The writes to a person that a journal delete cascades into: the person's
/// own deletion, and clearing a deleted image off their avatar or banner.
///
/// [JournalRepository] owns the generic delete path but not people, which
/// belong to the relationships feature above it. The composition root
/// registers a [RelationshipCascadeFactory] that builds the relationship
/// repository, so every edit of a person still goes through its single write
/// path without the journal layer importing it.
abstract interface class RelationshipCascade {
  /// Writes [relationship] through the relationship repository; true when it
  /// was stored.
  Future<bool> updateRelationship(RelationshipEntry relationship);

  /// Deletes the person [relationshipId] together with their check-ins
  /// (ADR 0037 §5); true when anything was deleted.
  Future<bool> deleteRelationship(String relationshipId);
}

/// Builds the [RelationshipCascade] over [journalRepository], writing through
/// [persistenceLogic].
typedef RelationshipCascadeFactory =
    RelationshipCascade Function(
      JournalRepository journalRepository,
      PersistenceLogic persistenceLogic,
    );

/// The [RelationshipCascadeFactory] the journal repository's deletes use.
/// The composition root binds the relationships feature's builder here.
final relationshipCascadeFactoryProvider = Provider<RelationshipCascadeFactory>(
  (ref) => throw UnimplementedError(
    'relationshipCascadeFactoryProvider must be overridden before use.',
  ),
  name: 'relationshipCascadeFactoryProvider',
);

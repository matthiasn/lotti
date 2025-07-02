import 'dart:developer' as developer;

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';

/// Helper class for safely fetching current entity state with type checking
class EntityStateHelper {
  const EntityStateHelper._();

  /// Fetches the current state of an entity and ensures it matches the expected type.
  ///
  /// This method is used to prevent concurrent modifications by fetching the latest
  /// entity state before updating. It provides type safety by checking that the
  /// fetched entity matches the expected type.
  ///
  /// Returns the typed entity if successful, or null if:
  /// - The entity cannot be fetched
  /// - The entity is null
  /// - The entity type doesn't match the expected type T
  ///
  /// Example usage:
  /// ```dart
  /// final currentImage = await EntityStateHelper.getCurrentEntityState<JournalImage>(
  ///   entityId: entity.id,
  ///   aiInputRepo: aiInputRepo,
  ///   entityTypeName: 'image',
  /// );
  /// if (currentImage == null) {
  ///   // Handle error - entity not found or wrong type
  ///   return;
  /// }
  /// // Use currentImage safely with type guarantee
  /// ```
  static Future<T?> getCurrentEntityState<T extends JournalEntity>({
    required String entityId,
    required AiInputRepository aiInputRepo,
    required String entityTypeName,
  }) async {
    try {
      final currentEntity = await aiInputRepo.getEntity(entityId);

      if (currentEntity == null) {
        developer.log(
          'Cannot update $entityTypeName - entity not found: $entityId',
          name: 'EntityStateHelper',
        );
        return null;
      }

      if (currentEntity is! T) {
        developer.log(
          'Cannot update $entityTypeName - entity type mismatch. '
          'Expected: $T, Got: ${currentEntity.runtimeType} for entity: $entityId',
          name: 'EntityStateHelper',
        );
        return null;
      }

      return currentEntity;
    } catch (e) {
      developer.log(
        'Failed to get current $entityTypeName state for $entityId',
        name: 'EntityStateHelper',
        error: e,
      );
      return null;
    }
  }
}

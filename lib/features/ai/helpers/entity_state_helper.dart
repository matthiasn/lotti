import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/services/domain_logging.dart';

/// Helper class for safely fetching current entity state with type checking
abstract final class EntityStateHelper {
  static const _subDomain = 'EntityStateHelper';

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
  /// Each of those outcomes is reported to [domainLogger].
  ///
  /// Example usage:
  /// ```dart
  /// final currentImage = await EntityStateHelper.getCurrentEntityState<JournalImage>(
  ///   entityId: entity.id,
  ///   aiInputRepo: aiInputRepo,
  ///   entityTypeName: 'image',
  ///   domainLogger: domainLogger,
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
    required DomainLogger domainLogger,
  }) async {
    try {
      final currentEntity = await aiInputRepo.getEntity(entityId);

      if (currentEntity == null) {
        domainLogger.log(
          LogDomain.ai,
          'Cannot update $entityTypeName - entity not found: $entityId',
          subDomain: _subDomain,
          level: InsightLevel.warn,
        );
        return null;
      }

      if (currentEntity is! T) {
        domainLogger.log(
          LogDomain.ai,
          'Cannot update $entityTypeName - entity type mismatch. '
          'Expected: $T, Got: ${currentEntity.runtimeType} for entity: $entityId',
          subDomain: _subDomain,
          level: InsightLevel.warn,
        );
        return null;
      }

      return currentEntity;
    } catch (e, stackTrace) {
      domainLogger.error(
        LogDomain.ai,
        e,
        stackTrace: stackTrace,
        subDomain: _subDomain,
        message: 'Failed to get current $entityTypeName state for $entityId',
      );
      return null;
    }
  }
}

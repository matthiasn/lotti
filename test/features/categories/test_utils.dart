import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:uuid/uuid.dart';

/// Shared test utilities for category-related tests.
class CategoryTestUtils {
  /// Creates a test [CategoryDefinition] with customizable parameters.
  ///
  /// All parameters are optional and have sensible defaults for testing.
  static CategoryDefinition createTestCategory({
    String? id,
    String name = 'Test Category',
    String? color,
    bool private = false,
    bool active = true,
    bool? favorite,
    String? defaultLanguageCode,
    List<String>? allowedPromptIds,
    Map<AiResponseType, List<String>>? automaticPrompts,
    List<String>? speechDictionary,
    CategoryIcon? icon,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    VectorClock? vectorClock,
  }) {
    final now = DateTime.now();
    return CategoryDefinition(
      id: id ?? const Uuid().v4(),
      name: name,
      color: color ?? '#0000FF',
      private: private,
      active: active,
      favorite: favorite,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
      deletedAt: deletedAt,
      vectorClock: vectorClock,
      defaultLanguageCode: defaultLanguageCode,
      allowedPromptIds: allowedPromptIds,
      automaticPrompts: automaticPrompts,
      speechDictionary: speechDictionary,
      icon: icon,
    );
  }
}

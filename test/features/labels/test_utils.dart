import 'package:lotti/classes/entity_definitions.dart';
import 'package:uuid/uuid.dart';

/// Shared test utilities for label-related tests.
class LabelTestUtils {
  /// Creates a test [LabelDefinition] with customizable parameters.
  static LabelDefinition createTestLabel({
    String? id,
    String name = 'Test Label',
    String color = '#0000FF',
    String? description,
    bool? private,
    List<String>? applicableCategoryIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final defaultDate = DateTime(2024);
    return LabelDefinition(
      id: id ?? const Uuid().v4(),
      name: name,
      color: color,
      description: description,
      private: private,
      applicableCategoryIds: applicableCategoryIds,
      createdAt: createdAt ?? defaultDate,
      updatedAt: updatedAt ?? defaultDate,
      vectorClock: null,
    );
  }
}

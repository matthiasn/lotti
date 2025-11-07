/// Utility class for validating checklist items across the AI features
class ChecklistValidation {
  /// Maximum allowed length for a checklist item title
  static const int maxTitleLength = 400;

  /// Maximum number of items allowed in a single batch
  static const int maxBatchSize = 20;

  /// Validates and sanitizes a list of raw checklist items
  /// Returns a list of validated items with title and isChecked status
  static List<({String title, bool isChecked})> validateItems(
      List<dynamic> raw) {
    final sanitized = <({String title, bool isChecked})>[];

    for (final entry in raw) {
      if (entry is Map<String, dynamic>) {
        final titleRaw = entry['title'];
        final isCheckedRaw = entry['isChecked'];

        if (titleRaw is String) {
          final title = titleRaw.trim();
          if (title.isNotEmpty && title.length <= maxTitleLength) {
            sanitized.add((
              title: title,
              isChecked: isCheckedRaw == true,
            ));
          }
        }
      }
    }

    return sanitized;
  }

  /// Validates an item entry and returns an error message if it's invalid
  static String? validateItemEntry(dynamic entry) {
    if (entry is String) {
      return 'Each item must be an object with a title. Example: {"items": [{"title": "Buy milk"}] }';
    }

    if (entry is! Map<String, dynamic>) {
      return 'Invalid item format: expected an object with "title" property';
    }

    final title = entry['title'];
    if (title is! String) {
      return 'Item title must be a string';
    }

    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      return 'Item title cannot be empty';
    }

    if (trimmedTitle.length > maxTitleLength) {
      return 'Item title exceeds maximum length of $maxTitleLength characters';
    }

    return null; // Valid
  }

  /// Checks if the batch size is within allowed limits
  static bool isValidBatchSize(int size) {
    return size > 0 && size <= maxBatchSize;
  }

  /// Creates a standardized error message for invalid batch size
  static String getBatchSizeErrorMessage(int actualSize) {
    if (actualSize == 0) {
      return 'No valid items found. Provide non-empty titles (max $maxTitleLength chars).';
    }
    if (actualSize > maxBatchSize) {
      return 'Too many items: max $maxBatchSize per call.';
    }
    return 'Invalid batch size: $actualSize';
  }
}

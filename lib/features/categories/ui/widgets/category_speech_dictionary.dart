import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/textareas/design_system_textarea.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Maximum length for individual dictionary terms.
const int kMaxTermLength = 50;

/// Warning threshold for number of terms (token budget concern).
/// Raised from 30 to 500 to align with correction examples limit.
const int kDictionaryWarningThreshold = 500;

/// A widget for editing the speech dictionary of a category, rendered as
/// a [DesignSystemTextarea] so it matches the design-system fields around
/// it. The "how to format terms" explanation lives in the section
/// description the page renders above the field (the textarea's helper
/// row clips to one line); the helper slot only surfaces the token-budget
/// warning once the term count exceeds [kDictionaryWarningThreshold].
///
/// Terms are separated by semicolons. The widget parses the input,
/// validates terms, and calls onChanged with the resulting list of terms.
///
/// Validation rules:
/// - Empty strings are filtered out
/// - Terms are limited to [kMaxTermLength] characters
/// - Duplicates are allowed (user's responsibility)
class CategorySpeechDictionary extends StatefulWidget {
  const CategorySpeechDictionary({
    required this.dictionary,
    required this.onChanged,
    super.key,
  });

  /// The current dictionary terms, or null if empty.
  final List<String>? dictionary;

  /// Called when the dictionary is modified.
  final ValueChanged<List<String>> onChanged;

  @override
  State<CategorySpeechDictionary> createState() =>
      _CategorySpeechDictionaryState();
}

class _CategorySpeechDictionaryState extends State<CategorySpeechDictionary> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _formatDictionary(widget.dictionary),
    );
  }

  @override
  void didUpdateWidget(CategorySpeechDictionary oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update text field if the dictionary changed externally
    // and differs from what the user has typed (to avoid clobbering input)
    final currentParsed = _parseDictionary(_controller.text);
    final newParsed = widget.dictionary ?? [];

    if (!_listsEqual(currentParsed, newParsed)) {
      _controller.text = _formatDictionary(widget.dictionary);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Formats a list of terms into a semicolon-separated string.
  String _formatDictionary(List<String>? dictionary) {
    if (dictionary == null || dictionary.isEmpty) return '';
    return dictionary.join('; ');
  }

  /// Parses a semicolon-separated string into a list of terms.
  /// Filters out empty strings and trims whitespace.
  /// Truncates terms to [kMaxTermLength] characters.
  List<String> _parseDictionary(String text) {
    if (text.trim().isEmpty) return [];

    return text
        .split(';')
        .map((term) => term.trim())
        .where((term) => term.isNotEmpty)
        .map(
          (term) => term.length > kMaxTermLength
              ? term.substring(0, kMaxTermLength)
              : term,
        )
        .toList();
  }

  bool _listsEqual(List<String> a, List<String> b) {
    return const DeepCollectionEquality().equals(a, b);
  }

  void _onChanged(String value) {
    final terms = _parseDictionary(value);
    setState(() {}); // Trigger rebuild to update warning
    widget.onChanged(terms);
  }

  @override
  Widget build(BuildContext context) {
    final termCount = _parseDictionary(_controller.text).length;
    final showWarning = termCount > kDictionaryWarningThreshold;

    return DesignSystemTextarea(
      controller: _controller,
      label: context.messages.speechDictionaryLabel,
      hintText: context.messages.speechDictionaryHint,
      helperText: showWarning
          ? context.messages.speechDictionaryWarning(termCount)
          : null,
      onChanged: _onChanged,
    );
  }
}

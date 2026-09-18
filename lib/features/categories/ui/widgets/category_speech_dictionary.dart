import 'package:collection/collection.dart';
import 'package:lotti/features/design_system/components/textareas/design_system_textarea.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Maximum length for individual dictionary terms.
const int kMaxTermLength = 50;

/// Warning threshold for number of terms (token budget concern).
/// Raised from 30 to 500 to align with correction examples limit.
const int kDictionaryWarningThreshold = 500;

/// Formats speech terms as the one semicolon-separated line the user edits.
String formatSpeechTerms(List<String>? terms) {
  if (terms == null || terms.isEmpty) return '';
  return terms.join('; ');
}

/// Parses a semicolon-separated line of speech terms: trimmed, blanks
/// dropped, each cut to [kMaxTermLength] characters.
List<String> parseSpeechTerms(String text) {
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
      text: formatSpeechTerms(widget.dictionary),
    );
  }

  @override
  void didUpdateWidget(CategorySpeechDictionary oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update text field if the dictionary changed externally
    // and differs from what the user has typed (to avoid clobbering input)
    final currentParsed = parseSpeechTerms(_controller.text);
    final newParsed = widget.dictionary ?? [];

    if (!_listsEqual(currentParsed, newParsed)) {
      _controller.text = formatSpeechTerms(widget.dictionary);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _listsEqual(List<String> a, List<String> b) {
    return const DeepCollectionEquality().equals(a, b);
  }

  void _onChanged(String value) {
    final terms = parseSpeechTerms(value);
    setState(() {}); // Trigger rebuild to update warning
    widget.onChanged(terms);
  }

  @override
  Widget build(BuildContext context) {
    final termCount = parseSpeechTerms(_controller.text).length;
    final showWarning = termCount > kDictionaryWarningThreshold;

    // The hosting "Speech recognition" section header already names this
    // sole field — an in-field Title Case label would repeat it.
    return DesignSystemTextarea(
      controller: _controller,
      semanticsLabel: context.messages.speechDictionaryLabel,
      hintText: context.messages.speechDictionaryHint,
      helperText: showWarning
          ? context.messages.speechDictionaryWarning(termCount)
          : null,
      onChanged: _onChanged,
    );
  }
}

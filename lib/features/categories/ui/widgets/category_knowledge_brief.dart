import 'package:lotti/features/categories/domain/category_knowledge_brief.dart';
import 'package:lotti/features/design_system/components/textareas/design_system_textarea.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The one field a category's knowledge brief is written in.
///
/// Plain multi-line text, reported as typed: the brief goes into prompts
/// verbatim, so this field never reflows or normalises it, and blank-versus-
/// null is the controller's concern. The hosting section header names the
/// field, so the label lives in semantics only — the same shape as the speech
/// dictionary beside it.
class CategoryKnowledgeBrief extends StatefulWidget {
  const CategoryKnowledgeBrief({
    required this.brief,
    required this.onChanged,
    super.key,
  });

  /// The stored brief, or null when the category has none.
  final String? brief;

  /// Called with the full text on every edit.
  final ValueChanged<String> onChanged;

  @override
  State<CategoryKnowledgeBrief> createState() => _CategoryKnowledgeBriefState();
}

class _CategoryKnowledgeBriefState extends State<CategoryKnowledgeBrief> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.brief ?? '',
  );

  @override
  void didUpdateWidget(CategoryKnowledgeBrief oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only an external change (sync, reload) replaces the text, and only when
    // it differs from what is typed — the controller echoes every keystroke
    // back through [brief], and that echo must never move the caret.
    final next = widget.brief ?? '';
    if (widget.brief != oldWidget.brief && _controller.text != next) {
      _controller.text = next;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DesignSystemTextarea(
      controller: _controller,
      semanticsLabel: context.messages.categoryKnowledgeBriefLabel,
      hintText: context.messages.categoryKnowledgeBriefHint,
      maxLength: categoryKnowledgeBriefMaxLength,
      showCounter: true,
      growWithContent: true,
      onChanged: widget.onChanged,
    );
  }
}

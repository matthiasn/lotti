import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/github/domain/github_repository.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The field a category's GitHub repository is typed into.
///
/// Takes `owner/repo` or the repository's URL, and reports the repository as
/// `owner/repo` — or null once the field is cleared. What does not read as a
/// repository is flagged and not reported, so the stored value never changes
/// to something the picker could not use.
class GitHubRepositoryField extends StatefulWidget {
  const GitHubRepositoryField({
    required this.repository,
    required this.onChanged,
    super.key,
  });

  /// The stored `owner/repo`, or null.
  final String? repository;

  final ValueChanged<String?> onChanged;

  @override
  State<GitHubRepositoryField> createState() => _GitHubRepositoryFieldState();
}

class _GitHubRepositoryFieldState extends State<GitHubRepositoryField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.repository ?? '',
  );
  var _invalid = false;

  @override
  void didUpdateWidget(GitHubRepositoryField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only an external change (sync, reload) replaces the text: what was typed
    // may be a URL that reads as the stored repository, and must not be
    // rewritten under the caret.
    final typed = parseGitHubRepository(_controller.text)?.toString();
    if (widget.repository != oldWidget.repository &&
        widget.repository != typed) {
      _controller.text = widget.repository ?? '';
      _invalid = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    if (text.trim().isEmpty) {
      setState(() => _invalid = false);
      widget.onChanged(null);
      return;
    }
    final repository = parseGitHubRepository(text);
    setState(() => _invalid = repository == null);
    if (repository != null) widget.onChanged(repository.toString());
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    return DesignSystemTextInput(
      key: const Key('github_repository_field'),
      controller: _controller,
      label: messages.githubRepositoryLabel,
      hintText: messages.githubRepositoryHint,
      helperText: _invalid ? null : messages.githubRepositoryHelper,
      errorText: _invalid ? messages.githubRepositoryInvalid : null,
      keyboardType: TextInputType.url,
      onChanged: _onChanged,
    );
  }
}

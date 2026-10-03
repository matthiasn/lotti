import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/github/domain/github_repository.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The field a category's GitHub repository is typed into.
///
/// Takes `owner/repo` or the repository's URL, and reports the repository as
/// `owner/repo` — or null once the field is cleared. What does not read as a
/// repository is flagged and not reported, so the stored value never changes
/// to something the picker could not use; [onValidityChanged] tells the form,
/// so it cannot save the last valid value while the field shows other text.
class GitHubRepositoryField extends StatefulWidget {
  const GitHubRepositoryField({
    required this.repository,
    required this.onChanged,
    required this.onValidityChanged,
    super.key,
  });

  /// The stored `owner/repo`, or null.
  final String? repository;

  final ValueChanged<String?> onChanged;

  /// Whether the text reads as a repository (or is empty), after every edit,
  /// after an external change replaces the text, and — valid — when the field
  /// goes away while invalid.
  final ValueChanged<bool> onValidityChanged;

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
      if (_invalid) {
        _invalid = false;
        // Not during the parent's build: the form's state is a provider.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onValidityChanged(true);
        });
      }
    }
  }

  @override
  void dispose() {
    // A field removed while invalid (its section hidden) must not leave the
    // form unable to save, with nothing on screen saying why.
    if (_invalid) {
      final report = widget.onValidityChanged;
      WidgetsBinding.instance.addPostFrameCallback((_) => report(true));
    }
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    if (text.trim().isEmpty) {
      setState(() => _invalid = false);
      widget
        ..onValidityChanged(true)
        ..onChanged(null);
      return;
    }
    final repository = parseGitHubRepository(text);
    setState(() => _invalid = repository == null);
    widget.onValidityChanged(repository != null);
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

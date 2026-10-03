import 'dart:io';

/// A `uses:` reference in workflow [source] that is not pinned to a full
/// commit SHA, with its 1-based [line].
typedef UnpinnedAction = ({int line, String reference});

final _uses = RegExp(r'^\s*(?:-\s*)?uses:\s*([^\s#]+)', multiLine: true);
final _pinned = RegExp(r'@[0-9a-f]{40}$');

/// Every third-party action [source] references by a tag or branch.
///
/// A tag can be moved to different code after review, so workflows that hold
/// signing and store secrets must name the exact commit they run. Local
/// actions (`./…`) and container images (`docker://…`) are not GitHub refs
/// and are left out.
List<UnpinnedAction> unpinnedActions(String source) {
  return [
    for (final match in _uses.allMatches(source))
      if (match.group(1) case final reference?)
        if (!reference.startsWith('./') &&
            !reference.startsWith('docker://') &&
            !_pinned.hasMatch(reference))
          (
            line: '\n'.allMatches(source.substring(0, match.start)).length + 1,
            reference: reference,
          ),
  ];
}

bool _isYaml(File file) =>
    file.path.endsWith('.yml') || file.path.endsWith('.yaml');

/// The files GitHub actually executes: workflows directly in
/// `.github/workflows` — it never runs a subdirectory, so
/// `workflows/archive/` is inert — and composite actions anywhere under
/// `.github/actions`.
List<File> _executedWorkflowFiles() {
  final workflows = Directory('.github/workflows');
  final actions = Directory('.github/actions');
  return [
    if (workflows.existsSync())
      ...workflows.listSync().whereType<File>().where(_isYaml),
    if (actions.existsSync())
      ...actions.listSync(recursive: true).whereType<File>().where(_isYaml),
  ]..sort((a, b) => a.path.compareTo(b.path));
}

void main() {
  final files = _executedWorkflowFiles();
  var violations = 0;
  for (final file in files) {
    for (final action in unpinnedActions(file.readAsStringSync())) {
      stderr.writeln(
        '${file.path}:${action.line}: ${action.reference} must be pinned to a '
        'full commit SHA (keep the tag as a trailing comment)',
      );
      violations++;
    }
  }
  if (violations > 0) exitCode = 1;
}

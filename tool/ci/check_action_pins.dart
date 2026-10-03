import 'dart:io';

import 'package:yaml/yaml.dart';

/// A `uses:` reference in a workflow that is not pinned to a full commit SHA,
/// with the 1-based line it sits on.
typedef UnpinnedAction = ({int line, String reference});

final _pinned = RegExp(r'@[0-9a-f]{40}$');

/// Every third-party action [source] references by a tag or branch.
///
/// A tag can be moved to different code after review, so workflows that hold
/// signing and store secrets must name the exact commit they run. The YAML is
/// parsed rather than scanned line by line, so a `uses` written in flow style
/// (`- {uses: …}`) or with a quoted key (`"uses": …`) is checked like any
/// other. Every `uses` value in the document is examined — a step's, a
/// reusable-workflow job's, a composite action's. Local actions (`./…`) and
/// container images (`docker://…`) are not GitHub refs and are left out.
List<UnpinnedAction> unpinnedActions(String source) {
  final found = <UnpinnedAction>[];
  void visit(YamlNode node) {
    switch (node) {
      case YamlMap(:final nodes):
        for (final MapEntry(:key, :value) in nodes.entries) {
          if (key is YamlScalar && key.value == 'uses' && value is YamlScalar) {
            final reference = '${value.value}'.trim();
            if (!reference.startsWith('./') &&
                !reference.startsWith('docker://') &&
                !_pinned.hasMatch(reference)) {
              found.add((
                line: value.span.start.line + 1,
                reference: reference,
              ));
            }
          }
          visit(value);
        }
      case YamlList(:final nodes):
        nodes.forEach(visit);
      default:
        break;
    }
  }

  visit(loadYamlNode(source));
  found.sort((a, b) => a.line.compareTo(b.line));
  return found;
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
  var violations = 0;
  for (final file in _executedWorkflowFiles()) {
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

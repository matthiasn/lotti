// Checks that no file outside lib/services/ logs through dart:developer.
//
// Usage:
//   dart run tool/logging/validate.dart
//
// Exits 0 when no such file exists, 1 otherwise. See
// `developer_log_guard.dart` for the rule and the reasoning behind it.

import 'dart:io';

import 'developer_log_guard.dart';

void main(List<String> args) {
  if (args.isNotEmpty) {
    stderr
      ..writeln('error: unrecognised argument(s): ${args.join(', ')}')
      ..writeln()
      ..writeln('Usage: dart run tool/logging/validate.dart');
    exit(1);
  }
  final lib = Directory('lib');
  if (!lib.existsSync()) {
    stderr.writeln('error: no `lib/` here — run from the repository root');
    exit(1);
  }

  final result = scan(root: lib, repoRoot: Directory.current.path);
  if (result.violations.isNotEmpty) {
    stderr.writeln('dart:developer logging check failed:\n');
    for (final violation in result.violations) {
      stderr.writeln('  $violation\n');
    }
    stderr.writeln(
      'Log through DomainLogger; dart:developer belongs to '
      '${loggingLayer.join(', ')}.',
    );
    exit(1);
  }
  stdout.writeln('dart:developer logging check passed.');
}

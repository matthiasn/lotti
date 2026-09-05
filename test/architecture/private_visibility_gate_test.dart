// Enforces the private-visibility gate described in
// knowledge/architecture/persistence.md ("Private visibility is gated three
// different ways"): every read of journal rows either applies the gate or is
// listed here with the reason it deliberately does not.
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _driftFile = 'lib/database/database.drift';
const _concept =
    'knowledge/architecture/persistence.md, "Private visibility is gated '
    'three different ways"';

/// Named queries in `database.drift` that read journal rows, reference no
/// `private` column, and are called from at least one place that does not
/// dispatch on the flag — each with the reason that is deliberate.
///
/// An entry that stops being needed fails the build too, so this list can
/// only ever describe the current exceptions.
const _ungatedNamedQueries = <String, String>{
  // Resolving ids the caller already holds: the flag changes what browsing
  // surfaces, not what an identifier resolves to.
  'entriesForIds':
      'ids the caller holds, tombstones included (task blockers, checklist '
      'updates)',
  'journalEntitiesByIdsUnorderedAllPrivate':
      'ids the caller holds (editor drafts, checklist items, coalesced by-id '
      'reads, outbox bundles)',
  'ratingForTimeEntry': 'the rating attached to an entry the caller holds',
  // Sync: every device holds every row, private or not.
  'orderedJournalInterval': 'historical re-sync walks every row for peers',
  // Numbers, not rows.
  'countJournalEntries': 'a count for maintenance progress',
  'countImportFlagEntries': 'a count for the import badge',
  // Not gated today. Listed here rather than silently so; whether they
  // should gate is the product decision tracked in lotti3-0qaz.
  'sortedCalenderEntriesInRange': 'not gated today: the calendar range read',
  'measurementsByType': 'not gated today: dashboard measurement series',
  'habitCompletionsByHabitId': 'not gated today: habit completion series',
  'quantitativeByType': 'not gated today: health quantitative series',
  'latestQuantByType': 'not gated today: latest health quantitative value',
  'workouts': 'not gated today: workout series',
  'findLatestWorkout': 'not gated today: latest workout',
  'workoutsByType': 'not gated today: workout series by type',
  'workoutTypes': 'not gated today: distinct workout types',
  'surveysByType': 'not gated today: survey completion series',
};

/// Dart declarations (`lib/…/file.dart:name`) whose own SQL or Drift query
/// reads journal rows without the gate, each with the reason.
const _ungatedDeclarations = <String, String>{
  // Resolving ids the caller already holds.
  'lib/database/database_journal_queries.dart:entityById':
      'the single-entity read behind every detail page',
  'lib/database/database_journal_queries.dart:'
          'getJournalEntitiesForIdsIncludingDeleted':
      'ids the caller holds, tombstones included (demo reseed inventory)',
  'lib/database/database_task_queries.dart:getTaskEstimatesByIds':
      'estimates for task ids the caller holds',
  'lib/database/database_project_queries.dart:getTaskIdsForProjects':
      'id-to-id resolution for project ids the caller holds; no row content',
  'lib/database/database_project_queries.dart:getExistingProjectIds':
      'existence check on project ids the caller holds; no row content',
  'lib/database/database_project_queries.dart:getProjectIdsForTaskIds':
      'id-to-id resolution for task ids the caller holds; no row content',
  'lib/database/database_project_queries.dart:getProjectIdMapForTasks':
      'id-to-id resolution for task ids the caller holds; no row content',
  // Sync and maintenance: every device holds every row, and nothing these
  // select is shown to a user.
  'lib/database/database_journal_queries.dart:'
          'journalEntityMapForIdsIncludingDeleted':
      'outbound sync payloads, tombstones included',
  'lib/database/database_journal_queries.dart:streamEntriesWithVectorClock':
      'sequence-log population walks every row for sync',
  'lib/database/database_journal_queries.dart:allNonDeletedJournalEntityIds':
      'ids only, for the demo reseed guard',
  'lib/database/database_entity_ops.dart:purgeDeletedFiles':
      'the purge walk over deleted rows',
  'lib/database/maintenance.dart:recreateFts5':
      'reindexes every row; search hits resolve through the gated id-batch '
      'read',
  // Numbers, not rows.
  'lib/database/database_journal_queries.dart:countAllJournalEntries':
      'a count for progress reporting, deleted rows included',
  // Not gated today (lotti3-0qaz).
  'lib/database/database_journal_queries.dart:getDayAudioEntries':
      'not gated today: the Daily OS audio entries of a day',
};

/// Files whose journal SQL is not a read path at all.
const _filesOutsideTheReadPath = <String, String>{
  'lib/database/database_migration_recent.dart':
      'the migration ladder rewrites rows; nothing it selects reaches a user',
};

/// SQL that reads the journal table: a `FROM` or `JOIN` on it, in a named
/// query or in a Dart string. `\b` keeps `journal_fts` and the like out.
final RegExp _readsJournalSql = RegExp(
  r'\b(from|join)\s+journal\b',
  caseSensitive: false,
);

/// A Drift Dart-API read of the table (`into`/`update`/`delete` are writes).
final RegExp _readsJournalApi = RegExp(r'\b(select|selectOnly)\(journal\)');

/// The gate inside SQL: any reference to the `private` column, whether a
/// bound `private IN (…)`, the `config_flags` subquery form, or the
/// `private_flag` CTE's `j.private` comparison.
final RegExp _sqlGate = RegExp(r'\bprivate\b', caseSensitive: false);

/// The gate inside Dart: the column referenced by the declaration's own SQL
/// or Drift expression, or a dispatch on the flag that picks the all-private
/// variant only when every private state is visible.
final RegExp _dartGate = RegExp(
  r'\bprivate\b|_queryWithPrivateFilter|_matchesAllPrivateStates',
);

typedef _NamedQuery = ({String name, String sql});

/// Every named query in [_driftFile] with its SQL, comments removed.
List<_NamedQuery> _namedQueries() {
  final source = File(_driftFile).readAsStringSync();
  final header = RegExp(r'^([A-Za-z0-9_]+):\s*$', multiLine: true);
  final matches = header.allMatches(source).toList();
  return [
    for (var i = 0; i < matches.length; i++)
      (
        name: matches[i].group(1)!,
        sql: source
            .substring(
              matches[i].end,
              i + 1 < matches.length ? matches[i + 1].start : source.length,
            )
            .replaceAll(RegExp('--.*'), ''),
      ),
  ];
}

typedef _Declaration = ({String file, String name, String source});

/// Hand-written Dart sources under `lib/`, as forward-slash relative paths.
Iterable<File> _libSources() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where(
      (f) =>
          f.path.endsWith('.dart') &&
          !f.path.endsWith('.g.dart') &&
          !f.path.endsWith('.freezed.dart'),
    );

String _relative(File file) => p.split(p.relative(file.path)).join('/');

/// Every method, function, field and top-level variable in [file], each
/// with the source text of its own declaration (comments excluded). The
/// parser, not a pattern, decides where one declaration ends and the next
/// begins, so an SQL string is always attributed to the code that runs it.
List<_Declaration> _declarations(File file) {
  final path = _relative(file);
  final result = parseString(
    content: file.readAsStringSync(),
    path: path,
    throwIfDiagnostics: false,
  );
  if (result.errors.isNotEmpty) {
    fail(
      '$path does not parse, so nothing in it was audited.\n'
      '${result.errors.join('\n')}',
    );
  }

  final declarations = <_Declaration>[];
  void add(String name, AstNode node) =>
      declarations.add((file: path, name: name, source: node.toSource()));
  void addMembers(Iterable<ClassMember> members) {
    for (final member in members) {
      switch (member) {
        case MethodDeclaration():
          add(member.name.lexeme, member);
        case FieldDeclaration():
          for (final variable in member.fields.variables) {
            add(variable.name.lexeme, variable);
          }
        case ConstructorDeclaration():
          add(member.name?.lexeme ?? 'new', member);
        case PrimaryConstructorBody():
          break;
      }
    }
  }

  Iterable<ClassMember> membersOf(ClassBody body) => switch (body) {
    BlockClassBody() => body.members,
    EmptyClassBody() => const [],
  };

  for (final declaration in result.unit.declarations) {
    switch (declaration) {
      case ClassDeclaration():
        addMembers(membersOf(declaration.body));
      case MixinDeclaration():
        addMembers(membersOf(declaration.body));
      case ExtensionDeclaration():
        addMembers(membersOf(declaration.body));
      case EnumDeclaration():
        addMembers(declaration.body.members);
      case FunctionDeclaration():
        add(declaration.name.lexeme, declaration);
      case TopLevelVariableDeclaration():
        for (final variable in declaration.variables.variables) {
          add(variable.name.lexeme, variable);
        }
      default:
        break;
    }
  }
  return declarations;
}

/// Declarations in every `lib/` file whose text mentions [needle]. Files
/// that cannot contain a match are not parsed, which keeps the audit cheap
/// on a tree of this size.
List<_Declaration> _declarationsMentioning(Pattern needle) => [
  for (final file in _libSources())
    if (file.readAsStringSync().contains(needle)) ..._declarations(file),
];

String _key(_Declaration d) => '${d.file}:${d.name}';

void main() {
  late List<_NamedQuery> queries;
  late List<_Declaration> journalMentions;

  setUpAll(() {
    queries = _namedQueries();
    journalMentions = _declarationsMentioning('journal');
  });

  group('private-visibility gate', () {
    test('every named query reading journal rows gates, dispatches, or is '
        'listed with a reason', () {
      final ungated = queries.where(
        (q) => _readsJournalSql.hasMatch(q.sql) && !_sqlGate.hasMatch(q.sql),
      );
      final offenders = <String>[];
      final stale = <String>[];
      for (final query in ungated) {
        final callers = journalMentions
            .where((d) => RegExp('\\b${query.name}\\(').hasMatch(d.source))
            .toList();
        final undispatched = callers
            .where((d) => !_dartGate.hasMatch(d.source))
            .map(_key)
            .toList();
        final listed = _ungatedNamedQueries.containsKey(query.name);
        if (callers.isEmpty) {
          offenders.add('${query.name}: no caller in lib/ — delete it');
        } else if (undispatched.isNotEmpty && !listed) {
          offenders.add(
            '${query.name}: called without a dispatch on the flag from '
            '${undispatched.join(', ')}',
          );
        } else if (undispatched.isEmpty && listed) {
          stale.add(
            '${query.name}: every caller now dispatches on the flag',
          );
        }
      }
      for (final name in _ungatedNamedQueries.keys) {
        final query = queries.where((q) => q.name == name).firstOrNull;
        if (query == null) {
          stale.add('$name: no such named query');
        } else if (!_readsJournalSql.hasMatch(query.sql)) {
          stale.add('$name: no longer reads journal rows');
        } else if (_sqlGate.hasMatch(query.sql)) {
          stale.add('$name: now references the private column');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'These named queries read journal rows without the private '
            'gate. Gate them by one of the three mechanisms in $_concept, '
            'or add them to _ungatedNamedQueries with the reason:\n'
            '${offenders.join('\n')}',
      );
      expect(
        stale,
        isEmpty,
        reason:
            'These _ungatedNamedQueries entries no longer describe an '
            'exception; remove them:\n${stale.join('\n')}',
      );
    });

    test('every Dart declaration reading journal rows gates or is listed '
        'with a reason', () {
      final readers = journalMentions.where(
        (d) =>
            !_filesOutsideTheReadPath.containsKey(d.file) &&
            (_readsJournalSql.hasMatch(d.source) ||
                _readsJournalApi.hasMatch(d.source)),
      );
      final offenders = <String>[];
      final stale = <String>[];
      for (final reader in readers) {
        final gated = _dartGate.hasMatch(reader.source);
        final listed = _ungatedDeclarations.containsKey(_key(reader));
        if (!gated && !listed) offenders.add(_key(reader));
        if (gated && listed) {
          stale.add('${_key(reader)}: now references the gate');
        }
      }
      final seen = readers.map(_key).toSet();
      for (final key in _ungatedDeclarations.keys) {
        if (!seen.contains(key)) {
          stale.add('$key: no such declaration reads journal rows');
        }
      }
      for (final file in _filesOutsideTheReadPath.keys) {
        if (!journalMentions.any(
          (d) => d.file == file && _readsJournalSql.hasMatch(d.source),
        )) {
          stale.add('$file: contains no journal SQL');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'These declarations read journal rows without the private '
            'gate. Gate them by one of the three mechanisms in $_concept, '
            'or add them to _ungatedDeclarations with the reason:\n'
            '${offenders.join('\n')}',
      );
      expect(
        stale,
        isEmpty,
        reason:
            'These allowlist entries no longer describe an exception; '
            'remove them:\n${stale.join('\n')}',
      );
    });

    // Guards the guard: a scanner that matched nothing would pass both
    // assertions above while enforcing nothing.
    test('recognises the gate where it is known to be applied', () {
      final filteredJournal = queries.singleWhere(
        (q) => q.name == 'filteredJournal',
      );
      expect(_readsJournalSql.hasMatch(filteredJournal.sql), isTrue);
      expect(_sqlGate.hasMatch(filteredJournal.sql), isTrue);

      final habitRecords = journalMentions.singleWhere(
        (d) =>
            d.file == 'lib/database/database_data_queries.dart' &&
            d.name == 'getHabitCompletionRecordsInRange',
      );
      expect(_readsJournalSql.hasMatch(habitRecords.source), isTrue);
      expect(_dartGate.hasMatch(habitRecords.source), isTrue);

      final dayAudio = journalMentions.singleWhere(
        (d) =>
            d.file == 'lib/database/database_journal_queries.dart' &&
            d.name == 'getDayAudioEntries',
      );
      expect(_readsJournalApi.hasMatch(dayAudio.source), isTrue);
    });
  });
}

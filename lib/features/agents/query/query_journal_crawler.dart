import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';

class QueryScopeUnavailable implements Exception {
  const QueryScopeUnavailable();
}

/// Text is read from exactly one stored representation, never stitched from
/// unrelated fields. An intentionally empty entry edit suppresses transcripts.
class QuerySourceDocument {
  const QuerySourceDocument({
    required this.entry,
    required this.text,
    required this.version,
    required this.kind,
    this.versionDate,
  });

  final JournalEntity entry;
  final String text;
  final String version;
  final DateTime? versionDate;
  final QuerySourceKind kind;

  String get fingerprint => sha256.convert(utf8.encode(text)).toString();

  String get label {
    final title = switch (entry) {
      Task(:final data) => data.title,
      ProjectEntry(:final data) => data.title,
      JournalAudio(:final data) => data.audioFile,
      _ => text.split('\n').first.trim(),
    };
    // A single-paragraph note must not duplicate the whole source as metadata.
    return title.length > 120 ? '${title.substring(0, 117)}...' : title;
  }

  static QuerySourceDocument? fromEntry(JournalEntity entry) {
    final kind = switch (entry) {
      JournalAudio() => QuerySourceKind.recording,
      Task() => QuerySourceKind.task,
      ProjectEntry() => QuerySourceKind.project,
      Checklist() || ChecklistItem() => QuerySourceKind.checklist,
      _ => QuerySourceKind.text,
    };
    var text = entry.entryText?.plainText;
    var version = 'entryText';
    var versionDate = entry.meta.updatedAt;
    if (text == null ||
        (text.trim().isEmpty &&
            (entry is Task ||
                entry is ProjectEntry ||
                entry is Checklist ||
                entry is ChecklistItem))) {
      switch (entry) {
        case JournalAudio(:final data):
          final transcripts = [...?data.transcripts]
            ..sort((a, b) => b.created.compareTo(a.created));
          final transcript = transcripts.firstOrNull;
          text = transcript?.transcript;
          if (transcript != null) {
            versionDate = transcript.created;
            version =
                'transcript:${transcript.library}:${transcript.model}:'
                '${transcript.id ?? transcript.created.toIso8601String()}';
          }
        case Task(:final data):
          text = data.title;
          version = 'title';
        case ProjectEntry(:final data):
          text = data.title;
          version = 'title';
        case Checklist(:final data):
          text = data.title;
          version = 'title';
        case ChecklistItem(:final data):
          text = data.title;
          version = 'title';
        default:
          break;
      }
    }
    if (text == null || text.trim().isEmpty) return null;
    return QuerySourceDocument(
      entry: entry,
      text: text,
      version: version.startsWith('transcript:')
          ? version
          : '$version:${entry.meta.updatedAt.toIso8601String()}',
      kind: kind,
      versionDate: versionDate,
    );
  }
}

typedef QueryAffiliation = ({
  List<String> labels,
  List<QuerySourceRef> sources,
});

class QueryCorpus {
  const QueryCorpus({
    required this.scope,
    required this.categoryId,
    required this.homeIds,
    required this.documents,
    required this.access,
    required this.coverage,
    required this.affiliations,
  });

  final QueryScope scope;
  final String? categoryId;
  final Set<String> homeIds;
  final List<QuerySourceDocument> documents;
  final QueryAccessSnapshot access;
  final QueryCoverage coverage;
  final Map<String, QueryAffiliation> affiliations;
}

/// Bounded read-only crawler. Link discovery begins at the home scope, then
/// keyword candidates and recent material can expand within the same category.
/// Every discovered ID is rechecked against live visibility before use.
class QueryJournalCrawler {
  const QueryJournalCrawler({
    required this.journal,
    required this.access,
    required this.search,
    this.maxDocuments = 60,
  });

  final JournalDb journal;
  final QuerySourceAccess access;
  final Future<List<String>> Function(String query) search;
  final int maxDocuments;

  static const sourceTypes = [
    'Task',
    'ProjectEntry',
    'JournalEntry',
    'JournalAudio',
    'JournalImage',
    'Checklist',
    'ChecklistItem',
  ];

  Future<QueryCorpus> discover(
    QueryScope scope,
    List<String> searchTerms, {
    bool homeOnly = false,
    bool ownTaskOnly = false,
    QuerySourceKind? kind,
  }) async {
    if (ownTaskOnly && scope.kind != QueryScopeKind.task) {
      throw ArgumentError('Original-entry fallback requires a home task');
    }
    final initial = await access.load([scope.id]);
    final home = initial.entries[scope.id];
    final categoryId = scope.kind == QueryScopeKind.category
        ? scope.id
        : home?.meta.categoryId;
    if (!initial.allowsCategory(categoryId) ||
        (scope.kind != QueryScopeKind.category &&
            (home == null || !initial.allowsEntry(home)))) {
      throw const QueryScopeUnavailable();
    }
    final homeIds = <String>{if (home != null) home.meta.id};
    if (scope.kind == QueryScopeKind.project) {
      final taskIds = await journal.getTaskIdsForProjects({scope.id});
      final tasks = await access.load(taskIds);
      homeIds.addAll(
        tasks.entries.values
            .where(
              (entry) =>
                  tasks.allowsEntry(entry) &&
                  entry.meta.categoryId == categoryId,
            )
            .map((entry) => entry.meta.id),
      );
    }
    if (homeIds.isNotEmpty) {
      final links = await journal.linksForEntryIdsBidirectional(homeIds);
      for (final link in links) {
        if (link.hidden == true || link.deletedAt != null) continue;
        homeIds
          ..add(link.fromId)
          ..add(link.toId);
      }
    }

    final candidates = <String>{...homeIds};
    var incomplete = false;
    final expand = categoryId != null && !homeOnly;
    if (expand || scope.kind == QueryScopeKind.category) {
      final terms = searchTerms
          .expand(
            (term) => RegExp(r'[\p{L}\p{N}]+', unicode: true).allMatches(term),
          )
          .map((match) => match.group(0)!)
          .where((term) => term.length > 2)
          .take(8)
          .toList();
      if (terms.isNotEmpty) {
        final ids = await search(terms.map((term) => '"$term"').join(' OR '));
        // The journal query applies scope and privacy BEFORE its limit.
        for (var offset = 0; offset < ids.length; offset += 400) {
          final end = (offset + 400).clamp(0, ids.length);
          candidates.addAll(
            (await _categoryEntries(
              categoryId!,
              ids: ids.sublist(offset, end),
              limit: maxDocuments + 1,
            )).map((entry) => entry.meta.id),
          );
          if (candidates.length > maxDocuments * 2) {
            incomplete = true;
            break;
          }
        }
      }
      final recent = await _categoryEntries(
        categoryId!,
        limit: maxDocuments + 1,
      );
      candidates.addAll(recent.map((entry) => entry.meta.id));
      incomplete = incomplete || recent.length > maxDocuments;
    }
    final current = await access.load(candidates);
    final documents = <QuerySourceDocument>[];
    var missingTranscripts = 0;
    final unreadableSources = <QuerySourceRef>[];
    for (final id in candidates) {
      final entry = current.entries[id];
      if (entry == null ||
          !current.allowsEntry(entry) ||
          entry.meta.categoryId != categoryId) {
        continue;
      }
      if (ownTaskOnly &&
          entry.meta.id != scope.id &&
          (entry is Task || entry is ProjectEntry)) {
        continue;
      }
      final document = QuerySourceDocument.fromEntry(entry);
      if (document == null) {
        if (entry is JournalAudio &&
            (kind == null || kind == QuerySourceKind.recording)) {
          missingTranscripts++;
          unreadableSources.add(current.reference(entry));
        }
        continue;
      }
      if (kind != null && document.kind != kind) continue;
      if (documents.length == maxDocuments) {
        incomplete = true;
        break;
      }
      documents.add(document);
    }
    return QueryCorpus(
      scope: scope,
      categoryId: categoryId,
      homeIds: homeIds,
      documents: documents,
      access: current,
      coverage: QueryCoverage(
        incomplete: incomplete || missingTranscripts > 0,
        missingTranscripts: missingTranscripts,
        expanded: expand,
        unreadableSources: unreadableSources,
      ),
      affiliations: await _affiliations(documents),
    );
  }

  Future<List<JournalEntity>> _categoryEntries(
    String categoryId, {
    required int limit,
    List<String>? ids,
  }) async => journal.getJournalEntities(
    types: sourceTypes,
    starredStatuses: const [false, true],
    privateStatuses: await journal.getConfigFlag('private')
        ? const [false, true]
        : const [false],
    flaggedStatuses: const [0, 1, 2, 3],
    ids: ids,
    categoryIds: {categoryId},
    limit: limit,
  );

  Future<Map<String, QueryAffiliation>> _affiliations(
    List<QuerySourceDocument> documents,
  ) async {
    final ids = documents.map((d) => d.entry.meta.id).toSet();
    if (ids.isEmpty) return {};
    final links = await journal.linksForEntryIdsBidirectional(ids);
    final linkedIds = <String>{};
    for (final link in links) {
      if (link.hidden == true || link.deletedAt != null) continue;
      linkedIds
        ..add(link.fromId)
        ..add(link.toId);
    }
    linkedIds.addAll(ids);
    final related = await access.load(linkedIds);
    final taskProjects = await journal.getProjectIdMapForTasks({
      for (final entry in related.entries.values)
        if (entry is Task && related.allowsEntry(entry)) entry.meta.id,
    });
    final projects = await access.load(taskProjects.values);
    final result = <String, QueryAffiliation>{};
    for (final document in documents) {
      final labels = <String>{};
      final sources = <QuerySourceRef>[];
      void addProject(String taskId) {
        final project = projects.entries[taskProjects[taskId]];
        if (project is ProjectEntry &&
            projects.allowsEntry(project) &&
            project.meta.categoryId == document.entry.meta.categoryId &&
            !sources.any((source) => source.id == project.meta.id)) {
          labels.add(project.data.title);
          sources.add(projects.reference(project));
        }
      }

      if (document.entry is Task) addProject(document.entry.meta.id);
      for (final link in links) {
        if (link.hidden == true || link.deletedAt != null) continue;
        final id = document.entry.meta.id;
        final other = link.fromId == id
            ? link.toId
            : link.toId == id
            ? link.fromId
            : null;
        final entry = related.entries[other];
        if (entry == null ||
            !related.allowsEntry(entry) ||
            entry.meta.categoryId != document.entry.meta.categoryId) {
          continue;
        }
        if (entry is Task || entry is ProjectEntry) {
          labels.add(
            entry is Task
                ? entry.data.title
                : (entry as ProjectEntry).data.title,
          );
          sources.add(related.reference(entry));
          if (entry is Task) addProject(entry.meta.id);
        }
      }
      result[document.entry.meta.id] = (
        labels: labels.toList(),
        sources: sources,
      );
    }
    return result;
  }
}

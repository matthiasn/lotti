/// The `search_memory` tool shared by every agent that recalls from its own
/// memory log (ADR 0057 decision 1): the parameter schema, argument parsing,
/// the search itself over an [AgentLogCompactor], and the text the model reads
/// back. Each agent supplies only its corpus — the inline events the compactor
/// scans beside the agent's observations — and the tool's description.
library;

import 'package:lotti/features/agents/memory/memory_links.dart';
import 'package:lotti/features/agents/sync/agent_log_compactor.dart';
import 'package:lotti/features/ai/service/text_chunker.dart';

/// The parameters a memory-search tool declares: `query` keywords, or `ids`
/// to pull up, and a `limit`.
const Map<String, Object?> memorySearchParameters = {
  'type': 'object',
  'properties': {
    'query': {
      'type': 'string',
      'description': 'Keywords to match (all must appear, any order).',
    },
    'ids': {
      'type': 'array',
      'items': {'type': 'string'},
      'description':
          'Specific entry ids to pull up (e.g. to follow a '
          '[[relation:id]] link). Provide query or ids.',
    },
    'limit': {
      'type': 'integer',
      'description': 'Max entries to return (1-20, default 8).',
      'minimum': 1,
      'maximum': 20,
    },
  },
  'additionalProperties': false,
};

/// What the model answers when it asked for nothing.
const memorySearchMissingTermsError =
    'Error: provide "query" keywords or "ids" to recall.';

/// What the model answers when the search itself failed.
const memorySearchFailedError = 'Error: memory search failed.';

/// One parsed memory search: ids to pull up, or a keyword `query`.
typedef MemorySearchRequest = ({String query, Set<String> ids, int limit});

/// Parses a memory-search tool call, or null when it names neither keywords
/// nor ids. A `limit` outside 1–20 is clamped; a missing or non-integer one
/// defaults to 8. Tolerant of blank and non-string ids.
MemorySearchRequest? parseMemorySearchRequest(Map<String, dynamic> args) {
  final rawIds = args['ids'];
  final ids = rawIds is List
      ? <String>{
          for (final e in rawIds)
            if (e is String && e.trim().isNotEmpty) e.trim(),
        }
      : const <String>{};
  final rawQuery = args['query'];
  final query = rawQuery is String ? rawQuery.trim() : '';
  if (ids.isEmpty && query.isEmpty) return null;
  final rawLimit = args['limit'];
  final limit = rawLimit is int ? rawLimit.clamp(1, 20) : 8;
  return (query: query, ids: ids, limit: limit);
}

/// Runs [request] over [compactor]'s view of [agentId]'s log: ids are pulled
/// up directly, otherwise every keyword must appear. Newest first.
Future<List<MemoryLogHit>> runMemorySearch(
  AgentLogCompactor compactor,
  String agentId,
  MemorySearchRequest request, {
  Set<String> extraKnownIds = const {},
}) => request.ids.isNotEmpty
    ? compactor.resolveByIds(
        agentId,
        ids: request.ids,
        extraKnownIds: extraKnownIds,
      )
    : compactor.searchLog(
        agentId,
        query: request.query,
        limit: request.limit,
        extraKnownIds: extraKnownIds,
      );

/// The text the model reads back for [hits] of [request].
///
/// Unbounded by default — the day agent's form. A caller with a wake budget
/// passes [hitTokenBudget], which cuts each hit's text to fit, and
/// [totalTokenBudget], which stops listing hits once the next would exceed it
/// and says how many were left out, so the model can narrow its query
/// rather than read a wall of history.
String formatMemorySearchResult(
  MemorySearchRequest request,
  List<MemoryLogHit> hits, {
  int? hitTokenBudget,
  int? totalTokenBudget,
}) {
  final ids = request.ids;
  final subject = ids.isNotEmpty
      ? 'ids ${ids.join(', ')}'
      : '"${request.query}"';
  if (hits.isEmpty) return 'No memory entries match $subject.';

  final lines = <String>[];
  var spent = 0;
  for (final hit in hits) {
    final text = hitTokenBudget == null
        ? hit.text
        : TextChunker.truncateToTokens(hit.text, hitTokenBudget);
    final line = StringBuffer(
      '- [${hit.at.toIso8601String()}] '
      '(${hit.type}${hit.edited ? ', edited' : ''}) '
      '(id: ${hit.contentEntryId}) $text',
    );
    if (hit.supersededByEntryId != null) {
      line.write(' [superseded by ${hit.supersededByEntryId}]');
    }
    if (hit.links.isNotEmpty) {
      line
        ..writeln()
        ..write('  links: ${hit.links.map(formatLink).join(', ')}');
    }
    final rendered = line.toString();
    final cost = TextChunker.estimateTokens(rendered);
    if (totalTokenBudget != null &&
        lines.isNotEmpty &&
        spent + cost > totalTokenBudget) {
      break;
    }
    lines.add(rendered);
    spent += cost;
  }

  final buf = StringBuffer(
    'Found ${hits.length} memory match(es) for $subject (most recent first):',
  );
  for (final line in lines) {
    buf
      ..writeln()
      ..write(line);
  }
  final omitted = hits.length - lines.length;
  if (omitted > 0) {
    buf
      ..writeln()
      ..write(
        '($omitted more not shown — narrow the query or pull them up by id.)',
      );
  }
  return buf.toString();
}

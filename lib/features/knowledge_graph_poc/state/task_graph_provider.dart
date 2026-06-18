/// Projects a real task's `linked_entries` neighborhood into the POC graph
/// model (ADR 0029 Phase 1). BFS to depth 2 from the task over bidirectional
/// links, plus its project (containment) and checklists/items (embedded refs),
/// classified into relation kinds and colored by real category colors.
library;

import 'dart:isolate';

import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_layout_engine.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_models.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/image_utils.dart';

/// Synthetic category id used when an entry has no category.
const String kUncategorized = 'uncategorized';

const int _maxDepth = 2;
const int _maxNodes = 140;

/// Cap on sibling tasks pulled in per project, so a huge project can't swamp
/// the local view.
const int _maxSiblingsPerProject = 24;

/// The graph for a task plus the real category colors + names to render it.
class TaskGraphData {
  const TaskGraphData({
    required this.scenario,
    required this.categoryColors,
    this.categoryNames = const {},
    this.layout,
  });

  final GraphScenario scenario;
  final Map<String, Color> categoryColors;

  /// Real category id → display name (so the inspector/legend show "Lotti",
  /// not a UUID).
  final Map<String, String> categoryNames;

  /// Layout computed off the main thread (see [taskGraphProvider]); the view
  /// renders the first frame from it instead of relaxing the graph on the UI
  /// thread. Null only when a caller builds the data without a layout pass.
  final GraphLayout? layout;
}

/// Node type for a journal entity (pure; unit-tested).
GraphNodeType graphNodeTypeFor(JournalEntity e) {
  return switch (e) {
    Task() => GraphNodeType.task,
    ProjectEntry() => GraphNodeType.project,
    JournalEntry() => GraphNodeType.textEntry,
    JournalAudio() => GraphNodeType.audioEntry,
    JournalImage() => GraphNodeType.imageEntry,
    AiResponseEntry() => GraphNodeType.aiResponse,
    Checklist() => GraphNodeType.checklist,
    ChecklistItem() => GraphNodeType.checklistItem,
    RatingEntry() => GraphNodeType.rating,
    _ => GraphNodeType.textEntry,
  };
}

/// Short display label for a node (pure; unit-tested).
String graphNodeLabelFor(JournalEntity e) {
  switch (e) {
    case Task():
      return e.data.title.trim().isEmpty
          ? 'Untitled task'
          : e.data.title.trim();
    case ProjectEntry():
      return e.data.title.trim().isEmpty ? 'Project' : e.data.title.trim();
    case Checklist():
      return e.data.title.trim().isEmpty ? 'Checklist' : e.data.title.trim();
    case ChecklistItem():
      return e.data.title.trim().isEmpty ? 'Item' : e.data.title.trim();
    case AiResponseEntry():
      return 'AI summary';
    case RatingEntry():
      return 'Rating';
    case JournalEntry():
      return _firstLine(e.entryText?.plainText) ?? 'Note';
    case JournalAudio():
      return _firstLine(e.entryText?.plainText) ?? 'Audio note';
    case JournalImage():
      return _firstLine(e.entryText?.plainText) ?? 'Photo';
    default:
      return 'Entry';
  }
}

/// Relation kind for a link given its two resolved endpoints (pure; tested).
GraphEdgeKind edgeKindFor(EntryLink link, JournalEntity a, JournalEntity b) {
  return switch (link) {
    ProjectLink() => GraphEdgeKind.containment,
    RatingLink() => GraphEdgeKind.evaluation,
    _ =>
      (a is AiResponseEntry || b is AiResponseEntry)
          ? GraphEdgeKind.provenance
          : GraphEdgeKind.association,
  };
}

/// Trims [s] and returns null when it is null or blank (so empty agent fields
/// fall through to the next source / the inspector's generic treatment).
String? _clean(String? s) {
  final t = s?.trim() ?? '';
  return t.isEmpty ? null : t;
}

String? _firstLine(String? s) {
  final t = (s ?? '').trim();
  if (t.isEmpty) return null;
  final first = t.split('\n').first.trim();
  if (first.isEmpty) return null;
  return first.length <= 42 ? first : '${first.substring(0, 41)}…';
}

bool _isLive(EntryLink link) => link.hidden != true && link.deletedAt == null;

/// Relaxes [scenario] into a layout on a background isolate. Kept at top level
/// (rather than an inline closure in the provider) so the isolate entry point
/// captures only [scenario] — an inline closure would capture the whole
/// provider body, including the unsendable riverpod `Ref`/`Future`.
Future<GraphLayout> layoutTaskGraphOffThread(GraphScenario scenario) =>
    Isolate.run(() => computeLayoutForScenario(scenario));

/// Loads the knowledge graph around a task (focus) — its links (depth 2),
/// project and checklists — and the real category colors. Null if the id is
/// not a journal entity.
final FutureProviderFamily<TaskGraphData?, String> taskGraphProvider =
    FutureProvider.autoDispose.family<TaskGraphData?, String>((
      ref,
      taskId,
    ) async {
      final db = getIt<JournalDb>();
      final cache = getIt<EntitiesCacheService>();
      final notifications = getIt<UpdateNotifications>();

      // Refresh when the seed task OR any loaded neighbor (linked task,
      // checklist item, rating, AI response, …) changes — not just the seed —
      // so a change to a connected node doesn't leave the graph stale. The
      // listener closes over `entities`, which grows as the BFS loads nodes.
      final entities = <String, JournalEntity>{};
      final sub = notifications.updateStream.listen((ids) {
        if (ids.contains(taskId) || ids.any(entities.containsKey)) {
          ref.invalidateSelf();
        }
      });
      ref.onDispose(sub.cancel);

      final focus = await db.journalEntityById(taskId);
      if (focus == null) return null;

      entities[focus.id] = focus;
      final visited = <String>{focus.id};
      final edgeKeys = <String>{};
      final edges = <GraphEdge>[];

      void addEdge(String from, String to, GraphEdgeKind kind) {
        if (from == to) return;
        if (edgeKeys.add('$from|$to|${kind.name}')) {
          edges.add(GraphEdge(fromId: from, toId: to, kind: kind));
        }
      }

      final expandedProjects = <String>{};
      var frontier = <String>{focus.id};
      var level = 0;
      while (frontier.isNotEmpty &&
          level < _maxDepth &&
          entities.length < _maxNodes) {
        final links = await db.linksForEntryIdsBidirectional(frontier);
        final wanted = <String>{};
        for (final link in links) {
          if (!_isLive(link)) continue;
          if (!entities.containsKey(link.fromId)) wanted.add(link.fromId);
          if (!entities.containsKey(link.toId)) wanted.add(link.toId);
        }

        // Project (containment) + checklists (embedded) for tasks in frontier.
        final projectByTask = <String, ProjectEntry>{};
        final checklistIdsByTask = <String, List<String>>{};
        for (final id in frontier) {
          final e = entities[id];
          if (e is Task) {
            final proj = await db.getProjectForTask(id);
            if (proj != null) {
              projectByTask[id] = proj;
              entities[proj.id] = proj;
              // Fan the project out into its sibling tasks (once per project)
              // so the view shows the project's task web, not just this task.
              if (expandedProjects.add(proj.id) &&
                  entities.length < _maxNodes) {
                final siblings = await db.getTasksForProject(proj.id);
                for (final s in siblings.take(_maxSiblingsPerProject)) {
                  entities[s.id] = s;
                  addEdge(proj.id, s.id, GraphEdgeKind.containment);
                }
              }
            }
            final cids = e.data.checklistIds ?? const [];
            checklistIdsByTask[id] = cids;
            wanted.addAll(cids);
          }
        }

        final fetched = await Future.wait(wanted.map(db.journalEntityById));
        for (final e in fetched) {
          if (e != null) entities[e.id] = e;
        }

        // Checklist items (one more embedded hop).
        final itemWanted = <String>{};
        for (final e in entities.values) {
          if (e is Checklist) {
            for (final it in e.data.linkedChecklistItems) {
              if (!entities.containsKey(it)) itemWanted.add(it);
            }
          }
        }
        if (itemWanted.isNotEmpty) {
          final items = await Future.wait(itemWanted.map(db.journalEntityById));
          for (final e in items) {
            if (e != null) entities[e.id] = e;
          }
        }

        for (final link in links) {
          if (!_isLive(link)) continue;
          final a = entities[link.fromId];
          final b = entities[link.toId];
          if (a == null || b == null) continue;
          addEdge(link.fromId, link.toId, edgeKindFor(link, a, b));
        }
        projectByTask.forEach((task, proj) {
          addEdge(proj.id, task, GraphEdgeKind.containment);
        });
        checklistIdsByTask.forEach((task, cids) {
          for (final cid in cids) {
            final cl = entities[cid];
            if (cl == null) continue;
            addEdge(task, cid, GraphEdgeKind.association);
            if (cl is Checklist) {
              for (final it in cl.data.linkedChecklistItems) {
                if (entities.containsKey(it)) {
                  addEdge(cid, it, GraphEdgeKind.checklist);
                }
              }
            }
          }
        });

        // Next frontier: newly-seen TASK nodes (expand tasks only).
        final next = <String>{};
        for (final e in entities.values) {
          if (visited.add(e.id) && e is Task && level + 1 < _maxDepth) {
            next.add(e.id);
          }
        }
        frontier = next;
        level++;
      }

      // Resolve task cover art (its `coverArtId` image) so the inspector shows
      // a real cover banner for task previews. Some cover images are already
      // loaded by the BFS; fetch only the missing ones.
      final coverArtIds = <String>{
        for (final e in entities.values)
          if (e is Task && (e.data.coverArtId?.isNotEmpty ?? false))
            e.data.coverArtId!,
      };
      final missingCovers = coverArtIds
          .where((id) => entities[id] is! JournalImage)
          .toList();
      final fetchedCovers = await Future.wait(
        missingCovers.map(db.journalEntityById),
      );
      final coverPathById = <String, String>{};
      for (final e in [...entities.values, ...fetchedCovers]) {
        if (e is JournalImage && coverArtIds.contains(e.id)) {
          coverPathById[e.id] = getFullImagePath(e);
        }
      }

      // Latest assigned-agent report per task — drives the inspector's
      // one-liner + TL;DR. One batched query for every task in the graph.
      final taskIds = [
        for (final e in entities.values)
          if (e is Task) e.id,
      ];
      final reportsByTask = taskIds.isEmpty
          ? const <String, AgentReportEntity>{}
          : await ref
                .read(agentRepositoryProvider)
                .getLatestTaskReportsForTaskIds(taskIds);

      final now = DateTime.now();
      final nodes = <GraphNode>[
        for (final e in entities.values.take(_maxNodes))
          GraphNode(
            id: e.id,
            type: graphNodeTypeFor(e),
            label: graphNodeLabelFor(e),
            categoryId: e.categoryId ?? kUncategorized,
            createdAt: e.meta.createdAt,
            imagePath: e is JournalImage ? getFullImagePath(e) : null,
            coverImagePath: e is Task ? coverPathById[e.data.coverArtId] : null,
            oneLiner: e is Task ? _clean(reportsByTask[e.id]?.oneLiner) : null,
            tldr: switch (e) {
              Task() =>
                _clean(reportsByTask[e.id]?.tldr) ??
                    _clean(reportsByTask[e.id]?.content),
              AiResponseEntry() => _clean(e.data.response),
              _ => null,
            },
          ),
      ];
      final nodeIds = nodes.map((n) => n.id).toSet();
      final keptEdges = edges
          .where((e) => nodeIds.contains(e.fromId) && nodeIds.contains(e.toId))
          .toList();

      final categoryColors = <String, Color>{};
      final categoryNames = <String, String>{};
      for (final n in nodes) {
        if (categoryColors.containsKey(n.categoryId)) continue;
        final cat = cache.getCategoryById(n.categoryId);
        if (cat == null) continue;
        final hex = cat.color;
        if (hex != null && hex.isNotEmpty) {
          categoryColors[n.categoryId] = categoryColorFromHex(hex);
        }
        if (cat.name.isNotEmpty) {
          categoryNames[n.categoryId] = cat.name;
        }
      }

      final scenario = GraphScenario(
        name: graphNodeLabelFor(focus),
        seedId: focus.id,
        nodes: nodes,
        edges: keptEdges,
        now: now,
      );

      // The force-directed relax is O(N²) over up to _maxNodes nodes (hundreds
      // of iterations for world-scale graphs) — run it on a background isolate
      // so opening the page never blocks the UI thread. The scenario is plain
      // sendable data and the layout is pure/deterministic.
      final layout = await layoutTaskGraphOffThread(scenario);

      return TaskGraphData(
        scenario: scenario,
        categoryColors: categoryColors,
        categoryNames: categoryNames,
        layout: layout,
      );
    });

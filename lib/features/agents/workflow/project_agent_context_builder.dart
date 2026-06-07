part of 'project_agent_workflow.dart';

/// Prompt/context assembly and payload-resolution helpers of
/// [ProjectAgentWorkflow].
extension ProjectAgentContextBuilder on ProjectAgentWorkflow {
  String _buildSystemPrompt(_TemplateContext? ctx) {
    const scaffold = '''
You are a Project Agent — a persistent assistant that maintains a high-level
report for a project. Your job is to:

1. Monitor the overall health and progress of the project by analyzing linked
   tasks, their statuses, and task agent reports.
2. Identify cross-cutting concerns, blockers, and dependencies between tasks.
3. Publish an updated project report via the `update_project_report` tool.
4. Record observations worth remembering for future wakes.
5. Recommend next steps when appropriate.

## Report

You MUST call `update_project_report` exactly once at the end of every wake
with the updated expanded report body as markdown. Structure the report as
follows:

### Required Sections

1. **📊 Progress Overview** — Summary of task completion rates and overall
   project health.
2. **✅ Recent Achievements** — What was accomplished since the last report.
   Omit if nothing new.
3. **📌 Active Work** — Currently in-progress tasks and their status.
   Omit if no active work.
4. **⚠️ Risks & Blockers** — Issues that could delay the project.
   Omit if none.
5. **📅 Next Steps** — Recommended priorities for the next work cycle.

Do not add a separate markdown headline or repeat the project title above
these sections. The UI already renders the title independently. Do not
repeat the TLDR inside the markdown body; the UI renders it separately from
the `tldr` field.

When referencing a linked task whose ID is present in the project context,
you may link the readable task title to `/tasks/<taskId>` so the user can jump
from report text to the task's proof of work. Never use bare task IDs or
shortened hashes as visible link text, and never invent task IDs.

## Health Assessment

Every `update_project_report` call must also include:

- `tldr`: a concise 1-3 sentence overview shown in the collapsed report view
- `health_band`: one of `surviving`, `on_track`, `watch`, `at_risk`, or
  `blocked`
- `health_rationale`: a short user-facing explanation of why the band fits
  right now
- `health_confidence`: optional number from 0 to 1

You are the source of truth for the user-facing project health band. Do not
treat this as a mechanical task-count rubric. Use your best overall judgment
from the project context, linked task reports, and the latest changes.

## Observations

Use `record_observations` for private notes that should persist across wakes
but are not shown in the user-facing report.

## Tool Usage

When several independent updates are warranted in one wake, issue them as
parallel tool calls in a single turn rather than one per turn.
`update_project_report` stays the separate, final step.

## Deferred Tools

The `recommend_next_steps`, `update_project_status`, and `create_task` tools
are deferred — they queue changes for user review rather than executing
immediately.''';

    if (ctx == null) return scaffold;

    final version = ctx.version;
    final soulVersion = ctx.soulVersion;
    final generalDirective = version.generalDirective.trim();
    final reportDirective = version.reportDirective.trim();
    final hasNewDirectives =
        generalDirective.isNotEmpty || reportDirective.isNotEmpty;

    final buf = StringBuffer()..write(scaffold);

    if (hasNewDirectives) {
      if (reportDirective.isNotEmpty) {
        buf
          ..writeln()
          ..writeln()
          ..writeln('## Report Directive')
          ..writeln()
          ..write(reportDirective);
      }

      if (soulVersion != null) {
        // Soul assigned: separate personality from operational directives.
        _appendSoulPersonality(buf, soulVersion);
        if (generalDirective.isNotEmpty) {
          buf
            ..writeln()
            ..writeln()
            ..writeln('## Your Operational Directives')
            ..writeln()
            ..write(generalDirective);
        }
      } else {
        // No soul: legacy combined heading.
        final effectiveGeneralDirective = generalDirective.isNotEmpty
            ? generalDirective
            : version.directives;
        if (effectiveGeneralDirective.trim().isNotEmpty) {
          buf
            ..writeln()
            ..writeln()
            ..writeln('## Your Personality & Directives')
            ..writeln()
            ..write(effectiveGeneralDirective);
        }
      }
    } else {
      // Legacy fallback: single directives field.
      final legacyDirective = version.directives.trim();
      if (legacyDirective.isNotEmpty) {
        buf
          ..writeln()
          ..writeln()
          ..writeln('## Your Personality & Directives')
          ..writeln()
          ..write(legacyDirective);
      }
    }

    return buf.toString();
  }

  /// Appends soul personality fields to the prompt buffer.
  static void _appendSoulPersonality(
    StringBuffer buf,
    SoulDocumentVersionEntity soul,
  ) {
    buf
      ..writeln()
      ..writeln()
      ..writeln('## Your Personality')
      ..writeln()
      ..write(soul.voiceDirective);

    if (soul.toneBounds.trim().isNotEmpty) {
      buf
        ..writeln()
        ..writeln()
        ..write(soul.toneBounds);
    }
    if (soul.coachingStyle.trim().isNotEmpty) {
      buf
        ..writeln()
        ..writeln()
        ..write(soul.coachingStyle);
    }
    if (soul.antiSycophancyPolicy.trim().isNotEmpty) {
      buf
        ..writeln()
        ..writeln()
        ..write(soul.antiSycophancyPolicy);
    }
  }

  ({String text, int? logStart, int? logEnd}) _buildUserMessage({
    required JournalEntity projectEntity,
    required AgentReportEntity? lastReport,
    required List<AgentMessageEntity> observations,
    required Map<String, AgentMessagePayloadEntity> observationPayloads,
    required String linkedTasksContext,
    required Set<String> triggerTokens,
    String? compactedLog,
  }) {
    final buf = StringBuffer();

    // With compaction on (ADR 0017/0020), the append-only event log — the
    // project's captured journal entries interleaved with the agent's own
    // observations — leads as the largest stable block (summary changes only
    // at folds, the tail only appends), so the provider prefix cache survives
    // consecutive wakes. The mutable blocks follow. The block's offsets are
    // recorded so the persisted prompt record can omit it (ADR 0020 v2).
    int? logStart;
    int? logEnd;
    if (compactedLog != null) {
      buf.writeln('## Project Log');
      logStart = buf.length;
      buf.write(compactedLog);
      logEnd = buf.length;
      buf
        ..writeln()
        ..writeln();
    }

    buf
      ..writeln('## Project Context')
      ..writeln();

    _writeProjectContext(buf, projectEntity);

    // Project identity + linked-task summaries, then the volatile tail
    // (previous report, observations, trigger tokens).
    if (linkedTasksContext != '{}') {
      buf
        ..writeln()
        ..writeln('## Linked Tasks')
        ..writeln()
        ..writeln(linkedTasksContext);
    }

    if (lastReport != null) {
      buf
        ..writeln()
        ..writeln('## Previous Report')
        ..writeln()
        ..writeln(lastReport.content);
    }

    // With the compacted log in place, observations live in the `## Project
    // Log` event tail (folded into summaries by the same watermarks) — a
    // separate capped listing would duplicate them.
    if (compactedLog == null && observations.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('## Recent Observations')
        ..writeln();
      for (final obs in observations.take(20)) {
        final payload = obs.contentEntryId != null
            ? observationPayloads[obs.contentEntryId]
            : null;
        final text = _extractPayloadText(payload);
        buf.writeln('- [${obs.createdAt.toIso8601String()}] $text');
      }
    }

    if (triggerTokens.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('## Trigger Tokens')
        ..writeln()
        ..writeln(triggerTokens.join(', '));
    }

    return (text: buf.toString(), logStart: logStart, logEnd: logEnd);
  }

  void _writeProjectContext(StringBuffer buf, JournalEntity entity) {
    final project = entity.maybeMap(
      project: (p) => p,
      orElse: () => null,
    );

    if (project == null) {
      buf.writeln('Project entity: $entity');
      return;
    }

    final data = project.data;
    buf
      ..writeln('- **Title**: ${data.title}')
      ..writeln('- **Status**: ${data.status.label}')
      ..writeln(
        '- **Date range**: '
        '${data.dateFrom.toIso8601String().substring(0, 10)} → '
        '${data.dateTo.toIso8601String().substring(0, 10)}',
      );

    if (data.targetDate != null) {
      buf.writeln(
        '- **Target date**: '
        '${data.targetDate!.toIso8601String().substring(0, 10)}',
      );
    }

    final onHoldReason = data.status.maybeMap(
      onHold: (s) => s.reason,
      orElse: () => null,
    );
    if (onHoldReason != null && onHoldReason.isNotEmpty) {
      buf.writeln('- **On-hold reason**: $onHoldReason');
    }

    if (project.entryText?.plainText != null &&
        project.entryText!.plainText.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('### Description')
        ..writeln()
        ..writeln(project.entryText!.plainText);
    }
  }

  List<AiTool> _buildToolDefinitions() {
    return projectAgentTools
        .map(
          (tool) => AiTool(
            name: tool.name,
            description: tool.description,
            parameters: tool.parameters,
          ),
        )
        .toList();
  }

  String? _extractFinalAssistantContent(ConversationManager? manager) {
    if (manager == null) return null;
    final messages = manager.messages;
    for (var i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      if (msg is AiAssistantMessage) {
        final content = msg.content;
        if (content != null && content.isNotEmpty) {
          return content;
        }
      }
    }
    return null;
  }

  // ── Linked-task context ───────────────────────────────────────────────────

  /// Builds a JSON string with linked tasks and their task-agent reports.
  ///
  /// Project links are stored as `project -> task`, so this must resolve the
  /// project's outgoing links. Uses batch queries (2 SQL statements total) for
  /// the agent-link and report lookups to avoid an N+1 pattern when many tasks
  /// are linked to the project.
  Future<String> _buildLinkedTasksContext(String projectId) async {
    try {
      final linkedEntities = await this.journalRepository.getLinkedEntities(
        linkedTo: projectId,
      );

      final taskEntities = linkedEntities.whereType<Task>().toList();

      if (taskEntities.isEmpty) return '{}';

      final taskIds = taskEntities.map((t) => t.meta.id).toList();

      // 1. Batch-fetch all agent_task links for the linked tasks (1 query).
      var linksByTaskId = <String, List<AgentLink>>{};
      try {
        linksByTaskId = await agentRepository.getLinksToMultiple(
          taskIds,
          type: AgentLinkTypes.agentTask,
        );
      } catch (e, s) {
        _logError('batch link lookup failed', error: e, stackTrace: s);
      }

      // 2. Batch-fetch the latest reports for all linked task agents (1 query).
      var reportsByAgentId = <String, AgentReportEntity>{};
      final linkedAgentIds = linksByTaskId.values
          .expand((links) => links.map((link) => link.fromId))
          .toSet()
          .toList();
      if (linkedAgentIds.isNotEmpty) {
        try {
          reportsByAgentId = await agentRepository.getLatestReportsByAgentIds(
            linkedAgentIds,
            AgentReportScopes.current,
          );
        } catch (e, s) {
          _logError('batch report lookup failed', error: e, stackTrace: s);
        }
      }

      // 3. Assemble rows, preserving the prior fallback behavior:
      // newest link wins only if that agent has a non-empty current report.
      final taskRows = <Map<String, dynamic>>[];
      for (final task in taskEntities) {
        final row = <String, dynamic>{
          'id': task.meta.id,
          'title': task.data.title,
          'status': _taskStatusLabel(task.data.status),
        };

        final taskLinks = linksByTaskId[task.meta.id];
        if (taskLinks != null) {
          for (final link in taskLinks.orderedPrimaryFirst()) {
            final report = reportsByAgentId[link.fromId];
            if (report == null) continue;
            // Gate on a non-empty body so only "real" reports surface, but
            // embed just the compact summary to keep wake prefill small.
            if (report.content.trim().isEmpty) continue;
            row['taskAgentId'] = link.fromId;
            row['latestTaskAgentReportOneLiner'] = report.oneLiner;
            row['latestTaskAgentReportTldr'] = report.tldr;
            row['latestTaskAgentReportCreatedAt'] = report.createdAt
                .toIso8601String();
            break;
          }
        }

        taskRows.add(row);
      }

      return const JsonEncoder.withIndent('    ').convert(<String, dynamic>{
        'linked_tasks': taskRows,
      });
    } catch (e, stackTrace) {
      _logError(
        'failed to build linked tasks context',
        error: e,
        stackTrace: stackTrace,
      );
      return '{}';
    }
  }

  // ── Observation payload resolution ────────────────────────────────────────

  /// Batch-resolves all observation payloads into a map keyed by payload ID.
  Future<Map<String, AgentMessagePayloadEntity>> _resolveObservationPayloads(
    List<AgentMessageEntity> observations,
  ) async {
    final payloadIds = observations
        .map((o) => o.contentEntryId)
        .whereType<String>()
        .toSet();

    if (payloadIds.isEmpty) {
      return const <String, AgentMessagePayloadEntity>{};
    }

    // Single batched IN-list lookup instead of `Future.wait(map →
    // getEntity)`. The fan-out version showed up at 2 484 hits/day in
    // the 2026-05-10 desktop slow_queries log because each per-row
    // `WHERE id = ?` queued independently behind the writer lock; the
    // bulk path makes one round-trip regardless of payload count.
    // Non-payload entities (or ids that have no row / are soft-deleted)
    // are silently dropped — the caller renders a placeholder, same as
    // the pre-batch failure mode.
    final Map<String, AgentDomainEntity> entitiesById;
    try {
      entitiesById = await agentRepository.getEntitiesByIds(payloadIds);
    } catch (e) {
      // Non-fatal — observation will render with placeholder text.
      return const <String, AgentMessagePayloadEntity>{};
    }

    final result = <String, AgentMessagePayloadEntity>{};
    for (final entry in entitiesById.entries) {
      final entity = entry.value;
      if (entity is AgentMessagePayloadEntity) {
        result[entry.key] = entity;
      }
    }
    return result;
  }

  /// Extracts the text content from an observation payload.
  static String _extractPayloadText(AgentMessagePayloadEntity? payload) {
    if (payload == null) return '(no content)';
    final text = payload.content['text'];
    if (text is String && text.isNotEmpty) return text;
    return '(no content)';
  }

  static String _taskStatusLabel(TaskStatus status) {
    return switch (status) {
      TaskOpen() => 'open',
      TaskGroomed() => 'groomed',
      TaskInProgress() => 'in_progress',
      TaskBlocked() => 'blocked',
      TaskOnHold() => 'on_hold',
      TaskDone() => 'done',
      TaskRejected() => 'rejected',
    };
  }

  // ── Deferred item helpers ─────────────────────────────────────────────────
}

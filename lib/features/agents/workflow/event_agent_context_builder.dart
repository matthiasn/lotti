import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/tools/event_tool_definitions.dart';
import 'package:lotti/features/agents/workflow/agent_system_prompt.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:openai_dart/openai_dart.dart';

/// Callback used by the event context builder to surface non-fatal errors
/// through the owning workflow's structured logger.
typedef EventLogErrorCallback =
    void Function(String message, {Object? error, StackTrace? stackTrace});

/// Prompt/context assembly and payload-resolution collaborator of the Event
/// Agent wake cycle.
///
/// Mirrors `ProjectAgentContextBuilder` but is leaner: there is no compacted
/// event-log block (v1 events are low-frequency recaps), and the user message
/// renders the event's own metadata plus its linked photos/notes/audio/tasks —
/// the raw material the recap narrates from. The event's **rating and cover**
/// are deliberately never rendered into the context, so the model has nothing
/// to act on there.
class EventAgentContextBuilder {
  EventAgentContextBuilder({
    required this.agentRepository,
    required this.journalRepository,
    required this.logError,
  });

  final AgentRepository agentRepository;
  final JournalRepository journalRepository;
  final EventLogErrorCallback logError;

  String buildSystemPrompt({
    required AgentTemplateVersionEntity? version,
    required SoulDocumentVersionEntity? soulVersion,
  }) {
    const scaffold = '''
You are an Event Agent — you narrate a personal event into a short, warm recap
the user would actually want to re-read. An event happened once; write a story,
not a status report.

Your job each wake is to:

1. Read the event's linked photos, notes, and voice memos.
2. Synthesize what happened — the highlights, the people, the through-line.
3. Publish the recap via the `update_report` tool.
4. Record private follow-up ideas via `record_observations`.

## Report

You MUST call `update_report` exactly once at the end of every wake, providing
a compact `oneLiner` tagline, a `tldr`, and the full recap as `content`
markdown. Ground every detail in the linked entries; never invent specifics.
Do not repeat the event title as a heading — the UI renders it separately — and
do not repeat the TLDR inside the body.

## User Sovereignty

The user's **rating** (stars) and **cover photo** are their own authorship of
their memory. Never comment on them and never propose to change them. There is
no tool to do so by design.

## Observations

Use `record_observations` for private notes and follow-up ideas that should
persist across recaps but are not shown to the user.''';

    return composeAgentSystemPrompt(
      scaffold: scaffold,
      version: version,
      soulVersion: soulVersion,
    );
  }

  String buildUserMessage({
    required JournalEntity eventEntity,
    required AgentReportEntity? lastReport,
    required List<AgentMessageEntity> observations,
    required Map<String, AgentMessagePayloadEntity> observationPayloads,
    required String linkedEntriesContext,
    required Set<String> triggerTokens,
  }) {
    final buf = StringBuffer()
      ..writeln('## Event Context')
      ..writeln();

    _writeEventContext(buf, eventEntity);

    if (linkedEntriesContext.trim().isNotEmpty) {
      buf
        ..writeln()
        ..writeln('## Linked Entries')
        ..writeln()
        ..writeln(linkedEntriesContext.trim());
    }

    if (lastReport != null) {
      buf
        ..writeln()
        ..writeln('## Previous Recap')
        ..writeln()
        ..writeln(lastReport.content);
    }

    if (observations.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('## Recent Observations')
        ..writeln();
      for (final obs in observations.take(20)) {
        final payload = obs.contentEntryId != null
            ? observationPayloads[obs.contentEntryId]
            : null;
        final text = extractPayloadText(payload);
        buf.writeln('- [${obs.createdAt.toIso8601String()}] $text');
      }
    }

    if (triggerTokens.isNotEmpty) {
      final sortedTriggerTokens = triggerTokens.toList()..sort();
      buf
        ..writeln()
        ..writeln('## Trigger Tokens')
        ..writeln()
        ..writeln(sortedTriggerTokens.join(', '));
    }

    return buf.toString();
  }

  void _writeEventContext(StringBuffer buf, JournalEntity entity) {
    if (entity is! JournalEvent) {
      buf.writeln('Event entity: ${entity.meta.id}');
      return;
    }

    final data = entity.data;
    buf
      ..writeln('- **Title**: ${data.title}')
      ..writeln('- **Status**: ${data.status.label}')
      ..writeln(
        '- **When**: '
        '${entity.meta.dateFrom.toIso8601String()} → '
        '${entity.meta.dateTo.toIso8601String()}',
      );

    final note = entity.entryText?.plainText.trim();
    if (note != null && note.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('### Event note')
        ..writeln()
        ..writeln(note);
    }
  }

  List<ChatCompletionTool> buildToolDefinitions() {
    return eventAgentTools.map((tool) {
      return ChatCompletionTool(
        type: ChatCompletionToolType.function,
        function: FunctionObject(
          name: tool.name,
          description: tool.description,
          parameters: tool.parameters,
        ),
      );
    }).toList();
  }

  String? extractFinalAssistantContent(ConversationManager? manager) {
    if (manager == null) return null;
    final messages = manager.messages;
    for (var i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      final content = msg.mapOrNull(assistant: (a) => a.content);
      if (content != null && content.isNotEmpty) {
        return content;
      }
    }
    return null;
  }

  // ── Linked-entries context ────────────────────────────────────────────────

  /// Builds a readable markdown block of the event's linked photos, notes,
  /// voice memos, and tasks — the raw material the recap narrates from.
  ///
  /// Photos are summarized by count plus any captions; notes and audio render
  /// their plain text; linked tasks render title + status (prep/follow-up).
  Future<String> buildLinkedEntriesContext(String eventId) async {
    try {
      final linked = await journalRepository.getLinkedEntities(
        linkedTo: eventId,
      );
      if (linked.isEmpty) return '';

      final photoCaptions = <String>[];
      var photoCount = 0;
      final notes = <String>[];
      final audio = <String>[];
      final tasks = <Task>[];

      for (final entity in linked) {
        if (entity.meta.deletedAt != null) continue;
        if (entity is JournalImage) {
          photoCount++;
          final caption = entity.entryText?.plainText.trim();
          if (caption != null && caption.isNotEmpty) {
            photoCaptions.add(caption);
          }
        } else if (entity is JournalAudio) {
          final transcript = entity.entryText?.plainText.trim();
          if (transcript != null && transcript.isNotEmpty) {
            audio.add(transcript);
          }
        } else if (entity is Task) {
          tasks.add(entity);
        } else if (entity is JournalEntry) {
          final text = entity.entryText?.plainText.trim();
          if (text != null && text.isNotEmpty) {
            notes.add(text);
          }
        }
      }

      final buf = StringBuffer();

      if (photoCount > 0) {
        buf.writeln('### Photos ($photoCount)');
        for (final caption in photoCaptions) {
          buf.writeln('- $caption');
        }
        buf.writeln();
      }

      if (notes.isNotEmpty) {
        buf.writeln('### Notes');
        for (final note in notes) {
          buf.writeln('- $note');
        }
        buf.writeln();
      }

      if (audio.isNotEmpty) {
        buf.writeln('### Voice memos');
        for (final transcript in audio) {
          buf.writeln('- $transcript');
        }
        buf.writeln();
      }

      if (tasks.isNotEmpty) {
        buf.writeln('### Linked tasks');
        for (final task in tasks) {
          buf.writeln(
            '- ${task.data.title} (${_taskStatusLabel(task.data.status)})',
          );
        }
        buf.writeln();
      }

      return buf.toString();
    } catch (e, stackTrace) {
      logError(
        'failed to build linked entries context',
        error: e,
        stackTrace: stackTrace,
      );
      return '';
    }
  }

  // ── Observation payload resolution ────────────────────────────────────────

  /// Batch-resolves all observation payloads into a map keyed by payload ID.
  Future<Map<String, AgentMessagePayloadEntity>> resolveObservationPayloads(
    List<AgentMessageEntity> observations,
  ) async {
    final payloadIds = observations
        .map((o) => o.contentEntryId)
        .whereType<String>()
        .toSet();

    if (payloadIds.isEmpty) {
      return const <String, AgentMessagePayloadEntity>{};
    }

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
  static String extractPayloadText(AgentMessagePayloadEntity? payload) {
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
}

import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

/// The `relation` enum advertised by the link tools, in display order.
///
/// Must stay identical to the `DirectedRelation.wireName` values in
/// `relationshipDirectedOptions` — tool schemas have to be `const`, so the
/// list is restated here and pinned by a test rather than derived at runtime.
/// Every phrase reads with the CURRENT task as its subject: "This task
/// ⟨relation⟩ the other task".
const List<String> taskRelationWireNames = [
  'relates_to',
  'blocks',
  'is_blocked_by',
  'follows_up_on',
  'has_follow_up',
  'duplicates',
  'is_duplicated_by',
  'fixes',
  'is_fixed_by',
  'supersedes',
  'is_superseded_by',
];

/// Shared schema fragment describing the `relation` parameter.
const Map<String, dynamic> taskRelationParameterSchema = {
  'type': 'string',
  'enum': taskRelationWireNames,
  'description':
      'The relationship, read with the CURRENT task as its subject: '
      '"This task <relation> the other task". Directional pairs describe '
      'the same relationship from either end — "A blocks B" and '
      '"B is_blocked_by A" store the same edge. Pick the phrase matching '
      "the user's words: blocks / is_blocked_by for dependencies, "
      'supersedes / is_superseded_by when one task replaces the other, '
      'duplicates / is_duplicated_by for the same work filed twice, '
      'fixes / is_fixed_by when a task fixes a defect another tracks, '
      'follows_up_on / has_follow_up for follow-up work, and relates_to '
      'for a plain undirected association.',
};

/// Tools for recording typed relationships between the current task and
/// other tasks (ADR 0042).
const taskLinkTools = <AgentToolDefinition>[
  AgentToolDefinition(
    name: TaskAgentToolNames.linkTask,
    description:
        'Record a relationship between the current task and another '
        'EXISTING task. Use when the user states how this task relates to '
        'another one — "this is blocked by X", "this supersedes Y", "this '
        'duplicates Z". targetTaskId must be a real task id from your '
        'context (e.g. the Linked Tasks section); never invent ids. For a '
        'task that does not exist yet, use create_follow_up_task with a '
        'relation instead. May be called once per distinct relationship.',
    parameters: {
      'type': 'object',
      'properties': {
        'relation': taskRelationParameterSchema,
        'targetTaskId': {
          'type': 'string',
          'description':
              'The id of the existing task on the other end of the '
              'relationship. Must come from the current context.',
        },
      },
      'required': ['relation', 'targetTaskId'],
      'additionalProperties': false,
    },
  ),
];

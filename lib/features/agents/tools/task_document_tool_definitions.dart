import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

/// Tools for the markdown documents a task holds (ADR 0167).
///
/// The wake lists the task's documents by id and title only. The agent reads
/// one in full on request, and writes a new version — or a first document —
/// only when the user asked for it. The version is the document's text at
/// once; every earlier version stays in its history, where the user goes back
/// to one.
const taskDocumentTools = <AgentToolDefinition>[
  AgentToolDefinition(
    name: TaskAgentToolNames.readDocument,
    description:
        'Read-only. Return the full markdown of the version a document of '
        'this task shows, by the id the Documents section lists. Read a '
        'document before writing a new version of it, so the new version '
        'keeps what the user did not ask to change. Changes nothing.',
    parameters: {
      'type': 'object',
      'properties': {
        'documentId': {
          'type': 'string',
          'description': 'The document id, as listed in the Documents section.',
        },
      },
      'required': ['documentId'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: TaskAgentToolNames.writeDocumentVersion,
    description:
        'Write the full text of a document of this task, as markdown: a '
        'new version of a listed document (documentId), or a first version '
        'of a new one (newTitle). Only when the user asked for a document or '
        'for changes to one, in a voice note, a note or a chat message — '
        'never because new material arrived. It becomes the document at '
        'once, with no confirmation; earlier versions stay in its history. '
        'Write the whole document, not a diff.',
    parameters: {
      'type': 'object',
      'properties': {
        'documentId': {
          'type': 'string',
          'description':
              'The document to revise, as listed in the Documents section. '
              'Omit it to create a document.',
        },
        'newTitle': {
          'type': 'string',
          'description':
              'The title of a new document, in the task language. Only '
              'without documentId.',
        },
        'markdown': {
          'type': 'string',
          'description':
              'The complete text of the version, in markdown, in '
              'the language the user asked in.',
        },
        'changeSummary': {
          'type': 'string',
          'description':
              'One sentence on what this version changes, or what the new '
              'document holds, for the user reading its history.',
        },
      },
      'required': ['markdown', 'changeSummary'],
      'additionalProperties': false,
    },
  ),
];

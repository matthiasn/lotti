import 'package:a2ui_agent/a2ui_agent.dart';
import 'package:a2ui_core/a2ui_core.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:lotti/features/front_agent/model/front_reply_surface.dart';
import 'package:lotti/features/front_agent/workflow/front_reply_reader.dart';

/// The id of the catalog she writes her reply's UI from. It is not the
/// catalog a stored reply is drawn with (`frontReplyCatalogId`): she names
/// things, and the app composes what is stored from what the turn saw.
const frontReplyAuthoringCatalogId =
    'https://lotti.app/catalogs/companion_reply_authoring.json';

/// The notation she writes UI in. Express is `a2ui_agent`'s compact default:
/// a block is a few short lines, so her prose — and her voice — starts
/// sooner, and there are no ids or root to get wrong. It is compiled to
/// A2UI v1.0 messages here, so nothing stored depends on it; direct JSON
/// (`DirectJsonFormatFactory`) is the one-line alternative.
const InferenceFormatFactory frontReplyFormat = ExpressFormatFactory(
  allowedMessages: ['createSurface'],
);

Schema _caption() => S.string(
  description: 'A short label for screen readers. Never shown or spoken.',
);

/// A component with nothing but its caption: it places what a lookup of
/// this turn made, which the app draws from its own records.
ComponentApi _fromLookup(String name, String what) => ComponentApi(
  name: name,
  schema: S.object(
    description: '$what The app draws it live; you pass no data.',
    properties: {'caption': _caption()},
    required: ['caption'],
  ),
);

/// What she composes a reply's UI from: a small catalog of whole things,
/// each a flat list of required fields. She passes ids and placements,
/// never titles or numbers.
final Catalog<ComponentApi, FunctionImplementation> frontReplyAuthoringCatalog =
    Catalog(
      id: frontReplyAuthoringCatalogId,
      protocolVersion: A2uiProtocolVersion.v1_0,
      components: [
        ComponentApi(
          name: FrontReplyComponents.reply,
          schema: S.object(
            description:
                'The root when there are several parts, top to bottom.',
            properties: {
              'children': Schema.fromMap({
                r'$ref': r'common_types.json#/$defs/ChildList',
              }),
            },
            required: ['children'],
          ),
        ),
        ComponentApi(
          name: FrontReplyComponents.text,
          schema: S.object(
            description:
                'A short label between other parts, such as a heading over '
                'a list. Not your answer: the answer is the prose.',
            properties: {'text': S.string()},
            required: ['text'],
          ),
        ),
        ComponentApi(
          name: FrontReplyComponents.taskCards,
          schema: S.object(
            description:
                'Tasks or projects as cards. The app shows each one live; '
                'pass only ids, as listed.',
            properties: {
              'caption': _caption(),
              'ids': S.list(
                items: S.string(),
                description: 'Each as listed: task:<id> or project:<id>.',
              ),
              'notes': S.list(
                items: S.string(),
                description:
                    'Optional: a few words per id, in the same order, shown '
                    'on its card — such as its logged time.',
              ),
            },
            required: ['caption', 'ids'],
          ),
        ),
        _fromLookup(
          FrontReplyComponents.closedTasks,
          'The cards of every task list_closed_tasks found this turn.',
        ),
        _fromLookup(
          FrontReplyComponents.loggedTimeChart,
          'The chart of the time summarize_logged_time summed this turn.',
        ),
        _fromLookup(
          FrontReplyComponents.pullRequestChart,
          'The charts of what summarize_pull_requests counted this turn.',
        ),
        ComponentApi(
          name: FrontReplyComponents.quickReplies,
          schema: S.object(
            description:
                'Up to $frontQuickRepliesMax short replies the user can tap '
                'to answer an offer you make, in their own words.',
            properties: {'options': S.list(items: S.string())},
            required: ['options'],
          ),
        ),
      ],
    );

AgentToRendererMessage _example(List<Map<String, Object?>> components) =>
    AgentToRendererMessage.fromJson({
      'version': '1.0',
      'createSurface': {
        'surfaceId': 'reply',
        'catalogId': frontReplyAuthoringCatalogId,
        'components': components,
      },
    });

/// Reads and writes her reply's UI in [frontReplyFormat]. The two examples
/// matter: without them a model gets the block's tags wrong.
final A2uiRequestProcessor _processor =
    A2uiGenerator(
      catalogs: [CatalogConfig(frontReplyAuthoringCatalog)],
      inferenceFormatFactory: frontReplyFormat,
      examples: [
        [
          _example([
            {
              'id': 'root',
              'component': FrontReplyComponents.taskCards,
              'caption': 'Tasks found',
              'ids': ['task:a1', 'task:b2'],
            },
          ]),
        ],
        [
          _example([
            {
              'id': 'root',
              'component': FrontReplyComponents.reply,
              'children': ['label', 'chart'],
            },
            {
              'id': 'label',
              'component': FrontReplyComponents.text,
              'text': 'This week',
            },
            {
              'id': 'chart',
              'component': FrontReplyComponents.loggedTimeChart,
              'caption': 'Logged time this week',
            },
          ]),
        ],
      ],
    ).createProcessor(
      MessageProcessor<ComponentApi>(
        catalogs: [frontReplyAuthoringCatalog],
      ).getRendererCapabilities(
        const CapabilitiesOptions(versions: [A2uiProtocolVersion.v1_0]),
      ),
    );

/// The part of her system prompt that teaches the notation, the catalog and
/// the examples. Constant for a build, so it sits in the cached prefix.
final String frontReplyPromptSnippet = _processor.promptSnippet;

/// Her answer as she streamed it: `prose`, her words outside any UI block;
/// `components`, what her blocks compose, top to bottom, each a
/// `{component, …properties}` map for `readFrontReply`; and `errors`, one
/// per block that could not be read, for the log.
typedef FrontStreamedReply = ({
  String prose,
  List<Map<String, Object?>> components,
  List<String> errors,
});

/// Reads her streamed answer [content].
///
/// A block that cannot be read — malformed, or naming what the catalog does
/// not have — is left out and reported in `errors`; the prose and the blocks
/// around it are kept, so a bad block never costs the answer.
///
/// With [complete] false, [content] is a message still being written: a
/// block left open is not an error yet, and text that could be the start of
/// a tag is held back rather than shown as prose.
FrontStreamedReply parseFrontReplyStream(
  String content, {
  bool complete = true,
}) {
  final errors = <String>[];
  // A continuing stream reports a block it cannot read — one left open
  // included — as an ErrorPart and goes on; it does not throw for one.
  final stream = _processor.openContinuingStream();
  final parts = [...stream.feed(content), if (complete) ...stream.close()];

  final prose = StringBuffer();
  final components = <Map<String, Object?>>[];
  for (final part in parts) {
    switch (part) {
      case TextPart(:final text):
        prose.write(text);
      case A2uiPart(:final a2ui):
        for (final message in a2ui) {
          if (message is CreateSurfaceMessage) {
            components.addAll(_topToBottom(message.components ?? const []));
          }
        }
      case ErrorPart(:final error):
        errors.add(error.message);
    }
  }
  return (
    prose: prose.toString().trim(),
    components: components,
    errors: errors,
  );
}

/// The parts of one surface, top to bottom: the children of a root `Reply`
/// — a `Reply` among them standing for its own children — or the root
/// itself, each without the ids that only wired them together.
List<Map<String, Object?>> _topToBottom(List<Map<String, dynamic>> components) {
  final byId = {
    for (final component in components) component['id']: component,
  };
  final seen = <Object?>{};
  Iterable<Map<String, dynamic>> partsOf(Object? id) sync* {
    final component = byId[id];
    // `seen` ends a Reply that lists itself, directly or through a child.
    if (component == null || !seen.add(id)) return;
    if (component['component'] != FrontReplyComponents.reply) {
      yield component;
    } else if (component['children'] case final List<Object?> children) {
      for (final child in children) {
        yield* partsOf(child);
      }
    }
  }

  return [
    for (final component in partsOf('root'))
      {
        for (final MapEntry(:key, :value) in component.entries)
          if (key != 'id' && key != 'catalogId') key: value,
      },
  ];
}

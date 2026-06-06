part of 'agent_tool_registry.dart';

/// Backing list for [AgentToolRegistry.evolutionAgentTools].
const _evolutionAgentTools = <AgentToolDefinition>[
  AgentToolDefinition(
    name: EvolutionToolNames.proposeDirectives,
    description:
        'Formally propose new SKILL directives for this template. '
        'Provide COMPLETE rewritten text for both the general directive '
        '(tools, objectives, sovereignty rules) and the report directive '
        '(report structure, formatting). These changes affect this '
        'template only. For personality changes (voice, tone, coaching), '
        'use propose_soul_directives instead.',
    parameters: {
      'type': 'object',
      'properties': {
        'general_directive': {
          'type': 'string',
          'description':
              'The complete proposed general directive text (tools, '
              'objectives, sovereignty rules).',
        },
        'report_directive': {
          'type': 'string',
          'description':
              'The complete proposed report directive text (report '
              'structure, formatting rules).',
        },
        'rationale': {
          'type': 'string',
          'description':
              'Brief explanation of what changed and why (1-3 sentences).',
        },
      },
      'required': ['general_directive', 'report_directive', 'rationale'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: EvolutionToolNames.proposeSoulDirectives,
    description:
        'Formally propose personality changes to the shared soul '
        'document. Provide COMPLETE rewritten text for any combination '
        'of voice, tone bounds, coaching style, and anti-sycophancy '
        'policy. These changes affect ALL templates using this soul. '
        'Include a rationale and note which other templates will be '
        'impacted.',
    parameters: {
      'type': 'object',
      'properties': {
        'voice_directive': {
          'type': 'string',
          'description':
              'Proposed voice directive: tone, warmth, humor, style, '
              'communication patterns.',
        },
        'tone_bounds': {
          'type': 'string',
          'description':
              'Proposed tone bounds: guardrails on what the personality '
              'must never do.',
        },
        'coaching_style': {
          'type': 'string',
          'description':
              'Proposed coaching style: how the personality coaches, '
              'mentors, and motivates.',
        },
        'anti_sycophancy_policy': {
          'type': 'string',
          'description':
              'Proposed anti-sycophancy policy: directness contract — '
              'when to push back vs. comply.',
        },
        'rationale': {
          'type': 'string',
          'description':
              'Brief explanation of what changed and why (1-3 sentences).',
        },
        'cross_template_notice': {
          'type': 'string',
          'description':
              'Impact statement listing other templates that share this '
              'soul and will be affected by these changes.',
        },
      },
      'required': ['rationale'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: EvolutionToolNames.publishRitualRecap,
    description:
        'Publish the structured recap for this evolution ritual. Call this '
        'when you have enough signal to summarize what changed in the '
        'session. Provide a concise TLDR for collapsed history cards and a '
        'full markdown recap for expanded history views.',
    parameters: {
      'type': 'object',
      'properties': {
        'tldr': {
          'type': 'string',
          'description':
              'A concise 1-2 sentence summary of the session outcome. '
              'This is shown in the collapsed session history view.',
        },
        'content': {
          'type': 'string',
          'description':
              'The full user-facing ritual recap as markdown. This is shown '
              'in the expanded session history view.',
        },
      },
      'required': ['tldr', 'content'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: EvolutionToolNames.recordEvolutionNote,
    description:
        'Record a private evolution note for your own future reference. '
        'Use this to capture patterns, hypotheses, decisions, or recurring '
        'themes that will help in future sessions.',
    parameters: {
      'type': 'object',
      'properties': {
        'kind': {
          'type': 'string',
          'enum': ['reflection', 'hypothesis', 'decision', 'pattern'],
          'description':
              'The kind of note: reflection (observation about performance), '
              'hypothesis (what might improve the template), decision (a '
              'choice made during the session), pattern (a recurring theme).',
        },
        'content': {
          'type': 'string',
          'description': 'The note content (markdown text).',
        },
      },
      'required': ['kind', 'content'],
      'additionalProperties': false,
    },
  ),
];

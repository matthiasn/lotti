import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/workflow/soul_evolution_context_builder.dart';

import '../test_utils.dart';

void main() {
  late SoulEvolutionContextBuilder builder;

  setUp(() {
    builder = SoulEvolutionContextBuilder();
  });

  group('system prompt', () {
    test('contains personality evolution focus', () {
      final ctx = builder.build(
        soul: makeTestSoulDocument(),
        currentVersion: makeTestSoulDocumentVersion(),
        recentVersions: [],
        affectedTemplates: [],
        feedbackByTemplate: {},
        pastNotes: [],
        sessionNumber: 1,
      );

      expect(ctx.systemPrompt, contains('Test Soul'));
      expect(ctx.systemPrompt, contains('Be warm and clear.'));
      expect(ctx.systemPrompt, contains('propose_soul_directives'));
      expect(ctx.systemPrompt, contains('publish_ritual_recap'));
      expect(ctx.systemPrompt, contains('record_evolution_note'));
      expect(ctx.systemPrompt, contains('ABComparison'));
    });

    test('does not mention propose_directives as standalone tool', () {
      final ctx = builder.build(
        soul: makeTestSoulDocument(),
        currentVersion: makeTestSoulDocumentVersion(),
        recentVersions: [],
        affectedTemplates: [],
        feedbackByTemplate: {},
        pastNotes: [],
        sessionNumber: 1,
      );

      // Should contain propose_soul_directives but not the
      // template-only propose_directives as a standalone tool reference.
      expect(ctx.systemPrompt, contains('propose_soul_directives'));
      expect(
        ctx.systemPrompt,
        isNot(contains('**propose_directives**')),
      );
    });

    test('instructs agent to produce visible text', () {
      final ctx = builder.build(
        soul: makeTestSoulDocument(),
        currentVersion: makeTestSoulDocumentVersion(),
        recentVersions: [],
        affectedTemplates: [],
        feedbackByTemplate: {},
        pastNotes: [],
        sessionNumber: 1,
      );

      expect(
        ctx.systemPrompt,
        contains('MUST Contain Visible Text'),
      );
      expect(
        ctx.systemPrompt,
        contains('Greet the user warmly'),
      );
    });

    test('mentions cross-template impact', () {
      final ctx = builder.build(
        soul: makeTestSoulDocument(),
        currentVersion: makeTestSoulDocumentVersion(),
        recentVersions: [],
        affectedTemplates: [],
        feedbackByTemplate: {},
        pastNotes: [],
        sessionNumber: 1,
      );

      expect(
        ctx.systemPrompt,
        contains('ALL templates sharing this soul'),
      );
    });
  });

  group('initial user message', () {
    test('includes soul name and session number', () {
      final ctx = builder.build(
        soul: makeTestSoulDocument(displayName: 'Laura Soul'),
        currentVersion: makeTestSoulDocumentVersion(),
        recentVersions: [],
        affectedTemplates: [],
        feedbackByTemplate: {},
        pastNotes: [],
        sessionNumber: 3,
      );

      expect(ctx.initialUserMessage, contains('Laura Soul'));
      expect(ctx.initialUserMessage, contains('Session #3'));
    });

    test('includes current personality fields', () {
      final ctx = builder.build(
        soul: makeTestSoulDocument(),
        currentVersion: makeTestSoulDocumentVersion(
          voiceDirective: 'Warm and clear.',
          toneBounds: 'Never be dismissive.',
          coachingStyle: 'Encouraging mentor.',
          antiSycophancyPolicy: 'Push back when needed.',
        ),
        recentVersions: [],
        affectedTemplates: [],
        feedbackByTemplate: {},
        pastNotes: [],
        sessionNumber: 1,
      );

      expect(ctx.initialUserMessage, contains('Warm and clear.'));
      expect(ctx.initialUserMessage, contains('Never be dismissive.'));
      expect(ctx.initialUserMessage, contains('Encouraging mentor.'));
      expect(ctx.initialUserMessage, contains('Push back when needed.'));
      expect(ctx.initialUserMessage, contains('Voice Directive'));
      expect(ctx.initialUserMessage, contains('Tone Bounds'));
      expect(ctx.initialUserMessage, contains('Coaching Style'));
      expect(ctx.initialUserMessage, contains('Anti-Sycophancy Policy'));
    });

    test('lists affected templates', () {
      final ctx = builder.build(
        soul: makeTestSoulDocument(),
        currentVersion: makeTestSoulDocumentVersion(),
        recentVersions: [],
        affectedTemplates: [
          (templateId: 't1', displayName: 'Laura Task Agent'),
          (templateId: 't2', displayName: 'Laura Project Analyst'),
        ],
        feedbackByTemplate: {},
        pastNotes: [],
        sessionNumber: 1,
      );

      expect(ctx.initialUserMessage, contains('Laura Task Agent'));
      expect(ctx.initialUserMessage, contains('Laura Project Analyst'));
      expect(ctx.initialUserMessage, contains('2 template(s)'));
    });

    test('shows no templates message when empty', () {
      final ctx = builder.build(
        soul: makeTestSoulDocument(),
        currentVersion: makeTestSoulDocumentVersion(),
        recentVersions: [],
        affectedTemplates: [],
        feedbackByTemplate: {},
        pastNotes: [],
        sessionNumber: 1,
      );

      expect(
        ctx.initialUserMessage,
        contains('No templates are currently using this soul'),
      );
    });

    test('groups feedback by template with sentiment', () {
      final ctx = builder.build(
        soul: makeTestSoulDocument(),
        currentVersion: makeTestSoulDocumentVersion(),
        recentVersions: [],
        affectedTemplates: [
          (templateId: 't1', displayName: 'Task Agent'),
          (templateId: 't2', displayName: 'Project Agent'),
        ],
        feedbackByTemplate: {
          't1': makeTestClassifiedFeedback(
            items: [
              makeTestClassifiedFeedbackItem(
                sentiment: FeedbackSentiment.negative,
                detail: 'Too terse in reports',
              ),
              makeTestClassifiedFeedbackItem(
                detail: 'Good coaching tone',
              ),
            ],
          ),
          't2': makeTestClassifiedFeedback(
            items: [
              makeTestClassifiedFeedbackItem(
                sentiment: FeedbackSentiment.neutral,
                detail: 'Standard interaction',
              ),
            ],
          ),
        },
        pastNotes: [],
        sessionNumber: 1,
      );

      expect(ctx.initialUserMessage, contains('From: Task Agent'));
      expect(ctx.initialUserMessage, contains('From: Project Agent'));
      expect(ctx.initialUserMessage, contains('Too terse in reports'));
      expect(ctx.initialUserMessage, contains('Good coaching tone'));
      expect(ctx.initialUserMessage, contains('Standard interaction'));
      // Negative should appear before positive within a template group.
      final negIdx = ctx.initialUserMessage.indexOf('[negative] Too terse');
      final posIdx = ctx.initialUserMessage.indexOf('[positive] Good coaching');
      expect(negIdx, lessThan(posIdx));
    });

    test('shows no feedback message when empty', () {
      final ctx = builder.build(
        soul: makeTestSoulDocument(),
        currentVersion: makeTestSoulDocumentVersion(),
        recentVersions: [],
        affectedTemplates: [],
        feedbackByTemplate: {},
        pastNotes: [],
        sessionNumber: 1,
      );

      expect(
        ctx.initialUserMessage,
        contains('No feedback signals in the current window'),
      );
    });

    test('includes version history excluding current', () {
      final current = makeTestSoulDocumentVersion(
        id: 'sv-2',
        version: 2,
      );
      final older = makeTestSoulDocumentVersion(
        id: 'sv-1',
        status: SoulDocumentVersionStatus.archived,
        authoredBy: 'evolution_agent',
      );

      final ctx = builder.build(
        soul: makeTestSoulDocument(),
        currentVersion: current,
        recentVersions: [current, older],
        affectedTemplates: [],
        feedbackByTemplate: {},
        pastNotes: [],
        sessionNumber: 1,
      );

      expect(ctx.initialUserMessage, contains('Soul Version History'));
      expect(ctx.initialUserMessage, contains('v1'));
      expect(ctx.initialUserMessage, contains('evolution_agent'));
      // Current version (v2) must NOT appear in the history section.
      final historySection = ctx.initialUserMessage
          .split(
            'Soul Version History',
          )
          .last;
      expect(historySection, isNot(contains('v2')));
    });

    test('includes past evolution notes', () {
      final ctx = builder.build(
        soul: makeTestSoulDocument(),
        currentVersion: makeTestSoulDocumentVersion(),
        recentVersions: [],
        affectedTemplates: [],
        feedbackByTemplate: {},
        pastNotes: [
          makeTestEvolutionNote(
            kind: EvolutionNoteKind.pattern,
            content: 'Users prefer warmer tone',
          ),
        ],
        sessionNumber: 1,
      );

      expect(
        ctx.initialUserMessage,
        contains('Notes From Past Soul Sessions'),
      );
      expect(
        ctx.initialUserMessage,
        contains('Users prefer warmer tone'),
      );
    });

    test('closing instruction mentions personality focus', () {
      final ctx = builder.build(
        soul: makeTestSoulDocument(),
        currentVersion: makeTestSoulDocumentVersion(),
        recentVersions: [],
        affectedTemplates: [],
        feedbackByTemplate: {},
        pastNotes: [],
        sessionNumber: 1,
      );

      expect(
        ctx.initialUserMessage,
        contains('propose_soul_directives'),
      );
      expect(
        ctx.initialUserMessage,
        contains('personality changes affect ALL templates'),
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/workflow/soul_evolution_context_builder.dart';

import '../test_utils.dart';

class _GeneratedSoulContextCounts {
  const _GeneratedSoulContextCounts({
    required this.templateCount,
    required this.versionCount,
    required this.noteCount,
    required this.feedbackTemplateCount,
    required this.feedbackItemsPerTemplate,
  });

  final int templateCount;
  final int versionCount;
  final int noteCount;
  final int feedbackTemplateCount;
  final int feedbackItemsPerTemplate;

  int get expectedTemplateOverflow =>
      templateCount > SoulEvolutionContextBuilder.maxCrossTemplateNames
      ? templateCount - SoulEvolutionContextBuilder.maxCrossTemplateNames
      : 0;

  int get expectedVersionHistoryCount =>
      versionCount - 1 > SoulEvolutionContextBuilder.maxVersionHistory
      ? SoulEvolutionContextBuilder.maxVersionHistory
      : versionCount - 1;

  int get expectedNoteCount =>
      noteCount > SoulEvolutionContextBuilder.maxPastNotes
      ? SoulEvolutionContextBuilder.maxPastNotes
      : noteCount;

  int get expectedFeedbackItems {
    var remaining = SoulEvolutionContextBuilder.maxTotalFeedbackItems;
    var written = 0;
    for (var i = 0; i < feedbackTemplateCount; i++) {
      if (remaining <= 0) break;
      final perTemplate =
          feedbackItemsPerTemplate >
              SoulEvolutionContextBuilder.maxFeedbackItemsPerTemplate
          ? SoulEvolutionContextBuilder.maxFeedbackItemsPerTemplate
          : feedbackItemsPerTemplate;
      final fromThisTemplate = perTemplate > remaining
          ? remaining
          : perTemplate;
      written += fromThisTemplate;
      remaining -= fromThisTemplate;
    }
    return written;
  }

  @override
  String toString() {
    return '_GeneratedSoulContextCounts('
        'templateCount: $templateCount, '
        'versionCount: $versionCount, '
        'noteCount: $noteCount, '
        'feedbackTemplateCount: $feedbackTemplateCount, '
        'feedbackItemsPerTemplate: $feedbackItemsPerTemplate)';
  }
}

extension _AnyGeneratedSoulContextCounts on glados.Any {
  glados.Generator<_GeneratedSoulContextCounts> get soulContextCounts =>
      glados.CombinableAny(this).combine5(
        glados.IntAnys(this).intInRange(
          0,
          SoulEvolutionContextBuilder.maxCrossTemplateNames + 8,
        ),
        glados.IntAnys(this).intInRange(
          1,
          SoulEvolutionContextBuilder.maxVersionHistory + 8,
        ),
        glados.IntAnys(this).intInRange(
          0,
          SoulEvolutionContextBuilder.maxPastNotes + 8,
        ),
        glados.IntAnys(this).intInRange(0, 8),
        glados.IntAnys(this).intInRange(
          0,
          SoulEvolutionContextBuilder.maxFeedbackItemsPerTemplate + 8,
        ),
        (
          int templateCount,
          int versionCount,
          int noteCount,
          int feedbackTemplateCount,
          int feedbackItemsPerTemplate,
        ) => _GeneratedSoulContextCounts(
          templateCount: templateCount,
          versionCount: versionCount,
          noteCount: noteCount,
          feedbackTemplateCount: feedbackTemplateCount,
          feedbackItemsPerTemplate: feedbackItemsPerTemplate,
        ),
      );
}

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

    glados.Glados(
      glados.any.soulContextCounts,
      glados.ExploreConfig(numRuns: 120),
    ).test('matches generated section cap and omission semantics', (
      scenario,
    ) {
      final currentVersion = makeTestSoulDocumentVersion(
        id: 'sv-current',
        version: 99,
      );
      final affectedTemplates = [
        for (var i = 0; i < scenario.templateCount; i++)
          (
            templateId: 't-${i.toString().padLeft(3, '0')}',
            displayName: 'Generated Template ${i + 1}',
          ),
      ];
      final feedbackByTemplate = {
        for (var i = 0; i < scenario.feedbackTemplateCount; i++)
          't-${i.toString().padLeft(3, '0')}': makeTestClassifiedFeedback(
            items: [
              for (
                var itemIndex = 0;
                itemIndex < scenario.feedbackItemsPerTemplate;
                itemIndex++
              )
                makeTestClassifiedFeedbackItem(
                  sentiment: switch (itemIndex % 3) {
                    0 => FeedbackSentiment.negative,
                    1 => FeedbackSentiment.positive,
                    _ => FeedbackSentiment.neutral,
                  },
                  detail: 'Generated feedback $i-$itemIndex for soul context',
                ),
            ],
          ),
      };

      final ctx = builder.build(
        soul: makeTestSoulDocument(),
        currentVersion: currentVersion,
        recentVersions: [
          currentVersion,
          for (var i = 0; i < scenario.versionCount - 1; i++)
            makeTestSoulDocumentVersion(
              id: 'sv-$i',
              version: i + 1,
              status: SoulDocumentVersionStatus.archived,
            ),
        ],
        affectedTemplates: affectedTemplates,
        feedbackByTemplate: feedbackByTemplate,
        pastNotes: [
          for (var i = 0; i < scenario.noteCount; i++)
            makeTestEvolutionNote(
              id: 'soul-note-$i',
              content: 'Generated soul note $i',
            ),
        ],
        sessionNumber: 7,
      );
      final message = ctx.initialUserMessage;

      if (scenario.templateCount == 0) {
        expect(
          message,
          contains('No templates are currently using this soul'),
          reason: '$scenario',
        );
      } else {
        expect(
          message,
          contains(
            'Any personality changes will affect ALL '
            '${scenario.templateCount} template(s)',
          ),
          reason: '$scenario',
        );
        if (scenario.expectedTemplateOverflow > 0) {
          expect(
            message,
            contains('...and ${scenario.expectedTemplateOverflow} more'),
            reason: '$scenario',
          );
        }
      }

      final feedbackLines = RegExp(
        r'- \[(negative|positive|neutral)\] Generated feedback',
      ).allMatches(message);
      expect(
        feedbackLines.length,
        scenario.expectedFeedbackItems,
        reason: '$scenario',
      );
      if (scenario.expectedFeedbackItems == 0) {
        expect(
          message,
          contains('No feedback signals in the current window'),
          reason: '$scenario',
        );
      }

      final versionLines = RegExp(r'- v\d+').allMatches(message);
      expect(
        versionLines.length,
        scenario.expectedVersionHistoryCount,
        reason: '$scenario',
      );

      if (scenario.noteCount == 0) {
        expect(
          message,
          isNot(contains('Notes From Past Soul Sessions')),
          reason: '$scenario',
        );
      } else {
        expect(
          message,
          contains(
            'Notes From Past Soul Sessions (${scenario.expectedNoteCount})',
          ),
          reason: '$scenario',
        );
      }
    }, tags: 'glados');
  });
}

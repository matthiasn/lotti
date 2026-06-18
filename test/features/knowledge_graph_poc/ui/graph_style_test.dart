import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_scenarios.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/graph_style.dart';

void main() {
  // `DsTokens` is a plain immutable value object exported by the design system,
  // so we can read the canonical dark-mode token set directly instead of
  // pumping a widget to fetch `context.designTokens`.
  const tokens = dsTokensDark;

  group('glyphForType', () {
    const expected = <GraphNodeType, IconData>{
      GraphNodeType.task: Icons.check_circle_outline,
      GraphNodeType.project: Icons.flag_outlined,
      GraphNodeType.textEntry: Icons.notes,
      GraphNodeType.audioEntry: Icons.mic_none,
      GraphNodeType.imageEntry: Icons.image_outlined,
      GraphNodeType.aiResponse: Icons.auto_awesome,
      GraphNodeType.checklist: Icons.checklist,
      GraphNodeType.checklistItem: Icons.check_box_outlined,
      GraphNodeType.rating: Icons.star_outline,
    };

    test('returns the expected glyph for every node type', () {
      for (final type in GraphNodeType.values) {
        expect(glyphForType(type), expected[type], reason: 'glyph for $type');
      }
      // Every enum value is covered by the expectation map.
      expect(expected.keys.toSet(), GraphNodeType.values.toSet());
    });

    test('assigns a distinct glyph to each node type', () {
      final glyphs = GraphNodeType.values.map(glyphForType).toSet();
      expect(glyphs.length, GraphNodeType.values.length);
    });
  });

  group('typeLabel', () {
    test('returns the expected label for every node type', () {
      const expected = <GraphNodeType, String>{
        GraphNodeType.task: 'Task',
        GraphNodeType.project: 'Project',
        GraphNodeType.textEntry: 'Note',
        GraphNodeType.audioEntry: 'Audio note',
        GraphNodeType.imageEntry: 'Photo',
        GraphNodeType.aiResponse: 'AI summary',
        GraphNodeType.checklist: 'Checklist',
        GraphNodeType.checklistItem: 'Checklist item',
        GraphNodeType.rating: 'Rating',
      };
      for (final type in GraphNodeType.values) {
        expect(typeLabel(type), expected[type], reason: 'label for $type');
      }
      expect(expected.keys.toSet(), GraphNodeType.values.toSet());
    });
  });

  group('relStyleLabel', () {
    test('returns the expected label for every relation style', () {
      const expected = <RelStyle, String>{
        RelStyle.containment: 'in project',
        RelStyle.linkedTask: 'linked task',
        RelStyle.note: 'note / log',
        RelStyle.checklist: 'checklist',
        RelStyle.provenance: 'AI source',
        RelStyle.evaluation: 'rating',
      };
      for (final style in RelStyle.values) {
        expect(relStyleLabel(style), expected[style], reason: 'label $style');
      }
      expect(expected.keys.toSet(), RelStyle.values.toSet());
    });
  });

  group('relStyleFor', () {
    test('maps each non-association kind straight through', () {
      // The target type is irrelevant for these kinds; assert it is ignored by
      // passing a target type that would change the association branch.
      expect(
        relStyleFor(GraphEdgeKind.containment, GraphNodeType.task),
        RelStyle.containment,
      );
      expect(
        relStyleFor(GraphEdgeKind.provenance, GraphNodeType.aiResponse),
        RelStyle.provenance,
      );
      expect(
        relStyleFor(GraphEdgeKind.evaluation, GraphNodeType.rating),
        RelStyle.evaluation,
      );
      expect(
        relStyleFor(GraphEdgeKind.checklist, GraphNodeType.checklistItem),
        RelStyle.checklist,
      );
    });

    test('association to a task is a linked-task tie', () {
      expect(
        relStyleFor(GraphEdgeKind.association, GraphNodeType.task),
        RelStyle.linkedTask,
      );
    });

    test('association to any non-task is a note / log tie', () {
      for (final target in GraphNodeType.values) {
        if (target == GraphNodeType.task) continue;
        expect(
          relStyleFor(GraphEdgeKind.association, target),
          RelStyle.note,
          reason: 'association to $target',
        );
      }
    });
  });

  group('relStylesIn', () {
    final created = DateTime(2026, 6, 15);

    GraphNode node(String id, GraphNodeType type) => GraphNode(
      id: id,
      type: type,
      label: id,
      categoryId: catWork,
      createdAt: created,
    );

    test('returns the styles present, deduplicated and in enum order', () {
      // Edges deliberately appear out of enum order, with a duplicate
      // containment, to prove ordering and deduplication.
      final scenario = GraphScenario(
        name: 'mixed',
        seedId: 'task',
        nodes: [
          node('task', GraphNodeType.task),
          node('proj', GraphNodeType.project),
          node('note', GraphNodeType.textEntry),
          node('chk', GraphNodeType.checklist),
          node('item', GraphNodeType.checklistItem),
          node('ai', GraphNodeType.aiResponse),
          node('rate', GraphNodeType.rating),
          node('task2', GraphNodeType.task),
        ],
        edges: const [
          // rating -> evaluation (enum index 5)
          GraphEdge(
            fromId: 'rate',
            toId: 'task',
            kind: GraphEdgeKind.evaluation,
          ),
          // association -> task = linkedTask (enum index 1)
          GraphEdge(
            fromId: 'task',
            toId: 'task2',
            kind: GraphEdgeKind.association,
          ),
          // association -> note = note (enum index 2)
          GraphEdge(
            fromId: 'task',
            toId: 'note',
            kind: GraphEdgeKind.association,
          ),
          // containment (enum index 0)
          GraphEdge(
            fromId: 'proj',
            toId: 'task',
            kind: GraphEdgeKind.containment,
          ),
          // duplicate containment — must be deduplicated.
          GraphEdge(
            fromId: 'proj',
            toId: 'task2',
            kind: GraphEdgeKind.containment,
          ),
          // checklist (enum index 3)
          GraphEdge(
            fromId: 'chk',
            toId: 'item',
            kind: GraphEdgeKind.checklist,
          ),
          // provenance (enum index 4)
          GraphEdge(
            fromId: 'ai',
            toId: 'task',
            kind: GraphEdgeKind.provenance,
          ),
        ],
        now: created,
      );

      expect(relStylesIn(scenario), const [
        RelStyle.containment,
        RelStyle.linkedTask,
        RelStyle.note,
        RelStyle.checklist,
        RelStyle.provenance,
        RelStyle.evaluation,
      ]);
    });

    test('skips edges whose target node is missing from the scenario', () {
      final scenario = GraphScenario(
        name: 'dangling',
        seedId: 'task',
        nodes: [
          node('task', GraphNodeType.task),
          node('note', GraphNodeType.textEntry),
        ],
        edges: const [
          GraphEdge(
            fromId: 'task',
            toId: 'note',
            kind: GraphEdgeKind.association,
          ),
          // toId 'ghost' has no node — must be ignored, not crash.
          GraphEdge(
            fromId: 'task',
            toId: 'ghost',
            kind: GraphEdgeKind.containment,
          ),
        ],
        now: created,
      );

      expect(relStylesIn(scenario), const [RelStyle.note]);
    });
  });

  group('EdgeVisual', () {
    test('defaults dash to null and directional to false', () {
      const visual = EdgeVisual(color: Color(0xFF112233), width: 2);
      expect(visual.color, const Color(0xFF112233));
      expect(visual.width, 2);
      expect(visual.dash, isNull);
      expect(visual.directional, isFalse);
    });

    test('stores the dash pattern and directional flag when provided', () {
      const visual = EdgeVisual(
        color: Color(0xFF445566),
        width: 1.5,
        dash: [3, 4],
        directional: true,
      );
      expect(visual.dash, const [3, 4]);
      expect(visual.directional, isTrue);
    });
  });

  group('GraphStyle.fromTokens', () {
    test('wires the resolved colors and text styles to the tokens', () {
      final style = GraphStyle.fromTokens(tokens);

      expect(style.background, tokens.colors.background.level01);
      expect(style.backgroundDeep, tokens.colors.background.alternative01);
      expect(style.vignetteLift, tokens.colors.background.level03);
      expect(style.starColor, tokens.colors.text.lowEmphasis);
      expect(style.focusRing, tokens.colors.interactive.enabled);
      expect(style.selectionRing, tokens.colors.interactive.hover);
      expect(style.fadeTarget, tokens.colors.background.level01);
      expect(style.coreLift, tokens.colors.text.onInteractiveAlert);
      expect(style.glyphColor, tokens.colors.text.onInteractiveAlert);
      expect(style.labelPill, tokens.colors.background.level02);
      expect(style.neutralCategory, tokens.colors.text.mediumEmphasis);

      expect(style.labelStyle.color, tokens.colors.text.highEmphasis);
      expect(
        style.labelStyle.fontSize,
        tokens.typography.styles.others.caption.fontSize,
      );
      expect(style.legendStyle.color, tokens.colors.text.mediumEmphasis);
      expect(
        style.legendStyle.fontSize,
        tokens.typography.styles.others.overline.fontSize,
      );
      expect(style.titleStyle.color, tokens.colors.text.highEmphasis);
      expect(
        style.titleStyle.fontSize,
        tokens.typography.styles.subtitle.subtitle1.fontSize,
      );
    });

    test('builds the synthetic category palette from AI-provider tokens', () {
      final style = GraphStyle.fromTokens(tokens);
      expect(style.categoryPalette, {
        catWork: tokens.colors.aiProvider.gemini.color,
        catWriting: tokens.colors.aiProvider.openAi.color,
        catHealth: tokens.colors.aiProvider.anthropic.color,
        catLearning: tokens.colors.aiProvider.ollama.color,
        catHome: tokens.colors.aiProvider.alibaba.color,
        catAdmin: tokens.colors.proposalKind.add.color,
      });
    });

    group('edgeVisual', () {
      late GraphStyle style;
      setUp(() => style = GraphStyle.fromTokens(tokens));

      test('containment is the thick, opaque, directional backbone', () {
        final v = style.edgeVisual(RelStyle.containment);
        expect(v.color, tokens.colors.text.highEmphasis);
        expect(v.width, 2.8);
        expect(v.dash, isNull);
        expect(v.directional, isTrue);
      });

      test('linkedTask is a dashed, directional medium-emphasis tie', () {
        final v = style.edgeVisual(RelStyle.linkedTask);
        expect(v.color, tokens.colors.text.mediumEmphasis);
        expect(v.width, 1.8);
        expect(v.dash, const [7, 5]);
        expect(v.directional, isTrue);
      });

      test('note is a thin solid medium-emphasis tie', () {
        final v = style.edgeVisual(RelStyle.note);
        expect(v.color, tokens.colors.text.mediumEmphasis);
        expect(v.width, 1.4);
        expect(v.dash, isNull);
        expect(v.directional, isFalse);
      });

      test('checklist is a thin solid low-emphasis tie', () {
        final v = style.edgeVisual(RelStyle.checklist);
        expect(v.color, tokens.colors.text.lowEmphasis);
        expect(v.width, 1.5);
        expect(v.dash, isNull);
        expect(v.directional, isFalse);
      });

      test('provenance uses the info color, dashed and directional', () {
        final v = style.edgeVisual(RelStyle.provenance);
        expect(v.color, tokens.colors.alert.info.defaultColor);
        expect(v.width, 1.9);
        expect(v.dash, const [7, 5]);
        expect(v.directional, isTrue);
      });

      test('evaluation uses the remove color, dotted and directional', () {
        final v = style.edgeVisual(RelStyle.evaluation);
        expect(v.color, tokens.colors.proposalKind.remove.color);
        expect(v.width, 1.9);
        expect(v.dash, const [3, 4]);
        expect(v.directional, isTrue);
      });

      test('every relation style resolves to a distinct visual', () {
        final visuals = RelStyle.values.map(style.edgeVisual).toList();
        expect(visuals.length, RelStyle.values.length);
      });
    });

    group('categoryColor', () {
      test('falls back to the synthetic palette when no live colors', () {
        final style = GraphStyle.fromTokens(tokens);
        // Direct hit on a palette id.
        expect(
          style.categoryColor(catWork),
          tokens.colors.aiProvider.gemini.color,
        );
        expect(
          style.categoryColor(catAdmin),
          tokens.colors.proposalKind.add.color,
        );
      });

      test('hashes unknown ids deterministically into the palette', () {
        final style = GraphStyle.fromTokens(tokens);
        final palette = style.categoryPalette.values.toList();

        const unknownId = 'no-such-category';
        final expected = palette[unknownId.hashCode.abs() % palette.length];
        expect(style.categoryColor(unknownId), expected);
        // It must resolve to one of the palette colors, never neutral.
        expect(palette, contains(style.categoryColor(unknownId)));
        // Deterministic: the same id maps to the same color every call.
        expect(
          style.categoryColor(unknownId),
          style.categoryColor(unknownId),
        );
      });

      test('live category colors take precedence over the palette', () {
        const liveWork = Color(0xFF0A0B0C);
        final style = GraphStyle.fromTokens(
          tokens,
          categoryColors: const {catWork: liveWork},
        );
        // Known live id wins over the synthetic gemini color.
        expect(style.categoryColor(catWork), liveWork);
        expect(
          style.categoryColor(catWork),
          isNot(tokens.colors.aiProvider.gemini.color),
        );
      });

      test('unknown ids fall back to neutral when live colors present', () {
        const liveWork = Color(0xFF0A0B0C);
        final style = GraphStyle.fromTokens(
          tokens,
          categoryColors: const {catWork: liveWork},
        );
        // catAdmin is in the synthetic palette but NOT in live colors: with a
        // live map present, the synthetic palette is bypassed entirely and the
        // neutral fallback is used.
        expect(style.categoryColor(catAdmin), style.neutralCategory);
        expect(style.neutralCategory, tokens.colors.text.mediumEmphasis);
      });
    });
  });
}

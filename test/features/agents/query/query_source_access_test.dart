import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/lockdown/domain/lockdown_state.dart';

import '../../../test_data/test_data.dart';

void main() {
  final category = categoryMindfulness.copyWith(id: 'penguin-operations');
  final note = testTextEntry.copyWith(
    meta: testTextEntry.meta.copyWith(
      id: 'penguin-note',
      categoryId: category.id,
      private: false,
    ),
  );
  final ref = QuerySourceRef(
    id: note.meta.id,
    categoryId: category.id,
    private: false,
    categoryPrivate: false,
  );
  QueryAccessSnapshot snapshot({
    bool showPrivate = false,
    JournalEntity? source,
    CategoryDefinition? sourceCategory,
    LockdownState lockdown = LockdownState.inactive,
  }) => QueryAccessSnapshot(
    showPrivate: showPrivate,
    entries: {note.meta.id: source ?? note},
    categories: {
      (sourceCategory ?? category).id: sourceCategory ?? category,
    },
    lockdown: lockdown,
  );

  test('making a source private hides saved quotes and derived content', () {
    final privateNote = note.copyWith(meta: note.meta.copyWith(private: true));
    final hidden = snapshot(source: privateNote);
    expect(hidden.allowsReference(ref), isFalse);
    expect(
      hidden.allowsEvent(
        QueryChatEventData.answer(
          questionId: 'question',
          text: 'Private conclusion.',
          coverage: const QueryCoverage(),
          dependencies: [ref],
        ),
      ),
      isFalse,
    );
    expect(
      hidden.allowsEvent(
        QueryChatEventData.memory(
          questionId: 'question',
          text: 'Private memory.',
          dependencies: [ref],
        ),
      ),
      isFalse,
    );
    expect(
      snapshot(source: privateNote, showPrivate: true).allowsReference(ref),
      isTrue,
    );
  });

  test('category moves preserve quotes while privacy still wins', () {
    final movedCategory = category.copyWith(id: 'another-category');
    final moved = note.copyWith(
      meta: note.meta.copyWith(categoryId: movedCategory.id),
    );
    expect(
      snapshot(
        source: moved,
        sourceCategory: movedCategory,
      ).allowsReference(ref),
      isTrue,
    );
    expect(
      snapshot(
        source: moved,
        sourceCategory: movedCategory.copyWith(private: true),
      ).allowsReference(ref),
      isFalse,
    );
  });

  test('saved summary answers require live owners in their saved category', () {
    final summary = QueryChatAnswer(
      questionId: 'question',
      text: 'Summary-derived calibration result.',
      coverage: const QueryCoverage(),
      summaryBased: true,
      dependencies: [ref],
    );
    final saved = QueryChatEventData.fromJson(
      jsonDecode(jsonEncode(summary)) as Map<String, dynamic>,
    );
    expect(snapshot().allowsEvent(saved), isTrue);
    final movedCategory = category.copyWith(id: 'another-category');
    final moved = note.copyWith(
      meta: note.meta.copyWith(categoryId: movedCategory.id),
    );
    final movedAccess = snapshot(source: moved, sourceCategory: movedCategory);
    expect(movedAccess.allowsEvent(saved), isFalse);
    expect(
      movedAccess.allowsEvent(summary.copyWith(summaryBased: false)),
      isTrue,
    );
    final deletedAccess = snapshot(
      source: note.copyWith(
        meta: note.meta.copyWith(deletedAt: DateTime(2026, 9, 12)),
      ),
    );
    expect(deletedAccess.allowsEvent(saved), isFalse);
    expect(
      deletedAccess.allowsEvent(summary.copyWith(summaryBased: false)),
      isTrue,
    );
    expect(
      const QueryAccessSnapshot(
        showPrivate: false,
        categories: {},
        entries: {},
      ).allowsEvent(saved),
      isFalse,
    );
  });

  test(
    'saved action proposals require live, visible owners in the saved category',
    () {
      final answer = QueryChatAnswer(
        questionId: 'q',
        text: 'Review.',
        coverage: const QueryCoverage(),
        dependencies: [ref],
        proposedActions: const [
          ChangeItem(
            toolName: 'add_checklist_item',
            args: {'title': 'Feeder'},
            humanSummary: 'Feeder',
          ),
        ],
      );
      final saved = QueryChatEventData.fromJson(
        jsonDecode(jsonEncode(answer)) as Map<String, dynamic>,
      );
      expect(snapshot().allowsEvent(saved), isTrue);
      for (final source in [
        note.copyWith(meta: note.meta.copyWith(private: true)),
        note.copyWith(meta: note.meta.copyWith(categoryId: 'foreign')),
        note.copyWith(
          meta: note.meta.copyWith(deletedAt: DateTime(2026, 9, 13)),
        ),
      ]) {
        expect(snapshot(source: source).allowsEvent(saved), isFalse);
      }
    },
  );

  test('public deletion tombstones retain evidence, private ones hide it', () {
    final deleted = note.copyWith(
      meta: note.meta.copyWith(deletedAt: DateTime(2026, 9, 10)),
    );
    expect(snapshot(source: deleted).allowsReference(ref), isTrue);
    expect(snapshot(source: deleted).allowsEntry(deleted), isFalse);
    final privateDeleted = deleted.copyWith(
      meta: deleted.meta.copyWith(private: true),
    );
    expect(snapshot(source: privateDeleted).allowsReference(ref), isFalse);
    expect(
      const QueryAccessSnapshot(
        showPrivate: true,
        categories: {},
        entries: {},
      ).allowsReference(ref),
      isFalse,
    );
  });

  test('lockdown and private question context cannot bypass visibility', () {
    expect(
      snapshot(
        showPrivate: true,
        lockdown: const LockdownState(categoryIds: {'different-category'}),
      ).allowsReference(ref),
      isFalse,
    );
    expect(
      snapshot().allowsEvent(
        const QueryChatEventData.question(
          text: 'Private follow-up',
          private: true,
        ),
      ),
      isFalse,
    );
  });
}

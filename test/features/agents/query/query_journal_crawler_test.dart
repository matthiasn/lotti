import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:mocktail/mocktail.dart';

import '../../../test_data/test_data.dart';
import '../../projects/test_utils.dart';
import 'query_test_utils.dart';

void main() {
  test(
    'summary fallback inspects own entries but not linked task bodies',
    () async {
      final bench = QueryTestBench();
      final category = categoryMindfulness.id;
      for (final id in ['home', 'other']) {
        bench.entries[id] = testTask.copyWith(
          meta: testTask.meta.copyWith(
            id: id,
            categoryId: category,
            private: false,
          ),
        );
      }
      bench
        ..add('note', category: category)
        ..link('home', 'note')
        ..link('home', 'other');
      final corpus = await bench.crawler.discover(
        const QueryScope(kind: QueryScopeKind.task, id: 'home'),
        const [],
        homeOnly: true,
        ownTaskOnly: true,
      );
      expect(
        corpus.documents.map((d) => d.entry.meta.id),
        containsAll(['home', 'note']),
      );
      expect(
        corpus.documents.map((d) => d.entry.meta.id),
        isNot(contains('other')),
      );
      expect(bench.searches, isEmpty);
      await expectLater(
        bench.crawler.discover(
          QueryScope(kind: QueryScopeKind.category, id: category),
          const [],
          ownTaskOnly: true,
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'meeting attribution includes a visible linked task and its project',
    () async {
      final bench = QueryTestBench();
      final category = categoryMindfulness.id;
      bench
        ..add('home', category: category)
        ..add('meeting', category: category)
        ..link('meeting', 'other-task');
      bench.entries['other-task'] = testTask.copyWith(
        meta: testTask.meta.copyWith(id: 'other-task', categoryId: category),
        data: testTask.data.copyWith(title: 'Calibrate feeder'),
      );
      final project = makeTestProject(
        id: 'project',
        categoryId: category,
        title: 'Orbital penguin habitat',
      );
      bench.entries['project'] = project;
      bench.taskProjects['other-task'] = 'project';
      const scope = QueryScope(kind: QueryScopeKind.task, id: 'home');
      final visible = await bench.crawler.discover(scope, ['feeder']);
      expect(visible.affiliations['meeting']!.labels, [
        'Calibrate feeder',
        'Orbital penguin habitat',
      ]);
      expect(visible.affiliations['meeting']!.sources.map((s) => s.id), [
        'other-task',
        'project',
      ]);
      expect(visible.homeIds, isNot(contains('meeting')));
      bench.entries['project'] = project.copyWith(
        meta: project.meta.copyWith(private: true),
      );
      final hidden = await bench.crawler.discover(scope, ['feeder']);
      expect(hidden.affiliations['meeting']!.labels, ['Calibrate feeder']);
      expect(hidden.affiliations['meeting']!.sources.map((s) => s.id), [
        'other-task',
      ]);
    },
  );
  test(
    'uncategorized retrieval stops at direct links in either direction',
    () async {
      final bench = QueryTestBench()
        ..add('task')
        ..add('direct')
        ..add('incoming')
        ..add('second-hop')
        ..add('unrelated')
        ..add('hidden-link')
        ..link('task', 'direct')
        ..link('incoming', 'task')
        ..link('direct', 'second-hop')
        ..link('task', 'hidden-link', hidden: true);
      final corpus = await bench.crawler.discover(
        const QueryScope(kind: QueryScopeKind.task, id: 'task'),
        ['feeder'],
      );
      expect(corpus.documents.map((d) => d.entry.meta.id).toSet(), {
        'task',
        'direct',
        'incoming',
      });
      expect(bench.searches, isEmpty);
      expect(bench.categoryReads, 0);
    },
  );

  test(
    'category expansion finds unlinked entries but excludes other categories and private sources',
    () async {
      final bench = QueryTestBench();
      final category = categoryMindfulness.id;
      bench
        ..add('task', category: category)
        ..add('unlinked', category: category)
        ..add('private', category: category, private: true)
        ..add('other-category', category: 'different')
        ..link('task', 'other-category');
      final corpus = await bench.crawler.discover(
        const QueryScope(kind: QueryScopeKind.task, id: 'task'),
        ['feeder'],
      );
      expect(corpus.documents.map((d) => d.entry.meta.id).toSet(), {
        'task',
        'unlinked',
      });
      expect(corpus.homeIds.contains('unlinked'), isFalse);
      expect(corpus.coverage.expanded, isTrue);
      expect(bench.searches, ['feeder']);
    },
  );

  test('a hidden home never reaches keyword search', () async {
    final bench = QueryTestBench()..add('task', private: true);
    await expectLater(
      bench.crawler.discover(
        const QueryScope(kind: QueryScopeKind.task, id: 'task'),
        ['feeder'],
      ),
      throwsA(isA<QueryScopeUnavailable>()),
    );
    expect(bench.searches, isEmpty);
  });

  test('an intentionally empty edit never revives an older transcript', () {
    final audio = testAudioEntryWithTranscripts.copyWith(
      entryText: const EntryText(plainText: ''),
    );
    expect(QuerySourceDocument.fromEntry(audio), isNull);
    final original = QuerySourceDocument.fromEntry(
      audio.copyWith(entryText: null),
    );
    expect(original, isNotNull);
    expect(original!.text, audio.data.transcripts!.last.transcript);
    expect(original.version, startsWith('transcript:'));
  });

  test('empty descriptions retain task and project titles as evidence', () {
    final task = testTask.copyWith(entryText: const EntryText(plainText: ''));
    final project = makeTestProject().copyWith(
      entryText: const EntryText(plainText: '   '),
    );
    for (final entry in [task, project]) {
      final document = QuerySourceDocument.fromEntry(entry);
      expect(document, isNotNull);
      expect(document!.text, document.label);
      expect(document.version, startsWith('title:'));
    }
  });

  test('notes-only coverage excludes missing recording transcripts', () async {
    final bench = QueryTestBench()
      ..add('task')
      ..link('task', 'recording');
    bench.entries['recording'] = testAudioEntry.copyWith(
      meta: testAudioEntry.meta.copyWith(id: 'recording', categoryId: null),
      entryText: null,
      data: testAudioEntry.data.copyWith(transcripts: []),
    );
    const scope = QueryScope(kind: QueryScopeKind.task, id: 'task');
    final notes = await bench.crawler.discover(
      scope,
      [],
      kind: QuerySourceKind.text,
    );
    expect(notes.documents.map((d) => d.entry.meta.id), ['task']);
    expect(notes.coverage.missingTranscripts, 0);
    expect(notes.coverage.unreadableSources, isEmpty);
    expect(notes.coverage.incomplete, isFalse);
    final recordings = await bench.crawler.discover(
      scope,
      [],
      kind: QuerySourceKind.recording,
    );
    expect(recordings.documents, isEmpty);
    expect(recordings.coverage.missingTranscripts, 1);
    expect(recordings.coverage.unreadableSources.single.id, 'recording');
    expect(recordings.coverage.unreadableSources.single.private, isFalse);
    expect(recordings.coverage.incomplete, isTrue);
  });

  test(
    'project home includes visible same-category tasks and one link hop',
    () async {
      final bench = QueryTestBench();
      final category = categoryMindfulness.id;
      final project = makeTestProject(id: 'project', categoryId: category);
      bench.entries['project'] = project;
      for (final (id, private, categoryId) in [
        ('task', false, category),
        ('private-task', true, category),
        ('moved-task', false, 'another-category'),
      ]) {
        bench.entries[id] = testTask.copyWith(
          meta: testTask.meta.copyWith(
            id: id,
            private: private,
            categoryId: categoryId,
          ),
          entryText: null,
        );
        bench.taskProjects[id] = 'project';
      }
      bench
        ..add('meeting', category: category)
        ..add('project-note', category: category)
        ..add('unrelated', category: category)
        ..add('second-hop', category: category)
        ..link('task', 'meeting')
        ..link('project', 'project-note')
        ..link('meeting', 'second-hop');
      final corpus = await bench.crawler.discover(
        const QueryScope(kind: QueryScopeKind.project, id: 'project'),
        [],
        homeOnly: true,
      );
      expect(corpus.documents.map((d) => d.entry.meta.id).toSet(), {
        'project',
        'task',
        'meeting',
        'project-note',
      });
      expect(corpus.affiliations['project-note']!.labels, [project.data.title]);
      expect(corpus.coverage.expanded, isFalse);
      expect(bench.searches, isEmpty);
    },
  );

  test('category retrieval is bounded and can use checklist titles', () async {
    final bench = QueryTestBench();
    final category = categoryMindfulness.id;
    final meta = testTask.meta.copyWith(categoryId: category);
    final checklist = Checklist(
      meta: meta.copyWith(id: 'checklist'),
      data: const ChecklistData(
        title: 'Feeder inspection',
        linkedChecklistItems: [],
        linkedTasks: [],
      ),
    );
    final item = ChecklistItem(
      meta: meta.copyWith(id: 'item'),
      data: const ChecklistItemData(
        title: 'Check feeder valve',
        isChecked: false,
        linkedChecklists: [],
      ),
    );
    for (final entry in [checklist, item]) {
      final document = QuerySourceDocument.fromEntry(entry)!;
      expect(document.kind, QuerySourceKind.checklist);
      expect(document.text, contains('eeder'));
      expect(document.version, startsWith('title:'));
    }
    for (var i = 0; i < 65; i++) {
      bench.add('note-$i', category: category);
    }
    final corpus = await bench.crawler.discover(
      QueryScope(kind: QueryScopeKind.category, id: category),
      [],
    );
    expect(corpus.documents, hasLength(60));
    expect(corpus.homeIds, isEmpty);
    expect(corpus.coverage.incomplete, isTrue);
    expect(
      corpus.documents.every((d) => d.entry.meta.categoryId == category),
      isTrue,
    );
  });

  group('search by meaning', () {
    final category = categoryMindfulness.id;

    QueryTestBench bench() => QueryTestBench()
      ..add('a', category: category)
      ..add('b', category: category)
      ..add('c', category: category)
      ..add('d', category: category)
      ..add('elsewhere', category: 'other-category')
      ..add('secret', category: category, private: true);

    test('its hits come first, nearest first, within the category and '
        'what may be shown', () async {
      final b = bench()
        ..meaningResults = {
          'fish stores': ['elsewhere', 'secret', 'd', 'c'],
          'ledger': ['b'],
        };

      final corpus = await b.crawler.discover(
        QueryScope(kind: QueryScopeKind.category, id: category),
        const ['feeder'],
        searches: const ['fish stores', 'ledger'],
      );

      expect(corpus.documents.map((d) => d.entry.meta.id), [
        'd',
        'c',
        'b',
        'a',
      ]);
      expect(b.searches, ['feeder'], reason: 'keywords still run');
    });

    test(
      'runs each planned search once, at most three, skipping blanks',
      () async {
        final b = bench()..meaningResults = {};

        await b.crawler.discover(
          QueryScope(kind: QueryScopeKind.category, id: category),
          const [],
          searches: const [
            'fish stores',
            ' ',
            'fish stores ',
            'ledger',
            'x',
            'y',
          ],
        );

        expect(b.meaningSearches, [
          ('fish stores', category),
          ('ledger', category),
          ('x', category),
        ]);
      },
    );

    test('a failing search by meaning leaves the keyword crawl running, '
        'with coverage marked incomplete', () async {
      final b = bench()
        ..meaningResults = {}
        ..meaningFails = true;

      final corpus = await b.crawler.discover(
        QueryScope(kind: QueryScopeKind.category, id: category),
        const ['feeder'],
        searches: const ['fish stores'],
      );

      expect(b.meaningSearches, [('fish stores', category)]);
      expect(b.searches, ['feeder']);
      expect(corpus.documents.map((d) => d.entry.meta.id), [
        'a',
        'b',
        'c',
        'd',
      ]);
      expect(corpus.coverage.incomplete, isTrue);
    });

    test('a home-only crawl searches nothing by meaning', () async {
      final b = bench()
        ..meaningResults = {
          'fish stores': ['d'],
        };
      b.entries['home'] = testTask.copyWith(
        meta: testTask.meta.copyWith(id: 'home', categoryId: category),
      );

      await b.crawler.discover(
        const QueryScope(kind: QueryScopeKind.task, id: 'home'),
        const ['feeder'],
        searches: const ['fish stores'],
        homeOnly: true,
      );

      expect(b.meaningSearches, isEmpty);
    });
  });

  group('journal-wide', () {
    QueryTestBench bench() {
      final b = QueryTestBench();
      b.categories.addAll([
        categoryMindfulness.copyWith(id: 'colony', name: 'Colony'),
        categoryMindfulness.copyWith(
          id: 'secret',
          name: 'Secret',
          private: true,
        ),
      ]);
      return b
        ..add('calm', category: categoryMindfulness.id)
        ..add('census', category: 'colony')
        ..add('hidden', category: 'secret');
    }

    test('reads every category the reader may see, and searches all of '
        'them by meaning', () async {
      final b = bench()
        ..meaningResults = {
          'fish stores': ['hidden', 'census', 'calm'],
        };

      final corpus = await b.crawler.discover(
        QueryScope.journal,
        const ['feeder'],
        searches: const ['fish stores'],
      );

      expect(corpus.documents.map((d) => d.entry.meta.id), [
        'census',
        'calm',
      ]);
      expect(corpus.homeIds, isEmpty);
      expect(corpus.categoryId, isNull);
      expect(b.meaningSearches, [('fish stores', null)]);
      // Visibility is applied before the limit: the query never asks for
      // the private category.
      final asked = verify(
        () => b.db.getJournalEntities(
          types: any(named: 'types'),
          starredStatuses: any(named: 'starredStatuses'),
          privateStatuses: any(named: 'privateStatuses'),
          flaggedStatuses: any(named: 'flaggedStatuses'),
          ids: any(named: 'ids'),
          categoryIds: captureAny(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).captured;
      for (final categories in asked) {
        expect(categories, containsAll([categoryMindfulness.id, 'colony']));
        expect(categories, isNot(contains('secret')));
      }
    });

    test("narrowed to the page's categories, reads and searches only "
        'those', () async {
      final b = bench()
        ..meaningResults = {
          'fish stores': ['census', 'calm'],
        };

      final corpus = await b.crawler.discover(
        QueryScope.journalIn(const {'colony', 'secret'}),
        const ['feeder'],
        searches: const ['fish stores'],
      );

      expect(corpus.documents.map((d) => d.entry.meta.id), ['census']);
      expect(b.meaningSearches, [('fish stores', 'colony,secret')]);
      final access = await b.crawler.access.load(const []);
      expect(corpus.admits(access, 'colony'), isTrue);
      expect(corpus.admits(access, categoryMindfulness.id), isFalse);
      expect(corpus.admits(access, 'secret'), isFalse, reason: 'private');
    });

    test('categories the question names narrow a selection, never widen '
        'it', () async {
      final b = bench()
        ..meaningResults = {
          'fish stores': ['census', 'calm'],
        };

      final corpus = await b.crawler.discover(
        QueryScope.journalIn({'colony', categoryMindfulness.id}),
        const [],
        searches: const ['fish stores'],
        narrowTo: const {'colony', 'elsewhere'},
      );

      expect(corpus.documents.map((d) => d.entry.meta.id), ['census']);
      expect(b.meaningSearches, [('fish stores', 'colony')]);
    });

    test('narrowed to nothing, it reads and searches nothing', () async {
      final b = bench()
        ..meaningResults = {
          'fish stores': ['census', 'calm'],
        };

      final corpus = await b.crawler.discover(
        QueryScope.journal,
        const ['fish'],
        searches: const ['fish stores'],
        narrowTo: const {},
      );

      expect(corpus.documents, isEmpty);
      expect(b.meaningSearches, isEmpty);
      verifyNever(
        () => b.db.getJournalEntities(
          types: any(named: 'types'),
          starredStatuses: any(named: 'starredStatuses'),
          privateStatuses: any(named: 'privateStatuses'),
          flaggedStatuses: any(named: 'flaggedStatuses'),
          ids: any(named: 'ids'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      );
    });

    test('a selection holding the uncategorized bucket searches every shard '
        'and narrows the hits', () async {
      final b = bench()
        ..add('loose')
        ..meaningResults = {
          'fish stores': ['census', 'calm'],
        };

      final corpus = await b.crawler.discover(
        QueryScope.journalIn(const {'colony', ''}),
        const [],
        searches: const ['fish stores'],
      );

      expect(b.meaningSearches, [('fish stores', null)]);
      expect(
        corpus.documents.map((d) => d.entry.meta.id),
        isNot(contains('calm')),
      );
    });

    test(
      'admits any visible category, and only the journal reads past one',
      () async {
        final b = bench();
        final journal = await b.crawler.discover(QueryScope.journal, const []);
        final access = await b.crawler.access.load(const []);

        expect(journal.admits(access, 'colony'), isTrue);
        expect(journal.admits(access, 'secret'), isFalse);
        expect(journal.isVisibleIn(access), isTrue);

        final category = await b.crawler.discover(
          QueryScope(kind: QueryScopeKind.category, id: categoryMindfulness.id),
          const [],
        );
        expect(category.admits(access, categoryMindfulness.id), isTrue);
        expect(category.admits(access, 'colony'), isFalse);
        expect(category.isVisibleIn(access), isTrue);
      },
    );
  });
}

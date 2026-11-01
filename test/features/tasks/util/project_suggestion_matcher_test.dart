import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/tasks/util/project_suggestion_matcher.dart';

ProjectMatchCandidate _project(
  String id,
  String title, {
  String description = '',
  List<String> taskTitles = const [],
}) => ProjectMatchCandidate(
  projectId: id,
  title: title,
  description: description,
  taskTitles: taskTitles,
);

String? _suggest(
  List<ProjectMatchCandidate> projects,
  String title, {
  String body = '',
  List<String> labels = const [],
}) =>
    ProjectSuggestionMatcher(
          projects,
        )
        .suggest(ProjectMatchTask(title: title, body: body, labels: labels))
        ?.projectId;

final List<ProjectMatchCandidate> _everyday = [
  _project('work', 'Work'),
  _project('home', 'Home'),
  _project('health', 'Health'),
];

void main() {
  group('suggest', () {
    test('a word of the project name in the title suggests that project — '
        'the user never names it as a project', () {
      expect(_suggest(_everyday, 'Prepare work presentation'), 'work');
    });

    test('a title sharing no topic word with any project suggests nothing', () {
      expect(_suggest(_everyday, 'Prepare presentation'), isNull);
    });

    test('an empty title and no projects both suggest nothing', () {
      expect(_suggest(_everyday, ''), isNull);
      expect(_suggest(const [], 'Prepare work presentation'), isNull);
      expect(ProjectSuggestionMatcher(const []).isEmpty, isTrue);
    });

    test('case, accents, plurals and -ing forms still match the name', () {
      final projects = [
        _project('garden', 'Garden'),
        _project('cafe', 'Café opening'),
      ];
      expect(_suggest(projects, 'WATER THE GARDENS'), 'garden');
      expect(_suggest(projects, 'Order cups for the cafe'), 'cafe');
      expect(
        _suggest([_project('run', 'Running'), ..._everyday], 'Plan run'),
        'run',
      );
    });

    test('a misspelt name word still matches through its letter triples', () {
      final projects = [
        _project('pres', 'Presentations'),
        _project('home', 'Home'),
      ];
      expect(_suggest(projects, 'Draft presentaton outline'), 'pres');
    });

    test('a bare prefix of a name word is too weak to suggest on its own', () {
      // "work" is a prefix of "workshop", not the same word.
      expect(_suggest(_everyday, 'Plan workshop agenda'), isNull);
    });

    test("words several of a project's tasks share suggest it, even when its "
        'name says nothing about them', () {
      final projects = [
        _project(
          'garden',
          'Backyard',
          taskTitles: const [
            'Order mulch',
            'Prune roses',
            'Water roses',
            'Order seeds',
          ],
        ),
        _project('home', 'Home'),
      ];
      expect(_suggest(projects, 'Order roses fertilizer'), 'garden');
    });

    test('a single one-off history word is not enough', () {
      final projects = [
        _project('garden', 'Backyard', taskTitles: const ['Order mulch']),
        _project('home', 'Home'),
      ];
      expect(_suggest(projects, 'Order pizza'), isNull);
    });

    test('stop words in task history never match', () {
      final projects = [
        _project(
          'finance',
          'Finance',
          taskTitles: const ['Call the bank', 'Pay the rent', 'Pay the bill'],
        ),
        _project('home', 'Home'),
      ];
      expect(_suggest(projects, 'Read the book with the kids'), isNull);
    });

    test('the description counts, at a lower weight than the name', () {
      final projects = [
        _project('fitness', 'Fitness', description: 'Gym, running and yoga'),
        _project('home', 'Home'),
      ];
      // One description word alone stays below the threshold …
      expect(_suggest(projects, 'Book yoga class'), isNull);
      // … two of them clear it.
      expect(_suggest(projects, 'Book yoga at the gym'), 'fitness');
    });

    test('the body and the labels contribute when the title is silent', () {
      final projects = [
        _project('kitchen', 'Kitchen renovation'),
        ..._everyday,
      ];
      expect(
        _suggest(
          projects,
          'Call the contractor',
          body: 'about the kitchen renovation quote',
        ),
        'kitchen',
      );
      expect(
        _suggest(projects, 'Call the contractor', labels: const ['Kitchen']),
        'kitchen',
      );
    });

    test('two projects the task matches equally well suggest neither', () {
      final projects = [
        _project('redesign', 'Website redesign'),
        _project('hosting', 'Website hosting'),
      ];
      expect(_suggest(projects, 'Update website'), isNull);
      // Naming what tells them apart resolves it.
      expect(_suggest(projects, 'Update website hosting plan'), 'hosting');
    });

    test('a project whose whole name the task covers outranks one it covers '
        'in part', () {
      final ranked = ProjectSuggestionMatcher([
        _project('work', 'Work'),
        _project('travel', 'Work travel'),
      ]).rank(const ProjectMatchTask(title: 'Prepare work presentation'));
      expect(ranked.map((s) => s.projectId), ['work', 'travel']);
      expect(ranked.first.score, greaterThan(ranked.last.score));
    });
  });

  group('rank', () {
    test('lists only matching projects, best first, with exact weights', () {
      final ranked = ProjectSuggestionMatcher(
        _everyday,
      ).rank(const ProjectMatchTask(title: 'Prepare work presentation'));
      // One exact name word: taskTitleWeight × projectTitleWeight × 1, plus
      // the full name covered (titleCoverageBonus × 1/1). Only "work" uses
      // "work", so its specificity is 1.
      expect(ranked, [
        (
          projectId: 'work',
          score:
              ProjectSuggestionMatcher.taskTitleWeight *
                  ProjectSuggestionMatcher.projectTitleWeight +
              ProjectSuggestionMatcher.titleCoverageBonus,
        ),
      ]);
    });

    test('a task word matching several name words approximately keeps the '
        'strongest match, whichever comes first', () {
      // "reno" is only a prefix of the misspelt "renovaton" (0.6), and comes
      // first; "renovation" is the same word misspelt (0.7) and must win.
      final ranked = ProjectSuggestionMatcher([
        _project(
          'kitchen',
          'Kitchen',
          description: 'Reno: renovation of the old room',
        ),
      ]).rank(const ProjectMatchTask(title: 'Plan renovaton'));

      expect(ranked, [
        (
          projectId: 'kitchen',
          score:
              ProjectSuggestionMatcher.taskTitleWeight *
              ProjectSuggestionMatcher.projectDescriptionWeight *
              ProjectSuggestionMatcher.fuzzySimilarity,
        ),
      ]);
    });

    test('a word every project shares is down-weighted by its spread', () {
      final ranked = ProjectSuggestionMatcher([
        _project('a', 'Team alpha'),
        _project('b', 'Team beta'),
      ]).rank(const ProjectMatchTask(title: 'Team lunch'));
      // "team" is in both names: specificity (2 − 2 + 1) / 2 = 0.5, and it
      // covers half of each name.
      expect(ranked.map((s) => s.score), [2.0, 2.0]);
      expect(ranked.map((s) => s.projectId), ['a', 'b']);
    });
  });

  group('historyWeightFor', () {
    test('rises with repeats and caps at 1.5', () {
      expect(ProjectSuggestionMatcher.historyWeightFor(1), 0.75);
      expect(ProjectSuggestionMatcher.historyWeightFor(2), 1.0);
      expect(ProjectSuggestionMatcher.historyWeightFor(4), 1.5);
      expect(ProjectSuggestionMatcher.historyWeightFor(40), 1.5);
    });
  });

  group('stemWord', () {
    test('folds plurals, -ies, -ing and -ed', () {
      expect(stemWord('presentations'), 'presentation');
      expect(stemWord('berries'), 'berry');
      expect(stemWord('painting'), 'paint');
      expect(stemWord('painted'), 'paint');
    });

    test('undoes the consonant an ending doubled, but no other double', () {
      expect(stemWord('running'), 'run');
      expect(stemWord('planned'), 'plan');
      expect(stemWord('shopping'), 'shop');
      expect(stemWord('rolling'), 'roll');
      expect(stemWord('passed'), 'pass');
      expect(stemWord('added'), 'add');
    });

    test('leaves words whose ending is not an inflection alone', () {
      expect(stemWord('glass'), 'glass');
      expect(stemWord('status'), 'status');
      expect(stemWord('analysis'), 'analysis');
      expect(stemWord('need'), 'need');
      expect(stemWord('sing'), 'sing');
      expect(stemWord('work'), 'work');
    });

    test('drops stop words, single characters and bare numbers', () {
      expect(stemWord('the'), isNull);
      expect(stemWord('und'), isNull);
      expect(stemWord('x'), isNull);
      expect(stemWord('2026'), isNull);
      expect(stemWord('q3'), 'q3');
    });
  });

  group('properties', () {
    const vocabulary = [
      'work',
      'garden',
      'roses',
      'website',
      'hosting',
      'team',
      'alpha',
      'presentation',
      'kitchen',
      'order',
      'the',
      'plan',
      'yoga',
      'run',
    ];
    final projects = [
      _project('work', 'Work', taskTitles: const ['Plan the team offsite']),
      _project('garden', 'Garden', taskTitles: const ['Prune roses']),
      _project('site', 'Website hosting'),
      _project('alpha', 'Team alpha', description: 'presentation planning'),
      _project('kitchen', 'Kitchen', taskTitles: const ['Order tiles']),
    ];

    String titleOf(List<int> picks) => [
      for (final i in picks) vocabulary[i % vocabulary.length],
    ].join(' ');

    glados.Glados2(
      glados.any.list(glados.any.intInRange(0, 1000)),
      glados.any.intInRange(1, 1000),
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'ranking does not depend on the order the projects arrive in',
      (picks, seed) {
        final title = titleOf(picks);
        final shuffled = [...projects]
          ..sort(
            (a, b) => ((a.projectId.hashCode * seed) % 997).compareTo(
              (b.projectId.hashCode * seed) % 997,
            ),
          );
        final task = ProjectMatchTask(title: title);
        expect(
          ProjectSuggestionMatcher(shuffled).rank(task),
          ProjectSuggestionMatcher(projects).rank(task),
        );
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.list(glados.any.intInRange(0, 1000)),
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'a suggestion is always the top-ranked project, clear of the threshold '
      'and of the runner-up',
      (picks) {
        final task = ProjectMatchTask(title: titleOf(picks));
        final matcher = ProjectSuggestionMatcher(projects);
        final ranked = matcher.rank(task);
        final suggestion = matcher.suggest(task);
        for (final score in ranked) {
          expect(score.score, greaterThan(0));
        }
        if (suggestion == null) return;
        expect(suggestion, ranked.first);
        expect(
          suggestion.score,
          greaterThanOrEqualTo(ProjectSuggestionMatcher.minSuggestionScore),
        );
        if (ranked.length > 1) {
          expect(
            suggestion.score,
            greaterThanOrEqualTo(
              ranked[1].score * ProjectSuggestionMatcher.ambiguityMargin,
            ),
          );
        }
      },
      tags: 'glados',
    );
  });
}

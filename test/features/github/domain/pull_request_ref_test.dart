import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/github/domain/pull_request_ref.dart';

void main() {
  PullRequestRef? parsed(String input) => switch (parsePullRequestRef(input)) {
    PullRequestRefParsed(:final ref) => ref,
    PullRequestRefRejected() => null,
  };

  PullRequestRefRejection? rejection(String input) =>
      switch (parsePullRequestRef(input)) {
        PullRequestRefParsed() => null,
        PullRequestRefRejected(:final reason) => reason,
      };

  const lotti42 = PullRequestRef(owner: 'matthiasn', repo: 'lotti', number: 42);

  group('parsePullRequestRef accepts', () {
    for (final input in [
      'https://github.com/matthiasn/lotti/pull/42',
      'http://github.com/matthiasn/lotti/pull/42',
      'https://www.github.com/matthiasn/lotti/pull/42',
      'github.com/matthiasn/lotti/pull/42',
      '  https://github.com/matthiasn/lotti/pull/42  \n',
      'https://github.com/matthiasn/lotti/pull/42/',
      'https://github.com/matthiasn/lotti/pull/42/files',
      'https://github.com/matthiasn/lotti/pull/42/commits/abc123',
      'https://github.com/matthiasn/lotti/pull/42?notification_referrer_id=x',
      'https://github.com/matthiasn/lotti/pull/42#issuecomment-1',
      'https://api.github.com/repos/matthiasn/lotti/pulls/42',
      'matthiasn/lotti#42',
    ]) {
      test(input.trim(), () => expect(parsed(input), lotti42));
    }

    test('names with dots, underscores and hyphens, keeping their case', () {
      final ref = parsed('https://github.com/Some-Org/my_repo.dart/pull/7');
      expect(ref?.owner, 'Some-Org');
      expect(ref?.repo, 'my_repo.dart');
      expect(ref?.number, 7);
      expect(ref?.key, 'some-org/my_repo.dart#7');
    });
  });

  group('parsePullRequestRef rejects', () {
    test('nothing pasted', () {
      expect(rejection(''), PullRequestRefRejection.empty);
      expect(rejection('   '), PullRequestRefRejection.empty);
    });

    test('links to other hosts, GitHub Enterprise included', () {
      for (final input in [
        'https://gitlab.com/matthiasn/lotti/-/merge_requests/42',
        'https://github.example.com/matthiasn/lotti/pull/42',
        'https://github.com.evil.example/matthiasn/lotti/pull/42',
        'ftp://github.com/matthiasn/lotti/pull/42',
        'just some words',
      ]) {
        expect(
          rejection(input),
          PullRequestRefRejection.notGitHub,
          reason: input,
        );
      }
    });

    test('GitHub links that are not pull requests', () {
      for (final input in [
        'https://github.com/matthiasn/lotti',
        'https://github.com/matthiasn/lotti/issues/42',
        'https://github.com/matthiasn/lotti/pull/',
        'https://github.com/matthiasn/lotti/pull/abc',
        'https://github.com/matthiasn/lotti/pull/0',
        'https://github.com/matthiasn/lotti/pull/042',
        'https://github.com/-bad/lotti/pull/42',
        'https://github.com/bad--owner/lotti/pull/42',
        'https://github.com/matthiasn/../pull/42',
        'https://api.github.com/repos/matthiasn/lotti/issues/42',
        'matthiasn/lotti#0',
        'matthiasn/lotti#99999999999',
      ]) {
        expect(
          rejection(input),
          PullRequestRefRejection.notAPullRequest,
          reason: input,
        );
      }
    });
  });

  test('refs compare by key, so case does not make a second link', () {
    expect(
      const PullRequestRef(owner: 'MatthiasN', repo: 'Lotti', number: 42),
      lotti42,
    );
    expect(
      const PullRequestRef(
        owner: 'MatthiasN',
        repo: 'Lotti',
        number: 42,
      ).hashCode,
      lotti42.hashCode,
    );
    expect(lotti42.toString(), 'matthiasn/lotti#42');
  });

  glados.Glados3<int, int, int>(
    glados.any.intInRange(0, 26),
    glados.any.intInRange(0, 26),
    glados.any.intInRange(1, 100000),
  ).test(
    'every way of writing one pull request parses to the same ref',
    (o, r, number) {
      final owner = 'own${String.fromCharCode(97 + o)}';
      final repo = 'repo-${String.fromCharCode(97 + r)}';
      final expected = PullRequestRef(
        owner: owner,
        repo: repo,
        number: number,
      );
      for (final input in [
        'https://github.com/$owner/$repo/pull/$number',
        'github.com/$owner/$repo/pull/$number/files',
        'https://api.github.com/repos/$owner/$repo/pulls/$number',
        '$owner/$repo#$number',
      ]) {
        expect(parsed(input), expected, reason: input);
      }
    },
    tags: 'glados',
  );
}

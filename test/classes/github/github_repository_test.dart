import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/github/github_repository.dart';

void main() {
  const lotti = GitHubRepository(owner: 'matthiasn', repo: 'lotti');

  group('parseGitHubRepository reads', () {
    for (final input in [
      'matthiasn/lotti',
      '  matthiasn/lotti  ',
      'https://github.com/matthiasn/lotti',
      'https://github.com/matthiasn/lotti/',
      'https://github.com/matthiasn/lotti.git',
      'https://www.github.com/matthiasn/lotti',
      'github.com/matthiasn/lotti',
      'https://github.com/matthiasn/lotti/tree/main/lib',
      'https://github.com/matthiasn/lotti/pull/42',
    ]) {
      test(input.trim(), () => expect(parseGitHubRepository(input), lotti));
    }
  });

  group('parseGitHubRepository refuses', () {
    for (final input in [
      '',
      '   ',
      'lotti',
      'matthiasn/lotti/extra',
      'https://gitlab.com/matthiasn/lotti',
      'https://github.com/matthiasn',
      'ftp://github.com/matthiasn/lotti',
      '-bad/lotti',
      'matthiasn/..',
      'matthiasn/lot ti',
    ]) {
      test(
        input.isEmpty ? '(empty)' : input,
        () => expect(parseGitHubRepository(input), isNull),
      );
    }
  });

  test('repositories compare without case and print as owner/repo', () {
    const upper = GitHubRepository(owner: 'MatthiasN', repo: 'Lotti');
    expect(upper, lotti);
    expect(upper.hashCode, lotti.hashCode);
    expect(upper.toString(), 'MatthiasN/Lotti');
  });

  test('name rules: logins and repository names', () {
    expect(isGitHubOwner('a-b'), isTrue);
    expect(isGitHubOwner('a--b'), isFalse);
    expect(isGitHubOwner('a' * 40), isFalse);
    expect(isGitHubRepoName('my_repo.dart'), isTrue);
    expect(isGitHubRepoName('.'), isFalse);
    expect(isGitHubRepoName(''), isFalse);
  });
}

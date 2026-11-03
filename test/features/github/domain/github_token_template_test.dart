import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/github/domain/github_token_template.dart';

void main() {
  final uri = gitHubTokenTemplateUri();
  final query = uri.queryParameters;

  /// The query without the token's own fields: the permissions alone.
  Map<String, String> permissions() => Map.of(query)
    ..removeWhere(
      (key, _) => const {'name', 'description', 'expires_in'}.contains(key),
    );

  group('where it points', () {
    test('over https', () {
      expect(uri.scheme, 'https');
    });

    test('to github.com itself, not the API host', () {
      expect(uri.host, 'github.com');
    });

    test("to the fine-grained token form, not the classic one's", () {
      expect(uri.path, '/settings/personal-access-tokens/new');
    });

    test('with no fragment or credentials to leak', () {
      expect(uri.fragment, isEmpty);
      expect(uri.userInfo, isEmpty);
    });
  });

  group('what it names the token', () {
    test('Lotti', () {
      expect(query['name'], 'Lotti');
    });

    test('with an English description of what Lotti reads', () {
      expect(
        query['description'],
        'Lotti reads the pull requests you link to tasks: their status, '
        'checks and reviews. Read-only.',
      );
    });
  });

  group('how long it lasts', () {
    test('366 days, the longest short of never expiring', () {
      expect(query['expires_in'], '366');
    });

    test('never `none`, which a lifetime policy refuses', () {
      expect(query['expires_in'], isNot('none'));
    });
  });

  group('which permissions it asks for', () {
    test('exactly pull requests, commit statuses and metadata', () {
      expect(permissions(), {
        'pull_requests': 'read',
        'statuses': 'read',
        'metadata': 'read',
      });
    });

    test('each read-only: never write or admin', () {
      expect(permissions().values, everyElement('read'));
    });

    test('no owner: GitHub defaults to the user, the user may change it', () {
      expect(query.containsKey('target_name'), isFalse);
    });
  });

  group("GitHub's limits", () {
    test('a name of at most 40 characters', () {
      expect(query['name']!.length, lessThanOrEqualTo(40));
    });

    test('a description of at most 1024 characters', () {
      expect(query['description']!.length, lessThanOrEqualTo(1024));
    });

    test('a lifetime of 1 to 366 days', () {
      expect(int.parse(query['expires_in']!), inInclusiveRange(1, 366));
    });
  });

  group('encoding', () {
    test('parsing the link gives back the same link', () {
      expect(Uri.parse(uri.toString()), uri);
    });

    test('parsing the link gives back the same fields', () {
      expect(Uri.parse(uri.toString()).queryParameters, query);
    });

    test('carries no raw space or colon in its query', () {
      expect(uri.query, isNot(contains(' ')));
      expect(uri.query, isNot(contains(':')));
    });

    test('is the same link on every call', () {
      expect(gitHubTokenTemplateUri(), uri);
    });
  });
}

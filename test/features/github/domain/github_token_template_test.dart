import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/github/domain/github_token_template.dart';

void main() {
  final uri = gitHubTokenTemplateUri();

  test("opens GitHub's fine-grained token form over https", () {
    expect(uri.scheme, 'https');
    expect(uri.host, 'github.com');
    expect(uri.path, '/settings/personal-access-tokens/new');
  });

  test('fills in exactly the name, description, lifetime and permissions', () {
    expect(uri.queryParameters, {
      'name': 'Lotti',
      'description':
          'Lotti reads the pull requests you link to tasks: their status, '
          'checks and reviews. Read-only.',
      'expires_in': '366',
      'pull_requests': 'read',
      'statuses': 'read',
      'metadata': 'read',
    });
  });

  test('asks for no permission beyond read', () {
    const fields = {'name', 'description', 'expires_in'};
    final permissions = Map.of(uri.queryParameters)
      ..removeWhere((key, _) => fields.contains(key));

    expect(permissions, isNotEmpty);
    expect(permissions.values, everyElement('read'));
  });

  test("stays within GitHub's limits for the form's fields", () {
    expect(uri.queryParameters['name']!.length, lessThanOrEqualTo(40));
    expect(
      uri.queryParameters['description']!.length,
      lessThanOrEqualTo(1024),
    );
    final days = int.parse(uri.queryParameters['expires_in']!);
    expect(days, inInclusiveRange(1, 366));
  });

  test('is encoded so that parsing it gives back the same fields', () {
    final reparsed = Uri.parse(uri.toString());

    expect(reparsed, uri);
    expect(reparsed.queryParameters, uri.queryParameters);
    expect(uri.toString(), isNot(contains(' ')));
  });
}

/// The GitHub form that creates a fine-grained personal access token, which
/// fills its fields from the query string.
const _host = 'github.com';
const _path = '/settings/personal-access-tokens/new';

/// The token's name on github.com. GitHub allows 40 characters.
const _name = 'Lotti';

/// The token's description on github.com, where the user manages it — so in
/// English, not localized. GitHub allows 1024 characters.
const _description =
    'Lotti reads the pull requests you link to tasks: their status, checks '
    'and reviews. Read-only.';

/// Days until the token expires: the longest GitHub accepts short of `none`,
/// which an owner with a token lifetime policy refuses. The token syncs to
/// every device, so a short lifetime would stop the tracking everywhere.
const _expiresInDays = 366;

/// The repository permissions the token needs, each read-only, by the
/// `GitHubClient` calls that need it. A new endpoint in the client adds its
/// permission here.
const _permissions = <String, String>{
  // `GET /repos/{o}/{r}/pulls/{n}`, `…/pulls/{n}/reviews`, `…/pulls`, and
  // the GraphQL query for open pull requests' sizes.
  'pull_requests': 'read',
  // `GET /repos/{o}/{r}/commits/{sha}/status`.
  'statuses': 'read',
  // Mandatory on every fine-grained token; named so the form shows it.
  'metadata': 'read',
};

/// The GitHub form that creates the token Lotti needs, with its name,
/// description, lifetime and read-only permissions filled in. The user still
/// chooses the repositories it reaches: GitHub takes no parameter for that.
///
/// Check runs have no fine-grained permission, so they stay unreadable on a
/// private repository whatever the token.
Uri gitHubTokenTemplateUri() {
  assert(_name.length <= 40, 'GitHub limits a token name to 40 characters');
  assert(
    _description.length <= 1024,
    'GitHub limits a token description to 1024 characters',
  );
  return Uri.https(_host, _path, {
    'name': _name,
    'description': _description,
    'expires_in': '$_expiresInDays',
    ..._permissions,
  });
}

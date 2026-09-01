import 'package:lotti/classes/config.dart';

final RegExp _whitespace = RegExp(r'\s');

/// Which field of a manual sign-in the user still has to fix.
enum MatrixCredentialsField { homeServer, user, password }

/// What typed credentials normalised to: either a [MatrixConfig] ready to sign
/// in with, or the first field that cannot be used as entered.
sealed class MatrixCredentialsInput {
  const MatrixCredentialsInput._();

  /// Normalises the three sign-in fields into a [MatrixConfig].
  ///
  /// The server address may be typed as a bare host — `matrix.example.com`
  /// becomes `https://matrix.example.com` — but never as plain `http://`:
  /// the password travels with the first request, and every bundle this app
  /// consumes is held to the same rule. The user must be the full Matrix ID
  /// (`@name:example.com`); the account's server name need not match the
  /// homeserver's host, so a localpart cannot be completed safely here.
  factory MatrixCredentialsInput.normalize({
    required String homeServer,
    required String user,
    required String password,
  }) {
    final trimmedServer = homeServer.trim();
    final serverWithScheme = trimmedServer.contains('://')
        ? trimmedServer
        : 'https://$trimmedServer';
    final uri = Uri.tryParse(serverWithScheme);
    // `Uri.tryParse` tolerates inner whitespace that no homeserver will, so
    // it is refused up front rather than surfacing as a failed login.
    if (trimmedServer.isEmpty ||
        _whitespace.hasMatch(trimmedServer) ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return const MatrixCredentialsInvalid(MatrixCredentialsField.homeServer);
    }

    final trimmedUser = user.trim();
    final colon = trimmedUser.indexOf(':');
    // Matrix user IDs contain no whitespace; a stray space inside one would
    // otherwise reach the server and come back as a rejected password.
    if (!trimmedUser.startsWith('@') ||
        _whitespace.hasMatch(trimmedUser) ||
        colon < 2 ||
        colon == trimmedUser.length - 1) {
      return const MatrixCredentialsInvalid(MatrixCredentialsField.user);
    }

    if (password.isEmpty) {
      return const MatrixCredentialsInvalid(MatrixCredentialsField.password);
    }

    // The trailing slash is dropped so the persisted address matches the form
    // pairing bundles carry and the roster shows.
    final normalizedServer = uri.path == '/'
        ? uri.replace(path: '').toString()
        : uri.toString();
    return MatrixCredentialsValid(
      MatrixConfig(
        homeServer: normalizedServer,
        user: trimmedUser,
        password: password,
      ),
    );
  }
}

/// The fields normalised to a config the app can sign in with.
final class MatrixCredentialsValid extends MatrixCredentialsInput {
  const MatrixCredentialsValid(this.config) : super._();

  final MatrixConfig config;
}

/// One field cannot be used as entered; [field] names the first such field in
/// form order, so the error lands next to the thing to fix.
final class MatrixCredentialsInvalid extends MatrixCredentialsInput {
  const MatrixCredentialsInvalid(this.field) : super._();

  final MatrixCredentialsField field;
}

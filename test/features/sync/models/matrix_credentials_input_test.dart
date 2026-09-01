import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/models/matrix_credentials_input.dart';

void main() {
  MatrixCredentialsInput normalize({
    String homeServer = 'https://matrix.example.com',
    String user = '@alice:example.com',
    String password = 'secret',
  }) => MatrixCredentialsInput.normalize(
    homeServer: homeServer,
    user: user,
    password: password,
  );

  group('MatrixCredentialsInput.normalize', () {
    test('passes well-formed fields through unchanged', () {
      final input = normalize();

      final config = (input as MatrixCredentialsValid).config;
      expect(config.homeServer, 'https://matrix.example.com');
      expect(config.user, '@alice:example.com');
      expect(config.password, 'secret');
    });

    test('completes a bare host to https and trims whitespace', () {
      // A user typing what their homeserver admin told them — the host —
      // should not be sent to a page about URL schemes.
      final input = normalize(homeServer: '  matrix.example.com ');

      expect(
        (input as MatrixCredentialsValid).config.homeServer,
        'https://matrix.example.com',
      );
    });

    test('drops a trailing slash so the address matches bundle form', () {
      final input = normalize(homeServer: 'https://matrix.example.com/');

      expect(
        (input as MatrixCredentialsValid).config.homeServer,
        'https://matrix.example.com',
      );
    });

    test('keeps a port and a path prefix', () {
      final input = normalize(homeServer: 'https://example.com:8448/matrix');

      expect(
        (input as MatrixCredentialsValid).config.homeServer,
        'https://example.com:8448/matrix',
      );
    });

    test('trims the Matrix ID but never the password', () {
      // A password may legitimately end in a space; an ID cannot.
      final input = normalize(user: ' @alice:example.com ', password: 'pw ');

      final config = (input as MatrixCredentialsValid).config;
      expect(config.user, '@alice:example.com');
      expect(config.password, 'pw ');
    });

    for (final server in ['http://matrix.example.com', 'ftp://x.example']) {
      test('rejects a non-https scheme ($server)', () {
        final input = normalize(homeServer: server);

        expect(
          (input as MatrixCredentialsInvalid).field,
          MatrixCredentialsField.homeServer,
        );
      });
    }

    for (final server in [
      '',
      '   ',
      'https://',
      'https://x?y=1',
      'https://x#f',
      'https://matrix. example.com',
    ]) {
      test('rejects an unusable server address ("$server")', () {
        final input = normalize(homeServer: server);

        expect(
          (input as MatrixCredentialsInvalid).field,
          MatrixCredentialsField.homeServer,
        );
      });
    }

    for (final user in [
      'alice',
      'alice:example.com',
      '@alice',
      '@:x',
      '@a:',
      // Whitespace inside either part: Matrix IDs have none, and the server
      // would report a failed login rather than a bad ID.
      '@alice: example.com',
      '@al ice:example.com',
    ]) {
      test('rejects a user that is not a full Matrix ID ("$user")', () {
        // The account's server name need not match the homeserver host, so
        // a localpart cannot be completed safely — it is sent back instead.
        final input = normalize(user: user);

        expect(
          (input as MatrixCredentialsInvalid).field,
          MatrixCredentialsField.user,
        );
      });
    }

    test('rejects an empty password', () {
      final input = normalize(password: '');

      expect(
        (input as MatrixCredentialsInvalid).field,
        MatrixCredentialsField.password,
      );
    });

    test('names the first bad field in form order', () {
      // Everything is wrong; the error must land on the topmost field so the
      // user fixes the form top to bottom rather than bouncing around.
      final input = normalize(
        homeServer: 'http://x',
        user: 'alice',
        password: '',
      );

      expect(
        (input as MatrixCredentialsInvalid).field,
        MatrixCredentialsField.homeServer,
      );
    });
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/support_links.dart';

void main() {
  group('contactEmailUri', () {
    test('addresses the contact mailbox over the mailto scheme', () {
      final uri = contactEmailUri(subject: 'Lotti feedback');

      expect(uri.scheme, 'mailto');
      expect(uri.path, lottiContactEmail);
    });

    test('percent-encodes the subject rather than form-encoding it', () {
      final uri = contactEmailUri(subject: 'Lotti feedback');

      // The distinction is the whole reason this builder exists:
      // `Uri(queryParameters: …)` would emit `Lotti+feedback`, and a `+` in a
      // mailto query reaches most mail clients as a literal plus rather than
      // as a space.
      expect(
        uri.toString(),
        'mailto:$lottiContactEmail?subject=Lotti%20feedback',
      );
    });

    test('escapes characters that would otherwise truncate the subject', () {
      // `&` starts another query parameter and `?` another query; unescaped,
      // everything after the ampersand would be lost from the subject line.
      final uri = contactEmailUri(subject: 'Sync & AI: broken?');

      expect(uri.toString(), contains('%26'));
      expect(uri.queryParameters['subject'], 'Sync & AI: broken?');
    });

    test('round-trips a subject carrying non-ASCII characters', () {
      // Every translated subject in the catalogs is non-ASCII somewhere —
      // Czech's "Zpětná vazba k Lotti" among them.
      final uri = contactEmailUri(subject: 'Zpětná vazba k Lotti');

      expect(uri.queryParameters['subject'], 'Zpětná vazba k Lotti');
    });

    test('omits the query entirely when the subject is empty', () {
      // A trailing `?subject=` makes some clients open with a blank-but-set
      // subject the user then has to clear.
      expect(
        contactEmailUri(subject: '').toString(),
        'mailto:$lottiContactEmail',
      );
    });
  });

  group('external destinations', () {
    test('the GitHub link is the repository root, not the issue tracker', () {
      final uri = Uri.parse(lottiGithubUrl);

      expect(uri.scheme, 'https');
      expect(uri.host, 'github.com');
      expect(uri.path, '/matthiasn/lotti');
    });

    test('the Discord link is an https invite', () {
      final uri = Uri.parse(lottiDiscordInviteUrl);

      expect(uri.scheme, 'https');
      expect(uri.host, 'discord.gg');
      expect(uri.path, isNot('/'));
    });

    test('both match the URLs the Flatpak metainfo advertises', () {
      // The metainfo is what Flathub shows as the app's homepage and contact
      // link. Two copies of the same address drift silently; this is the
      // assertion that makes the drift fail a build instead.
      final metainfo = File(
        'flatpak/com.matthiasn.lotti.metainfo.xml',
      ).readAsStringSync();

      expect(
        metainfo,
        contains('<url type="homepage">$lottiGithubUrl</url>'),
      );
      expect(
        metainfo,
        contains('<url type="contact">$lottiDiscordInviteUrl</url>'),
      );
    });
  });
}

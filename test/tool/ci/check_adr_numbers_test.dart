import 'package:flutter_test/flutter_test.dart';

import '../../../tool/ci/check_adr_numbers.dart';

void main() {
  test('unique numbers pass, and non-ADR files are ignored', () {
    expect(
      duplicateAdrNumbers([
        '0001-first.md',
        '0002-second.md',
        'README.md',
        'template.md',
        '0003-draft.txt',
      ]),
      isEmpty,
    );
  });

  test('reports each shared number with its files, sorted', () {
    expect(
      duplicateAdrNumbers([
        '0115-the-last-wake-outcome-is-two-watermarks.md',
        '0113-project-agents-update-in-synced-slots.md',
        '0114-only.md',
        '0115-github-token-syncs-like-inference-keys.md',
        '0113-inbound-sync-trusts-only-key-sharing-peers.md',
      ]),
      {
        '0113': [
          '0113-inbound-sync-trusts-only-key-sharing-peers.md',
          '0113-project-agents-update-in-synced-slots.md',
        ],
        '0115': [
          '0115-github-token-syncs-like-inference-keys.md',
          '0115-the-last-wake-outcome-is-two-watermarks.md',
        ],
      },
    );
  });
}

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/ci/check_action_pins.dart';

void main() {
  test('flags actions referenced by a tag or a branch, with their line', () {
    expect(
      unpinnedActions('''
jobs:
  build:
    steps:
      - uses: actions/checkout@v5
      - name: Rust
        uses: dtolnay/rust-toolchain@stable
      - uses: owner/repo/sub/action@v1.2.3 # a comment
'''),
      [
        (line: 4, reference: 'actions/checkout@v5'),
        (line: 6, reference: 'dtolnay/rust-toolchain@stable'),
        (line: 7, reference: 'owner/repo/sub/action@v1.2.3'),
      ],
    );
  });

  test('accepts full SHAs, local actions and container images', () {
    expect(
      unpinnedActions('''
steps:
  - uses: actions/checkout@fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09 # v5
  - uses: ./.github/actions/setup
  - uses: docker://alpine:3.20
'''),
      isEmpty,
    );
  });

  test('a shortened SHA is still unpinned', () {
    // Only the full 40 characters name one commit unambiguously.
    expect(
      unpinnedActions('      - uses: actions/checkout@fbc6f39\n'),
      [(line: 1, reference: 'actions/checkout@fbc6f39')],
    );
  });
}

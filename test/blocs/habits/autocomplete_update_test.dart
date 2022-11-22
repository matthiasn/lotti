import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/logic/habits/autocomplete_update.dart';

import 'autocomplete_update_data.dart';

void main() {
  group('Edit Autocomplete Rule Tests - ', () {
    test(
      'Remove last rule in top level AND: hydration',
      () {
        expect(
          removeAt(testAutoComplete, [0, 2]),
          testAutoCompleteWithoutHydration,
        );
      },
    );

    test(
      'Remove top level rule',
      () {
        expect(
          removeAt(testAutoComplete, [0]),
          null,
        );
      },
    );

    test(
      'Remove pull-ups rule',
      () {
        expect(
          removeAt(testAutoComplete, [0, 0, 0, 1]),
          testAutoCompleteWithoutPullUps,
        );
      },
    );
  });
}

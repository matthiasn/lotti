import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/workflow/prompt_log_wrap.dart';

void main() {
  group('renderPlainPromptLogWrap', () {
    test('splices the log verbatim between head and tail', () {
      expect(
        renderPlainPromptLogWrap(head: 'HEAD\n', log: 'LOG', tail: '\nTAIL'),
        'HEAD\nLOG\nTAIL',
      );
    });

    test('preserves an empty log without collapsing head into tail', () {
      // An empty visible log is a real state (a wake before any event was
      // rendered), and the splice must not eat the boundary between the halves.
      expect(
        renderPlainPromptLogWrap(head: 'HEAD', log: '', tail: 'TAIL'),
        'HEAD'
        'TAIL',
      );
    });

    test('does not reorder or escape its arguments', () {
      // Named-only parameters exist so a renderer cannot transpose the halves;
      // assert the ordering contract that the reconstructor relies on.
      expect(
        renderPlainPromptLogWrap(head: '<a>', log: '</b>', tail: '&c;'),
        '<a></b>&c;',
      );
    });
  });

  group('promptLogWrapRenderersProvider', () {
    test('defaults to empty so a bare container needs no wiring', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(promptLogWrapRenderersProvider), isEmpty);
    });

    test('an override supplies renderers keyed by wrap kind', () {
      final container = ProviderContainer(
        overrides: [
          promptLogWrapRenderersProvider.overrideWithValue({
            'shout': ({required head, required log, required tail}) =>
                '$head${log.toUpperCase()}$tail',
          }),
        ],
      );
      addTearDown(container.dispose);

      final renderers = container.read(promptLogWrapRenderersProvider);
      expect(renderers.keys, ['shout']);
      expect(
        renderers['shout']!(head: '[', log: 'quiet', tail: ']'),
        '[QUIET]',
      );
    });
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/workflow/prompt_record.dart';

/// Splices a re-derived log block back between a v2 prompt record's
/// non-derivable halves (ADR 0020).
///
/// One renderer per [PromptRecord.wrap] kind. The signature is deliberately
/// named-only so a renderer cannot silently transpose [head] and [tail].
typedef PromptLogWrapRenderer =
    String Function({
      required String head,
      required String log,
      required String tail,
    });

/// The [promptRecordWrapPlain] renderer: verbatim splice.
///
/// Also the fallback the reconstructor uses for a wrap kind no renderer was
/// contributed for — a reconstruction that loses its section framing is still
/// readable, whereas failing outright would blank the history UI.
String renderPlainPromptLogWrap({
  required String head,
  required String log,
  required String tail,
}) => head + log + tail;

/// [PromptLogWrapRenderer]s by wrap kind, keyed by the same string constants
/// that [PromptRecord.wrap] carries.
///
/// The reconstructor lives in `features/agents` and knows only
/// [promptRecordWrapPlain]. Every other wrap kind is a *payload format* owned
/// by the feature that persists it, so that feature contributes the renderer
/// here and the runtime never imports it — the dependency points inward only.
/// Populated by overriding this provider in the composition root
/// (`buildProviderOverrides`); the default is empty so a bare test container
/// reconstructs plain records without any wiring.
final promptLogWrapRenderersProvider =
    Provider<Map<String, PromptLogWrapRenderer>>(
      (ref) => const <String, PromptLogWrapRenderer>{},
      name: 'promptLogWrapRenderersProvider',
    );

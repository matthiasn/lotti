/// The Lotti inference domain: the types every provider, workflow and agent
/// speaks.
///
/// `openai_dart` is confined to
/// `lib/features/ai/repository/openai_compat_adapter.dart`. Import this
/// barrel rather than the client library so that upgrading the client stays a
/// change to the adapter instead of a change to every call site.
library;

export 'inference_chunk.dart';
export 'inference_message.dart';
export 'inference_request.dart';
export 'inference_tool.dart';

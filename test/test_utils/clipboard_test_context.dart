// `super_clipboard`'s native write path routes through the irondash message
// channel. `MockMessageChannelContext` and `superNativeExtensionsContext` come
// from its transitive dependencies, hence the lint ignore.
// ignore_for_file: depend_on_referenced_packages
import 'package:irondash_message_channel/irondash_message_channel.dart';
import 'package:super_native_extensions/src/native/context.dart';

/// Plain-text payloads handed to `super_clipboard`'s `registerDataProvider`,
/// in write order, across the whole test process.
final List<String> clipboardWrittenPlainText = [];

/// Provider-id lists handed to `writeToClipboard`, one entry per write call.
final List<List<int>> clipboardWrittenProviderIds = [];

int _nextProviderId = 1;
bool _installed = false;

/// Installs recording handlers for `super_clipboard`'s native write channels
/// (`DataProviderManager`, `ClipboardWriter`) so that clipboard writes succeed
/// and can be observed in tests.
///
/// `super_native_extensions` binds each channel singleton to
/// `superNativeExtensionsContext` (i.e. the bare default `_nativeContext`, a
/// `MockMessageChannelContext`, when no override is set) the first time it is
/// constructed — which, in a bundled `very_good test` run, can be before any
/// individual test runs. So we deliberately do **not** call
/// `setContextOverride`: swapping in a fresh override context would be ignored
/// by an already-constructed singleton, and every later write would throw
/// `NoSuchChannelException: "DataProviderManager" not found`. Instead we
/// register the handlers on that same shared default context. Mock handlers are
/// looked up at *send* time, so this is honoured regardless of when the
/// singleton was built, as long as the handlers are in place before the write —
/// which they are, since this runs from `flutter_test_config.dart` before any
/// test. (This failure is invisible in CI only because sharding tends to
/// separate the first writer from the asserting test.)
///
/// Reads (`ClipboardReader`) are intentionally left unhandled, matching the
/// default test environment where reads throw `NoSuchChannelException`.
///
/// Idempotent: handlers and their recording lists are installed once and
/// reused, so repeated calls (one per test file outside the optimizer) are
/// no-ops after the first.
void installSharedClipboardTestContext() {
  if (_installed) return;
  _installed = true;

  // The context the channel singletons bind to. With no override set this is
  // the shared default `_nativeContext`; registering on it reaches every
  // singleton that binds it, whenever it was constructed.
  final context = superNativeExtensionsContext;
  if (context is! MockMessageChannelContext) return;

  context
    ..registerMockMethodCallHandler('DataProviderManager', (call) {
      if (call.method == 'registerDataProvider') {
        // The serialized provider carries the representations we record, e.g.
        // {representations: ({type: simple, format: text/plain, data: <text>})}.
        final args = call.arguments as Map<Object?, Object?>?;
        final representations = (args?['representations'] as Iterable?)
            ?.cast<Map<Object?, Object?>>();
        for (final representation
            in representations ?? const <Map<Object?, Object?>>[]) {
          final data = representation['data'];
          if (representation['format'] == 'text/plain' && data is String) {
            clipboardWrittenPlainText.add(data);
          }
        }
        return _nextProviderId++;
      }
      return null;
    })
    ..registerMockMethodCallHandler('ClipboardWriter', (call) {
      if (call.method == 'writeToClipboard') {
        clipboardWrittenProviderIds.add(
          (call.arguments as Iterable).cast<int>().toList(),
        );
      }
      return null;
    });
}

/// Clears recorded writes so a test can assert on only the writes it triggers.
void resetClipboardTestRecorder() {
  clipboardWrittenPlainText.clear();
  clipboardWrittenProviderIds.clear();
}

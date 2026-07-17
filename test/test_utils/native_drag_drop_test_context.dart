// `super_drag_and_drop` routes through irondash's native message channels.
// These transitive packages expose the test context needed to make the
// production drag-and-drop wrapper deterministic under the Flutter test
// binding.
// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irondash_message_channel/irondash_message_channel.dart';
import 'package:super_native_extensions/src/native/context.dart';

const _engineContextChannel = MethodChannel('dev.irondash.engine_context');

/// Installs the minimal native bridge used when a production drop region
/// registers its supported formats in widget tests.
void installSharedNativeDragDropTestContext() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        _engineContextChannel,
        (call) async => call.method == 'getEngineHandle' ? 1 : null,
      );

  final context = superNativeExtensionsContext;
  if (context is! MockMessageChannelContext) return;

  context
    ..registerMockMethodCallHandler('DropManager', (call) => null)
    ..registerMockMethodCallHandler('DragManager', (call) => null);
}

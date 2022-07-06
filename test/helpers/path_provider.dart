import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void setFakeDocumentsPath() {
  const MethodChannel('plugins.flutter.io/path_provider_macos')
      .setMockMethodCallHandler((MethodCall methodCall) async {
    return '/tmp/lotti';
  });

  const MethodChannel('plugins.flutter.io/path_provider_linux')
      .setMockMethodCallHandler((MethodCall methodCall) async {
    return '/tmp/lotti';
  });

  const MethodChannel('plugins.flutter.io/path_provider_windows')
      .setMockMethodCallHandler((MethodCall methodCall) async {
    return '/tmp/lotti';
  });
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/file_utils.dart';

void setFakeDocumentsPath() {
  final dir = uuid.v1();
  const MethodChannel('plugins.flutter.io/path_provider_macos')
      .setMockMethodCallHandler((MethodCall methodCall) async {
    return '/tmp/$dir';
  });

  const MethodChannel('plugins.flutter.io/path_provider_linux')
      .setMockMethodCallHandler((MethodCall methodCall) async {
    return '/tmp/$dir';
  });

  const MethodChannel('plugins.flutter.io/path_provider_windows')
      .setMockMethodCallHandler((MethodCall methodCall) async {
    return '/tmp/$dir';
  });
}

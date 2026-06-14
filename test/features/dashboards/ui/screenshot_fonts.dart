import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Loads the app's bundled fonts (Inter, Inconsolata) and the Flutter
/// MaterialIcons glyphs into the test binding so design-review screenshots
/// render real type instead of the blocky FlutterTest fallback.
///
/// OPT-IN ONLY: `FontLoader` registers fonts process-wide with no way to
/// unload, which changes text metrics for unrelated tests under the shared
/// CI isolate — so this is only called from the opt-in screenshot harnesses.
Future<void> loadScreenshotFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ByteData> fontBytes(String path) async {
    final bytes = await File(path).readAsBytes();
    return ByteData.view(bytes.buffer);
  }

  final inter = FontLoader('Inter')
    ..addFont(fontBytes('assets/fonts/Inter/Inter-VariableFont_opsz,wght.ttf'));
  final inconsolata = FontLoader('Inconsolata')
    ..addFont(fontBytes('assets/fonts/Inconsolata/Inconsolata-Regular.ttf'))
    ..addFont(fontBytes('assets/fonts/Inconsolata/Inconsolata-Medium.ttf'));
  await inter.load();
  await inconsolata.load();

  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ?? '.fvm/flutter_sdk';
  final iconFont = File(
    p.join(
      flutterRoot,
      'bin',
      'cache',
      'artifacts',
      'material_fonts',
      'MaterialIcons-Regular.otf',
    ),
  );
  if (iconFont.existsSync()) {
    final icons = FontLoader('MaterialIcons')
      ..addFont(fontBytes(iconFont.path));
    await icons.load();
  }
}

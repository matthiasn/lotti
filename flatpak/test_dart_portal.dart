import 'dart:io';

void main() async {
  print('=== Dart Portal Detection Test ===');
  print('');

  // Check environment variables
  print('Environment variables:');
  print('  FLATPAK_ID: ${Platform.environment['FLATPAK_ID'] ?? 'not set'}');
  print('  FLATPAK_DEST: ${Platform.environment['FLATPAK_DEST'] ?? 'not set'}');
  print('  container: ${Platform.environment['container'] ?? 'not set'}');
  print('');

  // Check directories
  print('Directory checks:');
  print('  /app exists: ${Directory('/app').existsSync()}');
  print('  /var/run/host exists: ${Directory('/var/run/host').existsSync()}');
  print('');

  // Simulate portal detection logic
  bool isRunningInFlatpak = false;

  final flatpakId = Platform.environment['FLATPAK_ID'];
  if (flatpakId != null && flatpakId.isNotEmpty) {
    print('✓ Detected via FLATPAK_ID: $flatpakId');
    isRunningInFlatpak = true;
  }

  final containerValue = Platform.environment['container'];
  if (containerValue == 'flatpak') {
    print('✓ Detected via container=flatpak');
    isRunningInFlatpak = true;
  }

  if (Directory('/app').existsSync() && Directory('/var/run/host').existsSync()) {
    print('✓ Detected via Flatpak directories');
    isRunningInFlatpak = true;
  }

  print('');
  print('Result: isRunningInFlatpak = $isRunningInFlatpak');
  print('shouldUsePortal = $isRunningInFlatpak');
}
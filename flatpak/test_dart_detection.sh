#!/bin/bash

echo "=== Testing Dart Portal Detection in Flatpak ==="
echo ""

# Create a temporary Dart test file
cat > /tmp/test_portal_detection.dart << 'EOF'
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

  // Simulate portal detection logic from portal_service.dart
  bool isRunningInFlatpak = false;

  final flatpakId = Platform.environment['FLATPAK_ID'];
  if (flatpakId != null && flatpakId.isNotEmpty) {
    print('✓ Detected via FLATPAK_ID: $flatpakId');
    isRunningInFlatpak = true;
  }

  final flatpakDest = Platform.environment['FLATPAK_DEST'];
  if (flatpakDest != null && flatpakDest.isNotEmpty) {
    print('✓ Detected via FLATPAK_DEST: $flatpakDest');
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
EOF

echo "Test 1: Running Dart detection test outside Flatpak"
echo "----------------------------------------------------"
dart /tmp/test_portal_detection.dart 2>/dev/null || echo "Dart not available on host"

echo ""
echo "Test 2: Running Dart detection test inside Flatpak"
echo "---------------------------------------------------"
# Copy the test file into Flatpak and run it
flatpak run --command=bash com.matthiasn.lotti -c "cat > /tmp/test.dart && dart /tmp/test.dart 2>/dev/null || echo 'Dart runtime not available in Flatpak (this is expected)'" < /tmp/test_portal_detection.dart

echo ""
echo "Test 3: Simulating detection with shell script inside Flatpak"
echo "-------------------------------------------------------------"
flatpak run --command=bash com.matthiasn.lotti -c '
echo "Environment check in Flatpak:"
echo "  FLATPAK_ID=$FLATPAK_ID"
echo "  container=$container"
echo "  /app exists: $(test -d /app && echo yes || echo no)"
echo "  /var/run/host exists: $(test -d /var/run/host && echo yes || echo no)"
echo ""
echo "Based on these values, the Dart code SHOULD detect Flatpak environment."
'

echo ""
echo "=== Test Complete ==="
echo ""
echo "If the app is not using the portal, check:"
echo "1. That the portal detection code is being called"
echo "2. That the portal service initialization succeeds"
echo "3. That the D-Bus connection can be established"
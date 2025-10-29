import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/model/sync_message.dart';

void main() {
  group('SyncMessage.themingSelection', () {
    test('serializes to JSON correctly', () {
      const message = SyncMessage.themingSelection(
        lightThemeName: 'Indigo',
        darkThemeName: 'Shark',
        themeMode: 'dark',
        updatedAt: 1234567890,
        status: SyncEntryStatus.update,
      );

      final json = message.toJson();

      expect(json['runtimeType'], 'themingSelection');
      expect(json['lightThemeName'], 'Indigo');
      expect(json['darkThemeName'], 'Shark');
      expect(json['themeMode'], 'dark');
      expect(json['updatedAt'], 1234567890);
      expect(json['status'], 'update');
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'runtimeType': 'themingSelection',
        'lightThemeName': 'Indigo',
        'darkThemeName': 'Shark',
        'themeMode': 'dark',
        'updatedAt': 1234567890,
        'status': 'update',
      };

      final message = SyncMessage.fromJson(json) as SyncThemingSelection;

      expect(message.lightThemeName, 'Indigo');
      expect(message.darkThemeName, 'Shark');
      expect(message.themeMode, 'dark');
      expect(message.updatedAt, 1234567890);
      expect(message.status, SyncEntryStatus.update);
    });

    test('round-trip preserves all fields', () {
      const original = SyncMessage.themingSelection(
        lightThemeName: 'Indigo',
        darkThemeName: 'Shark',
        themeMode: 'light',
        updatedAt: 9876543210,
        status: SyncEntryStatus.initial,
      ) as SyncThemingSelection;

      final json = original.toJson();
      final decoded = SyncMessage.fromJson(json) as SyncThemingSelection;

      expect(decoded.lightThemeName, original.lightThemeName);
      expect(decoded.darkThemeName, original.darkThemeName);
      expect(decoded.themeMode, original.themeMode);
      expect(decoded.updatedAt, original.updatedAt);
      expect(decoded.status, original.status);
    });

    test('handles extra JSON fields gracefully', () {
      final json = {
        'runtimeType': 'themingSelection',
        'lightThemeName': 'Indigo',
        'darkThemeName': 'Shark',
        'themeMode': 'dark',
        'updatedAt': 1234567890,
        'status': 'update',
        'extraField': 'should be ignored',
      };

      final message = SyncMessage.fromJson(json) as SyncThemingSelection;

      expect(message.lightThemeName, 'Indigo');
      expect(message.darkThemeName, 'Shark');
    });
  });
}

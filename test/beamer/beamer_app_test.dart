import 'package:flutter_test/flutter_test.dart';

/// Helper function that mimics the index clamping logic in AppScreen
int calculateClampedIndex({
  required int rawIndex,
  required bool isCalendarEnabled,
  required bool isHabitsEnabled,
  required bool isDashboardsEnabled,
}) {
  // Calculate the number of navigation items based on enabled flags
  final navItems = [
    true, // Tasks
    isCalendarEnabled, // Calendar
    isHabitsEnabled, // Habits
    isDashboardsEnabled, // Dashboards
    true, // Journal
    true, // Settings
  ];
  final itemCount = navItems.where((isEnabled) => isEnabled).length;

  // Clamp index to valid range to prevent out of bounds errors
  return rawIndex.clamp(0, itemCount - 1);
}

void main() {
  group('Navigation Index Clamping Logic Tests - ', () {
    test('clamps index when all flags are disabled and index is high', () {
      // All flags disabled: [Tasks(0), Journal(1), Settings(2)]
      // Original index 5 (Settings when all flags enabled)
      final clampedIndex = calculateClampedIndex(
        rawIndex: 5,
        isCalendarEnabled: false,
        isHabitsEnabled: false,
        isDashboardsEnabled: false,
      );

      // Should clamp from 5 to 2 (max valid index)
      expect(clampedIndex, 2);
    });

    test('does not clamp index when within bounds', () {
      // All flags enabled: [Tasks(0), Calendar(1), Habits(2), Dashboards(3), Journal(4), Settings(5)]
      final clampedIndex = calculateClampedIndex(
        rawIndex: 3,
        isCalendarEnabled: true,
        isHabitsEnabled: true,
        isDashboardsEnabled: true,
      );

      // Index 3 is valid, should not change
      expect(clampedIndex, 3);
    });

    test('clamps index when calendar flag is toggled off', () {
      // Calendar disabled: [Tasks(0), Habits(1), Dashboards(2), Journal(3), Settings(4)]
      // If user was on Settings (5) when all enabled
      final clampedIndex = calculateClampedIndex(
        rawIndex: 5,
        isCalendarEnabled: false,
        isHabitsEnabled: true,
        isDashboardsEnabled: true,
      );

      // Should clamp from 5 to 4 (max valid index)
      expect(clampedIndex, 4);
    });

    test('handles zero index correctly', () {
      // Index 0 (Tasks) should always be valid
      final clampedIndex = calculateClampedIndex(
        rawIndex: 0,
        isCalendarEnabled: false,
        isHabitsEnabled: false,
        isDashboardsEnabled: false,
      );

      expect(clampedIndex, 0);
    });

    test('clamps negative index to zero', () {
      final clampedIndex = calculateClampedIndex(
        rawIndex: -1,
        isCalendarEnabled: true,
        isHabitsEnabled: true,
        isDashboardsEnabled: true,
      );

      expect(clampedIndex, 0);
    });

    test('handles sequential flag toggles correctly', () {
      // Start with all flags enabled, index at Settings (5)
      var clampedIndex = calculateClampedIndex(
        rawIndex: 5,
        isCalendarEnabled: true,
        isHabitsEnabled: true,
        isDashboardsEnabled: true,
      );
      expect(clampedIndex, 5); // Valid

      // Toggle off calendar
      clampedIndex = calculateClampedIndex(
        rawIndex: 5,
        isCalendarEnabled: false,
        isHabitsEnabled: true,
        isDashboardsEnabled: true,
      );
      expect(clampedIndex, 4); // Clamped

      // Toggle off habits
      clampedIndex = calculateClampedIndex(
        rawIndex: 5,
        isCalendarEnabled: false,
        isHabitsEnabled: false,
        isDashboardsEnabled: true,
      );
      expect(clampedIndex, 3); // Clamped further

      // Toggle off dashboards
      clampedIndex = calculateClampedIndex(
        rawIndex: 5,
        isCalendarEnabled: false,
        isHabitsEnabled: false,
        isDashboardsEnabled: false,
      );
      expect(clampedIndex, 2); // Clamped to max
    });

    test('calculates correct item count with different flag combinations', () {
      // All enabled: Tasks, Calendar, Habits, Dashboards, Journal, Settings = 6
      expect(
        calculateClampedIndex(
          rawIndex: 100,
          isCalendarEnabled: true,
          isHabitsEnabled: true,
          isDashboardsEnabled: true,
        ),
        5,
      ); // Max index is 5

      // Only calendar enabled: Tasks, Calendar, Journal, Settings = 4
      expect(
        calculateClampedIndex(
          rawIndex: 100,
          isCalendarEnabled: true,
          isHabitsEnabled: false,
          isDashboardsEnabled: false,
        ),
        3,
      ); // Max index is 3

      // None enabled: Tasks, Journal, Settings = 3
      expect(
        calculateClampedIndex(
          rawIndex: 100,
          isCalendarEnabled: false,
          isHabitsEnabled: false,
          isDashboardsEnabled: false,
        ),
        2,
      ); // Max index is 2
    });
  });
}

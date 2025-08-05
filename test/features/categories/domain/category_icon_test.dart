import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

void main() {
  group('CategoryIcon', () {
    group('iconData', () {
      test('should return correct IconData for all enum values', () {
        // Verify that all enum values have corresponding IconData
        for (final icon in CategoryIcon.values) {
          expect(icon.iconData, isA<IconData>());
        }
      });

      test('should return specific icons for known values', () {
        expect(CategoryIcon.fitness.iconData, equals(Icons.fitness_center));
        expect(CategoryIcon.running.iconData, equals(Icons.directions_run));
        expect(CategoryIcon.yoga.iconData, equals(MdiIcons.yoga));
        expect(CategoryIcon.home.iconData, equals(Icons.home));
        expect(CategoryIcon.reading.iconData, equals(Icons.menu_book));
      });
    });

    group('displayName', () {
      test('should return human-readable names for all enum values', () {
        // Verify that all enum values have display names
        for (final icon in CategoryIcon.values) {
          expect(icon.displayName, isNotEmpty);
          expect(icon.displayName, isA<String>());
        }
      });

      test('should return specific display names for known values', () {
        expect(CategoryIcon.fitness.displayName, equals('Fitness'));
        expect(CategoryIcon.heartHealth.displayName, equals('Heart Health'));
        expect(CategoryIcon.laptop.displayName, equals('Computer Work'));
        expect(CategoryIcon.mentalHealth.displayName, equals('Mental Health'));
      });

      test('should have unique display names', () {
        final displayNames = CategoryIcon.values.map((e) => e.displayName).toSet();
        expect(displayNames.length, equals(CategoryIcon.values.length));
      });
    });

    group('suggestFromName', () {
      test('should return null for null input', () {
        expect(CategoryIconExtension.suggestFromName(null), isNull);
      });

      test('should return null for empty input', () {
        expect(CategoryIconExtension.suggestFromName(''), isNull);
        expect(CategoryIconExtension.suggestFromName('   '), isNull);
      });

      test('should find exact enum name matches', () {
        expect(CategoryIconExtension.suggestFromName('fitness'), equals(CategoryIcon.fitness));
        expect(CategoryIconExtension.suggestFromName('running'), equals(CategoryIcon.running));
        expect(CategoryIconExtension.suggestFromName('yoga'), equals(CategoryIcon.yoga));
      });

      test('should be case insensitive for enum names', () {
        expect(CategoryIconExtension.suggestFromName('FITNESS'), equals(CategoryIcon.fitness));
        expect(CategoryIconExtension.suggestFromName('Running'), equals(CategoryIcon.running));
        expect(CategoryIconExtension.suggestFromName('YOGA'), equals(CategoryIcon.yoga));
      });

      test('should find word-boundary matches in display names', () {
        expect(CategoryIconExtension.suggestFromName('Heart'), equals(CategoryIcon.heartHealth));
        expect(CategoryIconExtension.suggestFromName('Computer'), equals(CategoryIcon.computer));
        expect(CategoryIconExtension.suggestFromName('Health'), equals(CategoryIcon.heartHealth));
      });

      test('should not match partial words incorrectly', () {
        // This test ensures we fixed the bug where "art" would match "Heart Health"
        expect(CategoryIconExtension.suggestFromName('art'), equals(CategoryIcon.art));
        expect(CategoryIconExtension.suggestFromName('art'), isNot(equals(CategoryIcon.heartHealth)));
        
        // Other examples of avoiding false matches
        expect(CategoryIconExtension.suggestFromName('men'), isNot(equals(CategoryIcon.mentalHealth)));
        expect(CategoryIconExtension.suggestFromName('car'), equals(CategoryIcon.car));
        expect(CategoryIconExtension.suggestFromName('car'), isNot(equals(CategoryIcon.medical))); // "care" partial match
      });

      test('should match complete words and reasonable prefixes', () {
        // Complete word matches
        expect(CategoryIconExtension.suggestFromName('mental'), equals(CategoryIcon.mentalHealth));
        expect(CategoryIconExtension.suggestFromName('heart'), equals(CategoryIcon.heartHealth));
        
        // Reasonable prefix matches (4+ characters and at least 60% of target word)
        expect(CategoryIconExtension.suggestFromName('men'), isNull); // Too short, should not match "mental"
        expect(CategoryIconExtension.suggestFromName('ment'), equals(CategoryIcon.mentalHealth)); // Should match "mental" (4 chars, 67% of "mental")
        expect(CategoryIconExtension.suggestFromName('heal'), equals(CategoryIcon.heartHealth)); // Should match "health" (4 chars, 67% of "health")
      });

      test('should find keyword mappings', () {
        expect(CategoryIconExtension.suggestFromName('gym'), equals(CategoryIcon.fitness));
        expect(CategoryIconExtension.suggestFromName('exercise'), equals(CategoryIcon.fitness));
        expect(CategoryIconExtension.suggestFromName('doctor'), equals(CategoryIcon.medical));
        expect(CategoryIconExtension.suggestFromName('book'), equals(CategoryIcon.reading));
        expect(CategoryIconExtension.suggestFromName('diary'), equals(CategoryIcon.journal));
      });

      test('should handle whitespace in input', () {
        expect(CategoryIconExtension.suggestFromName('  gym  '), equals(CategoryIcon.fitness));
        expect(CategoryIconExtension.suggestFromName('\tfitness\n'), equals(CategoryIcon.fitness));
      });

      test('should return null for unknown input', () {
        expect(CategoryIconExtension.suggestFromName('unknown_category'), isNull);
        expect(CategoryIconExtension.suggestFromName('xyz123'), isNull);
      });

      test('should prioritize exact matches over partial matches', () {
        // If there's both an exact enum name match and a partial display name match,
        // it should return the exact match
        expect(CategoryIconExtension.suggestFromName('work'), equals(CategoryIcon.work));
      });

      test('should prioritize exact display name matches over word matches', () {
        // Test that exact display name matches are found before word-boundary matches
        // This ensures "Work" matches CategoryIcon.work (display: "Work") 
        // before any other icons that might contain "work" as a word
        expect(CategoryIconExtension.suggestFromName('Work'), equals(CategoryIcon.work));
        expect(CategoryIconExtension.suggestFromName('Art'), equals(CategoryIcon.art));
        expect(CategoryIconExtension.suggestFromName('Music'), equals(CategoryIcon.music));
      });
    });

    group('JSON serialization', () {
      test('toJson should return enum name', () {
        expect(CategoryIcon.fitness.toJson(), equals('fitness'));
        expect(CategoryIcon.heartHealth.toJson(), equals('heartHealth'));
        expect(CategoryIcon.mentalHealth.toJson(), equals('mentalHealth'));
      });

      test('fromJson should parse valid enum names', () {
        expect(CategoryIconExtension.fromJson('fitness'), equals(CategoryIcon.fitness));
        expect(CategoryIconExtension.fromJson('heartHealth'), equals(CategoryIcon.heartHealth));
        expect(CategoryIconExtension.fromJson('mentalHealth'), equals(CategoryIcon.mentalHealth));
      });

      test('fromJson should return null for null input', () {
        expect(CategoryIconExtension.fromJson(null), isNull);
      });

      test('fromJson should return null for empty input', () {
        expect(CategoryIconExtension.fromJson(''), isNull);
        expect(CategoryIconExtension.fromJson('   '), isNull);
      });

      test('fromJson should return null for invalid input', () {
        expect(CategoryIconExtension.fromJson('invalid_icon'), isNull);
        expect(CategoryIconExtension.fromJson('xyz123'), isNull);
      });

      test('fromJson should handle whitespace', () {
        expect(CategoryIconExtension.fromJson('  fitness  '), equals(CategoryIcon.fitness));
        expect(CategoryIconExtension.fromJson('\theartHealth\n'), equals(CategoryIcon.heartHealth));
      });

      test('roundtrip serialization should work', () {
        for (final icon in CategoryIcon.values) {
          final json = icon.toJson();
          final restored = CategoryIconExtension.fromJson(json);
          expect(restored, equals(icon));
        }
      });
    });
  });

  group('CategoryIconConstants', () {
    test('should have reasonable default values', () {
      expect(CategoryIconConstants.defaultIconSize, greaterThan(0));
      expect(CategoryIconConstants.iconSizeMultiplier, greaterThan(0));
      expect(CategoryIconConstants.iconSizeMultiplier, lessThan(1));
      expect(CategoryIconConstants.textSizeMultiplier, greaterThan(0));
      expect(CategoryIconConstants.textSizeMultiplier, lessThan(1));
      expect(CategoryIconConstants.borderWidth, greaterThan(0));
      expect(CategoryIconConstants.pickerGridColumns, greaterThan(0));
      expect(CategoryIconConstants.pickerMaxWidth, greaterThan(0));
    });

    test('should have alpha values in valid range', () {
      expect(CategoryIconConstants.selectedBackgroundAlpha, greaterThanOrEqualTo(0));
      expect(CategoryIconConstants.selectedBackgroundAlpha, lessThanOrEqualTo(1));
    });
  });

  group('CategoryIconStrings', () {
    test('should have non-empty string constants', () {
      expect(CategoryIconStrings.fallbackCharacter, isNotEmpty);
      expect(CategoryIconStrings.chooseIconTitle, isNotEmpty);
      expect(CategoryIconStrings.iconLabel, isNotEmpty);
      expect(CategoryIconStrings.iconSelectionHint, isNotEmpty);
      expect(CategoryIconStrings.createModeIconHint, isNotEmpty);
      expect(CategoryIconStrings.chooseIconText, isNotEmpty);
      expect(CategoryIconStrings.invalidIconWarning, isNotEmpty);
    });

    test('fallback character should be a single character', () {
      expect(CategoryIconStrings.fallbackCharacter.length, equals(1));
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:lotti/services/dev_logger.dart';

part 'category_icon_data.dart';
part 'category_icon_names.dart';

/// Constants for CategoryIcon functionality.
///
/// This class provides reusable constants for sizing, spacing, and configuration
/// of category icon-related widgets to ensure consistent styling throughout the app.
class CategoryIconConstants {
  CategoryIconConstants._(); // Private constructor to prevent instantiation

  /// Default icon size multiplier for category display
  static const double iconSizeMultiplier = 0.56;

  /// Default text size multiplier for category display
  static const double textSizeMultiplier = 0.4;

  /// Default border width for category icon display
  static const double borderWidth = 2;

  /// Default icon size for icon picker grid
  static const double pickerIconSize = 28;

  /// Number of columns in icon picker grid
  static const int pickerGridColumns = 4;

  /// Spacing between grid items
  static const double pickerGridSpacing = 12;

  /// Icon picker dialog max width
  static const double pickerMaxWidth = 400;

  /// Icon picker text size
  static const double pickerTextSize = 10;

  /// Default category icon display size
  static const double defaultIconSize = 43.2;

  /// Icon sizes for different contexts - Single source of truth
  /// Large icons for prominent displays (category details, large cards)
  static const double iconSizeLarge = 38.4;

  /// Medium icons for list items, cards with text (task definition)
  static const double iconSizeMedium = 35.2;

  /// Small icons for compact lists, inline displays (journal entries)
  static const double iconSizeSmall = 24;

  /// Extra small icons for dense interfaces
  static const double iconSizeExtraSmall = 16;

  /// Alpha values and other constants
  static const double selectedBackgroundAlpha = 0.15;
  static const double fallbackIconAlpha = 51;
  static const double fallbackIconSizeMultiplier = 0.6;
  static const double luminanceThreshold = 0.5;

  /// Border width in picker (same for selected and unselected to prevent breathing)
  static const double pickerBorderWidth = 2;

  /// Default padding for icon picker
  static const double pickerPadding = 16;

  /// Spacing between icon and text in picker
  static const double iconTextSpacing = 4;

  /// Modal and UI layout constants
  /// Maximum height ratio for create modal
  static const double modalMaxHeightRatio = 0.85;

  /// Standard border radius for UI elements
  static const double borderRadius = 12;

  /// Small border radius for color picker
  static const double colorPickerBorderRadius = 10;

  /// Upper clamp on the `flutter_colorpicker` saturation/value square
  /// — matches the package's own default (`colorPickerWidth = 300`) so
  /// wide modals don't get a disproportionately huge picker. There is
  /// no lower clamp on purpose: with `portraitOnly: true` the whole
  /// picker is exactly this wide, so enforcing a minimum bigger than
  /// the available width would just re-introduce horizontal overflow
  /// on extremely narrow surfaces (split-views, narrow test rigs).
  static const double colorPickerMaxSquareWidth = 300;

  /// Standard section spacing
  static const double sectionSpacing = 16;

  /// Small section spacing (also used for button spacing)
  static const double smallSectionSpacing = 8;

  /// Icon preview size in forms
  static const double iconPreviewSize = iconSizeMedium;

  /// Standard icon size for buttons and UI elements
  static const double standardIconSize = 28;

  /// Small arrow icon size
  static const double arrowIconSize = 16;
}

/// String constants for CategoryIcon functionality.
///
/// This class provides reusable string constants to avoid hardcoded strings
/// throughout the category icon implementation, improving maintainability and localization.
/// Non-localizable string constants for category icons. All user-visible
/// icon-picker copy lives in the l10n catalog (`categoryIcon*` keys).
class CategoryIconStrings {
  CategoryIconStrings._(); // Private constructor to prevent instantiation

  /// Default fallback character when category name is empty
  static const String fallbackCharacter = '?';

  /// Warning message prefix for invalid icon names (log output)
  static const String invalidIconWarning =
      'Warning: Invalid CategoryIcon name: ';
}

/// Enum representing all available category icons in Lotti.
///
/// These icons cover the main use cases for life tracking, habits, and tasks.
/// Each enum value maps to a specific Material Design icon and has a human-readable
/// display name for use in the UI.
///
/// The icons are organized into logical groups:
/// - Health & Wellness: fitness, medical, nutrition, etc.
/// - Work & Productivity: tasks, meetings, work-related activities
/// - Personal Development: learning, reading, social activities
/// - Utility & Tracking: money, travel, technology-related
enum CategoryIcon {
  // Health & Wellness
  fitness,
  running,
  swimming,
  yoga,
  nutrition,
  water,
  dining,
  medical,
  medication,
  heartHealth,
  heartPulse,
  sleep,
  bedtime,
  mood,
  mindfulness,
  mentalHealth,

  // Work & Productivity
  checklist,
  assignment,
  clipboard,
  work,
  meeting,
  laptop,
  home,
  cleaning,
  chores,
  shopping,
  groceries,
  store,
  commute,
  car,
  transit,

  // Personal Development
  reading,
  writing,
  journal,
  school,
  brain,
  learning,
  people,
  relationships,
  social,
  baby,
  gaming,
  music,
  art,
  photography,

  // Utility & Tracking
  wallet,
  money,
  savings,
  location,
  travel,
  airplane,
  schedule,
  calendar,
  timer,
  phone,
  computer,
  connectivity,

  // Nature & Outdoors
  cycling,
  hiking,
  camping,
  pets,
  garden,

  // Food & Drink
  cooking,
  coffee,

  // Communication
  email,
  chat,
  videoCall,

  // Entertainment
  movie,
  podcast,
  theater,

  // Creative & Skills
  coding,
  crafts,
  dance,

  // Household & Maintenance
  laundry,
  repair,

  // Finance & Career
  banking,
  investment,
  receipt,

  // Events & Celebrations
  celebration,
  gift,
  cake,

  // Education & Knowledge
  language,
  science,
  presentation,

  // Spiritual & Well-being
  prayer,
  gratitude,

  // Self-care & Wellness
  spa,
  stretching,

  // Weather & Nature
  weather,
  nature,

  // Volunteering
  volunteer,
  recycling,
}

/// Extension to map CategoryIcon enum values to their corresponding IconData
extension CategoryIconExtension on CategoryIcon {
  /// Static map for O(1) lookup of CategoryIcon by name
  /// Initialized once to avoid repeated iteration through enum values
  static final Map<String, CategoryIcon> _byName = Map.fromEntries(
    CategoryIcon.values.map((e) => MapEntry(e.name, e)),
  );

  IconData get iconData => categoryIconData[this]!;

  /// Human-readable display name for the icon
  String get displayName => categoryIconDisplayNames[this]!;

  /// Returns a suggested icon based on category name
  /// Returns null if [categoryName] is null, empty, or no match is found
  static CategoryIcon? suggestFromName(String? categoryName) {
    if (categoryName == null || categoryName.trim().isEmpty) {
      return null;
    }
    final lowercaseName = categoryName.trim().toLowerCase();

    // Check for exact matches first
    for (final icon in CategoryIcon.values) {
      if (icon.name.toLowerCase() == lowercaseName) {
        return icon;
      }
    }

    // Check for exact display name match
    for (final icon in CategoryIcon.values) {
      if (icon.displayName.toLowerCase() == lowercaseName) {
        return icon;
      }
    }

    // Check for word-boundary matches in display names
    final nameWords = lowercaseName.split(RegExp(r'\s+'));
    for (final icon in CategoryIcon.values) {
      final displayWords = icon.displayName.toLowerCase().split(RegExp(r'\s+'));

      // Check if any complete word from the category name matches any complete word from the display name
      for (final nameWord in nameWords) {
        if (nameWord.isNotEmpty) {
          for (final displayWord in displayWords) {
            // Exact word match
            if (displayWord == nameWord) {
              return icon;
            }
            // Prefix match: require at least 4 characters and must be at least 60% of the target word
            if (nameWord.length >= 4 &&
                displayWord.startsWith(nameWord) &&
                nameWord.length >= (displayWord.length * 0.6)) {
              return icon;
            }
            if (displayWord.length >= 4 &&
                nameWord.startsWith(displayWord) &&
                displayWord.length >= (nameWord.length * 0.6)) {
              return icon;
            }
          }
        }
      }
    }

    // Common keyword mappings
    final keywordMappings = {
      'gym': CategoryIcon.fitness,
      'exercise': CategoryIcon.fitness,
      'run': CategoryIcon.running,
      'jog': CategoryIcon.running,
      'swim': CategoryIcon.swimming,
      'food': CategoryIcon.nutrition,
      'eat': CategoryIcon.dining,
      'meal': CategoryIcon.dining,
      'doctor': CategoryIcon.medical,
      'health': CategoryIcon.heartHealth,
      'pills': CategoryIcon.medication,
      'medicine': CategoryIcon.medication,
      'rest': CategoryIcon.sleep,
      'nap': CategoryIcon.sleep,
      'happy': CategoryIcon.mood,
      'sad': CategoryIcon.mood,
      'meditation': CategoryIcon.mindfulness,
      'task': CategoryIcon.checklist,
      'todo': CategoryIcon.checklist,
      'project': CategoryIcon.assignment,
      'office': CategoryIcon.work,
      'job': CategoryIcon.work,
      'house': CategoryIcon.home,
      'clean': CategoryIcon.cleaning,
      'shop': CategoryIcon.shopping,
      'buy': CategoryIcon.shopping,
      'drive': CategoryIcon.car,
      'bus': CategoryIcon.transit,
      'train': CategoryIcon.transit,
      'book': CategoryIcon.reading,
      'read': CategoryIcon.reading,
      'write': CategoryIcon.writing,
      'diary': CategoryIcon.journal,
      'study': CategoryIcon.learning,
      'learn': CategoryIcon.learning,
      'friend': CategoryIcon.relationships,
      'family': CategoryIcon.relationships,
      'baby': CategoryIcon.baby,
      'child': CategoryIcon.baby,
      'kid': CategoryIcon.baby,
      'nursing': CategoryIcon.baby,
      'infant': CategoryIcon.baby,
      'toddler': CategoryIcon.baby,
      'game': CategoryIcon.gaming,
      'play': CategoryIcon.gaming,
      'sing': CategoryIcon.music,
      'draw': CategoryIcon.art,
      'paint': CategoryIcon.art,
      'photo': CategoryIcon.photography,
      'finance': CategoryIcon.money,
      'budget': CategoryIcon.wallet,
      'save': CategoryIcon.savings,
      'trip': CategoryIcon.travel,
      'vacation': CategoryIcon.travel,
      'fly': CategoryIcon.airplane,
      'time': CategoryIcon.schedule,
      'date': CategoryIcon.calendar,
      'mobile': CategoryIcon.phone,
      'pc': CategoryIcon.computer,
      'internet': CategoryIcon.connectivity,
      'wifi': CategoryIcon.connectivity,
      'bike': CategoryIcon.cycling,
      'cycle': CategoryIcon.cycling,
      'bicycle': CategoryIcon.cycling,
      'hike': CategoryIcon.hiking,
      'trail': CategoryIcon.hiking,
      'trek': CategoryIcon.hiking,
      'camp': CategoryIcon.camping,
      'tent': CategoryIcon.camping,
      'pet': CategoryIcon.pets,
      'dog': CategoryIcon.pets,
      'cat': CategoryIcon.pets,
      'animal': CategoryIcon.pets,
      'plant': CategoryIcon.garden,
      'flower': CategoryIcon.garden,
      'cook': CategoryIcon.cooking,
      'kitchen': CategoryIcon.cooking,
      'recipe': CategoryIcon.cooking,
      'bake': CategoryIcon.cooking,
      'coffee': CategoryIcon.coffee,
      'tea': CategoryIcon.coffee,
      'cafe': CategoryIcon.coffee,
      'caffeine': CategoryIcon.coffee,
      'email': CategoryIcon.email,
      'mail': CategoryIcon.email,
      'chat': CategoryIcon.chat,
      'message': CategoryIcon.chat,
      'videocall': CategoryIcon.videoCall,
      'zoom': CategoryIcon.videoCall,
      'facetime': CategoryIcon.videoCall,
      'movie': CategoryIcon.movie,
      'film': CategoryIcon.movie,
      'cinema': CategoryIcon.movie,
      'television': CategoryIcon.movie,
      'podcast': CategoryIcon.podcast,
      'radio': CategoryIcon.podcast,
      'theater': CategoryIcon.theater,
      'theatre': CategoryIcon.theater,
      'drama': CategoryIcon.theater,
      'code': CategoryIcon.coding,
      'programming': CategoryIcon.coding,
      'developer': CategoryIcon.coding,
      'software': CategoryIcon.coding,
      'craft': CategoryIcon.crafts,
      'diy': CategoryIcon.crafts,
      'sewing': CategoryIcon.crafts,
      'knitting': CategoryIcon.crafts,
      'dance': CategoryIcon.dance,
      'dancing': CategoryIcon.dance,
      'ballet': CategoryIcon.dance,
      'laundry': CategoryIcon.laundry,
      'wash': CategoryIcon.laundry,
      'repair': CategoryIcon.repair,
      'maintenance': CategoryIcon.repair,
      'bank': CategoryIcon.banking,
      'invest': CategoryIcon.investment,
      'stocks': CategoryIcon.investment,
      'portfolio': CategoryIcon.investment,
      'trading': CategoryIcon.investment,
      'receipt': CategoryIcon.receipt,
      'expense': CategoryIcon.receipt,
      'invoice': CategoryIcon.receipt,
      'bill': CategoryIcon.receipt,
      'party': CategoryIcon.celebration,
      'celebrate': CategoryIcon.celebration,
      'present': CategoryIcon.gift,
      'cake': CategoryIcon.cake,
      'anniversary': CategoryIcon.cake,
      'translate': CategoryIcon.language,
      'foreign': CategoryIcon.language,
      'science': CategoryIcon.science,
      'experiment': CategoryIcon.science,
      'lab': CategoryIcon.science,
      'chemistry': CategoryIcon.science,
      'slides': CategoryIcon.presentation,
      'lecture': CategoryIcon.presentation,
      'conference': CategoryIcon.presentation,
      'pray': CategoryIcon.prayer,
      'church': CategoryIcon.prayer,
      'worship': CategoryIcon.prayer,
      'spiritual': CategoryIcon.prayer,
      'faith': CategoryIcon.prayer,
      'thankful': CategoryIcon.gratitude,
      'grateful': CategoryIcon.gratitude,
      'blessing': CategoryIcon.gratitude,
      'spa': CategoryIcon.spa,
      'relax': CategoryIcon.spa,
      'pamper': CategoryIcon.spa,
      'skincare': CategoryIcon.spa,
      'beauty': CategoryIcon.spa,
      'stretch': CategoryIcon.stretching,
      'warmup': CategoryIcon.stretching,
      'flexibility': CategoryIcon.stretching,
      'sunny': CategoryIcon.weather,
      'rain': CategoryIcon.weather,
      'park': CategoryIcon.nature,
      'forest': CategoryIcon.nature,
      'tree': CategoryIcon.nature,
      'outdoors': CategoryIcon.nature,
      'volunteer': CategoryIcon.volunteer,
      'charity': CategoryIcon.volunteer,
      'donate': CategoryIcon.volunteer,
      'community': CategoryIcon.volunteer,
      'recycle': CategoryIcon.recycling,
      'eco': CategoryIcon.recycling,
      'green': CategoryIcon.recycling,
      'environment': CategoryIcon.recycling,
      'sustainability': CategoryIcon.recycling,
    };

    for (final entry in keywordMappings.entries) {
      // Use word boundary regex to avoid partial matches (e.g. "run" in "prune")
      final regex = RegExp(r'\b' + RegExp.escape(entry.key) + r'\b');
      if (regex.hasMatch(lowercaseName)) {
        return entry.value;
      }
    }

    return null;
  }

  /// Convert CategoryIcon to string for serialization
  String toJson() => name;

  /// Convert string to CategoryIcon for deserialization
  /// Returns null if [json] is null, empty, or not a valid CategoryIcon name
  /// Uses O(1) map lookup for efficient performance
  static CategoryIcon? fromJson(String? json) {
    if (json == null || json.trim().isEmpty) return null;

    final trimmedJson = json.trim();
    final icon = _byName[trimmedJson];

    if (icon == null) {
      // Log the error in debug mode for troubleshooting
      assert(() {
        DevLogger.warning(
          name: 'CategoryIcon',
          message: '${CategoryIconStrings.invalidIconWarning}"$trimmedJson"',
        );
        return true;
      }(), 'Invalid CategoryIcon name: "$trimmedJson"');
    }

    return icon;
  }
}

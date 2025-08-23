import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

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
  static const double selectedBackgroundAlpha = 0.1;
  static const double fallbackIconAlpha = 51;
  static const double fallbackIconSizeMultiplier = 0.6;
  static const double luminanceThreshold = 0.5;

  /// Selected border width in picker
  static const double selectedBorderWidth = 2;

  /// Unselected border width in picker
  static const double unselectedBorderWidth = 1;

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
class CategoryIconStrings {
  CategoryIconStrings._(); // Private constructor to prevent instantiation

  /// Default fallback character when category name is empty
  static const String fallbackCharacter = '?';

  /// Title for icon picker dialog
  static const String chooseIconTitle = 'Choose Icon';

  /// Label for icon section in forms
  static const String iconLabel = 'Icon';

  /// Instruction text for icon selection
  static const String iconSelectionHint = 'Tap to select a different icon';

  /// Instruction text for create mode icon selection
  static const String createModeIconHint = 'Tap to select an icon';

  /// Fallback text when no icon is selected
  static const String chooseIconText = 'Choose an icon';

  /// Warning message prefix for invalid icon names
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
}

/// Extension to map CategoryIcon enum values to their corresponding IconData
extension CategoryIconExtension on CategoryIcon {
  /// Static map for O(1) lookup of CategoryIcon by name
  /// Initialized once to avoid repeated iteration through enum values
  static final Map<String, CategoryIcon> _byName =
      Map.fromEntries(CategoryIcon.values.map((e) => MapEntry(e.name, e)));

  IconData get iconData {
    switch (this) {
      // Health & Wellness Icons
      case CategoryIcon.fitness:
        return Icons.fitness_center;
      case CategoryIcon.running:
        return Icons.directions_run;
      case CategoryIcon.swimming:
        return Icons.pool;
      case CategoryIcon.yoga:
        return MdiIcons.yoga;
      case CategoryIcon.nutrition:
        return Icons.restaurant;
      case CategoryIcon.water:
        return Icons.water_drop;
      case CategoryIcon.dining:
        return Icons.local_dining;
      case CategoryIcon.medical:
        return Icons.medical_services;
      case CategoryIcon.medication:
        return Icons.medication;
      case CategoryIcon.heartHealth:
        return Icons.favorite;
      case CategoryIcon.heartPulse:
        return MdiIcons.heartPulse;
      case CategoryIcon.sleep:
        return MdiIcons.sleep;
      case CategoryIcon.bedtime:
        return Icons.bedtime;
      case CategoryIcon.mood:
        return Icons.mood;
      case CategoryIcon.mindfulness:
        return Icons.self_improvement;
      case CategoryIcon.mentalHealth:
        return MdiIcons.headHeart;

      // Work & Productivity Icons
      case CategoryIcon.checklist:
        return Icons.checklist;
      case CategoryIcon.assignment:
        return Icons.assignment;
      case CategoryIcon.clipboard:
        return MdiIcons.clipboardCheck;
      case CategoryIcon.work:
        return Icons.work;
      case CategoryIcon.meeting:
        return Icons.meeting_room;
      case CategoryIcon.laptop:
        return Icons.laptop_mac;
      case CategoryIcon.home:
        return Icons.home;
      case CategoryIcon.cleaning:
        return Icons.cleaning_services;
      case CategoryIcon.chores:
        return MdiIcons.broom;
      case CategoryIcon.shopping:
        return Icons.shopping_cart;
      case CategoryIcon.groceries:
        return Icons.local_grocery_store;
      case CategoryIcon.store:
        return Icons.store;
      case CategoryIcon.commute:
        return Icons.commute;
      case CategoryIcon.car:
        return Icons.directions_car;
      case CategoryIcon.transit:
        return Icons.directions_transit;

      // Personal Development Icons
      case CategoryIcon.reading:
        return Icons.menu_book;
      case CategoryIcon.writing:
        return Icons.create;
      case CategoryIcon.journal:
        return Icons.book;
      case CategoryIcon.school:
        return Icons.school;
      case CategoryIcon.brain:
        return Icons.psychology;
      case CategoryIcon.learning:
        return MdiIcons.lightbulbOn;
      case CategoryIcon.people:
        return Icons.people;
      case CategoryIcon.relationships:
        return Icons.favorite;
      case CategoryIcon.social:
        return MdiIcons.accountGroup;
      case CategoryIcon.gaming:
        return Icons.games;
      case CategoryIcon.music:
        return Icons.music_note;
      case CategoryIcon.art:
        return Icons.palette;
      case CategoryIcon.photography:
        return MdiIcons.cameraOutline;
      case CategoryIcon.baby:
        return Icons.baby_changing_station;

      // Utility & Tracking Icons
      case CategoryIcon.wallet:
        return Icons.account_balance_wallet;
      case CategoryIcon.money:
        return Icons.attach_money;
      case CategoryIcon.savings:
        return MdiIcons.piggyBank;
      case CategoryIcon.location:
        return Icons.location_on;
      case CategoryIcon.travel:
        return Icons.travel_explore;
      case CategoryIcon.airplane:
        return MdiIcons.airplane;
      case CategoryIcon.schedule:
        return Icons.schedule;
      case CategoryIcon.calendar:
        return Icons.calendar_today;
      case CategoryIcon.timer:
        return Icons.timer;
      case CategoryIcon.phone:
        return Icons.smartphone;
      case CategoryIcon.computer:
        return Icons.computer;
      case CategoryIcon.connectivity:
        return MdiIcons.wifi;
    }
  }

  /// Human-readable display name for the icon
  String get displayName {
    switch (this) {
      case CategoryIcon.fitness:
        return 'Fitness';
      case CategoryIcon.running:
        return 'Running';
      case CategoryIcon.swimming:
        return 'Swimming';
      case CategoryIcon.yoga:
        return 'Yoga';
      case CategoryIcon.nutrition:
        return 'Nutrition';
      case CategoryIcon.water:
        return 'Water';
      case CategoryIcon.dining:
        return 'Dining';
      case CategoryIcon.medical:
        return 'Medical';
      case CategoryIcon.medication:
        return 'Medication';
      case CategoryIcon.heartHealth:
        return 'Heart Health';
      case CategoryIcon.heartPulse:
        return 'Heart Rate';
      case CategoryIcon.sleep:
        return 'Sleep';
      case CategoryIcon.bedtime:
        return 'Bedtime';
      case CategoryIcon.mood:
        return 'Mood';
      case CategoryIcon.mindfulness:
        return 'Mindfulness';
      case CategoryIcon.mentalHealth:
        return 'Mental Health';
      case CategoryIcon.checklist:
        return 'Checklist';
      case CategoryIcon.assignment:
        return 'Assignment';
      case CategoryIcon.clipboard:
        return 'Tasks';
      case CategoryIcon.work:
        return 'Work';
      case CategoryIcon.meeting:
        return 'Meeting';
      case CategoryIcon.laptop:
        return 'Computer Work';
      case CategoryIcon.home:
        return 'Home';
      case CategoryIcon.cleaning:
        return 'Cleaning';
      case CategoryIcon.chores:
        return 'Chores';
      case CategoryIcon.shopping:
        return 'Shopping';
      case CategoryIcon.groceries:
        return 'Groceries';
      case CategoryIcon.store:
        return 'Store';
      case CategoryIcon.commute:
        return 'Commute';
      case CategoryIcon.car:
        return 'Driving';
      case CategoryIcon.transit:
        return 'Public Transit';
      case CategoryIcon.reading:
        return 'Reading';
      case CategoryIcon.writing:
        return 'Writing';
      case CategoryIcon.journal:
        return 'Journal';
      case CategoryIcon.school:
        return 'Education';
      case CategoryIcon.brain:
        return 'Learning';
      case CategoryIcon.learning:
        return 'Study';
      case CategoryIcon.people:
        return 'Social';
      case CategoryIcon.relationships:
        return 'Relationships';
      case CategoryIcon.social:
        return 'Groups';
      case CategoryIcon.gaming:
        return 'Gaming';
      case CategoryIcon.music:
        return 'Music';
      case CategoryIcon.art:
        return 'Art';
      case CategoryIcon.photography:
        return 'Photography';
      case CategoryIcon.wallet:
        return 'Wallet';
      case CategoryIcon.money:
        return 'Money';
      case CategoryIcon.savings:
        return 'Savings';
      case CategoryIcon.location:
        return 'Location';
      case CategoryIcon.travel:
        return 'Travel';
      case CategoryIcon.airplane:
        return 'Flight';
      case CategoryIcon.schedule:
        return 'Schedule';
      case CategoryIcon.calendar:
        return 'Calendar';
      case CategoryIcon.timer:
        return 'Timer';
      case CategoryIcon.phone:
        return 'Phone';
      case CategoryIcon.computer:
        return 'Computer';
      case CategoryIcon.connectivity:
        return 'Internet';
      case CategoryIcon.baby:
        return 'Baby';
    }
  }

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
        debugPrint('${CategoryIconStrings.invalidIconWarning}"$trimmedJson"');
        return true;
      }(), 'Invalid CategoryIcon name: "$trimmedJson"');
    }

    return icon;
  }
}

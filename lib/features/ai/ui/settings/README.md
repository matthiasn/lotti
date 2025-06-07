# AI Settings Module

A comprehensive settings interface for managing AI configurations including inference providers, models, and prompts.

## Overview

The AI Settings module provides a unified interface for managing all AI-related configurations in the Lotti application. It replaces the previous scattered AI settings buried in advanced menus with a top-level, user-friendly interface.

## Architecture

### Design Principles

1. **Separation of Concerns**: UI, business logic, and state management are clearly separated
2. **Single Responsibility**: Each component has one clear responsibility
3. **Testability**: All components can be unit tested in isolation
4. **Type Safety**: Heavy use of sealed classes and generics for compile-time safety
5. **Documentation**: Comprehensive documentation for maintainability

### Module Structure

```
lib/features/ai/ui/settings/
├── ai_settings_page.dart                   # Main page component
├── ai_settings_filter_state.dart           # Filter state model
├── ai_settings_filter_service.dart         # Filtering business logic
├── ai_settings_navigation_service.dart     # Navigation logic
├── ai_config_card.dart                     # Reusable config card component
├── widgets/
│   ├── ai_settings_search_bar.dart         # Search input component
│   ├── ai_settings_tab_bar.dart            # Tab navigation component
│   ├── ai_settings_filter_chips.dart       # Filter UI components
│   └── ai_settings_config_list.dart        # Config list component
└── README.md                               # This documentation
```

## Components

### Core Components

#### `AiSettingsPage`
The main page component that orchestrates the entire AI settings interface.

**Responsibilities:**
- Managing tab state and transitions
- Coordinating filter state with UI
- Handling search query updates
- Delegating navigation to service

**Usage:**
```dart
// Navigate to AI Settings
context.beamToNamed('/settings/ai');

// Or push directly
Navigator.push(context, MaterialPageRoute(
  builder: (_) => const AiSettingsPage(),
));
```

#### `AiConfigCard`
A reusable card component for displaying AI configurations.

**Features:**
- Supports all AI config types (providers, models, prompts)
- Capability indicators for models
- Compact mode for dense layouts
- Consistent Material 3 design

**Usage:**
```dart
AiConfigCard(
  config: myAiConfig,
  showCapabilities: true,
  isCompact: false,
  onTap: () => navigateToEdit(config),
)
```

### State Management

#### `AiSettingsFilterState`
Immutable state model using Freezed for all filter criteria.

**Features:**
- Type-safe filter state
- Immutable updates with `copyWith`
- Helper methods for common operations
- Validation for tab-specific filters

**Usage:**
```dart
// Create initial state
final state = AiSettingsFilterState.initial();

// Update search query
final newState = state.copyWith(searchQuery: 'anthropic');

// Check if filters are active
if (state.hasActiveFilters) {
  // Show clear filters button
}
```

### Services

#### `AiSettingsFilterService`
Pure functions for filtering AI configurations.

**Benefits:**
- Easily unit testable
- No side effects
- Consistent filtering logic
- Performance optimized

**Usage:**
```dart
final service = AiSettingsFilterService();
final filtered = service.filterModels(allModels, filterState);
```

#### `AiSettingsNavigationService`
Centralized navigation logic for AI configuration editing.

**Features:**
- Type-safe navigation based on config type
- Consistent edit page routing
- Support for create vs edit modes
- Permission checking hooks

**Usage:**
```dart
final navigationService = AiSettingsNavigationService();
await navigationService.navigateToConfigEdit(context, config);
```

## Key Features

### 1. Unified Interface
- **Before**: AI settings scattered across 3 levels: Settings → Advanced → AI entries
- **After**: Top-level "AI Settings" in main settings menu

### 2. Advanced Filtering
- **Text Search**: Across all configuration names and descriptions
- **Provider Filtering**: Filter models by their inference provider
- **Capability Filtering**: Filter models by capabilities (vision, audio, reasoning)
- **Smart Filtering**: Filters are context-aware (only relevant filters shown per tab)

### 3. Tabbed Navigation
- **Providers Tab**: Manage AI inference providers (OpenAI, Anthropic, etc.)
- **Models Tab**: Manage AI models with advanced filtering options
- **Prompts Tab**: Manage AI prompts and templates

### 4. Direct Navigation
- **One-Click Access**: Click any configuration card to go directly to edit page
- **No Intermediate Steps**: Eliminates unnecessary list page navigation

## Usage Examples

### Basic Page Usage

```dart
import 'package:lotti/features/ai/ui/settings/ai_settings_page.dart';

// In your route configuration
BeamPage(
  key: const ValueKey('settings-ai'),
  title: 'AI Settings',
  child: const AiSettingsPage(),
),
```

### Custom Filtering

```dart
// Create custom filter state
final customFilter = AiSettingsFilterState(
  searchQuery: 'claude',
  selectedCapabilities: {Modality.image, Modality.audio},
  reasoningFilter: true,
);

// Apply filters
final service = AiSettingsFilterService();
final filteredModels = service.filterModels(allModels, customFilter);
```

### Navigation Integration

```dart
// Navigate to specific config edit page
final navigationService = AiSettingsNavigationService();

// Edit existing config
await navigationService.navigateToConfigEdit(context, existingConfig);

// Create new config
await navigationService.navigateToCreateProvider(context);
```

## Testing

### Unit Tests
All business logic is unit testable:

```dart
// Test filter service
test('filters models by capabilities', () {
  final service = AiSettingsFilterService();
  final filterState = AiSettingsFilterState(
    selectedCapabilities: {Modality.image},
  );
  
  final result = service.filterModels(testModels, filterState);
  
  expect(result.every((m) => m.inputModalities.contains(Modality.image)), isTrue);
});
```

### Widget Tests
UI components can be tested in isolation:

```dart
testWidgets('search bar shows clear button when text present', (tester) async {
  final controller = TextEditingController(text: 'test');
  
  await tester.pumpWidget(
    MaterialApp(
      home: AiSettingsSearchBar(controller: controller),
    ),
  );
  
  expect(find.byIcon(Icons.clear), findsOneWidget);
});
```

### Integration Tests
Full page functionality:

```dart
testWidgets('switches tabs and updates filters', (tester) async {
  await tester.pumpWidget(createTestApp());
  
  // Switch to models tab
  await tester.tap(find.text('Models'));
  await tester.pumpAndSettle();
  
  // Should show model-specific filters
  expect(find.text('Capabilities:'), findsOneWidget);
});
```

## Performance Considerations

### 1. Filtering Performance
- Filters are applied only when state changes
- Uses efficient `where()` operations on lists
- Debounced search to avoid excessive filtering

### 2. Memory Management
- Controllers are properly disposed
- State updates use immutable data structures
- No memory leaks in navigation

### 3. Rendering Performance
- ListView.separated for efficient scrolling
- Minimal rebuilds with proper state management
- Optimized search field updates

## Accessibility

### 1. Semantic Labels
- All interactive elements have semantic labels
- Screen reader friendly descriptions
- Proper focus management

### 2. Keyboard Navigation
- Tab order follows logical flow
- Search field supports keyboard navigation
- All actions accessible via keyboard

### 3. Color Accessibility
- High contrast color schemes
- No color-only information
- Proper focus indicators

## Migration Guide

### From Old AI Settings

The new AI Settings page replaces several old interfaces:

1. **Advanced Settings → AI Providers** → Now: AI Settings → Providers tab
2. **Advanced Settings → AI Models** → Now: AI Settings → Models tab  
3. **Advanced Settings → AI Prompts** → Now: AI Settings → Prompts tab

### Breaking Changes

- Navigation paths have changed (old paths still work but redirect)
- Some filter combinations may behave differently
- Edit page navigation is now direct (no intermediate list pages)

### Compatibility

- All existing AI configurations continue to work
- Data migration is not required
- Old navigation paths redirect to new interface

## Future Enhancements

### Planned Features

1. **Batch Operations**: Select and edit multiple configurations
2. **Import/Export**: Backup and restore AI configurations
3. **Configuration Validation**: Real-time validation of settings
4. **Usage Analytics**: Show which configs are most used
5. **Configuration Templates**: Quick setup for common scenarios

### Extension Points

The modular architecture allows easy extension:

- Add new filter types in `AiSettingsFilterService`
- Add new navigation targets in `AiSettingsNavigationService`
- Add new UI components in `widgets/` directory
- Extend filter state in `AiSettingsFilterState`

## Contributing

### Code Style

- Follow existing Dart/Flutter conventions
- Use comprehensive documentation comments
- Add unit tests for all business logic
- Add widget tests for UI components

### Adding New Features

1. Define requirements and design
2. Update relevant state models
3. Implement business logic in services
4. Create/update UI components
5. Add comprehensive tests
6. Update documentation

### Testing Requirements

- Unit tests for all services and utilities
- Widget tests for all UI components
- Integration tests for key user flows
- Accessibility testing for new components
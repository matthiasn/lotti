# AI Form Components

This directory contains a set of reusable form components specifically designed for the AI configuration pages in Lotti. These components provide a consistent, modern interface for all AI-related settings while maintaining a cohesive design language throughout the application.

## Why These Components Exist

1. **Consistency**: All AI configuration forms (providers, models, prompts) share the same visual language and behavior patterns
2. **Reusability**: Common form patterns are abstracted into components that can be used across different AI settings pages
3. **Modern Design**: Implements a clean, card-based design with proper spacing, shadows, and visual hierarchy
4. **Accessibility**: Ensures consistent keyboard navigation, screen reader support, and visual feedback
5. **Error Handling**: Provides standardized error display and validation feedback

## Component Overview

### Core Components

#### `AiFormSection`
A container component that groups related form fields together.

**Usage:**
```dart
AiFormSection(
  title: 'Basic Configuration',
  icon: Icons.settings_rounded,
  description: 'Configure your AI model settings',
  children: [
    // Form fields go here
  ],
)
```

**Features:**
- Card-based design with subtle shadow and border
- Icon and title header
- Optional description text
- Consistent padding and spacing

#### `AiTextField`
A styled text input field with built-in label, validation, and icon support.

**Usage:**
```dart
AiTextField(
  label: 'Display Name',
  hint: 'Enter a friendly name',
  controller: nameController,
  onChanged: (value) => handleNameChange(value),
  validator: (value) => validateName(value),
  prefixIcon: Icons.label_outline_rounded,
  suffixIcon: Icons.info_outline_rounded,
)
```

**Features:**
- Floating label design
- Optional prefix/suffix icons
- Built-in validation with error display
- Support for single/multi-line input
- Password/obscure text support
- Read-only mode for display fields

#### `AiSwitchField`
A toggle switch with label and description.

**Usage:**
```dart
AiSwitchField(
  label: 'Reasoning Mode',
  description: 'Enable for prompts requiring deep thinking',
  value: useReasoning,
  onChanged: (value) => handleReasoningChange(value),
  icon: Icons.psychology_rounded,
)
```

#### `AiDropdownField`
A dropdown selection field with consistent styling.

**Usage:**
```dart
AiDropdownField<String>(
  label: 'Default Model',
  hint: 'Select a model',
  value: selectedModel,
  items: availableModels,
  onChanged: (value) => handleModelChange(value),
  prefixIcon: Icons.model_training_rounded,
)
```

### Button Components

For buttons, use the standardized Lotti button components:

- **`LottiPrimaryButton`**: For primary actions (save, create, etc.)
- **`LottiSecondaryButton`**: For secondary actions (cancel, back, etc.)
- **`LottiTertiaryButton`**: For text-only buttons (dismiss, etc.)

**Usage:**
```dart
Row(
  children: [
    LottiTertiaryButton(
      label: 'Cancel',
      onPressed: onCancel,
    ),
    const SizedBox(width: 12),
    LottiPrimaryButton(
      label: 'Save',
      onPressed: onSave,
      icon: Icons.save_rounded,
    ),
  ],
)
```

### Helper Extensions

#### `FormErrorExtension`
Provides human-readable error messages for form validation errors.

```dart
// Automatically converts enum errors to display messages
validator: (_) => formState.name.error?.displayMessage,
```

## Design Principles

1. **Visual Hierarchy**: Sections create clear groupings, with consistent spacing between elements
2. **Interactive Feedback**: All interactive elements provide immediate visual feedback
3. **Error Prevention**: Validation happens in real-time where appropriate
4. **Accessibility**: All components support keyboard navigation and screen readers
5. **Responsive**: Components adapt to different screen sizes while maintaining usability

## Common Patterns

### Form Layout
```dart
Column(
  children: [
    AiFormSection(
      title: 'Section 1',
      children: [
        AiTextField(...),
        const SizedBox(height: 20),
        AiTextField(...),
      ],
    ),
    const SizedBox(height: 32),
    AiFormSection(
      title: 'Section 2',
      children: [...],
    ),
    const SizedBox(height: 40),
    // Action buttons at bottom
    Row(
      children: [
        Expanded(
          child: LottiTertiaryButton(
            label: 'Cancel',
            onPressed: onCancel,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: LottiPrimaryButton(
            label: 'Save',
            onPressed: onSave,
          ),
        ),
      ],
    ),
  ],
)
```

### Modal Integration
These components work seamlessly with the selection modals in the parent directory, maintaining consistent styling between form fields and modal selections.

## Best Practices

1. **Always use `AiFormSection`** to group related fields
2. **Provide meaningful hints** in text fields to guide users
3. **Use appropriate icons** to help users quickly identify field purposes
4. **Enable/disable save buttons** based on form validity
5. **Show validation errors** immediately when users interact with fields
6. **Use consistent spacing**: 20px between fields, 32px between sections
7. **Use standardized button components** for consistency across the app

## Testing

When testing forms that use these components:
- Look for semantic elements (text labels, buttons) rather than implementation details
- Test user interactions (tapping, entering text) rather than internal state
- Verify error messages appear when expected
- Ensure keyboard shortcuts (like Cmd+S) work when form is valid

## Future Enhancements

- Additional field types (date picker, color picker, etc.)
- Animation support for form transitions
- Theme customization options
- Enhanced accessibility features
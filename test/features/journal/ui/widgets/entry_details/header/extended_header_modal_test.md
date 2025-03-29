# Testing the ExtendedHeaderModal Component

The `ExtendedHeaderModal` component is a complex component with many dependencies. When writing tests for this component, there are several considerations to be aware of:

## Required Mocks

To properly test this component, you need to mock the following services and providers:

1. `TagsService` - For handling tag operations
2. `LinkService` - For handling link operations
3. `JournalDb` - For database operations
4. `PersistenceLogic` - Critical for many operations in the modal
5. `EditorStateService` - For editor state management
6. `UpdateNotifications` - For handling update notifications
7. Riverpod Providers - Several providers need to be mocked, particularly:
   - `entryControllerProvider` - For entry state management
   - `linkedEntriesControllerProvider` - For linked entries state management

## Test Strategy

Due to the complexity of this component, it's recommended to:

1. **Test individual components separately** - Test the small widgets inside the modal (DeleteIconListTile, TogglePrivateListTile, etc.) in isolation.

2. **Manual Testing for Navigation** - For testing navigation between modal pages, manual testing is more practical as it's challenging to properly mock all the dependencies needed for automated testing.

3. **Integration Tests** - Consider using Flutter integration tests instead of widget tests for this component to ensure all dependencies are properly available.

## How The Modal Works

The modal uses the `WoltModalSheet` to show different pages:

1. Initial page with action items (delete, link, tag, etc.)
2. Tags modal page for managing tags
3. Speech recognition modal page
4. Transcription progress modal page

Navigation between these pages is managed by a `ValueNotifier<int>` that is passed to the modal components.

## Example Test Cases

For individual components, test cases should include:

- Tapping on each action item and verifying the correct service method is called
- Verifying conditional rendering (e.g., showing/hiding options based on props)
- Testing specific functionality like toggling private status

## Common Issues

- **GetIt Service Dependencies**: Many components rely on GetIt for service location, which can be challenging to mock in tests.
- **Riverpod Providers**: The components use Riverpod providers which need to be properly overridden in tests.
- **Nested Navigation**: The multi-page modal structure makes navigation testing complex.

For any substantial changes to this component, consider manually testing the full flow to ensure all pages and navigation work correctly. 
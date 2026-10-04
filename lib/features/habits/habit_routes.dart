/// Route helpers for the habits tab (`/habits/...`).
///
/// `HabitsLocation` in the app shell serves these paths. The habits pages
/// reach them through these helpers rather than through the location, since
/// the shell ranks above this feature and the feature may not import it.
library;

/// The root path of the habits tab.
const String habitsRootPath = '/habits';

/// The route that creates a habit.
const String habitCreatePath = '$habitsRootPath/create';

/// The route that edits the habit [habitId].
String habitEditPath(String habitId) => '$habitsRootPath/edit/$habitId';

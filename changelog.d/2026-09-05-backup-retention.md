### Fixed
- **Database safety copies piled up forever.** Every database upgrade and
  every "purge deleted entries" run wrote a full copy of the database into the
  app's backup folder, and nothing ever removed one, so the folder kept
  growing for as long as the app was used. The app now keeps only the three
  most recent copies of each database.

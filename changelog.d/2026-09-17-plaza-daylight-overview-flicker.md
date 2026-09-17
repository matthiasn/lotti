### Fixed
- **The daylight district no longer flickers on the way up to Overview.** In
  daylight, the teal route ribbons that appear on the roads from the air sat
  at exactly the height of the shade every building throws, so wherever a
  shadow crossed a road the two fought over each pixel and the ribbon
  sparkled as the camera moved. The ribbons now sit just under the shade.
  The surrounding city blocks that the map view hides also used to leave
  their shadows behind, so the ground around a district was covered in shade
  with nothing casting it; their shade now goes with them. And the camera's
  near plane grows with its altitude, so from the air the shade keeps clear
  of the pavement however large the project is.

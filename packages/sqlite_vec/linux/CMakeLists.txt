cmake_minimum_required(VERSION 3.10)
project(sqlite_vec LANGUAGES C)

add_subdirectory("../src" sqlite_vec_build)

# List of absolute paths to libraries that should be bundled with the plugin.
set(sqlite_vec_bundled_libraries
  "$<TARGET_FILE:sqlite_vec>"
  PARENT_SCOPE
)

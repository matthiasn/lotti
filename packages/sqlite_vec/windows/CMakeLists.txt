cmake_minimum_required(VERSION 3.14)
project(sqlite_vec LANGUAGES C)

add_subdirectory("../src" sqlite_vec_build)

# Install the DLL next to the executable so Flutter bundles it.
install(TARGETS sqlite_vec
  RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  LIBRARY DESTINATION "${CMAKE_INSTALL_PREFIX}"
)

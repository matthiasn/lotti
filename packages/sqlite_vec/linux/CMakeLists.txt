cmake_minimum_required(VERSION 3.10)
project(sqlite_vec LANGUAGES C)

add_subdirectory("../src" sqlite_vec_build)

# Install the shared library so Flutter bundles it.
install(TARGETS sqlite_vec LIBRARY DESTINATION "${CMAKE_INSTALL_PREFIX}/lib")

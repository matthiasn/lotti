cmake_minimum_required(VERSION 3.10)
project(sqlite_vec LANGUAGES C)

add_library(sqlite_vec SHARED
  sqlite-vec.c
)

target_compile_options(sqlite_vec PRIVATE
  -O3
)

# Enable NEON on ARM64
if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64|ARM64")
  target_compile_options(sqlite_vec PRIVATE -DSQLITE_VEC_ENABLE_NEON)
endif()

# Enable AVX on x86_64
if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64")
  target_compile_options(sqlite_vec PRIVATE -DSQLITE_VEC_ENABLE_AVX)
endif()

# Link math library on Linux
if(UNIX AND NOT APPLE)
  target_link_libraries(sqlite_vec PRIVATE m)
endif()

set_target_properties(sqlite_vec PROPERTIES
  PUBLIC_HEADER sqlite-vec.h
  OUTPUT_NAME "sqlite_vec"
)

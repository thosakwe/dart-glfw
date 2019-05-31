find_package(Dart REQUIRED)

add_dart_native_extension(glfw_extension
  src/glfw_extension.h src/glfw_extension.cc
  src/instantiate_glfw_classes.h src/instantiate_glfw_classes.cc
  src/manual_bindings.h src/manual_bindings.cc
  src/util.h src/util.cc
  src/generated/function_list.h src/generated/function_list.cc
  src/generated/glfw_bindings.h src/generated/glfw_bindings.cc
)

# Find and include GLFW...
find_library(GLFW3_LIBRARY NAMES glfw3 glfw)
find_path(GLFW3_INCLUDE_DIR GLFW/glfw3.h)
target_include_directories(glfw_extension PUBLIC ${GLFW3_INCLUDE_DIR})
target_link_libraries(glfw_extension ${GLFW3_LIBRARY})

# Install it to lib/src.
install(TARGETS glfw_extension LIBRARY DESTINATION "${CMAKE_CURRENT_LIST_DIR}/src")

cmake_minimum_required(VERSION 3.8)
project(action_tutorials_interfaces_ex)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

find_package(ament_cmake REQUIRED)
# --- DIPENDENZE AGGIUNTE ---
find_package(rosidl_default_generators REQUIRED)
find_package(action_msgs REQUIRED)

# Generazione delle interfacce [cite: 434]
rosidl_generate_interfaces(${PROJECT_NAME}
  "action/MoveX.action"
  "action/Rotate.action"
  DEPENDENCIES action_msgs
)
# ---------------------------

if(BUILD_TESTING)
  find_package(ament_lint_auto REQUIRED)
  set(ament_cmake_copyright_FOUND TRUE)
  set(ament_cmake_cpplint_FOUND TRUE)
  ament_lint_auto_find_test_dependencies()
endif()

ament_package()
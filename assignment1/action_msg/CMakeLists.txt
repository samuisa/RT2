cmake_minimum_required(VERSION 3.8)
project(action_msg)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

find_package(ament_cmake REQUIRED)
# These two are required to generate actions
find_package(rosidl_default_generators REQUIRED)
find_package(action_msgs REQUIRED)

# Generate the C++ interfaces
rosidl_generate_interfaces(${PROJECT_NAME}
  "action/Linear.action"
  "action/Angular.action"
  DEPENDENCIES action_msgs
)

ament_package()
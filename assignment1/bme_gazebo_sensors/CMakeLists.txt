cmake_minimum_required(VERSION 3.8)
project(bme_gazebo_sensors)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(rclcpp_action REQUIRED)
find_package(rclcpp_components REQUIRED)
find_package(geometry_msgs REQUIRED)
find_package(nav_msgs REQUIRED)
find_package(action_msg REQUIRED)
find_package(tf2 REQUIRED)
find_package(tf2_ros REQUIRED)

# 1. Action Server Component
add_library(move_server_component SHARED src/move_server.cpp)
ament_target_dependencies(move_server_component 
  rclcpp 
  rclcpp_action 
  rclcpp_components 
  geometry_msgs 
  nav_msgs 
  action_msg 
  tf2       # <-- AGGIUNTO
  tf2_ros   # <-- AGGIUNTO
)
rclcpp_components_register_node(move_server_component
  PLUGIN "bme_gazebo_sensors::MoveActionServer"
  EXECUTABLE move_server_node
)

# 2. UI Client Component
add_library(user_interface_component SHARED src/user_interface.cpp)
ament_target_dependencies(user_interface_component 
  rclcpp rclcpp_action rclcpp_components action_msg)
rclcpp_components_register_node(user_interface_component
  PLUGIN "bme_gazebo_sensors::UserInterface"
  EXECUTABLE user_interface_node
)

install(TARGETS
  move_server_component
  user_interface_component
  ARCHIVE DESTINATION lib
  LIBRARY DESTINATION lib
  RUNTIME DESTINATION bin
)

install(DIRECTORY launch worlds rviz urdf meshes config
  DESTINATION share/${PROJECT_NAME}
)

ament_package()
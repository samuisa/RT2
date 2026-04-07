cmake_minimum_required(VERSION 3.8)
project(bme_gazebo_sensors)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# find dependencies
find_package(ament_cmake REQUIRED)
find_package(action_tutorials_interfaces_ex REQUIRED)

# --- NUOVE DIPENDENZE PER IL COMPONENTE C++ ---
find_package(rclcpp REQUIRED)
find_package(rclcpp_action REQUIRED)
find_package(rclcpp_components REQUIRED)
find_package(geometry_msgs REQUIRED)
find_package(nav_msgs REQUIRED)

# ---> AGGIUNTO QUI: trova il pacchetto turtlesim
find_package(turtlesim REQUIRED) 

if(BUILD_TESTING)
  find_package(ament_lint_auto REQUIRED)
  set(ament_cmake_copyright_FOUND TRUE)
  set(ament_cmake_cpplint_FOUND TRUE)
  ament_lint_auto_find_test_dependencies()
endif()

# --- COSTRUZIONE DELLA LIBRERIA CONDIVISA (PLUGIN) ---
add_library(move_x_component SHARED src/move_x_component.cpp)

ament_target_dependencies(move_x_component 
  rclcpp 
  rclcpp_action 
  rclcpp_components 
  geometry_msgs 
  nav_msgs 
  action_tutorials_interfaces_ex
  turtlesim # ---> AGGIUNTO QUI: collega le dipendenze al target
)

# Registra la libreria come Componente ROS 2 ed espone l'eseguibile autonomo
rclcpp_components_register_node(move_x_component 
  PLUGIN "bme_gazebo_sensors::MoveXActionServer" 
  EXECUTABLE move_x_server_exe
)

ament_export_targets(export_${PROJECT_NAME}_move_x_component)

# --- REGOLE DI INSTALLAZIONE ---
install(DIRECTORY
  launch
  worlds
  rviz
  urdf
  meshes
  config
  DESTINATION share/${PROJECT_NAME}
)

# Installa gli script python (il tuo vecchio server python e il client)
install(PROGRAMS
  src/move_x_action.py
  DESTINATION lib/${PROJECT_NAME}
)

# Installa il Componente C++ compilato
install(TARGETS move_x_component
  EXPORT export_${PROJECT_NAME}_move_x_component
  ARCHIVE DESTINATION lib
  LIBRARY DESTINATION lib
  RUNTIME DESTINATION bin
)

ament_package()